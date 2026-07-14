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
