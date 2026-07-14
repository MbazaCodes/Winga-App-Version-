-- ============================================================
-- Migration 016: Claim Policies + Sequence Grants (safe rerun)
-- ============================================================
-- The publication ALTER is already done — this only fixes
-- the RLS policies and grants. Safe to run multiple times.
-- ============================================================

-- ── 1. Allow Winga to CLAIM unassigned requests ──────────────
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

-- ── 2. Allow Winga to UPDATE their own assigned requests ────
DROP POLICY IF EXISTS "requests_winga_update" ON public.requests;
CREATE POLICY "requests_winga_update" ON public.requests
  FOR UPDATE USING (
    winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid())
  );

-- ── 3. Allow customers to INSERT requests ───────────────────
DROP POLICY IF EXISTS "requests_customer_insert" ON public.requests;
CREATE POLICY "requests_customer_insert" ON public.requests
  FOR INSERT WITH CHECK (auth.uid() = customer_id);

-- ── 4. Grant USAGE on all sequences ─────────────────────────
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated, anon;

-- ═══ DONE ═══
SELECT 'Migration 016 complete ✅ — Claim policies + grants applied' AS result;