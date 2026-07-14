-- Drop views first (safe re-run)
DROP VIEW IF EXISTS public.v_dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.v_pending_verifications CASCADE;
DROP VIEW IF EXISTS public.v_earnings_summary CASCADE;
DROP VIEW IF EXISTS public.v_winga_leaderboard CASCADE;
DROP VIEW IF EXISTS public.v_recent_activity CASCADE;

-- ============================================================
-- Winga App — Migration 005: Admin Views & Helper Queries
-- For use in Admin Panel (Next.js)
-- ============================================================

-- ── Dashboard Stats View ──────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.v_dashboard_stats AS
SELECT
  (SELECT COUNT(*) FROM public.requests)                                          AS total_requests,
  (SELECT COUNT(*) FROM public.requests WHERE status = 'completed')               AS completed_requests,
  (SELECT COUNT(*) FROM public.requests WHERE status IN ('accepted','shopping'))   AS in_progress,
  (SELECT COUNT(*) FROM public.requests WHERE status = 'cancelled')               AS cancelled,
  (SELECT COUNT(*) FROM public.wingas WHERE status = 'active')                    AS active_wingas,
  (SELECT COUNT(*) FROM public.users WHERE user_type = 'customer')                AS total_clients,
  (SELECT COUNT(*) FROM public.wingas WHERE verification_status = 'under_review') AS pending_verifications,
  (SELECT COALESCE(SUM(winga_payout), 0) FROM public.transactions WHERE status = 'success') AS total_earnings,
  (SELECT COALESCE(SUM(tax), 0) FROM public.transactions WHERE status = 'success')          AS total_tax_collected,
  (SELECT COUNT(*) FROM public.wingas WHERE badge = 'Verified')  AS verified_wingas,
  (SELECT COUNT(*) FROM public.wingas WHERE badge = 'Mid')       AS mid_wingas,
  (SELECT COUNT(*) FROM public.wingas WHERE badge = 'Starter')   AS starter_wingas;

GRANT SELECT ON public.v_dashboard_stats TO authenticated, service_role;

-- ── Pending Verifications View ────────────────────────────────────────────
CREATE OR REPLACE VIEW public.v_pending_verifications AS
SELECT
  w.id,
  w.winga_id,
  w.name,
  w.phone,
  w.email,
  w.specialty,
  w.home_location,
  w.verification_status,
  w.verification_tier,
  w.badge,
  w.created_at,
  vp.amount       AS payment_amount,
  vp.payment_method,
  vp.paid_at,
  vt.name         AS tier_requested,
  vt.monthly_fee  AS tier_fee,
  (SELECT COUNT(*) FROM public.winga_documents wd WHERE wd.winga_id = w.id) AS doc_count,
  (SELECT COUNT(*) FROM public.winga_documents wd WHERE wd.winga_id = w.id AND wd.status = 'approved') AS approved_docs
FROM public.wingas w
LEFT JOIN public.verification_payments vp ON vp.winga_id = w.id AND vp.status = 'success'
  AND vp.paid_at = (SELECT MAX(paid_at) FROM public.verification_payments WHERE winga_id = w.id AND status = 'success')
LEFT JOIN public.verification_tiers vt ON vt.id = vp.tier_id
WHERE w.verification_status IN ('documents_submitted','payment_pending','under_review')
ORDER BY w.created_at ASC;

GRANT SELECT ON public.v_pending_verifications TO authenticated, service_role;

-- ── Earnings Summary View ─────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.v_earnings_summary AS
SELECT
  DATE_TRUNC('day', created_at)   AS day,
  DATE_TRUNC('week', created_at)  AS week,
  DATE_TRUNC('month', created_at) AS month,
  SUM(gross_amount)               AS gross,
  SUM(platform_fee)               AS platform_fee,
  SUM(winga_payout)               AS winga_payout,
  SUM(tax)                        AS tax,
  COUNT(*)                        AS transaction_count
FROM public.transactions
WHERE status = 'success'
GROUP BY 1, 2, 3
ORDER BY 1 DESC;

GRANT SELECT ON public.v_earnings_summary TO authenticated, service_role;

-- ── Winga Leaderboard View ────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.v_winga_leaderboard AS
SELECT
  w.id,
  w.winga_id,
  w.name,
  w.specialty,
  w.badge,
  w.rating,
  w.total_trips,
  w.completion_rate,
  w.total_earnings,
  w.status,
  w.is_online,
  RANK() OVER (ORDER BY w.total_earnings DESC) AS earnings_rank,
  RANK() OVER (ORDER BY w.rating DESC, w.total_trips DESC) AS rating_rank
FROM public.wingas w
WHERE w.status = 'active'
ORDER BY w.total_earnings DESC;

GRANT SELECT ON public.v_winga_leaderboard TO authenticated, service_role;

-- ── Recent Activity View (for admin dashboard feed) ───────────────────────
CREATE OR REPLACE VIEW public.v_recent_activity AS
  SELECT 'request' AS type, r.id, r.created_at,
    u.name AS actor, r.category AS detail, r.status
  FROM public.requests r
  JOIN public.users u ON u.id = r.customer_id
UNION ALL
  SELECT 'payment', p.id, p.created_at,
    w.name AS actor, vt.name AS detail, p.status
  FROM public.verification_payments p
  JOIN public.wingas w ON w.id = p.winga_id
  JOIN public.verification_tiers vt ON vt.id = p.tier_id
UNION ALL
  SELECT 'transaction', t.id, t.created_at,
    u.name AS actor, 'TZS ' || t.gross_amount::TEXT AS detail, t.status
  FROM public.transactions t
  JOIN public.users u ON u.id = t.customer_id
ORDER BY created_at DESC
LIMIT 50;

GRANT SELECT ON public.v_recent_activity TO authenticated, service_role;

-- ── RPC: Get dashboard stats (safe for anon with RLS) ─────────────────────
CREATE OR REPLACE FUNCTION public.get_dashboard_stats()
RETURNS JSONB AS $$
DECLARE
  result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'total_requests',         (SELECT COUNT(*) FROM public.requests),
    'completed_requests',     (SELECT COUNT(*) FROM public.requests WHERE status = 'completed'),
    'in_progress',            (SELECT COUNT(*) FROM public.requests WHERE status IN ('accepted','shopping')),
    'cancelled',              (SELECT COUNT(*) FROM public.requests WHERE status = 'cancelled'),
    'active_wingas',          (SELECT COUNT(*) FROM public.wingas WHERE status = 'active'),
    'total_clients',          (SELECT COUNT(*) FROM public.users WHERE user_type = 'customer'),
    'pending_verifications',  (SELECT COUNT(*) FROM public.wingas WHERE verification_status = 'under_review'),
    'total_earnings',         (SELECT COALESCE(SUM(winga_payout),0) FROM public.transactions WHERE status = 'success'),
    'total_tax',              (SELECT COALESCE(SUM(tax),0) FROM public.transactions WHERE status = 'success'),
    'verified_wingas',        (SELECT COUNT(*) FROM public.wingas WHERE badge = 'Verified'),
    'mid_wingas',             (SELECT COUNT(*) FROM public.wingas WHERE badge = 'Mid'),
    'starter_wingas',         (SELECT COUNT(*) FROM public.wingas WHERE badge = 'Starter'),
    'new_wingas_this_week',   (SELECT COUNT(*) FROM public.wingas WHERE created_at >= NOW() - INTERVAL '7 days'),
    'new_clients_this_week',  (SELECT COUNT(*) FROM public.users WHERE user_type = 'customer' AND created_at >= NOW() - INTERVAL '7 days')
  ) INTO result;
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

GRANT EXECUTE ON FUNCTION public.get_dashboard_stats() TO authenticated, service_role;
