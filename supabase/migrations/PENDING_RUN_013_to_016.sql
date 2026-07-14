-- ============================================================
-- PENDING MIGRATIONS 013–016 — Run ALL at once
-- Paste this entire file into Supabase SQL Editor:
-- https://supabase.com/dashboard/project/kevdbsyiqelksxvmuped/sql/new
-- Safe to re-run (uses IF NOT EXISTS + DROP IF EXISTS)
-- ============================================================


-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Migration 013: TIN, social media, profile photo fields     ║
-- ╚══════════════════════════════════════════════════════════════╝
ALTER TABLE public.wingas
  ADD COLUMN IF NOT EXISTS tin_number        TEXT,
  ADD COLUMN IF NOT EXISTS instagram         TEXT,
  ADD COLUMN IF NOT EXISTS facebook          TEXT,
  ADD COLUMN IF NOT EXISTS tiktok            TEXT,
  ADD COLUMN IF NOT EXISTS twitter           TEXT,
  ADD COLUMN IF NOT EXISTS whatsapp          TEXT,
  ADD COLUMN IF NOT EXISTS profile_photo_url TEXT;

GRANT UPDATE ON public.users  TO authenticated;
GRANT UPDATE ON public.wingas TO authenticated;
SELECT '013 ✅' AS result;


-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Migration 014: Sequence fix + NIDA + profile completion    ║
-- ╚══════════════════════════════════════════════════════════════╝

-- 1. Fix "permission denied for sequence winga_id_seq"
GRANT USAGE, SELECT ON SEQUENCE public.winga_id_seq TO authenticated, anon;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated, anon;

-- 2. Make winga_id trigger SECURITY DEFINER (bulletproof)
CREATE OR REPLACE FUNCTION public.generate_winga_id()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.winga_id IS NULL OR NEW.winga_id = '' THEN
    NEW.winga_id = 'WNGA' || LPAD(nextval('winga_id_seq')::TEXT, 5, '0');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Add NIDA + profile completion columns
ALTER TABLE public.wingas
  ADD COLUMN IF NOT EXISTS national_id      TEXT,
  ADD COLUMN IF NOT EXISTS profile_complete BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS completion_pct   INT NOT NULL DEFAULT 0;

-- 4. Profile completion calculator
CREATE OR REPLACE FUNCTION public.calc_winga_completion(p_id UUID)
RETURNS INT AS $$
DECLARE w RECORD; s INT := 0;
BEGIN
  SELECT * INTO w FROM public.wingas WHERE id = p_id;
  IF NOT FOUND THEN RETURN 0; END IF;
  IF w.name IS NOT NULL AND trim(w.name) <> '' THEN s := s + 15; END IF;
  IF w.phone IS NOT NULL AND trim(w.phone) <> '' THEN s := s + 15; END IF;
  IF w.specialty IS NOT NULL AND trim(w.specialty) <> '' THEN s := s + 15; END IF;
  IF w.current_city IS NOT NULL AND trim(w.current_city) <> '' THEN s := s + 10; END IF;
  IF w.national_id IS NOT NULL AND trim(w.national_id) <> '' THEN s := s + 20; END IF;
  IF w.profile_photo_url IS NOT NULL AND trim(w.profile_photo_url) <> '' THEN s := s + 15; END IF;
  IF w.tin_number IS NOT NULL AND trim(w.tin_number) <> '' THEN s := s + 10; END IF;
  RETURN LEAST(s, 100);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

GRANT EXECUTE ON FUNCTION public.calc_winga_completion(UUID) TO authenticated;

-- 5. Auto-update completion on every winga save
CREATE OR REPLACE FUNCTION public.update_winga_completion()
RETURNS TRIGGER AS $$
DECLARE pct INT;
BEGIN
  pct := public.calc_winga_completion(NEW.id);
  NEW.completion_pct   := pct;
  NEW.profile_complete := (pct >= 75);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_winga_completion ON public.wingas;
CREATE TRIGGER trg_winga_completion
  BEFORE INSERT OR UPDATE ON public.wingas
  FOR EACH ROW EXECUTE FUNCTION public.update_winga_completion();

-- 6. Lookup Winga by Winga ID (for login flow)
CREATE OR REPLACE FUNCTION public.find_user_by_winga_id(p_winga_id TEXT)
RETURNS TABLE (user_id UUID, phone TEXT, name TEXT) AS $$
  SELECT w.user_id, u.phone, w.name
  FROM public.wingas w
  JOIN public.users u ON u.id = w.user_id
  WHERE UPPER(w.winga_id) = UPPER(p_winga_id)
  LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

GRANT EXECUTE ON FUNCTION public.find_user_by_winga_id(TEXT) TO anon, authenticated;

-- 7. Refresh completion for existing wingas
UPDATE public.wingas SET updated_at = NOW() WHERE TRUE;

SELECT '014 ✅' AS result;


-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Migration 015: Enable Supabase Realtime on key tables     ║
-- ╚══════════════════════════════════════════════════════════════╝
DO $$
BEGIN
  -- requests
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'requests'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.requests;
  END IF;
  -- wingas
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'wingas'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.wingas;
  END IF;
  -- messages
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;
END $$;

SELECT '015 ✅' AS result;


-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Migration 016: Claim policies + all sequence grants        ║
-- ╚══════════════════════════════════════════════════════════════╝

-- Winga can claim a searching request
DROP POLICY IF EXISTS "requests_winga_claim"  ON public.requests;
CREATE POLICY "requests_winga_claim" ON public.requests
  FOR UPDATE
  USING (status = 'searching')
  WITH CHECK (
    winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid())
    OR winga_id IS NULL
  );

-- Winga updates their assigned requests
DROP POLICY IF EXISTS "requests_winga_update" ON public.requests;
CREATE POLICY "requests_winga_update" ON public.requests
  FOR UPDATE
  USING (
    winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid())
  );

-- Customer inserts with their own uid
DROP POLICY IF EXISTS "requests_customer_insert" ON public.requests;
CREATE POLICY "requests_customer_insert" ON public.requests
  FOR INSERT WITH CHECK (auth.uid() = customer_id);

-- Final sequence grant
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated, anon;

SELECT '016 ✅ — All migrations complete' AS result;
