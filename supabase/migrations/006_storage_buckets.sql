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
