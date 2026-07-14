-- ============================================================
-- Migration 015: Enable Realtime + Fix Request Claim Permissions
-- ============================================================
-- RUN THIS IN SUPABASE SQL EDITOR:
-- https://supabase.com/dashboard/project/kevdbsyiqelksxvmuped/sql/new
-- ============================================================

-- ── 1. ENABLE REALTIME ON requests TABLE ─────────────────────────
-- This is THE FIX for notifications not working.
-- Without this, NO postgres_changes events fire on the requests table.
-- Both Winga and Customer rely on this.

-- Add tables to supabase_realtime publication (idempotent)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='requests') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.requests;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='wingas') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.wingas;
  END IF;
END $$;


-- ── 2. FIX: Allow Winga to UPDATE searching requests ─────────────
-- The "claim" operation does:
--   UPDATE requests SET winga_id=X, status='accepted'
--   WHERE id=Y AND winga_id IS NULL AND status='searching'
--
-- The existing 'requests_winga_update' policy requires:
--   winga_id IN (SELECT id FROM wingas WHERE user_id = auth.uid())
-- But at claim time, winga_id IS NULL — so this policy NEVER matches!
-- This new policy allows a Winga to claim unassigned requests.

DROP POLICY IF EXISTS "requests_winga_claim" ON public.requests;
CREATE POLICY "requests_winga_claim" ON public.requests
  FOR UPDATE USING (
    status = 'searching'
    AND winga_id IS NULL
    AND EXISTS (
      SELECT 1 FROM public.wingas
      WHERE user_id = auth.uid()
        AND status = 'active'
        AND profile_complete = true
    )
  )
  WITH CHECK (
    status IN ('accepted', 'searching')
  );


-- ── 3. Allow Winga to UPDATE their own assigned requests ─────────
-- For status transitions: accepted → shopping → completed
-- (The existing policy handles this, but let's be explicit)

DROP POLICY IF EXISTS "requests_winga_update" ON public.requests;
CREATE POLICY "requests_winga_update" ON public.requests
  FOR UPDATE USING (
    winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid())
  );


-- ── 4. Allow customers to INSERT requests ─────────────────────────
-- (Already covered by 'requests_customer_own' FOR ALL, but be explicit)

DROP POLICY IF EXISTS "requests_customer_insert" ON public.requests;
CREATE POLICY "requests_customer_insert" ON public.requests
  FOR INSERT WITH CHECK (auth.uid() = customer_id);


-- ── 5. Grant USAGE on sequences for request triggers ─────────────
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated, anon;


-- ═══ VERIFY ═══
SELECT 'Migration 015 complete — Realtime ENABLED on requests + wingas tables ✅' AS result;
SELECT tablename FROM pg_tables WHERE schemaname = 'pg_catalog'
  AND tablename = 'pg_publication_tables'
  UNION ALL
SELECT tablename FROM pg_publication_tables
  WHERE pubname = 'supabase_realtime'
  AND schemaname = 'public';