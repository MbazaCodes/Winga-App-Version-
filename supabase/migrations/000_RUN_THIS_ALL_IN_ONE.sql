-- ============================================================
-- Winga App — COMPLETE DATABASE SETUP (All-in-One)
-- Run this ENTIRE file in the Supabase SQL Editor.
-- https://supabase.com/dashboard/project/kevdbsyiqelksxvmuped/sql/new
-- Safe to re-run: drops and rebuilds everything.
-- ============================================================

DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON SCHEMA public TO public;

-- ============================================================
-- Winga App — Migration 001: Initial Schema
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ── Users ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.users (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone             TEXT UNIQUE NOT NULL,
  email             TEXT UNIQUE,
  name              TEXT,
  profile_image_url TEXT,
  user_type         TEXT NOT NULL DEFAULT 'customer'
                    CHECK (user_type IN ('customer', 'winga', 'admin')),
  is_verified       BOOLEAN NOT NULL DEFAULT FALSE,
  fcm_token         TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── User Credentials (bypass auth — dev & production OTP alternative) ─────
CREATE TABLE IF NOT EXISTS public.user_credentials (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  phone         TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Winga Verification Fee Tiers ──────────────────────────────────────────
-- Starter: TZS 5,000/month  — basic listing
-- Mid:     TZS 15,000/month — priority listing + badge
-- Verified:TZS 30,000/month — top listing + gold badge + featured

CREATE TABLE IF NOT EXISTS public.verification_tiers (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name         TEXT UNIQUE NOT NULL CHECK (name IN ('Starter', 'Mid', 'Verified')),
  monthly_fee  INT NOT NULL,
  description  TEXT NOT NULL,
  features     JSONB NOT NULL DEFAULT '[]',
  badge_color  TEXT NOT NULL,
  sort_order   INT NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed tiers
INSERT INTO public.verification_tiers (name, monthly_fee, description, badge_color, sort_order, features) VALUES
  ('Starter',  5000,  'Basic verified listing on Winga platform',
   '#CD7F32',  1,
   '["Verified badge","Listed on platform","Basic profile","Customer requests"]'::jsonb),
  ('Mid',      15000, 'Priority listing with enhanced visibility',
   '#C0C0C0',  2,
   '["Mid badge","Priority search listing","Enhanced profile","Analytics dashboard","Priority support"]'::jsonb),
  ('Verified', 30000, 'Top-tier featured Winga with gold badge',
   '#F9A825',  3,
   '["Verified gold badge","Top search placement","Featured on home screen","Full analytics","Dedicated support","Marketing boost"]'::jsonb)
ON CONFLICT (name) DO NOTHING;

-- ── Wingas ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.wingas (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  winga_id            TEXT UNIQUE NOT NULL,
  user_id             UUID UNIQUE NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  name                TEXT NOT NULL,
  phone               TEXT NOT NULL,
  email               TEXT,
  specialty           TEXT NOT NULL DEFAULT 'General',
  bio                 TEXT,
  home_location       TEXT,
  national_id         TEXT,
  national_id_doc_url TEXT,
  face_photo_url      TEXT,
  police_clearance_url TEXT,
  address_proof_url   TEXT,

  -- Verification
  verification_status TEXT NOT NULL DEFAULT 'unverified'
                      CHECK (verification_status IN (
                        'unverified','documents_submitted','payment_pending',
                        'under_review','verified','suspended','rejected'
                      )),
  verification_tier   TEXT CHECK (verification_tier IN ('Starter','Mid','Verified')),
  tier_id             UUID REFERENCES public.verification_tiers(id),
  verified_at         TIMESTAMPTZ,
  verified_by         UUID REFERENCES public.users(id),
  verification_notes  TEXT,
  rejection_reason    TEXT,

  -- Badge
  badge               TEXT NOT NULL DEFAULT 'none'
                      CHECK (badge IN ('none','Starter','Mid','Verified')),
  badge_assigned_at   TIMESTAMPTZ,
  badge_assigned_by   UUID REFERENCES public.users(id),
  badge_expires_at    TIMESTAMPTZ,

  -- Subscription
  subscription_active    BOOLEAN NOT NULL DEFAULT FALSE,
  subscription_start     TIMESTAMPTZ,
  subscription_end       TIMESTAMPTZ,
  last_payment_date      TIMESTAMPTZ,
  last_payment_amount    INT,
  next_payment_due       TIMESTAMPTZ,

  -- Stats
  rating              NUMERIC(3,2) NOT NULL DEFAULT 5.00,
  total_trips         INT NOT NULL DEFAULT 0,
  completion_rate     NUMERIC(5,2) NOT NULL DEFAULT 100.00,
  total_earnings      INT NOT NULL DEFAULT 0,

  -- Status
  is_online           BOOLEAN NOT NULL DEFAULT FALSE,
  status              TEXT NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('active','inactive','suspended','pending')),

  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Verification Payments ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.verification_payments (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  winga_id        UUID NOT NULL REFERENCES public.wingas(id) ON DELETE CASCADE,
  tier_id         UUID NOT NULL REFERENCES public.verification_tiers(id),
  amount          INT NOT NULL,
  payment_method  TEXT NOT NULL CHECK (payment_method IN ('mpesa','airtel','tigo','halopesa','card')),
  mobile_number   TEXT,
  provider_ref    TEXT,
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','success','failed','refunded')),
  paid_at         TIMESTAMPTZ,
  month_covered   DATE NOT NULL DEFAULT DATE_TRUNC('month', NOW()),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Winga Documents (submitted for verification) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.winga_documents (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  winga_id      UUID NOT NULL REFERENCES public.wingas(id) ON DELETE CASCADE,
  doc_type      TEXT NOT NULL CHECK (doc_type IN (
                  'national_id','face_photo','police_clearance',
                  'address_proof','business_license','other'
                )),
  file_url      TEXT NOT NULL,
  file_name     TEXT,
  status        TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending','approved','rejected')),
  reviewed_by   UUID REFERENCES public.users(id),
  reviewed_at   TIMESTAMPTZ,
  notes         TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Requests ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.requests (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id     UUID NOT NULL REFERENCES public.users(id),
  winga_id        UUID REFERENCES public.wingas(id),
  category        TEXT NOT NULL,
  meeting_point   TEXT NOT NULL,
  shopping_area   TEXT NOT NULL DEFAULT 'Kariakoo Market',
  service_type    TEXT NOT NULL DEFAULT 'hourly'
                  CHECK (service_type IN ('hourly','half_day','full_day','custom')),
  delivery_method TEXT NOT NULL DEFAULT 'with_client'
                  CHECK (delivery_method IN ('with_client','deliver','pickup')),
  estimated_price INT NOT NULL,
  final_price     INT,
  status          TEXT NOT NULL DEFAULT 'searching'
                  CHECK (status IN ('searching','accepted','shopping','completed','cancelled')),
  note            TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  accepted_at     TIMESTAMPTZ,
  completed_at    TIMESTAMPTZ,
  cancelled_at    TIMESTAMPTZ,
  cancel_reason   TEXT,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Transactions ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.transactions (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id      UUID NOT NULL REFERENCES public.requests(id),
  winga_id        UUID NOT NULL REFERENCES public.wingas(id),
  customer_id     UUID NOT NULL REFERENCES public.users(id),
  gross_amount    INT NOT NULL,
  platform_fee    INT NOT NULL,
  winga_payout    INT NOT NULL,
  tax             INT NOT NULL,
  payment_method  TEXT NOT NULL
                  CHECK (payment_method IN ('mpesa','airtel','tigo','halopesa','wallet','card','bank')),
  mobile_number   TEXT,
  provider_ref    TEXT,
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('success','pending','failed','refunded')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Reviews ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.reviews (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id  UUID NOT NULL REFERENCES public.requests(id),
  customer_id UUID NOT NULL REFERENCES public.users(id),
  winga_id    UUID NOT NULL REFERENCES public.wingas(id),
  rating      INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment     TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Notifications ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notifications (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title       TEXT NOT NULL,
  body        TEXT NOT NULL,
  type        TEXT NOT NULL DEFAULT 'info'
              CHECK (type IN ('info','success','warning','error','request','payment','verification')),
  is_read     BOOLEAN NOT NULL DEFAULT FALSE,
  data        JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Admin Audit Log ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.admin_audit_log (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  admin_id    UUID NOT NULL REFERENCES public.users(id),
  action      TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_id   UUID NOT NULL,
  details     JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Indexes ───────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_wingas_status          ON public.wingas(status);
CREATE INDEX IF NOT EXISTS idx_wingas_verification    ON public.wingas(verification_status);
CREATE INDEX IF NOT EXISTS idx_wingas_badge           ON public.wingas(badge);
CREATE INDEX IF NOT EXISTS idx_wingas_online          ON public.wingas(is_online);
CREATE INDEX IF NOT EXISTS idx_requests_customer      ON public.requests(customer_id);
CREATE INDEX IF NOT EXISTS idx_requests_winga         ON public.requests(winga_id);
CREATE INDEX IF NOT EXISTS idx_requests_status        ON public.requests(status);
CREATE INDEX IF NOT EXISTS idx_transactions_winga     ON public.transactions(winga_id);
CREATE INDEX IF NOT EXISTS idx_ver_payments_winga     ON public.verification_payments(winga_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user     ON public.notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_winga_docs_winga       ON public.winga_documents(winga_id);


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


-- ============================================================
-- Winga App — Migration 003: Triggers & DB Functions
-- ============================================================

-- ── Auto-generate Winga ID (WNGA00001) ───────────────────────────────────
CREATE SEQUENCE IF NOT EXISTS winga_id_seq START 10001;

CREATE OR REPLACE FUNCTION public.generate_winga_id()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.winga_id IS NULL OR NEW.winga_id = '' THEN
    NEW.winga_id = 'WNGA' || LPAD(nextval('winga_id_seq')::TEXT, 5, '0');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_winga_id ON public.wingas;
CREATE TRIGGER set_winga_id
  BEFORE INSERT ON public.wingas
  FOR EACH ROW EXECUTE FUNCTION public.generate_winga_id();

-- ── Auto-update updated_at ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_updated_at_users ON public.users;
CREATE TRIGGER set_updated_at_users
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_updated_at_wingas ON public.wingas;
CREATE TRIGGER set_updated_at_wingas
  BEFORE UPDATE ON public.wingas
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_updated_at_requests ON public.requests;
CREATE TRIGGER set_updated_at_requests
  BEFORE UPDATE ON public.requests
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── Recalculate Winga rating after review ────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_winga_rating()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.wingas
  SET rating = (
    SELECT ROUND(AVG(rating)::NUMERIC, 2)
    FROM public.reviews WHERE winga_id = NEW.winga_id
  ),
  total_trips = (
    SELECT COUNT(*) FROM public.requests
    WHERE winga_id = NEW.winga_id AND status = 'completed'
  ),
  completion_rate = (
    SELECT ROUND(
      COUNT(*) FILTER (WHERE status = 'completed') * 100.0 /
      NULLIF(COUNT(*) FILTER (WHERE status IN ('completed','cancelled')), 0),
      2
    )
    FROM public.requests WHERE winga_id = NEW.winga_id
  )
  WHERE id = NEW.winga_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS recalculate_winga_rating ON public.reviews;
CREATE TRIGGER recalculate_winga_rating
  AFTER INSERT OR UPDATE ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION public.update_winga_rating();

-- ── Check & expire subscriptions daily ───────────────────────────────────
CREATE OR REPLACE FUNCTION public.expire_subscriptions()
RETURNS void AS $$
BEGIN
  UPDATE public.wingas
  SET
    subscription_active = FALSE,
    badge = 'none',
    verification_status = CASE
      WHEN verification_status = 'verified' THEN 'suspended'
      ELSE verification_status
    END,
    status = CASE
      WHEN status = 'active' THEN 'inactive'
      ELSE status
    END
  WHERE
    subscription_active = TRUE
    AND subscription_end < NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── RPC: Admin verify winga ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_verify_winga(
  p_winga_id     UUID,
  p_tier         TEXT,   -- 'Starter' | 'Mid' | 'Verified'
  p_notes        TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_admin_id UUID;
  v_tier_id  UUID;
  v_winga    RECORD;
BEGIN
  -- Must be admin
  v_admin_id := auth.uid();
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized — admin only');
  END IF;

  -- Get tier
  SELECT id INTO v_tier_id FROM public.verification_tiers WHERE name = p_tier;
  IF v_tier_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid tier: ' || p_tier);
  END IF;

  -- Get winga
  SELECT * INTO v_winga FROM public.wingas WHERE id = p_winga_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Winga not found');
  END IF;

  -- Update winga
  UPDATE public.wingas SET
    verification_status  = 'verified',
    verification_tier    = p_tier,
    tier_id              = v_tier_id,
    badge                = p_tier,
    verified_at          = NOW(),
    verified_by          = v_admin_id,
    verification_notes   = p_notes,
    status               = 'active',
    badge_assigned_at    = NOW(),
    badge_assigned_by    = v_admin_id,
    badge_expires_at     = NOW() + INTERVAL '30 days'
  WHERE id = p_winga_id;

  -- Also mark user as verified
  UPDATE public.users SET is_verified = TRUE
  WHERE id = v_winga.user_id;

  -- Log admin action
  INSERT INTO public.admin_audit_log (admin_id, action, target_type, target_id, details)
  VALUES (v_admin_id, 'verify_winga', 'winga', p_winga_id,
    jsonb_build_object('tier', p_tier, 'notes', p_notes));

  -- Notify winga
  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES (
    v_winga.user_id,
    '🎉 Hongera! Umeidhinishwa kama Winga',
    'Akaunti yako imeidhinishwa kama ' || p_tier || ' Winga. Sasa unaweza kupokea maombi!',
    'verification',
    jsonb_build_object('tier', p_tier, 'winga_id', p_winga_id)
  );

  RETURN jsonb_build_object('success', true, 'tier', p_tier, 'winga_id', p_winga_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── RPC: Admin reject winga ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_reject_winga(
  p_winga_id UUID,
  p_reason   TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_winga RECORD;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT * INTO v_winga FROM public.wingas WHERE id = p_winga_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Winga not found');
  END IF;

  UPDATE public.wingas SET
    verification_status = 'rejected',
    rejection_reason    = p_reason,
    badge               = 'none'
  WHERE id = p_winga_id;

  INSERT INTO public.admin_audit_log (admin_id, action, target_type, target_id, details)
  VALUES (auth.uid(), 'reject_winga', 'winga', p_winga_id,
    jsonb_build_object('reason', p_reason));

  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES (
    v_winga.user_id,
    'Maombi ya Uthibitisho Yamekataliwa',
    'Ombi lako la uthibitisho limekataliwa. Sababu: ' || p_reason || '. Tafadhali wasiliana nasi.',
    'verification',
    jsonb_build_object('reason', p_reason)
  );

  RETURN jsonb_build_object('success', true, 'winga_id', p_winga_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── RPC: Admin assign / change badge ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_assign_badge(
  p_winga_id UUID,
  p_badge    TEXT   -- 'Starter' | 'Mid' | 'Verified'
)
RETURNS JSONB AS $$
DECLARE
  v_winga RECORD;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  IF p_badge NOT IN ('Starter', 'Mid', 'Verified') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid badge. Use: Starter, Mid, Verified');
  END IF;

  SELECT * INTO v_winga FROM public.wingas WHERE id = p_winga_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Winga not found');
  END IF;

  UPDATE public.wingas SET
    badge             = p_badge,
    badge_assigned_at = NOW(),
    badge_assigned_by = auth.uid(),
    badge_expires_at  = NOW() + INTERVAL '30 days'
  WHERE id = p_winga_id;

  INSERT INTO public.admin_audit_log (admin_id, action, target_type, target_id, details)
  VALUES (auth.uid(), 'assign_badge', 'winga', p_winga_id,
    jsonb_build_object('badge', p_badge, 'previous_badge', v_winga.badge));

  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES (
    v_winga.user_id,
    'Badge Yako Imesasishwa — ' || p_badge,
    'Hongera! Umepewa badge ya ' || p_badge || ' kwenye Winga App.',
    'verification',
    jsonb_build_object('badge', p_badge)
  );

  RETURN jsonb_build_object('success', true, 'badge', p_badge, 'winga_id', p_winga_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── RPC: Confirm verification payment ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.confirm_verification_payment(
  p_winga_id       UUID,
  p_tier_name      TEXT,
  p_payment_method TEXT,
  p_mobile_number  TEXT DEFAULT NULL,
  p_provider_ref   TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_tier      RECORD;
  v_winga     RECORD;
  v_payment   UUID;
BEGIN
  SELECT * INTO v_tier FROM public.verification_tiers WHERE name = p_tier_name;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid tier');
  END IF;

  SELECT * INTO v_winga FROM public.wingas WHERE id = p_winga_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Winga not found');
  END IF;

  -- Record payment
  INSERT INTO public.verification_payments
    (winga_id, tier_id, amount, payment_method, mobile_number, provider_ref, status, paid_at)
  VALUES
    (p_winga_id, v_tier.id, v_tier.monthly_fee, p_payment_method, p_mobile_number, p_provider_ref, 'success', NOW())
  RETURNING id INTO v_payment;

  -- Update winga subscription & set to under_review
  UPDATE public.wingas SET
    verification_status  = 'under_review',
    verification_tier    = p_tier_name,
    tier_id              = v_tier.id,
    subscription_active  = TRUE,
    subscription_start   = NOW(),
    subscription_end     = NOW() + INTERVAL '30 days',
    next_payment_due     = NOW() + INTERVAL '30 days',
    last_payment_date    = NOW(),
    last_payment_amount  = v_tier.monthly_fee
  WHERE id = p_winga_id;

  -- Notify winga
  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES (
    v_winga.user_id,
    'Malipo Yamefanikiwa ✓',
    'Malipo ya TZS ' || v_tier.monthly_fee || ' kwa tier ya ' || p_tier_name || ' yamefanikiwa. Akaunti yako iko chini ya ukaguzi.',
    'payment',
    jsonb_build_object('tier', p_tier_name, 'amount', v_tier.monthly_fee, 'payment_id', v_payment)
  );

  -- Notify admin
  INSERT INTO public.notifications (user_id, title, body, type, data)
  SELECT id, 
    'Winga Amewasilisha Malipo — ' || v_winga.name,
    p_tier_name || ' tier · TZS ' || v_tier.monthly_fee || ' · Anahitaji uthibitisho',
    'verification',
    jsonb_build_object('winga_id', p_winga_id, 'tier', p_tier_name, 'payment_id', v_payment)
  FROM public.users WHERE user_type = 'admin';

  RETURN jsonb_build_object(
    'success', true,
    'payment_id', v_payment,
    'tier', p_tier_name,
    'amount', v_tier.monthly_fee,
    'status', 'under_review'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.admin_verify_winga(UUID, TEXT, TEXT)    TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reject_winga(UUID, TEXT)           TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_assign_badge(UUID, TEXT)           TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_verification_payment(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.expire_subscriptions()                   TO service_role;


-- ============================================================
-- Winga App — Migration 004: Seed Admin User
-- ============================================================
-- IMPORTANT: Login uses Supabase Auth (signInWithPassword).
-- The admin user MUST exist in BOTH:
--   1. Supabase Auth (Authentication → Users)
--   2. public.users table (below) — with user_type = 'admin'
-- ============================================================

-- Clean up old credentials that block the user ID change
DELETE FROM public.user_credentials WHERE user_id IN (
  SELECT id FROM public.users WHERE phone = '+255000000000'
);

-- Clean up any existing user with this phone
DELETE FROM public.users WHERE phone = '+255000000000';

-- Grant admin access to support@winga.com
INSERT INTO public.users (id, phone, email, name, user_type, is_verified)
VALUES (
  'a4224bfa-2604-4695-8e02-becd5242cf5f',
  '+255000000000',
  'support@winga.com',
  'Winga Support',
  'admin',
  TRUE
);

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


-- ============================================================
-- Winga App — Migration 006: Storage Buckets
-- For document uploads (Winga verification docs, profile photos)
-- ============================================================

-- Create storage buckets
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('avatars',   'avatars',   true,  5242880,  -- 5MB
   ARRAY['image/jpeg','image/png','image/webp']),
  ('documents', 'documents', false, 10485760, -- 10MB (private)
   ARRAY['image/jpeg','image/png','image/pdf']),
  ('app-assets','app-assets', true,  5242880,
   ARRAY['image/jpeg','image/png','image/svg+xml','image/webp'])
ON CONFLICT (id) DO NOTHING;

-- ── Storage RLS Policies ──────────────────────────────────────────────────

-- Avatars: public read, owner write
DROP POLICY IF EXISTS "avatars_public_read" ON storage.objects;
CREATE POLICY "avatars_public_read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "avatars_owner_upload" ON storage.objects;
CREATE POLICY "avatars_owner_upload"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "avatars_owner_delete" ON storage.objects;
CREATE POLICY "avatars_owner_delete"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Documents: private — only owner and admin
DROP POLICY IF EXISTS "documents_owner_read" ON storage.objects;
CREATE POLICY "documents_owner_read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'documents' AND (
    auth.uid()::text = (storage.foldername(name))[1]
    OR public.is_admin()
  ));

DROP POLICY IF EXISTS "documents_owner_upload" ON storage.objects;
CREATE POLICY "documents_owner_upload"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'documents' AND auth.uid()::text = (storage.foldername(name))[1]);

-- App assets: public read, admin write
DROP POLICY IF EXISTS "app_assets_public_read" ON storage.objects;
CREATE POLICY "app_assets_public_read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'app-assets');

DROP POLICY IF EXISTS "app_assets_admin_write" ON storage.objects;
CREATE POLICY "app_assets_admin_write"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'app-assets' AND public.is_admin());


-- ============================================================
-- Winga App — Migration 007: Points & Reputation System
--
-- Customer rates each completed trip:
--   Good service = 1 point
--   Bad service  = 0 points
--
-- "Best Winga" ranking uses a WILSON LOWER BOUND score, not raw totals.
-- Raw totals reward volume (500/900 = 56% good beats 90/90 = 100% good).
-- A raw percentage rewards flukes (3/3 = 100% beats 200/205 = 97.5%).
-- Wilson gives the *statistically confident* minimum quality:
--   3/3     -> 0.44   (not enough evidence yet)
--   90/90   -> 0.96
--   500/900 -> 0.53
-- ============================================================

-- ── Points ledger — one row per rated trip ────────────────────────────────
CREATE TABLE IF NOT EXISTS public.winga_points (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  winga_id    UUID NOT NULL REFERENCES public.wingas(id)  ON DELETE CASCADE,
  request_id  UUID NOT NULL REFERENCES public.requests(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES public.users(id),
  point       INT  NOT NULL CHECK (point IN (0, 1)),   -- 1 = good, 0 = bad
  reason      TEXT,                                    -- optional customer note
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- one rating per request: a customer cannot farm points for a Winga
  CONSTRAINT uniq_point_per_request UNIQUE (request_id)
);

CREATE INDEX IF NOT EXISTS idx_points_winga    ON public.winga_points(winga_id);
CREATE INDEX IF NOT EXISTS idx_points_customer ON public.winga_points(customer_id);

-- ── Denormalised counters on wingas (kept in sync by trigger) ─────────────
ALTER TABLE public.wingas
  ADD COLUMN IF NOT EXISTS total_points   INT NOT NULL DEFAULT 0,  -- good trips
  ADD COLUMN IF NOT EXISTS rated_trips    INT NOT NULL DEFAULT 0,  -- good + bad
  ADD COLUMN IF NOT EXISTS point_rate     NUMERIC(5,2) NOT NULL DEFAULT 0,  -- % good
  ADD COLUMN IF NOT EXISTS winga_score    NUMERIC(6,4) NOT NULL DEFAULT 0,  -- Wilson 0..1
  ADD COLUMN IF NOT EXISTS is_top_rated   BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_wingas_score     ON public.wingas(winga_score DESC);
CREATE INDEX IF NOT EXISTS idx_wingas_top_rated ON public.wingas(is_top_rated);

-- ── Wilson lower bound (95% confidence) ───────────────────────────────────
-- z = 1.96. Returns 0 when there are no rated trips.
CREATE OR REPLACE FUNCTION public.wilson_score(good INT, total INT)
RETURNS NUMERIC AS $$
DECLARE
  z    CONSTANT NUMERIC := 1.96;
  phat NUMERIC;
BEGIN
  IF total <= 0 THEN RETURN 0; END IF;
  phat := good::NUMERIC / total::NUMERIC;
  RETURN ROUND(
    (
      phat + (z*z) / (2*total)
      - z * SQRT( (phat * (1 - phat) + (z*z) / (4*total)) / total )
    ) / (1 + (z*z) / total)
  , 4);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ── Recalculate a Winga's reputation after any rating change ──────────────
CREATE OR REPLACE FUNCTION public.recalc_winga_points()
RETURNS TRIGGER AS $$
DECLARE
  v_winga UUID := COALESCE(NEW.winga_id, OLD.winga_id);
  v_good  INT;
  v_total INT;
BEGIN
  SELECT COALESCE(SUM(point), 0), COUNT(*)
    INTO v_good, v_total
  FROM public.winga_points
  WHERE winga_id = v_winga;

  UPDATE public.wingas SET
    total_points = v_good,
    rated_trips  = v_total,
    point_rate   = CASE WHEN v_total = 0 THEN 0
                        ELSE ROUND(v_good * 100.0 / v_total, 2) END,
    winga_score  = public.wilson_score(v_good, v_total)
  WHERE id = v_winga;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_recalc_points ON public.winga_points;
CREATE TRIGGER trg_recalc_points
  AFTER INSERT OR UPDATE OR DELETE ON public.winga_points
  FOR EACH ROW EXECUTE FUNCTION public.recalc_winga_points();

-- ── Tier eligibility gate ─────────────────────────────────────────────────
-- Points can now unlock or BLOCK a badge tier. Paying is necessary but not
-- sufficient — a Winga with poor service cannot buy their way to Verified.
--
--   Starter  : no requirement (entry tier)
--   Mid      : >= 10 rated trips AND score >= 0.60
--   Verified : >= 30 rated trips AND score >= 0.80
CREATE TABLE IF NOT EXISTS public.tier_requirements (
  tier          TEXT PRIMARY KEY REFERENCES public.verification_tiers(name),
  min_rated_trips INT     NOT NULL DEFAULT 0,
  min_score       NUMERIC NOT NULL DEFAULT 0
);

INSERT INTO public.tier_requirements (tier, min_rated_trips, min_score) VALUES
  ('Starter',   0,  0.00),
  ('Mid',      10,  0.60),
  ('Verified', 30,  0.80)
ON CONFLICT (tier) DO UPDATE
  SET min_rated_trips = EXCLUDED.min_rated_trips,
      min_score       = EXCLUDED.min_score;

-- Returns eligibility + a human-readable reason, so the admin panel and the
-- Winga app can both explain *why* an upgrade is blocked.
CREATE OR REPLACE FUNCTION public.check_tier_eligibility(
  p_winga_id UUID,
  p_tier     TEXT
)
RETURNS JSONB AS $$
DECLARE
  w   RECORD;
  req RECORD;
BEGIN
  SELECT rated_trips, winga_score, total_points
    INTO w FROM public.wingas WHERE id = p_winga_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('eligible', false, 'reason', 'Winga not found');
  END IF;

  SELECT * INTO req FROM public.tier_requirements WHERE tier = p_tier;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('eligible', false, 'reason', 'Unknown tier: ' || p_tier);
  END IF;

  IF w.rated_trips < req.min_rated_trips THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'reason', format('Inahitaji safari %s zilizopimwa (ana %s)',
                       req.min_rated_trips, w.rated_trips),
      'rated_trips', w.rated_trips,
      'required_trips', req.min_rated_trips,
      'score', w.winga_score,
      'required_score', req.min_score
    );
  END IF;

  IF w.winga_score < req.min_score THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'reason', format('Alama ya huduma ni ndogo mno (%s, inahitajika %s)',
                       w.winga_score, req.min_score),
      'rated_trips', w.rated_trips,
      'required_trips', req.min_rated_trips,
      'score', w.winga_score,
      'required_score', req.min_score
    );
  END IF;

  RETURN jsonb_build_object(
    'eligible', true,
    'reason', 'Anastahili tier ya ' || p_tier,
    'rated_trips', w.rated_trips,
    'score', w.winga_score
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ── Customer awards a point ───────────────────────────────────────────────
-- Only the customer on the request, only once, only after completion.
CREATE OR REPLACE FUNCTION public.rate_winga(
  p_request_id UUID,
  p_point      INT,          -- 1 = good service, 0 = bad service
  p_reason     TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  r RECORD;
BEGIN
  IF p_point NOT IN (0, 1) THEN
    RETURN jsonb_build_object('success', false, 'error', 'point must be 0 or 1');
  END IF;

  SELECT id, customer_id, winga_id, status
    INTO r FROM public.requests WHERE id = p_request_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Request not found');
  END IF;
  IF r.customer_id <> auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Only the customer on this request can rate it');
  END IF;
  IF r.status <> 'completed' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Request is not completed yet');
  END IF;
  IF r.winga_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'No Winga assigned to this request');
  END IF;
  IF EXISTS (SELECT 1 FROM public.winga_points WHERE request_id = p_request_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'This trip has already been rated');
  END IF;

  INSERT INTO public.winga_points (winga_id, request_id, customer_id, point, reason)
  VALUES (r.winga_id, p_request_id, r.customer_id, p_point, p_reason);

  -- trigger has now refreshed the counters
  RETURN (
    SELECT jsonb_build_object(
      'success', true,
      'point', p_point,
      'total_points', w.total_points,
      'rated_trips', w.rated_trips,
      'point_rate', w.point_rate,
      'score', w.winga_score
    )
    FROM public.wingas w WHERE w.id = r.winga_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── Refresh the "Top Rated" set ───────────────────────────────────────────
-- Top Rated = active + verified + meets a real evidence bar + top 10%.
-- Run nightly (pg_cron) or from the admin panel.
CREATE OR REPLACE FUNCTION public.refresh_top_rated()
RETURNS JSONB AS $$
DECLARE
  v_count INT;
BEGIN
  UPDATE public.wingas SET is_top_rated = FALSE WHERE is_top_rated = TRUE;

  WITH eligible AS (
    SELECT id,
           NTILE(10) OVER (ORDER BY winga_score DESC, rated_trips DESC) AS decile
    FROM public.wingas
    WHERE status = 'active'
      AND verification_status = 'verified'
      AND rated_trips >= 10        -- evidence bar: no 3/3 flukes
      AND winga_score >= 0.75
  )
  UPDATE public.wingas w
     SET is_top_rated = TRUE
    FROM eligible e
   WHERE w.id = e.id AND e.decile = 1;

  SELECT COUNT(*) INTO v_count FROM public.wingas WHERE is_top_rated;
  RETURN jsonb_build_object('success', true, 'top_rated_count', v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── Leaderboard view ──────────────────────────────────────────────────────
DROP VIEW IF EXISTS public.v_winga_leaderboard CASCADE;
CREATE OR REPLACE VIEW public.v_winga_leaderboard AS
SELECT
  w.id,
  w.winga_id,
  w.name,
  w.specialty,
  w.home_location,
  w.badge,
  w.total_points,
  w.rated_trips,
  w.point_rate,
  w.winga_score,
  w.is_top_rated,
  w.total_trips,
  w.total_earnings,
  w.is_online,
  RANK() OVER (ORDER BY w.winga_score DESC, w.rated_trips DESC) AS rank
FROM public.wingas w
WHERE w.status = 'active'
  AND w.verification_status = 'verified'
ORDER BY w.winga_score DESC, w.rated_trips DESC;

GRANT SELECT ON public.v_winga_leaderboard TO anon, authenticated, service_role;

-- ── Featured Wingas for the customer Home screen ──────────────────────────
CREATE OR REPLACE FUNCTION public.get_featured_wingas(p_limit INT DEFAULT 10)
RETURNS TABLE (
  id UUID, winga_id TEXT, name TEXT, specialty TEXT, home_location TEXT,
  badge TEXT, total_points INT, rated_trips INT, point_rate NUMERIC,
  winga_score NUMERIC, is_top_rated BOOLEAN, is_online BOOLEAN, rating NUMERIC
) AS $$
  SELECT w.id, w.winga_id, w.name, w.specialty, w.home_location,
         w.badge, w.total_points, w.rated_trips, w.point_rate,
         w.winga_score, w.is_top_rated, w.is_online, w.rating
  FROM public.wingas w
  WHERE w.status = 'active'
    AND w.verification_status = 'verified'
    AND w.is_top_rated = TRUE
  ORDER BY w.winga_score DESC, w.is_online DESC, w.rated_trips DESC
  LIMIT p_limit;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ── RLS ───────────────────────────────────────────────────────────────────
ALTER TABLE public.winga_points      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tier_requirements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "points_public_read"   ON public.winga_points;
DROP POLICY IF EXISTS "points_customer_own"  ON public.winga_points;
DROP POLICY IF EXISTS "points_admin"         ON public.winga_points;
DROP POLICY IF EXISTS "tier_req_public_read" ON public.tier_requirements;
DROP POLICY IF EXISTS "tier_req_admin"       ON public.tier_requirements;

-- Anyone can read points (they drive public reputation)
CREATE POLICY "points_public_read" ON public.winga_points
  FOR SELECT USING (true);
-- Only the rating customer may insert (rate_winga enforces the rest)
CREATE POLICY "points_customer_own" ON public.winga_points
  FOR INSERT WITH CHECK (auth.uid() = customer_id);
CREATE POLICY "points_admin" ON public.winga_points
  FOR ALL USING (public.is_admin());

CREATE POLICY "tier_req_public_read" ON public.tier_requirements
  FOR SELECT USING (true);
CREATE POLICY "tier_req_admin" ON public.tier_requirements
  FOR ALL USING (public.is_admin());

GRANT EXECUTE ON FUNCTION public.wilson_score(INT, INT)              TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rate_winga(UUID, INT, TEXT)         TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_tier_eligibility(UUID, TEXT)  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_featured_wingas(INT)            TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_top_rated()                 TO service_role;


-- ============================================================
-- Winga App — Migration 008: Enforce point-based tier gating
--
-- Paying the monthly fee is now NECESSARY BUT NOT SUFFICIENT.
-- A Winga with poor service points cannot buy their way into Mid/Verified.
--
-- Admin can still override (p_override = true) — e.g. a Winga with great
-- offline reputation but few rated trips. Overrides are written to the
-- audit log with the reason, so the decision is always attributable.
-- ============================================================

-- Drop the OLD ungated signatures from migration 003 first.
-- Postgres overloads on signature, so without these DROPs the ungated
-- 3-arg admin_verify_winga(uuid,text,text) would survive and could be called
-- to bypass the points gate entirely.
DROP FUNCTION IF EXISTS public.admin_verify_winga(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.admin_assign_badge(UUID, TEXT);

-- ── admin_verify_winga: now checks eligibility ────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_verify_winga(
  p_winga_id UUID,
  p_tier     TEXT,
  p_notes    TEXT    DEFAULT NULL,
  p_override BOOLEAN DEFAULT FALSE
)
RETURNS JSONB AS $$
DECLARE
  v_admin_id UUID;
  v_tier_id  UUID;
  v_winga    RECORD;
  v_elig     JSONB;
BEGIN
  v_admin_id := auth.uid();
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized — admin only');
  END IF;

  SELECT id INTO v_tier_id FROM public.verification_tiers WHERE name = p_tier;
  IF v_tier_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid tier: ' || p_tier);
  END IF;

  SELECT * INTO v_winga FROM public.wingas WHERE id = p_winga_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Winga not found');
  END IF;

  -- POINT GATE
  v_elig := public.check_tier_eligibility(p_winga_id, p_tier);
  IF NOT (v_elig->>'eligible')::BOOLEAN AND NOT p_override THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'blocked_by_points',
      'message', v_elig->>'reason',
      'eligibility', v_elig,
      'hint', 'Pass p_override => true to approve anyway (logged to audit trail)'
    );
  END IF;

  UPDATE public.wingas SET
    verification_status = 'verified',
    verification_tier   = p_tier,
    tier_id             = v_tier_id,
    badge               = p_tier,
    verified_at         = NOW(),
    verified_by         = v_admin_id,
    verification_notes  = p_notes,
    status              = 'active',
    badge_assigned_at   = NOW(),
    badge_assigned_by   = v_admin_id,
    badge_expires_at    = NOW() + INTERVAL '30 days'
  WHERE id = p_winga_id;

  UPDATE public.users SET is_verified = TRUE WHERE id = v_winga.user_id;

  INSERT INTO public.admin_audit_log (admin_id, action, target_type, target_id, details)
  VALUES (v_admin_id,
          CASE WHEN p_override THEN 'verify_winga_OVERRIDE' ELSE 'verify_winga' END,
          'winga', p_winga_id,
          jsonb_build_object('tier', p_tier, 'notes', p_notes,
                             'override', p_override, 'eligibility', v_elig));

  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES (
    v_winga.user_id,
    '🎉 Hongera! Umeidhinishwa kama Winga',
    'Akaunti yako imeidhinishwa kama ' || p_tier || ' Winga. Sasa unaweza kupokea maombi!',
    'verification',
    jsonb_build_object('tier', p_tier, 'winga_id', p_winga_id)
  );

  RETURN jsonb_build_object('success', true, 'tier', p_tier,
                            'winga_id', p_winga_id, 'override', p_override);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── admin_assign_badge: now checks eligibility ────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_assign_badge(
  p_winga_id UUID,
  p_badge    TEXT,
  p_override BOOLEAN DEFAULT FALSE
)
RETURNS JSONB AS $$
DECLARE
  v_winga RECORD;
  v_elig  JSONB;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;
  IF p_badge NOT IN ('Starter', 'Mid', 'Verified') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid badge. Use: Starter, Mid, Verified');
  END IF;

  SELECT * INTO v_winga FROM public.wingas WHERE id = p_winga_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Winga not found');
  END IF;

  -- POINT GATE (downgrades are always allowed — only upgrades are gated)
  v_elig := public.check_tier_eligibility(p_winga_id, p_badge);
  IF NOT (v_elig->>'eligible')::BOOLEAN AND NOT p_override THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'blocked_by_points',
      'message', v_elig->>'reason',
      'eligibility', v_elig
    );
  END IF;

  UPDATE public.wingas SET
    badge             = p_badge,
    verification_tier = p_badge,
    badge_assigned_at = NOW(),
    badge_assigned_by = auth.uid(),
    badge_expires_at  = NOW() + INTERVAL '30 days'
  WHERE id = p_winga_id;

  INSERT INTO public.admin_audit_log (admin_id, action, target_type, target_id, details)
  VALUES (auth.uid(),
          CASE WHEN p_override THEN 'assign_badge_OVERRIDE' ELSE 'assign_badge' END,
          'winga', p_winga_id,
          jsonb_build_object('badge', p_badge, 'previous_badge', v_winga.badge,
                             'override', p_override, 'eligibility', v_elig));

  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES (
    v_winga.user_id,
    'Badge Yako Imesasishwa — ' || p_badge,
    'Hongera! Umepewa badge ya ' || p_badge || ' kwenye Winga App.',
    'verification',
    jsonb_build_object('badge', p_badge)
  );

  RETURN jsonb_build_object('success', true, 'badge', p_badge,
                            'winga_id', p_winga_id, 'override', p_override);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── Payment: warn instead of silently taking money for a blocked tier ─────
-- confirm_verification_payment now records the payment (the Winga did pay)
-- but flags it when the tier is not yet earned, so the admin sees it and the
-- Winga is told *why* they are not upgraded yet rather than just waiting.
CREATE OR REPLACE FUNCTION public.confirm_verification_payment(
  p_winga_id       UUID,
  p_tier_name      TEXT,
  p_payment_method TEXT,
  p_mobile_number  TEXT DEFAULT NULL,
  p_provider_ref   TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_tier    RECORD;
  v_winga   RECORD;
  v_payment UUID;
  v_elig    JSONB;
BEGIN
  SELECT * INTO v_tier FROM public.verification_tiers WHERE name = p_tier_name;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid tier');
  END IF;

  SELECT * INTO v_winga FROM public.wingas WHERE id = p_winga_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Winga not found');
  END IF;

  v_elig := public.check_tier_eligibility(p_winga_id, p_tier_name);

  INSERT INTO public.verification_payments
    (winga_id, tier_id, amount, payment_method, mobile_number, provider_ref, status, paid_at)
  VALUES
    (p_winga_id, v_tier.id, v_tier.monthly_fee, p_payment_method,
     p_mobile_number, p_provider_ref, 'success', NOW())
  RETURNING id INTO v_payment;

  UPDATE public.wingas SET
    verification_status = 'under_review',
    verification_tier   = p_tier_name,
    tier_id             = v_tier.id,
    subscription_active = TRUE,
    subscription_start  = NOW(),
    subscription_end    = NOW() + INTERVAL '30 days',
    next_payment_due    = NOW() + INTERVAL '30 days',
    last_payment_date   = NOW(),
    last_payment_amount = v_tier.monthly_fee
  WHERE id = p_winga_id;

  -- Tell the Winga the truth about where they stand
  IF (v_elig->>'eligible')::BOOLEAN THEN
    INSERT INTO public.notifications (user_id, title, body, type, data)
    VALUES (v_winga.user_id, 'Malipo Yamefanikiwa ✓',
      'Malipo ya TZS ' || v_tier.monthly_fee || ' kwa tier ya ' || p_tier_name ||
      ' yamefanikiwa. Akaunti yako iko chini ya ukaguzi.',
      'payment',
      jsonb_build_object('tier', p_tier_name, 'amount', v_tier.monthly_fee,
                         'payment_id', v_payment, 'eligible', true));
  ELSE
    INSERT INTO public.notifications (user_id, title, body, type, data)
    VALUES (v_winga.user_id, 'Malipo Yamepokelewa — Bado Hujafikia Kiwango',
      'Tumepokea TZS ' || v_tier.monthly_fee || '. Lakini: ' || (v_elig->>'reason') ||
      '. Endelea kutoa huduma nzuri ili kufikia tier ya ' || p_tier_name || '.',
      'verification',
      jsonb_build_object('tier', p_tier_name, 'amount', v_tier.monthly_fee,
                         'payment_id', v_payment, 'eligible', false,
                         'eligibility', v_elig));
  END IF;

  -- Admin queue, flagged when the tier is not earned
  INSERT INTO public.notifications (user_id, title, body, type, data)
  SELECT id,
    CASE WHEN (v_elig->>'eligible')::BOOLEAN
         THEN 'Winga Amelipa — ' || v_winga.name
         ELSE '⚠️ Malipo Bila Kustahili — ' || v_winga.name END,
    p_tier_name || ' · TZS ' || v_tier.monthly_fee || ' · ' || (v_elig->>'reason'),
    'verification',
    jsonb_build_object('winga_id', p_winga_id, 'tier', p_tier_name,
                       'payment_id', v_payment, 'eligibility', v_elig)
  FROM public.users WHERE user_type = 'admin';

  RETURN jsonb_build_object(
    'success', true,
    'payment_id', v_payment,
    'tier', p_tier_name,
    'amount', v_tier.monthly_fee,
    'status', 'under_review',
    'eligibility', v_elig
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.admin_verify_winga(UUID, TEXT, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_assign_badge(UUID, TEXT, BOOLEAN)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_verification_payment(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated;


-- ============================================================
-- Winga App — Migration 009: Full Feature Expansion
-- Global Locations · Chat · Live Tracking · Preferred Winga
-- Substitutions · Disputes · Tips · Shopping List · Referrals · Availability
-- ============================================================

-- ════════════════════════════════════════════════════════════
-- 1. GLOBAL LOCATIONS
-- Not just Kariakoo — Winga can operate anywhere in Tanzania
-- (or East Africa). Customers search by city/area/radius.
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.locations (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  country     TEXT NOT NULL DEFAULT 'Tanzania',
  region      TEXT NOT NULL,             -- e.g. Dar es Salaam, Arusha
  city        TEXT NOT NULL,             -- e.g. Dar es Salaam, Moshi
  area        TEXT,                      -- e.g. Kariakoo, Mwenge, CBD
  lat         NUMERIC(10,7),
  lng         NUMERIC(10,7),
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order  INT NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_locations_city ON public.locations(city);
CREATE INDEX IF NOT EXISTS idx_locations_region ON public.locations(region);

-- Seed Tanzania locations (expandable)
INSERT INTO public.locations (country, region, city, area, lat, lng, sort_order) VALUES
  ('Tanzania','Dar es Salaam','Dar es Salaam','Kariakoo',       -6.8161, 39.2894, 1),
  ('Tanzania','Dar es Salaam','Dar es Salaam','Mwenge',          -6.7780, 39.2630, 2),
  ('Tanzania','Dar es Salaam','Dar es Salaam','Mnazi Mmoja',     -6.8193, 39.2884, 3),
  ('Tanzania','Dar es Salaam','Dar es Salaam','Ilala',           -6.8235, 39.2695, 4),
  ('Tanzania','Dar es Salaam','Dar es Salaam','Kinondoni',       -6.7834, 39.2707, 5),
  ('Tanzania','Dar es Salaam','Dar es Salaam','Temeke',          -6.8726, 39.2990, 6),
  ('Tanzania','Dar es Salaam','Dar es Salaam','Mbagala',         -6.9000, 39.3167, 7),
  ('Tanzania','Dar es Salaam','Dar es Salaam','Tabata',          -6.8416, 39.2534, 8),
  ('Tanzania','Arusha','Arusha','Arusha CBD',                   -3.3869, 36.6830, 10),
  ('Tanzania','Arusha','Arusha','Sakina Market',                -3.3650, 36.6680, 11),
  ('Tanzania','Arusha','Arusha','Kaloleni',                     -3.4000, 36.6700, 12),
  ('Tanzania','Kilimanjaro','Moshi','Moshi Market',              -3.3531, 37.3403, 20),
  ('Tanzania','Kilimanjaro','Moshi','Moshi CBD',                 -3.3500, 37.3400, 21),
  ('Tanzania','Mwanza','Mwanza','Mwanza Market',                 -2.5164, 32.9175, 30),
  ('Tanzania','Mwanza','Mwanza','Kirumba',                       -2.5100, 32.9000, 31),
  ('Tanzania','Dodoma','Dodoma','Dodoma Market',                 -6.1731, 35.7395, 40),
  ('Tanzania','Tanga','Tanga','Tanga Market',                    -5.0688, 39.0988, 50),
  ('Tanzania','Morogoro','Morogoro','Morogoro Market',           -6.8160, 37.6620, 60),
  ('Tanzania','Zanzibar','Zanzibar City','Darajani Market',      -6.1622, 39.1894, 70),
  ('Tanzania','Zanzibar','Zanzibar City','Stone Town',           -6.1630, 39.1900, 71)
ON CONFLICT DO NOTHING;

-- Winga service areas (a Winga can cover multiple areas)
CREATE TABLE IF NOT EXISTS public.winga_service_areas (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  winga_id    UUID NOT NULL REFERENCES public.wingas(id) ON DELETE CASCADE,
  location_id UUID NOT NULL REFERENCES public.locations(id),
  is_primary  BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uniq_winga_area UNIQUE (winga_id, location_id)
);

CREATE INDEX IF NOT EXISTS idx_wsa_winga ON public.winga_service_areas(winga_id);
CREATE INDEX IF NOT EXISTS idx_wsa_location ON public.winga_service_areas(location_id);

-- Extend requests to carry full location
ALTER TABLE public.requests
  ADD COLUMN IF NOT EXISTS location_id  UUID REFERENCES public.locations(id),
  ADD COLUMN IF NOT EXISTS city         TEXT,
  ADD COLUMN IF NOT EXISTS area         TEXT,
  ADD COLUMN IF NOT EXISTS request_lat  NUMERIC(10,7),
  ADD COLUMN IF NOT EXISTS request_lng  NUMERIC(10,7);

-- Extend wingas with current city for search
ALTER TABLE public.wingas
  ADD COLUMN IF NOT EXISTS current_city TEXT,
  ADD COLUMN IF NOT EXISTS current_area TEXT,
  ADD COLUMN IF NOT EXISTS current_lat  NUMERIC(10,7),
  ADD COLUMN IF NOT EXISTS current_lng  NUMERIC(10,7);

-- ════════════════════════════════════════════════════════════
-- 2. REAL-TIME CHAT + PHOTO SHARING
-- One channel per request. Messages can be text or photos.
-- Supabase Realtime broadcasts new rows automatically.
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.messages (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id  UUID NOT NULL REFERENCES public.requests(id) ON DELETE CASCADE,
  sender_id   UUID NOT NULL REFERENCES public.users(id),
  sender_type TEXT NOT NULL CHECK (sender_type IN ('customer','winga','system')),
  type        TEXT NOT NULL DEFAULT 'text'
              CHECK (type IN ('text','photo','substitution','system','tip','location')),
  body        TEXT,          -- text content or caption
  photo_url   TEXT,          -- Supabase storage URL for photos
  metadata    JSONB,         -- extra data (item info for substitution, etc.)
  is_read     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_request ON public.messages(request_id, created_at);
CREATE INDEX IF NOT EXISTS idx_messages_sender  ON public.messages(sender_id);

-- Enable realtime for messages
ALTER TABLE public.messages REPLICA IDENTITY FULL;

-- RLS
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "messages_participants" ON public.messages;
CREATE POLICY "messages_participants" ON public.messages
  FOR ALL USING (
    request_id IN (
      SELECT id FROM public.requests
      WHERE customer_id = auth.uid()
         OR winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid())
    )
  );
DROP POLICY IF EXISTS "messages_admin" ON public.messages;
CREATE POLICY "messages_admin" ON public.messages FOR ALL USING (public.is_admin());

-- ════════════════════════════════════════════════════════════
-- 3. LIVE GPS TRACKING
-- Winga broadcasts location updates during active requests.
-- Customer subscribes via Supabase Realtime.
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.winga_locations (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  winga_id    UUID NOT NULL REFERENCES public.wingas(id) ON DELETE CASCADE,
  request_id  UUID REFERENCES public.requests(id),
  lat         NUMERIC(10,7) NOT NULL,
  lng         NUMERIC(10,7) NOT NULL,
  accuracy    NUMERIC(8,2),   -- metres
  speed       NUMERIC(8,2),   -- km/h
  heading     NUMERIC(6,2),   -- degrees
  status      TEXT DEFAULT 'active',  -- active | idle | offline
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wloc_winga   ON public.winga_locations(winga_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_wloc_request ON public.winga_locations(request_id);

-- Latest location per Winga (fast lookup for customer map)
CREATE OR REPLACE VIEW public.v_winga_live_location AS
SELECT DISTINCT ON (winga_id)
  winga_id, request_id, lat, lng, accuracy, speed, heading, status, recorded_at
FROM public.winga_locations
ORDER BY winga_id, recorded_at DESC;

GRANT SELECT ON public.v_winga_live_location TO authenticated;

ALTER TABLE public.winga_locations REPLICA IDENTITY FULL;
ALTER TABLE public.winga_locations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wloc_winga_write" ON public.winga_locations;
CREATE POLICY "wloc_winga_write" ON public.winga_locations
  FOR INSERT WITH CHECK (
    winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid())
  );
DROP POLICY IF EXISTS "wloc_customer_read" ON public.winga_locations;
CREATE POLICY "wloc_customer_read" ON public.winga_locations
  FOR SELECT USING (
    -- Customer can see location of Winga on their active request
    request_id IN (SELECT id FROM public.requests WHERE customer_id = auth.uid())
    OR winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid())
    OR public.is_admin()
  );

-- ════════════════════════════════════════════════════════════
-- 4. PREFERRED WINGA
-- Customer marks Winga as favourite. Booking flow checks
-- if their preferred Winga is available before searching.
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.preferred_wingas (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  winga_id    UUID NOT NULL REFERENCES public.wingas(id) ON DELETE CASCADE,
  trip_count  INT NOT NULL DEFAULT 1,   -- how many trips with this Winga
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uniq_preferred UNIQUE (customer_id, winga_id)
);

CREATE INDEX IF NOT EXISTS idx_preferred_customer ON public.preferred_wingas(customer_id);

ALTER TABLE public.preferred_wingas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "preferred_own" ON public.preferred_wingas;
CREATE POLICY "preferred_own" ON public.preferred_wingas
  FOR ALL USING (auth.uid() = customer_id);

-- Auto-increment trip_count on request completion
CREATE OR REPLACE FUNCTION public.update_preferred_on_completion()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status <> 'completed' AND NEW.winga_id IS NOT NULL THEN
    INSERT INTO public.preferred_wingas (customer_id, winga_id, trip_count)
    VALUES (NEW.customer_id, NEW.winga_id, 1)
    ON CONFLICT (customer_id, winga_id)
    DO UPDATE SET trip_count = preferred_wingas.trip_count + 1,
                  updated_at = NOW();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_update_preferred ON public.requests;
CREATE TRIGGER trg_update_preferred
  AFTER UPDATE ON public.requests
  FOR EACH ROW EXECUTE FUNCTION public.update_preferred_on_completion();

-- ════════════════════════════════════════════════════════════
-- 5. ITEM SUBSTITUTION APPROVAL
-- Winga sends substitution request → customer approves/rejects
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.substitutions (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id      UUID NOT NULL REFERENCES public.requests(id) ON DELETE CASCADE,
  message_id      UUID REFERENCES public.messages(id),
  winga_id        UUID NOT NULL REFERENCES public.wingas(id),
  original_item   TEXT NOT NULL,
  original_price  INT,
  suggested_item  TEXT NOT NULL,
  suggested_price INT,
  photo_url       TEXT,         -- photo of the suggested substitute
  reason          TEXT,         -- why original is unavailable
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','approved','rejected','cancelled')),
  customer_note   TEXT,         -- customer's reason for rejection
  responded_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_subs_request ON public.substitutions(request_id);
CREATE INDEX IF NOT EXISTS idx_subs_status  ON public.substitutions(status, created_at);

ALTER TABLE public.substitutions REPLICA IDENTITY FULL;
ALTER TABLE public.substitutions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "subs_participants" ON public.substitutions;
CREATE POLICY "subs_participants" ON public.substitutions
  FOR ALL USING (
    request_id IN (
      SELECT id FROM public.requests
      WHERE customer_id = auth.uid()
         OR winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid())
    )
  );

-- RPC: Winga proposes a substitution
CREATE OR REPLACE FUNCTION public.propose_substitution(
  p_request_id    UUID,
  p_original_item TEXT,
  p_original_price INT,
  p_suggested_item TEXT,
  p_suggested_price INT,
  p_photo_url      TEXT DEFAULT NULL,
  p_reason         TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_sub  UUID;
  v_req  RECORD;
  v_msg  UUID;
BEGIN
  SELECT * INTO v_req FROM public.requests WHERE id = p_request_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Request not found');
  END IF;

  INSERT INTO public.substitutions
    (request_id, winga_id, original_item, original_price,
     suggested_item, suggested_price, photo_url, reason)
  VALUES
    (p_request_id, v_req.winga_id, p_original_item, p_original_price,
     p_suggested_item, p_suggested_price, p_photo_url, p_reason)
  RETURNING id INTO v_sub;

  -- Send as a chat message too so it appears inline in the conversation
  INSERT INTO public.messages
    (request_id, sender_id, sender_type, type, body, photo_url, metadata)
  VALUES (
    p_request_id,
    (SELECT user_id FROM public.wingas WHERE id = v_req.winga_id),
    'winga', 'substitution',
    p_original_item || ' haipatikani. Napendekeza: ' || p_suggested_item,
    p_photo_url,
    jsonb_build_object('substitution_id', v_sub,
                       'original', p_original_item,
                       'suggested', p_suggested_item,
                       'original_price', p_original_price,
                       'suggested_price', p_suggested_price,
                       'reason', p_reason)
  ) RETURNING id INTO v_msg;

  UPDATE public.substitutions SET message_id = v_msg WHERE id = v_sub;

  -- Notify customer
  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES (
    v_req.customer_id,
    '🔄 Badiliko la bidhaa linasubiri idhini yako',
    p_original_item || ' → ' || p_suggested_item,
    'info',
    jsonb_build_object('request_id', p_request_id, 'substitution_id', v_sub)
  );

  RETURN jsonb_build_object('success', true, 'substitution_id', v_sub, 'message_id', v_msg);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Customer approves or rejects substitution
CREATE OR REPLACE FUNCTION public.respond_substitution(
  p_sub_id   UUID,
  p_approved BOOLEAN,
  p_note     TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_sub RECORD;
BEGIN
  SELECT s.*, r.customer_id, r.winga_id
    INTO v_sub
  FROM public.substitutions s
  JOIN public.requests r ON r.id = s.request_id
  WHERE s.id = p_sub_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Substitution not found');
  END IF;
  IF v_sub.customer_id <> auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Only the customer can respond');
  END IF;
  IF v_sub.status <> 'pending' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Already responded');
  END IF;

  UPDATE public.substitutions SET
    status        = CASE WHEN p_approved THEN 'approved' ELSE 'rejected' END,
    customer_note = p_note,
    responded_at  = NOW()
  WHERE id = p_sub_id;

  -- System message in chat
  INSERT INTO public.messages
    (request_id, sender_id, sender_type, type, body, metadata)
  VALUES (
    v_sub.request_id, auth.uid(), 'system', 'system',
    CASE WHEN p_approved
      THEN '✅ Umeidhinisha: ' || v_sub.suggested_item
      ELSE '❌ Umekataa: ' || v_sub.suggested_item || COALESCE(' — ' || p_note, '')
    END,
    jsonb_build_object('substitution_id', p_sub_id, 'approved', p_approved)
  );

  -- Notify Winga
  INSERT INTO public.notifications (user_id, title, body, type, data)
  SELECT user_id,
    CASE WHEN p_approved THEN '✅ Badiliko limeidhinishwa' ELSE '❌ Badiliko limekataliwa' END,
    CASE WHEN p_approved
      THEN 'Mteja ameidhinisha: ' || v_sub.suggested_item
      ELSE 'Mteja amekataa: ' || COALESCE(p_note, 'hakuna sababu')
    END,
    'info',
    jsonb_build_object('substitution_id', p_sub_id, 'approved', p_approved)
  FROM public.wingas WHERE id = v_sub.winga_id;

  RETURN jsonb_build_object('success', true, 'approved', p_approved);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.propose_substitution(UUID,TEXT,INT,TEXT,INT,TEXT,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_substitution(UUID,BOOLEAN,TEXT)               TO authenticated;

-- ════════════════════════════════════════════════════════════
-- 6. DISPUTE RESOLUTION
-- Customer raises dispute → admin reviews → resolves
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.disputes (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id    UUID NOT NULL REFERENCES public.requests(id),
  raised_by     UUID NOT NULL REFERENCES public.users(id),
  winga_id      UUID NOT NULL REFERENCES public.wingas(id),
  category      TEXT NOT NULL
                CHECK (category IN (
                  'wrong_items','missing_items','overcharged',
                  'late_delivery','winga_no_show','quality',
                  'damage','misconduct','other'
                )),
  description   TEXT NOT NULL,
  evidence_urls TEXT[],          -- photos/screenshots
  amount_disputed INT,
  status        TEXT NOT NULL DEFAULT 'open'
                CHECK (status IN ('open','under_review','resolved_customer',
                                  'resolved_winga','resolved_partial','closed')),
  admin_id      UUID REFERENCES public.users(id),
  admin_note    TEXT,
  refund_amount INT,
  penalty_points INT DEFAULT 0,  -- deducted from Winga's points on resolution
  resolved_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_disputes_request ON public.disputes(request_id);
CREATE INDEX IF NOT EXISTS idx_disputes_status  ON public.disputes(status, created_at);
CREATE INDEX IF NOT EXISTS idx_disputes_winga   ON public.disputes(winga_id);

ALTER TABLE public.disputes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "disputes_own" ON public.disputes;
CREATE POLICY "disputes_own" ON public.disputes
  FOR ALL USING (auth.uid() = raised_by OR public.is_admin());
DROP POLICY IF EXISTS "disputes_winga_view" ON public.disputes;
CREATE POLICY "disputes_winga_view" ON public.disputes
  FOR SELECT USING (winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid()));

-- RPC: Raise a dispute
CREATE OR REPLACE FUNCTION public.raise_dispute(
  p_request_id    UUID,
  p_category      TEXT,
  p_description   TEXT,
  p_amount_disputed INT DEFAULT NULL,
  p_evidence_urls TEXT[] DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_req RECORD;
  v_dispute UUID;
BEGIN
  SELECT * INTO v_req FROM public.requests WHERE id = p_request_id
    AND customer_id = auth.uid();
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Request not found or not yours');
  END IF;
  IF v_req.winga_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'No Winga on this request');
  END IF;
  IF EXISTS (SELECT 1 FROM public.disputes WHERE request_id = p_request_id AND status = 'open') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Dispute already open for this request');
  END IF;

  INSERT INTO public.disputes
    (request_id, raised_by, winga_id, category, description, amount_disputed, evidence_urls)
  VALUES
    (p_request_id, auth.uid(), v_req.winga_id, p_category, p_description, p_amount_disputed, p_evidence_urls)
  RETURNING id INTO v_dispute;

  -- Notify admins
  INSERT INTO public.notifications (user_id, title, body, type, data)
  SELECT id,
    '⚠️ Malalamiko Mapya — ' || p_category,
    p_description,
    'error',
    jsonb_build_object('dispute_id', v_dispute, 'request_id', p_request_id)
  FROM public.users WHERE user_type = 'admin';

  RETURN jsonb_build_object('success', true, 'dispute_id', v_dispute);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Admin resolves dispute
CREATE OR REPLACE FUNCTION public.resolve_dispute(
  p_dispute_id   UUID,
  p_resolution   TEXT,
  p_admin_note   TEXT,
  p_refund_amount INT DEFAULT 0,
  p_penalty_points INT DEFAULT 0
)
RETURNS JSONB AS $$
DECLARE
  v_disp RECORD;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Admin only');
  END IF;

  SELECT * INTO v_disp FROM public.disputes WHERE id = p_dispute_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Not found'); END IF;

  UPDATE public.disputes SET
    status         = p_resolution,
    admin_id       = auth.uid(),
    admin_note     = p_admin_note,
    refund_amount  = p_refund_amount,
    penalty_points = p_penalty_points,
    resolved_at    = NOW()
  WHERE id = p_dispute_id;

  -- Apply point penalty to Winga
  IF p_penalty_points > 0 THEN
    INSERT INTO public.winga_points (winga_id, request_id, customer_id, point, reason)
    VALUES (v_disp.winga_id, v_disp.request_id, v_disp.raised_by, 0,
            'Adhabu ya malalamiko: ' || p_admin_note)
    ON CONFLICT (request_id) DO NOTHING;
  END IF;

  -- Notify both parties
  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES
    (v_disp.raised_by,
     'Malalamiko yameshughulikiwa',
     p_admin_note || CASE WHEN p_refund_amount > 0 THEN ' · TZS ' || p_refund_amount || ' itarudishwa.' ELSE '' END,
     'success',
     jsonb_build_object('dispute_id', p_dispute_id, 'refund', p_refund_amount));

  INSERT INTO public.notifications (user_id, title, body, type, data)
  SELECT user_id,
    'Malalamiko yamekamilika',
    p_admin_note,
    'warning',
    jsonb_build_object('dispute_id', p_dispute_id, 'penalty', p_penalty_points)
  FROM public.wingas WHERE id = v_disp.winga_id;

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.raise_dispute(UUID,TEXT,TEXT,INT,TEXT[])        TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_dispute(UUID,TEXT,TEXT,INT,INT)          TO service_role, authenticated;

-- ════════════════════════════════════════════════════════════
-- 7. TIPS
-- Customer adds tip after payment. Separate from service fee.
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.tips (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id     UUID NOT NULL REFERENCES public.requests(id),
  customer_id    UUID NOT NULL REFERENCES public.users(id),
  winga_id       UUID NOT NULL REFERENCES public.wingas(id),
  amount         INT NOT NULL CHECK (amount > 0),
  payment_method TEXT NOT NULL,
  provider_ref   TEXT,
  status         TEXT NOT NULL DEFAULT 'success',
  message        TEXT,          -- optional "great job!" note
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uniq_tip_per_request UNIQUE (request_id)
);

CREATE INDEX IF NOT EXISTS idx_tips_winga ON public.tips(winga_id);

ALTER TABLE public.tips ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "tips_customer_own" ON public.tips;
CREATE POLICY "tips_customer_own" ON public.tips FOR ALL USING (auth.uid() = customer_id);
DROP POLICY IF EXISTS "tips_winga_view" ON public.tips;
CREATE POLICY "tips_winga_view"   ON public.tips FOR SELECT USING (
  winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid())
);

-- Include tips in Winga earnings
CREATE OR REPLACE FUNCTION public.get_winga_tip_total(p_winga_id UUID)
RETURNS INT AS $$
  SELECT COALESCE(SUM(amount), 0) FROM public.tips
  WHERE winga_id = p_winga_id AND status = 'success';
$$ LANGUAGE sql SECURITY DEFINER STABLE;

GRANT EXECUTE ON FUNCTION public.get_winga_tip_total(UUID) TO authenticated;

-- ════════════════════════════════════════════════════════════
-- 8. SHOPPING LIST
-- Customer sends a structured item list before/during booking
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.shopping_lists (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id  UUID NOT NULL REFERENCES public.requests(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES public.users(id),
  title       TEXT NOT NULL DEFAULT 'Orodha yangu',
  notes       TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.shopping_list_items (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  list_id         UUID NOT NULL REFERENCES public.shopping_lists(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  quantity        TEXT NOT NULL DEFAULT '1',
  unit            TEXT,                -- e.g. kg, pieces, litres
  estimated_price INT,
  notes           TEXT,               -- e.g. "must be Samsung not Tecno"
  photo_url       TEXT,               -- reference photo
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','found','substituted','not_found')),
  actual_price    INT,                -- filled by Winga
  sort_order      INT NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_list_items_list ON public.shopping_list_items(list_id);

ALTER TABLE public.shopping_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shopping_list_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "list_participants" ON public.shopping_lists;
CREATE POLICY "list_participants" ON public.shopping_lists
  FOR ALL USING (
    customer_id = auth.uid()
    OR request_id IN (SELECT id FROM public.requests WHERE
      winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid()))
  );
DROP POLICY IF EXISTS "list_items_via_list" ON public.shopping_list_items;
CREATE POLICY "list_items_via_list" ON public.shopping_list_items
  FOR ALL USING (
    list_id IN (SELECT id FROM public.shopping_lists WHERE
      customer_id = auth.uid()
      OR request_id IN (SELECT id FROM public.requests WHERE
        winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid())))
  );

-- ════════════════════════════════════════════════════════════
-- 9. REFERRAL PROGRAM
-- Invite code → both customer and referred friend get discount
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.referrals (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  referrer_id     UUID NOT NULL REFERENCES public.users(id),
  referred_id     UUID REFERENCES public.users(id),
  code            TEXT UNIQUE NOT NULL,
  discount_pct    INT NOT NULL DEFAULT 20,      -- 20% off first booking
  referrer_reward INT NOT NULL DEFAULT 2000,    -- TZS 2,000 wallet credit
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','used','expired')),
  used_at         TIMESTAMPTZ,
  expires_at      TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '90 days',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_referrals_code     ON public.referrals(code);
CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON public.referrals(referrer_id);

ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "referrals_own" ON public.referrals;
CREATE POLICY "referrals_own" ON public.referrals
  FOR ALL USING (auth.uid() = referrer_id OR auth.uid() = referred_id);

-- Wallet balance (referral rewards + refunds accumulate here)
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS wallet_balance INT NOT NULL DEFAULT 0;

CREATE OR REPLACE FUNCTION public.generate_referral_code(p_user_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_code TEXT;
  v_name TEXT;
BEGIN
  SELECT UPPER(SUBSTR(name, 1, 4)) INTO v_name FROM public.users WHERE id = p_user_id;
  v_code := COALESCE(v_name, 'WNGA') || UPPER(SUBSTR(MD5(p_user_id::TEXT || NOW()::TEXT), 1, 4));

  INSERT INTO public.referrals (referrer_id, code)
  VALUES (p_user_id, v_code)
  ON CONFLICT (code) DO UPDATE SET code = v_code || '2';  -- handle collision

  RETURN v_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.apply_referral_code(p_code TEXT, p_new_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_ref RECORD;
BEGIN
  SELECT * INTO v_ref FROM public.referrals
  WHERE code = UPPER(p_code) AND status = 'pending' AND expires_at > NOW();

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Code si sahihi au imeisha muda');
  END IF;
  IF v_ref.referrer_id = p_new_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Huwezi kutumia code yako mwenyewe');
  END IF;

  UPDATE public.referrals SET
    referred_id = p_new_user_id, status = 'used', used_at = NOW()
  WHERE id = v_ref.id;

  -- Credit referrer's wallet
  UPDATE public.users SET wallet_balance = wallet_balance + v_ref.referrer_reward
  WHERE id = v_ref.referrer_id;

  RETURN jsonb_build_object(
    'success', true,
    'discount_pct', v_ref.discount_pct,
    'referrer_reward', v_ref.referrer_reward,
    'message', 'Unafaidika na punguzo la ' || v_ref.discount_pct || '% kwenye booking yako ya kwanza!'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.generate_referral_code(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.apply_referral_code(TEXT, UUID) TO authenticated;

-- ════════════════════════════════════════════════════════════
-- 10. WINGA AVAILABILITY CALENDAR
-- Winga sets which hours/days they are available.
-- Prevents ghosted bookings when Winga is offline.
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.winga_availability (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  winga_id    UUID NOT NULL REFERENCES public.wingas(id) ON DELETE CASCADE,
  day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6), -- 0=Sun
  start_time  TIME NOT NULL DEFAULT '08:00',
  end_time    TIME NOT NULL DEFAULT '18:00',
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT uniq_winga_day UNIQUE (winga_id, day_of_week)
);

CREATE TABLE IF NOT EXISTS public.winga_blackout_dates (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  winga_id   UUID NOT NULL REFERENCES public.wingas(id) ON DELETE CASCADE,
  date       DATE NOT NULL,
  reason     TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uniq_blackout UNIQUE (winga_id, date)
);

CREATE INDEX IF NOT EXISTS idx_avail_winga   ON public.winga_availability(winga_id);
CREATE INDEX IF NOT EXISTS idx_blackout_date ON public.winga_blackout_dates(winga_id, date);

ALTER TABLE public.winga_availability    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.winga_blackout_dates  ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "avail_own" ON public.winga_availability;
CREATE POLICY "avail_own"     ON public.winga_availability   FOR ALL USING (
  winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid()) OR public.is_admin()
);
DROP POLICY IF EXISTS "avail_public" ON public.winga_availability;
CREATE POLICY "avail_public"  ON public.winga_availability   FOR SELECT USING (true);
DROP POLICY IF EXISTS "blackout_own" ON public.winga_blackout_dates;
CREATE POLICY "blackout_own"  ON public.winga_blackout_dates FOR ALL USING (
  winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid()) OR public.is_admin()
);
DROP POLICY IF EXISTS "blackout_pub" ON public.winga_blackout_dates;
CREATE POLICY "blackout_pub"  ON public.winga_blackout_dates FOR SELECT USING (true);

-- Is a Winga available right now?
CREATE OR REPLACE FUNCTION public.is_winga_available(p_winga_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_now   TIMESTAMPTZ := NOW() AT TIME ZONE 'Africa/Dar_es_Salaam';
  v_day   INT := EXTRACT(DOW FROM v_now);
  v_time  TIME := v_now::TIME;
  v_date  DATE := v_now::DATE;
  v_avail RECORD;
BEGIN
  -- Check blackout
  IF EXISTS (SELECT 1 FROM public.winga_blackout_dates
             WHERE winga_id = p_winga_id AND date = v_date) THEN
    RETURN FALSE;
  END IF;

  SELECT * INTO v_avail FROM public.winga_availability
  WHERE winga_id = p_winga_id AND day_of_week = v_day AND is_active = TRUE;

  IF NOT FOUND THEN RETURN FALSE; END IF;
  RETURN v_time BETWEEN v_avail.start_time AND v_avail.end_time;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

GRANT EXECUTE ON FUNCTION public.is_winga_available(UUID) TO anon, authenticated;

-- ════════════════════════════════════════════════════════════
-- 11. SCALABILITY INDEXES & REALTIME
-- Pre-set for high-volume queries
-- ════════════════════════════════════════════════════════════

-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_wingas_city_online
  ON public.wingas(current_city, is_online, status)
  WHERE status = 'active' AND verification_status = 'verified';

CREATE INDEX IF NOT EXISTS idx_wingas_score_city
  ON public.wingas(current_city, winga_score DESC)
  WHERE status = 'active' AND verification_status = 'verified';

CREATE INDEX IF NOT EXISTS idx_requests_active
  ON public.requests(status, created_at DESC)
  WHERE status IN ('searching','accepted','shopping');

CREATE INDEX IF NOT EXISTS idx_messages_unread
  ON public.messages(request_id, is_read)
  WHERE is_read = FALSE;

-- Enable realtime on key tables
ALTER TABLE public.requests      REPLICA IDENTITY FULL;
ALTER TABLE public.substitutions REPLICA IDENTITY FULL;
ALTER TABLE public.disputes      REPLICA IDENTITY FULL;
ALTER TABLE public.tips          REPLICA IDENTITY FULL;


-- ============================================================
-- Winga App — Migration 010: Auto-Verification via Points
--
-- BADGES ARE NOW AUTOMATIC. No admin approval needed.
-- Customer ratings (points) drive badge promotion:
--   Starter  : Auto on registration (0 trips required)
--   Mid      : Auto at 10+ rated trips AND Wilson score >= 0.60
--   Verified : Auto at 30+ rated trips AND Wilson score >= 0.80
--
-- Downgrades happen automatically if score drops (decay protection
-- gives 7 days grace before losing a tier).
--
-- Admin can still MANUALLY override (assign/demote) if needed.
-- ============================================================

-- ── Auto-promote function ─────────────────────────────────────
-- Called by trigger after every point recalculation.
-- Checks highest eligible tier and auto-assigns.
CREATE OR REPLACE FUNCTION public.auto_promote_winga(p_winga_id UUID)
RETURNS VOID AS $$
DECLARE
  v_winga RECORD;
  v_old_badge TEXT;
  v_new_badge TEXT;
  v_tier_id  UUID;
  v_promoted BOOLEAN := FALSE;
BEGIN
  SELECT * INTO v_winga
  FROM public.wingas WHERE id = p_winga_id;

  IF NOT FOUND THEN RETURN; END IF;
  -- Don't auto-promote suspended/rejected wingas
  IF v_winga.status = 'suspended' THEN RETURN; END IF;

  v_old_badge := COALESCE(v_winga.badge, 'none');

  -- Determine highest eligible tier (check from highest to lowest)
  -- Verified: 30+ trips, score >= 0.80
  IF v_winga.rated_trips >= 30 AND v_winga.winga_score >= 0.80 THEN
    v_new_badge := 'Verified';
  -- Mid: 10+ trips, score >= 0.60
  ELSIF v_winga.rated_trips >= 10 AND v_winga.winga_score >= 0.60 THEN
    v_new_badge := 'Mid';
  -- Starter: always eligible (even 0 trips)
  ELSE
    v_new_badge := 'Starter';
  END IF;

  -- No change needed
  IF v_new_badge = v_old_badge THEN RETURN; END IF;

  -- Get tier ID
  SELECT id INTO v_tier_id
  FROM public.verification_tiers WHERE name = v_new_badge;

  -- Auto-assign the badge
  UPDATE public.wingas SET
    badge               = v_new_badge,
    verification_tier   = v_new_badge,
    tier_id             = v_tier_id,
    verification_status = 'verified',
    status              = 'active',
    verified_at         = COALESCE(v_winga.verified_at, NOW()),
    verified_by         = NULL,  -- system, not admin
    badge_assigned_at   = NOW(),
    badge_assigned_by   = NULL,  -- system
    badge_expires_at    = NULL   -- auto-promoted badges don't expire
  WHERE id = p_winga_id;

  -- Mark user as verified
  UPDATE public.users SET is_verified = TRUE
  WHERE id = v_winga.user_id AND NOT is_verified;

  v_promoted := TRUE;

  -- Notify the Winga
  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES (
    v_winga.user_id,
    CASE
      WHEN v_new_badge = 'Verified' THEN '🎉 Umeitwa kuwa Winga Aliyethibitishwa!'
      WHEN v_new_badge = 'Mid' THEN '🥈 Badge ya Mid Imekubaliwa!'
      ELSE '🥉 Karibu! Umepata Badge ya Starter'
    END,
    CASE
      WHEN v_new_badge = 'Verified' THEN
        'Huduma yako bora imekufanya upate badge ya Verified! ' ||
        'Utaonekana kwenye orodha ya juu na utapewa kipaumbele.'
      WHEN v_new_badge = 'Mid' THEN
        'Maoni ya wateja yamekupa badge ya Mid! ' ||
        'Endelea kutoa huduma nzuri kupata Verified.'
      ELSE
        'Karibu kwenye Winga! Umeanza na badge ya Starter. ' ||
        'Toa huduma nzuri na pata maoni mazuri kustahili Mid.'
    END,
    'verification',
    jsonb_build_object(
      'badge', v_new_badge,
      'previous_badge', v_old_badge,
      'auto', true,
      'rated_trips', v_winga.rated_trips,
      'score', v_winga.winga_score,
      'winga_id', p_winga_id
    )
  );

  -- Log the auto-promotion
  INSERT INTO public.admin_audit_log (admin_id, action, target_type, target_id, details)
  VALUES (
    NULL,  -- system action, no admin
    'auto_promote',
    'winga',
    p_winga_id,
    jsonb_build_object(
      'old_badge', v_old_badge,
      'new_badge', v_new_badge,
      'rated_trips', v_winga.rated_trips,
      'score', v_winga.winga_score,
      'auto', true
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── Auto-grant Starter badge on Winga registration ─────────────
-- When a new Winga is inserted, immediately give them Starter badge
-- and set status to active (no manual approval needed).
CREATE OR REPLACE FUNCTION public.auto_starter_on_register()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.badge IS NULL OR NEW.badge = 'none' THEN
    NEW.badge := 'Starter';
    NEW.verification_tier := 'Starter';
    NEW.verification_status := 'verified';
    NEW.status := 'active';
    NEW.verified_at := NOW();
    NEW.badge_assigned_at := NOW();
    -- Get tier_id for Starter
    SELECT id INTO NEW.tier_id
    FROM public.verification_tiers WHERE name = 'Starter' LIMIT 1;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auto_starter ON public.wingas;
CREATE TRIGGER trg_auto_starter
  BEFORE INSERT ON public.wingas
  FOR EACH ROW EXECUTE FUNCTION public.auto_starter_on_register();

-- ── Hook auto-promote into the existing points recalc trigger ──
-- Modify recalc_winga_points to call auto_promote after updating
CREATE OR REPLACE FUNCTION public.recalc_winga_points()
RETURNS TRIGGER AS $$
DECLARE
  v_winga UUID := COALESCE(NEW.winga_id, OLD.winga_id);
  v_good  INT;
  v_total INT;
BEGIN
  SELECT COALESCE(SUM(point), 0), COUNT(*)
    INTO v_good, v_total
  FROM public.winga_points
  WHERE winga_id = v_winga;

  UPDATE public.wingas SET
    total_points = v_good,
    rated_trips  = v_total,
    point_rate   = CASE WHEN v_total = 0 THEN 0
                        ELSE ROUND(v_good * 100.0 / v_total, 2) END,
    winga_score  = public.wilson_score(v_good, v_total)
  WHERE id = v_winga;

  -- AUTO-PROMOTE: check if badge should upgrade
  PERFORM public.auto_promote_winga(v_winga);

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── Grace period: don't auto-downgrade immediately ─────────────
-- If a Winga's score drops, give 7 days before downgrading.
-- (The auto_promote function above only upgrades.
--  Downgrading is handled by a separate cron-safe function.)
CREATE OR REPLACE FUNCTION public.auto_downgrade_badges()
RETURNS JSONB AS $$
DECLARE
  v_count INT := 0;
  v_rec RECORD;
  v_new_badge TEXT;
  v_tier_id UUID;
BEGIN
  -- Find wingas whose badge doesn't match their earned tier
  -- AND have been at current tier for 7+ days (grace period)
  FOR v_rec IN
    SELECT w.id, w.badge, w.rated_trips, w.winga_score,
           w.badge_assigned_at
    FROM public.wingas w
    WHERE w.verification_status = 'verified'
      AND w.badge != 'none'
      AND w.badge_assigned_at < NOW() - INTERVAL '7 days'
  LOOP
    -- Determine what tier they should be at
    IF v_rec.rated_trips >= 30 AND v_rec.winga_score >= 0.80 THEN
      v_new_badge := 'Verified';
    ELSIF v_rec.rated_trips >= 10 AND v_rec.winga_score >= 0.60 THEN
      v_new_badge := 'Mid';
    ELSE
      v_new_badge := 'Starter';
    END IF;

    IF v_new_badge <> v_rec.badge THEN
      SELECT id INTO v_tier_id
      FROM public.verification_tiers WHERE name = v_new_badge;

      UPDATE public.wingas SET
        badge = v_new_badge,
        verification_tier = v_new_badge,
        tier_id = v_tier_id,
        badge_assigned_at = NOW()
      WHERE id = v_rec.id;

      INSERT INTO public.notifications (user_id, title, body, type, data)
      VALUES (
        (SELECT user_id FROM public.wingas WHERE id = v_rec.id),
        'Badge Imeshushwa — ' || v_new_badge,
        'Alama yako ya huduma imeshuka. Sasa uko kwenye tier ya ' || v_new_badge ||
        '. Toa huduma bora kupata nyuzi zaidi.',
        'verification',
        jsonb_build_object('old_badge', v_rec.badge, 'new_badge', v_new_badge, 'auto', true)
      );

      v_count := v_count + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'downgraded', v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── RLS for the new function ───────────────────────────────────
GRANT EXECUTE ON FUNCTION public.auto_promote_winga(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.auto_downgrade_badges() TO service_role;

-- ── Update expire_subscriptions: don't strip badges ────────────
-- Since badges are now points-based (not payment-based),
-- subscription expiry should NOT remove the badge.
CREATE OR REPLACE FUNCTION public.expire_subscriptions()
RETURNS void AS $$
BEGIN
  UPDATE public.wingas
  SET
    subscription_active = FALSE
  WHERE
    subscription_active = TRUE
    AND subscription_end < NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.expire_subscriptions() TO service_role;

-- ============================================================
-- Migration 011: Fix RLS policies for PWA
-- Fixes "permission denied for table requests" error
-- Also ensures all PWA-required columns exist
-- ============================================================

-- ── Fix requests RLS: FOR ALL with only USING doesn't cover INSERT ──────────
-- PostgreSQL: USING applies to SELECT/UPDATE/DELETE row filtering
--             WITH CHECK applies to INSERT/UPDATE row creation
-- The old policy "FOR ALL USING (auth.uid() = customer_id)" 
-- does NOT allow INSERT because there's no WITH CHECK clause

DROP POLICY IF EXISTS "requests_customer_own"    ON public.requests;
DROP POLICY IF EXISTS "requests_winga_assigned"  ON public.requests;
DROP POLICY IF EXISTS "requests_winga_searching" ON public.requests;
DROP POLICY IF EXISTS "requests_winga_update"    ON public.requests;
DROP POLICY IF EXISTS "requests_admin"           ON public.requests;

-- Customer: full access to their own requests
CREATE POLICY "requests_customer_select" ON public.requests
  FOR SELECT USING (auth.uid() = customer_id);

CREATE POLICY "requests_customer_insert" ON public.requests
  FOR INSERT WITH CHECK (auth.uid() = customer_id);

CREATE POLICY "requests_customer_update" ON public.requests
  FOR UPDATE USING (auth.uid() = customer_id);

-- Winga: see requests assigned to them OR open 'searching' requests  
CREATE POLICY "requests_winga_view" ON public.requests
  FOR SELECT USING (
    status = 'searching'
    OR winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid())
  );

-- Winga: update requests assigned to them (accept, shopping, complete)
CREATE POLICY "requests_winga_update" ON public.requests
  FOR UPDATE USING (
    winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid())
  ) WITH CHECK (
    winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid())
  );

-- Admin: full access
CREATE POLICY "requests_admin" ON public.requests
  FOR ALL USING (public.is_admin());

-- ── Fix wingas INSERT/UPDATE: PWA registers Wingas directly ──────────────────
DROP POLICY IF EXISTS "wingas_insert"    ON public.wingas;
DROP POLICY IF EXISTS "wingas_own"       ON public.wingas;
DROP POLICY IF EXISTS "wingas_admin_all" ON public.wingas;

-- Public: read active verified wingas
CREATE POLICY "wingas_public_read" ON public.wingas
  FOR SELECT USING (
    status = 'active' AND verification_status = 'verified'
    OR user_id = auth.uid()
    OR public.is_admin()
  );

-- Winga: insert their own record
CREATE POLICY "wingas_insert" ON public.wingas
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Winga: update their own record
CREATE POLICY "wingas_own_update" ON public.wingas
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Admin: full access
CREATE POLICY "wingas_admin" ON public.wingas
  FOR ALL USING (public.is_admin());

-- ── Fix users: allow upsert from PWA registration ────────────────────────────
DROP POLICY IF EXISTS "users_insert"   ON public.users;
DROP POLICY IF EXISTS "users_own_read" ON public.users;

CREATE POLICY "users_own_read" ON public.users
  FOR SELECT USING (auth.uid() = id OR public.is_admin());

CREATE POLICY "users_insert" ON public.users
  FOR INSERT WITH CHECK (true);  -- anyone can register

CREATE POLICY "users_upsert" ON public.users
  FOR UPDATE USING (auth.uid() = id);

-- ── Ensure all columns exist (safe ADD COLUMN IF NOT EXISTS) ─────────────────

-- requests: columns added in 009
ALTER TABLE public.requests
  ADD COLUMN IF NOT EXISTS location_id  UUID REFERENCES public.locations(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS city         TEXT,
  ADD COLUMN IF NOT EXISTS area         TEXT,
  ADD COLUMN IF NOT EXISTS request_lat  NUMERIC(10,7),
  ADD COLUMN IF NOT EXISTS request_lng  NUMERIC(10,7),
  ADD COLUMN IF NOT EXISTS total_price  INT;        -- alias for estimated_price, used by PWA

-- wingas: columns added in 007, 009
ALTER TABLE public.wingas
  ADD COLUMN IF NOT EXISTS total_points    INT     NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rated_trips     INT     NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS point_rate      NUMERIC(5,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS winga_score     NUMERIC(6,4) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_top_rated    BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS current_city    TEXT,
  ADD COLUMN IF NOT EXISTS current_area    TEXT,
  ADD COLUMN IF NOT EXISTS current_lat     NUMERIC(10,7),
  ADD COLUMN IF NOT EXISTS current_lng     NUMERIC(10,7),
  ADD COLUMN IF NOT EXISTS bio             TEXT;

-- users: wallet balance added in 009
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS wallet_balance INT NOT NULL DEFAULT 0;

-- ── tips table (from 009) ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.tips (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id     UUID NOT NULL REFERENCES public.requests(id),
  customer_id    UUID NOT NULL REFERENCES public.users(id),
  winga_id       UUID NOT NULL REFERENCES public.wingas(id),
  amount         INT NOT NULL CHECK (amount > 0),
  payment_method TEXT NOT NULL DEFAULT 'wallet',
  provider_ref   TEXT,
  status         TEXT NOT NULL DEFAULT 'success',
  message        TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uniq_tip_per_request UNIQUE (request_id)
);

ALTER TABLE public.tips ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "tips_customer_own" ON public.tips;
DROP POLICY IF EXISTS "tips_winga_view"   ON public.tips;
CREATE POLICY "tips_customer_own" ON public.tips FOR ALL   USING (auth.uid() = customer_id);
CREATE POLICY "tips_winga_view"   ON public.tips FOR SELECT USING (
  winga_id IN (SELECT id FROM public.wingas WHERE user_id = auth.uid())
);
GRANT SELECT, INSERT ON public.tips TO authenticated;

-- ── locations table (from 009) ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.locations (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  country     TEXT NOT NULL DEFAULT 'Tanzania',
  region      TEXT NOT NULL,
  city        TEXT NOT NULL,
  area        TEXT,
  lat         NUMERIC(10,7),
  lng         NUMERIC(10,7),
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order  INT NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.locations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "locations_public" ON public.locations;
CREATE POLICY "locations_public" ON public.locations FOR SELECT USING (is_active = TRUE);
GRANT SELECT ON public.locations TO anon, authenticated;

-- Seed Tanzania locations if empty
INSERT INTO public.locations (country, region, city, area, lat, lng, sort_order)
SELECT * FROM (VALUES
  ('Tanzania','Dar es Salaam','Dar es Salaam','Kariakoo',       -6.8161, 39.2894, 1),
  ('Tanzania','Dar es Salaam','Dar es Salaam','Mwenge',          -6.7780, 39.2630, 2),
  ('Tanzania','Dar es Salaam','Dar es Salaam','Mnazi Mmoja',     -6.8193, 39.2884, 3),
  ('Tanzania','Dar es Salaam','Dar es Salaam','Ilala',           -6.8235, 39.2695, 4),
  ('Tanzania','Dar es Salaam','Dar es Salaam','Kinondoni',       -6.7834, 39.2707, 5),
  ('Tanzania','Dar es Salaam','Dar es Salaam','Temeke',          -6.8726, 39.2990, 6),
  ('Tanzania','Dar es Salaam','Dar es Salaam','Tabata',          -6.8416, 39.2534, 7),
  ('Tanzania','Arusha','Arusha','Arusha CBD',                   -3.3869, 36.6830, 10),
  ('Tanzania','Kilimanjaro','Moshi','Moshi Market',              -3.3531, 37.3403, 20),
  ('Tanzania','Mwanza','Mwanza','Mwanza Market',                 -2.5164, 32.9175, 30),
  ('Tanzania','Dodoma','Dodoma','Dodoma Market',                 -6.1731, 35.7395, 40),
  ('Tanzania','Zanzibar','Zanzibar City','Darajani Market',      -6.1622, 39.1894, 50),
  ('Tanzania','Zanzibar','Zanzibar City','Stone Town',           -6.1630, 39.1900, 51)
) AS t(country,region,city,area,lat,lng,sort_order)
WHERE NOT EXISTS (SELECT 1 FROM public.locations LIMIT 1);

-- ── Grant permissions ─────────────────────────────────────────────────────────
GRANT SELECT ON public.wingas    TO anon;
GRANT SELECT ON public.wingas    TO authenticated;
GRANT INSERT, UPDATE ON public.wingas    TO authenticated;
GRANT SELECT ON public.requests  TO authenticated;
GRANT INSERT, UPDATE ON public.requests  TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.users TO authenticated;
GRANT SELECT ON public.verification_tiers TO anon, authenticated;
GRANT SELECT ON public.locations TO anon, authenticated;

-- ── rate_winga function grant (points RPC) ────────────────────────────────────
GRANT EXECUTE ON FUNCTION public.rate_winga(UUID, INT, TEXT) TO authenticated;

