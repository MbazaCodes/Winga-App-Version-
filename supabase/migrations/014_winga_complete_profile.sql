-- ============================================================
-- Migration 014: Fix winga_id_seq permission + Profile Completion
-- Run in Supabase SQL Editor:
-- https://supabase.com/dashboard/project/kevdbsyiqelksxvmuped/sql/new
-- ============================================================

-- ── 1. FIX: Grant USAGE on winga_id_seq to authenticated ───────
-- This fixes "permission denied for sequence winga_id_seq" error
-- that occurs when the set_winga_id trigger runs for client-side inserts
GRANT USAGE, SELECT ON SEQUENCE public.winga_id_seq TO authenticated, anon;

-- ── 2. Make trigger function SECURITY DEFINER ──────────────────
-- Even with the grant, make it bulletproof by running as table owner
CREATE OR REPLACE FUNCTION public.generate_winga_id()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.winga_id IS NULL OR NEW.winga_id = '' THEN
    NEW.winga_id = 'WNGA' || LPAD(nextval('winga_id_seq')::TEXT, 5, '0');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 3. Add profile_complete column ─────────────────────────────
ALTER TABLE public.wingas
  ADD COLUMN IF NOT EXISTS profile_complete BOOLEAN NOT NULL DEFAULT FALSE;

-- ── 4. RPC: Complete Winga Profile ─────────────────────────────
-- Called when Winga fills all required fields
-- Sets profile_complete = true only if ALL required fields are filled
CREATE OR REPLACE FUNCTION public.complete_winga_profile(
  p_user_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_winga RECORD;
  v_complete BOOLEAN;
  v_missing TEXT[];
BEGIN
  SELECT * INTO v_winga FROM public.wingas WHERE user_id = p_user_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Winga not found');
  END IF;

  -- Check all required fields
  v_missing := ARRAY[]::TEXT[];
  IF v_winga.national_id IS NULL OR v_winga.national_id = '' THEN
    v_missing := v_missing || 'Namba ya NIDA';
  END IF;
  IF v_winga.specialty IS NULL OR v_winga.specialty = '' OR v_winga.specialty = 'General' THEN
    v_missing := v_missing || 'Utaalamu';
  END IF;
  IF v_winga.current_city IS NULL OR v_winga.current_city = '' THEN
    v_missing := v_missing || 'Mji';
  END IF;
  IF v_winga.current_area IS NULL OR v_winga.current_area = '' THEN
    v_missing := v_missing || 'Eneo';
  END IF;
  IF v_winga.bio IS NULL OR v_winga.bio = '' THEN
    v_missing := v_missing || 'Kuhusu Mimi';
  END IF;
  IF v_winga.profile_photo_url IS NULL OR v_winga.profile_photo_url = '' THEN
    v_missing := v_missing || 'Picha ya Wasifu';
  END IF;

  v_complete := array_length(v_missing, 1) IS NULL;

  -- Update profile_complete status
  UPDATE public.wingas
  SET profile_complete = v_complete,
      status = CASE WHEN v_complete AND verification_status = 'verified' THEN 'active'
                    WHEN NOT v_complete THEN 'pending'
                    ELSE status END
  WHERE user_id = p_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'profile_complete', v_complete,
    'missing_fields', v_missing,
    'winga_id', v_winga.winga_id,
    'total_fields', 6,
    'filled_fields', 6 - COALESCE(array_length(v_missing, 1), 0)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.complete_winga_profile(UUID) TO authenticated;

-- ── 5. RPC: Lookup Winga by Winga ID (for login) ──────────────
CREATE OR REPLACE FUNCTION public.lookup_winga_by_id(
  p_winga_id TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_winga RECORD;
BEGIN
  SELECT * INTO v_winga FROM public.wingas
    WHERE winga_id = UPPER(p_winga_id);
  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;
  RETURN jsonb_build_object(
    'found', true,
    'phone', v_winga.phone,
    'name', v_winga.name,
    'user_id', v_winga.user_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.lookup_winga_by_id(TEXT) TO anon, authenticated;

-- ── 6. RPC: Get profile completion status ──────────────────────
CREATE OR REPLACE FUNCTION public.get_winga_profile_status(
  p_user_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_winga RECORD;
  v_fields JSONB;
  v_filled INT;
  v_total INT;
BEGIN
  SELECT * INTO v_winga FROM public.wingas WHERE user_id = p_user_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Winga not found');
  END IF;

  v_total := 6;
  v_filled := 0;
  v_fields := '[]'::jsonb;

  IF v_winga.national_id IS NOT NULL AND v_winga.national_id != '' THEN
    v_filled := v_filled + 1;
    v_fields := v_fields || '{"field": "Namba ya NIDA", "done": true}'::jsonb;
  ELSE
    v_fields := v_fields || '{"field": "Namba ya NIDA", "done": false}'::jsonb;
  END IF;

  IF v_winga.specialty IS NOT NULL AND v_winga.specialty != '' AND v_winga.specialty != 'General' THEN
    v_filled := v_filled + 1;
    v_fields := v_fields || '{"field": "Utaalamu", "done": true}'::jsonb;
  ELSE
    v_fields := v_fields || '{"field": "Utaalamu", "done": false}'::jsonb;
  END IF;

  IF v_winga.current_city IS NOT NULL AND v_winga.current_city != '' THEN
    v_filled := v_filled + 1;
    v_fields := v_fields || '{"field": "Mji", "done": true}'::jsonb;
  ELSE
    v_fields := v_fields || '{"field": "Mji", "done": false}'::jsonb;
  END IF;

  IF v_winga.current_area IS NOT NULL AND v_winga.current_area != '' THEN
    v_filled := v_filled + 1;
    v_fields := v_fields || '{"field": "Eneo", "done": true}'::jsonb;
  ELSE
    v_fields := v_fields || '{"field": "Eneo", "done": false}'::jsonb;
  END IF;

  IF v_winga.bio IS NOT NULL AND v_winga.bio != '' THEN
    v_filled := v_filled + 1;
    v_fields := v_fields || '{"field": "Kuhusu Mimi", "done": true}'::jsonb;
  ELSE
    v_fields := v_fields || '{"field": "Kuhusu Mimi", "done": false}'::jsonb;
  END IF;

  IF v_winga.profile_photo_url IS NOT NULL AND v_winga.profile_photo_url != '' THEN
    v_filled := v_filled + 1;
    v_fields := v_fields || '{"field": "Picha ya Wasifu", "done": true}'::jsonb;
  ELSE
    v_fields := v_fields || '{"field": "Picha ya Wasifu", "done": false}'::jsonb;
  END IF;

  UPDATE public.wingas SET profile_complete = (v_filled = v_total) WHERE user_id = p_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'profile_complete', v_filled = v_total,
    'filled', v_filled,
    'total', v_total,
    'percent', ROUND((v_filled::NUMERIC / v_total::NUMERIC) * 100, 0),
    'winga_id', v_winga.winga_id,
    'fields', v_fields
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_winga_profile_status(UUID) TO authenticated;

SELECT 'Migration 014 complete ✅' AS result;