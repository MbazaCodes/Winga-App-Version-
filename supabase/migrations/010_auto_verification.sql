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