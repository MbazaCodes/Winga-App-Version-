-- Migration 013: Add TIN, social media, profile photos to Winga + users
ALTER TABLE public.wingas
  ADD COLUMN IF NOT EXISTS tin_number       TEXT,        -- TRA Tax ID (3% deducted)
  ADD COLUMN IF NOT EXISTS instagram        TEXT,
  ADD COLUMN IF NOT EXISTS facebook         TEXT,
  ADD COLUMN IF NOT EXISTS tiktok           TEXT,
  ADD COLUMN IF NOT EXISTS twitter          TEXT,
  ADD COLUMN IF NOT EXISTS whatsapp         TEXT,
  ADD COLUMN IF NOT EXISTS profile_photo_url TEXT;       -- Winga face photo (public)

-- users already has profile_image_url from schema — ensure grant
GRANT UPDATE ON public.users  TO authenticated;
GRANT UPDATE ON public.wingas TO authenticated;

-- Storage: allow uploading to avatars bucket (profile photos)
GRANT USAGE ON SCHEMA storage TO authenticated;

SELECT 'Migration 013 complete ✅' AS result;
