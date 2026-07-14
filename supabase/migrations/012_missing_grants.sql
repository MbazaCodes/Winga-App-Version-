-- ============================================================
-- Migration 012: Fix missing RLS grants for PWA tables
-- Run in Supabase SQL Editor:
-- https://supabase.com/dashboard/project/kevdbsyiqelksxvmuped/sql/new
-- ============================================================

-- ── winga_points: grant SELECT to authenticated (fixes "permission denied for table winga_points") ──
ALTER TABLE public.winga_points ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "points_public_read"  ON public.winga_points;
DROP POLICY IF EXISTS "points_customer_own" ON public.winga_points;
DROP POLICY IF EXISTS "points_admin"        ON public.winga_points;
DROP POLICY IF EXISTS "points_winga_view"   ON public.winga_points;

-- Anyone can read points (they drive public reputation + needed for requests join)
CREATE POLICY "points_public_read" ON public.winga_points
  FOR SELECT USING (true);

-- Only the rating customer can insert
CREATE POLICY "points_customer_own" ON public.winga_points
  FOR INSERT WITH CHECK (auth.uid() = customer_id);

-- Admin full access
CREATE POLICY "points_admin" ON public.winga_points
  FOR ALL USING (public.is_admin());

-- Explicit grant (required alongside RLS)
GRANT SELECT          ON public.winga_points TO anon, authenticated;
GRANT INSERT          ON public.winga_points TO authenticated;

-- ── messages: grant SELECT + INSERT ──────────────────────────────────────────
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "messages_participants" ON public.messages;
DROP POLICY IF EXISTS "messages_admin"        ON public.messages;

CREATE POLICY "messages_participants" ON public.messages
  FOR ALL USING (
    request_id IN (
      SELECT id FROM public.requests
      WHERE customer_id = auth.uid()
         OR winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid())
    )
  );
CREATE POLICY "messages_admin" ON public.messages
  FOR ALL USING (public.is_admin());

GRANT SELECT, INSERT ON public.messages TO authenticated;

-- ── tips: grant SELECT + INSERT ───────────────────────────────────────────────
ALTER TABLE public.tips ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tips_customer_own" ON public.tips;
DROP POLICY IF EXISTS "tips_winga_view"   ON public.tips;

CREATE POLICY "tips_customer_own" ON public.tips
  FOR ALL USING (auth.uid() = customer_id);
CREATE POLICY "tips_winga_view" ON public.tips
  FOR SELECT USING (
    winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid())
  );

GRANT SELECT, INSERT ON public.tips TO authenticated;

-- ── winga_availability: public read ──────────────────────────────────────────
DO $$ BEGIN
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'winga_availability') THEN
    GRANT SELECT ON public.winga_availability TO anon, authenticated;
  END IF;
END $$;

-- ── locations: public read ────────────────────────────────────────────────────
DO $$ BEGIN
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'locations') THEN
    GRANT SELECT ON public.locations TO anon, authenticated;
  END IF;
END $$;

-- ── notifications: own read ───────────────────────────────────────────────────
DO $$ BEGIN
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'notifications') THEN
    ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
    GRANT SELECT, UPDATE ON public.notifications TO authenticated;
  END IF;
END $$;

-- ── rate_winga RPC grant ──────────────────────────────────────────────────────
DO $$ BEGIN
  IF EXISTS (SELECT FROM pg_proc WHERE proname = 'rate_winga') THEN
    GRANT EXECUTE ON FUNCTION public.rate_winga(UUID, INT, TEXT) TO authenticated;
  END IF;
END $$;

SELECT 'Migration 012 complete ✅' AS result;
