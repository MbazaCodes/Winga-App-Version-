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
