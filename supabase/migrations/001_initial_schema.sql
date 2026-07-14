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
