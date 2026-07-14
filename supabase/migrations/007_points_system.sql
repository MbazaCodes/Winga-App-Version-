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
