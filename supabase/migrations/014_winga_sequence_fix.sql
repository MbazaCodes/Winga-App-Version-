-- ============================================================
-- Migration 014: Fix winga_id_seq permission + profile fields
-- Run in Supabase SQL Editor:
-- https://supabase.com/dashboard/project/kevdbsyiqelksxvmuped/sql/new
-- ============================================================

-- ── 1. CRITICAL: Grant sequence usage to authenticated users ────────────────
-- The winga_id trigger calls nextval('winga_id_seq') when a Winga registers.
-- Without this grant, authenticated users get "permission denied for sequence"
GRANT USAGE, SELECT ON SEQUENCE public.winga_id_seq TO authenticated;

-- ── 2. Also grant execute on the trigger function ────────────────────────────
GRANT EXECUTE ON FUNCTION public.generate_winga_id() TO authenticated;

-- ── 3. Add NIDA and profile completion fields to wingas ─────────────────────
ALTER TABLE public.wingas
  ADD COLUMN IF NOT EXISTS national_id       TEXT,      -- NIDA number
  ADD COLUMN IF NOT EXISTS profile_complete  BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS completion_pct    INT NOT NULL DEFAULT 0;

-- ── 4. Function: calculate profile completion % ──────────────────────────────
CREATE OR REPLACE FUNCTION public.calc_winga_completion(p_winga_id UUID)
RETURNS INT AS $$
DECLARE
  w RECORD;
  score INT := 0;
BEGIN
  SELECT * INTO w FROM public.wingas WHERE id = p_winga_id;
  IF NOT FOUND THEN RETURN 0; END IF;

  -- Required fields (each = 14 points, total 7 = 98, +2 for rounding = 100)
  IF w.name IS NOT NULL AND trim(w.name) != '' THEN score := score + 15; END IF;
  IF w.phone IS NOT NULL AND trim(w.phone) != '' THEN score := score + 15; END IF;
  IF w.specialty IS NOT NULL AND trim(w.specialty) != '' THEN score := score + 15; END IF;
  IF w.current_city IS NOT NULL AND trim(w.current_city) != '' THEN score := score + 10; END IF;
  IF w.national_id IS NOT NULL AND trim(w.national_id) != '' THEN score := score + 20; END IF;
  IF w.profile_photo_url IS NOT NULL AND trim(w.profile_photo_url) != '' THEN score := score + 15; END IF;
  IF w.tin_number IS NOT NULL AND trim(w.tin_number) != '' THEN score := score + 10; END IF;

  RETURN LEAST(score, 100);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

GRANT EXECUTE ON FUNCTION public.calc_winga_completion(UUID) TO authenticated;

-- ── 5. Trigger to auto-update completion_pct on winga update ─────────────────
CREATE OR REPLACE FUNCTION public.update_winga_completion()
RETURNS TRIGGER AS $$
DECLARE pct INT;
BEGIN
  pct := public.calc_winga_completion(NEW.id);
  NEW.completion_pct := pct;
  NEW.profile_complete := (pct >= 75);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_winga_completion ON public.wingas;
CREATE TRIGGER trg_winga_completion
  BEFORE INSERT OR UPDATE ON public.wingas
  FOR EACH ROW EXECUTE FUNCTION public.update_winga_completion();

-- ── 6. Update existing wingas completion percentages ─────────────────────────
UPDATE public.wingas SET updated_at = NOW();

-- ── 7. Allow Winga to login with their Winga ID (WNGA10001) ─────────────────
-- The lookup function for the PWA login-by-WingaID flow
CREATE OR REPLACE FUNCTION public.find_user_by_winga_id(p_winga_id TEXT)
RETURNS TABLE (user_id UUID, phone TEXT, name TEXT) AS $$
  SELECT w.user_id, u.phone, w.name
  FROM public.wingas w
  JOIN public.users u ON u.id = w.user_id
  WHERE UPPER(w.winga_id) = UPPER(p_winga_id)
  LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

GRANT EXECUTE ON FUNCTION public.find_user_by_winga_id(TEXT) TO anon, authenticated;

SELECT 'Migration 014 complete ✅' AS result;
