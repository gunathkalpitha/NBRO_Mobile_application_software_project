-- Profile settings extension for officer/admin professional profile management

ALTER TABLE public.profile
  ADD COLUMN IF NOT EXISTS phone_number TEXT,
  ADD COLUMN IF NOT EXISTS position_title TEXT,
  ADD COLUMN IF NOT EXISTS employee_id TEXT,
  ADD COLUMN IF NOT EXISTS work_role TEXT,
  ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Storage bucket for profile photos
INSERT INTO storage.buckets (id, name, public)
VALUES ('profile-images', 'profile-images', true)
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'profile_images_select_public'
  ) THEN
    CREATE POLICY profile_images_select_public
      ON storage.objects
      FOR SELECT
      USING (bucket_id = 'profile-images');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'profile_images_insert_own'
  ) THEN
    CREATE POLICY profile_images_insert_own
      ON storage.objects
      FOR INSERT
      TO authenticated
      WITH CHECK (
        bucket_id = 'profile-images'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'profile_images_update_own'
  ) THEN
    CREATE POLICY profile_images_update_own
      ON storage.objects
      FOR UPDATE
      TO authenticated
      USING (
        bucket_id = 'profile-images'
        AND (storage.foldername(name))[1] = auth.uid()::text
      )
      WITH CHECK (
        bucket_id = 'profile-images'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'profile_images_delete_own'
  ) THEN
    CREATE POLICY profile_images_delete_own
      ON storage.objects
      FOR DELETE
      TO authenticated
      USING (
        bucket_id = 'profile-images'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;
END
$$;
