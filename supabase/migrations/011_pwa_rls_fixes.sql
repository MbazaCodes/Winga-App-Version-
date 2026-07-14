-- ============================================================
-- Migration 011: Fix RLS + Missing Columns for PWA
-- Run this in Supabase SQL Editor:
-- https://supabase.com/dashboard/project/kevdbsyiqelksxvmuped/sql/new
-- ============================================================

-- ── 1. Fix requests RLS (403/409 errors when booking or viewing) ─────────────
ALTER TABLE public.requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "requests_customer_own"      ON public.requests;
DROP POLICY IF EXISTS "requests_customer_select"   ON public.requests;
DROP POLICY IF EXISTS "requests_customer_insert"   ON public.requests;
DROP POLICY IF EXISTS "requests_customer_update"   ON public.requests;
DROP POLICY IF EXISTS "requests_winga_assigned"    ON public.requests;
DROP POLICY IF EXISTS "requests_winga_view"        ON public.requests;
DROP POLICY IF EXISTS "requests_winga_searching"   ON public.requests;
DROP POLICY IF EXISTS "requests_winga_update"      ON public.requests;
DROP POLICY IF EXISTS "requests_admin"             ON public.requests;

CREATE POLICY "requests_customer_select" ON public.requests
  FOR SELECT USING (auth.uid() = customer_id);
CREATE POLICY "requests_customer_insert" ON public.requests
  FOR INSERT WITH CHECK (auth.uid() = customer_id);
CREATE POLICY "requests_customer_update" ON public.requests
  FOR UPDATE USING (auth.uid() = customer_id);
CREATE POLICY "requests_winga_view" ON public.requests
  FOR SELECT USING (
    status = 'searching'
    OR winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid())
  );
CREATE POLICY "requests_winga_update" ON public.requests
  FOR UPDATE USING (
    winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid())
  );
CREATE POLICY "requests_admin" ON public.requests
  FOR ALL USING (public.is_admin());

-- ── 2. Fix wingas RLS (403 when registering as Winga) ────────────────────────
ALTER TABLE public.wingas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wingas_public_active"  ON public.wingas;
DROP POLICY IF EXISTS "wingas_public_read"    ON public.wingas;
DROP POLICY IF EXISTS "wingas_own"            ON public.wingas;
DROP POLICY IF EXISTS "wingas_own_update"     ON public.wingas;
DROP POLICY IF EXISTS "wingas_insert"         ON public.wingas;
DROP POLICY IF EXISTS "wingas_admin_all"      ON public.wingas;
DROP POLICY IF EXISTS "wingas_admin"          ON public.wingas;

CREATE POLICY "wingas_public_read" ON public.wingas
  FOR SELECT USING (
    (status = 'active' AND verification_status = 'verified')
    OR user_id = auth.uid()
    OR public.is_admin()
  );
CREATE POLICY "wingas_insert" ON public.wingas
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "wingas_own_update" ON public.wingas
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "wingas_admin" ON public.wingas
  FOR ALL USING (public.is_admin());

-- ── 3. Fix users RLS (allow OTP registration to upsert) ──────────────────────
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_own_read"    ON public.users;
DROP POLICY IF EXISTS "users_own_update"  ON public.users;
DROP POLICY IF EXISTS "users_insert"      ON public.users;
DROP POLICY IF EXISTS "users_upsert"      ON public.users;
DROP POLICY IF EXISTS "admin_all_users"   ON public.users;

CREATE POLICY "users_own_read"   ON public.users FOR SELECT USING (auth.uid() = id OR public.is_admin());
CREATE POLICY "users_insert"     ON public.users FOR INSERT WITH CHECK (true);
CREATE POLICY "users_own_update" ON public.users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "admin_all_users"  ON public.users FOR ALL USING (public.is_admin());

-- ── 4. Explicit GRANTS (required alongside RLS) ───────────────────────────────
GRANT SELECT, INSERT, UPDATE ON public.requests  TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.wingas    TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.users     TO authenticated;
GRANT SELECT                 ON public.wingas    TO anon;
GRANT SELECT                 ON public.verification_tiers TO anon, authenticated;

-- ── 5. Add missing columns (safe — IF NOT EXISTS) ─────────────────────────────
ALTER TABLE public.wingas
  ADD COLUMN IF NOT EXISTS total_points  INT     NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rated_trips   INT     NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS point_rate    NUMERIC(5,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS winga_score   NUMERIC(6,4) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_top_rated  BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS current_city  TEXT,
  ADD COLUMN IF NOT EXISTS current_area  TEXT,
  ADD COLUMN IF NOT EXISTS current_lat   NUMERIC(10,7),
  ADD COLUMN IF NOT EXISTS current_lng   NUMERIC(10,7),
  ADD COLUMN IF NOT EXISTS bio           TEXT;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS wallet_balance INT NOT NULL DEFAULT 0;

ALTER TABLE public.requests
  ADD COLUMN IF NOT EXISTS city         TEXT,
  ADD COLUMN IF NOT EXISTS area         TEXT,
  ADD COLUMN IF NOT EXISTS total_price  INT;

-- Done
SELECT 'Migration 011 complete ✅' AS result;
