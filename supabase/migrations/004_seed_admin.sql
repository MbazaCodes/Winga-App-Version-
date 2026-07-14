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