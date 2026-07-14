-- ============================================================
-- Winga App — Migration 002: RLS Policies
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE public.users               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_credentials    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wingas              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.verification_tiers  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.verification_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.winga_documents     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.requests            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_audit_log     ENABLE ROW LEVEL SECURITY;

-- ── Helper: is current user an admin ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND user_type = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ── Users ─────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "users_own_read" ON public.users;
CREATE POLICY "users_own_read"   ON public.users FOR SELECT USING (auth.uid() = id OR public.is_admin());
DROP POLICY IF EXISTS "users_own_update" ON public.users;
CREATE POLICY "users_own_update" ON public.users FOR UPDATE USING (auth.uid() = id);
DROP POLICY IF EXISTS "users_insert" ON public.users;
CREATE POLICY "users_insert"     ON public.users FOR INSERT WITH CHECK (true); -- registration
DROP POLICY IF EXISTS "admin_all_users" ON public.users;
CREATE POLICY "admin_all_users"  ON public.users FOR ALL USING (public.is_admin());

-- ── Verification Tiers (public read) ─────────────────────────────────────
DROP POLICY IF EXISTS "tiers_public_read" ON public.verification_tiers;
CREATE POLICY "tiers_public_read" ON public.verification_tiers FOR SELECT USING (true);
DROP POLICY IF EXISTS "tiers_admin_write" ON public.verification_tiers;
CREATE POLICY "tiers_admin_write" ON public.verification_tiers FOR ALL USING (public.is_admin());

-- ── Wingas ────────────────────────────────────────────────────────────────
-- Public can see active verified wingas
DROP POLICY IF EXISTS "wingas_public_active" ON public.wingas;
CREATE POLICY "wingas_public_active" ON public.wingas
  FOR SELECT USING (status = 'active' AND verification_status = 'verified');

-- Winga sees own profile
DROP POLICY IF EXISTS "wingas_own" ON public.wingas;
CREATE POLICY "wingas_own" ON public.wingas
  FOR ALL USING (auth.uid() = user_id);

-- Admin sees all
DROP POLICY IF EXISTS "wingas_admin_all" ON public.wingas;
CREATE POLICY "wingas_admin_all" ON public.wingas
  FOR ALL USING (public.is_admin());

-- Insert for registration
DROP POLICY IF EXISTS "wingas_insert" ON public.wingas;
CREATE POLICY "wingas_insert" ON public.wingas
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ── Verification Payments ─────────────────────────────────────────────────
DROP POLICY IF EXISTS "ver_payments_own" ON public.verification_payments;
CREATE POLICY "ver_payments_own" ON public.verification_payments
  FOR SELECT USING (
    winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid())
  );
DROP POLICY IF EXISTS "ver_payments_insert" ON public.verification_payments;
CREATE POLICY "ver_payments_insert" ON public.verification_payments
  FOR INSERT WITH CHECK (
    winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid())
  );
DROP POLICY IF EXISTS "ver_payments_admin" ON public.verification_payments;
CREATE POLICY "ver_payments_admin" ON public.verification_payments
  FOR ALL USING (public.is_admin());

-- ── Winga Documents ───────────────────────────────────────────────────────
DROP POLICY IF EXISTS "docs_own" ON public.winga_documents;
CREATE POLICY "docs_own" ON public.winga_documents
  FOR ALL USING (
    winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid())
  );
DROP POLICY IF EXISTS "docs_admin" ON public.winga_documents;
CREATE POLICY "docs_admin" ON public.winga_documents
  FOR ALL USING (public.is_admin());

-- ── Requests ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "requests_customer_own" ON public.requests;
CREATE POLICY "requests_customer_own" ON public.requests
  FOR ALL USING (auth.uid() = customer_id);

DROP POLICY IF EXISTS "requests_winga_assigned" ON public.requests;
CREATE POLICY "requests_winga_assigned" ON public.requests
  FOR SELECT USING (
    winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "requests_winga_searching" ON public.requests;
CREATE POLICY "requests_winga_searching" ON public.requests
  FOR SELECT USING (status = 'searching');

DROP POLICY IF EXISTS "requests_winga_update" ON public.requests;
CREATE POLICY "requests_winga_update" ON public.requests
  FOR UPDATE USING (
    winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "requests_admin" ON public.requests;
CREATE POLICY "requests_admin" ON public.requests
  FOR ALL USING (public.is_admin());

-- ── Transactions ──────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "tx_customer" ON public.transactions;
CREATE POLICY "tx_customer" ON public.transactions
  FOR SELECT USING (auth.uid() = customer_id);
DROP POLICY IF EXISTS "tx_winga" ON public.transactions;
CREATE POLICY "tx_winga" ON public.transactions
  FOR SELECT USING (
    winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid())
  );
DROP POLICY IF EXISTS "tx_admin" ON public.transactions;
CREATE POLICY "tx_admin" ON public.transactions
  FOR ALL USING (public.is_admin());

-- ── Reviews ───────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "reviews_public_read" ON public.reviews;
CREATE POLICY "reviews_public_read"  ON public.reviews FOR SELECT USING (true);
DROP POLICY IF EXISTS "reviews_customer_own" ON public.reviews;
CREATE POLICY "reviews_customer_own" ON public.reviews
  FOR INSERT WITH CHECK (auth.uid() = customer_id);
DROP POLICY IF EXISTS "reviews_admin" ON public.reviews;
CREATE POLICY "reviews_admin" ON public.reviews FOR ALL USING (public.is_admin());

-- ── Notifications ─────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "notifs_own" ON public.notifications;
CREATE POLICY "notifs_own" ON public.notifications
  FOR ALL USING (auth.uid() = user_id);

-- ── Admin Audit Log ───────────────────────────────────────────────────────
DROP POLICY IF EXISTS "audit_admin_only" ON public.admin_audit_log;
CREATE POLICY "audit_admin_only" ON public.admin_audit_log
  FOR ALL USING (public.is_admin());

-- Grant execute to anon/authenticated
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon, authenticated;
