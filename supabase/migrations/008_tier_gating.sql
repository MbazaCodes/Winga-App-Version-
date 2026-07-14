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
