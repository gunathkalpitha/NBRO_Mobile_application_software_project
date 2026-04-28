DO $$
DECLARE
    admin_user_id UUID;
BEGIN
    UPDATE public.profile
    SET is_active = true
    WHERE is_active IS NULL;

    UPDATE public.profile
    SET role = 'officer'
    WHERE role IS NULL OR role = '';

    UPDATE public.profile
    SET full_name = COALESCE(NULLIF(full_name, ''), 'Officer')
    WHERE full_name IS NULL OR full_name = '';

    UPDATE public.site
    SET sync_status = 'pending'
    WHERE sync_status IS NULL;

    SELECT id INTO admin_user_id FROM auth.users WHERE email = 'admin@gmail.com';
    IF admin_user_id IS NOT NULL THEN
        INSERT INTO public.profile (id, full_name, role, email, is_active)
        VALUES (admin_user_id, 'Administrator', 'admin', 'admin@gmail.com', true)
        ON CONFLICT (id) DO UPDATE 
        SET role = 'admin', 
            full_name = 'Administrator', 
            email = 'admin@gmail.com',
            is_active = true;
        RAISE NOTICE '✓ Admin profile created for admin@gmail.com (ID: %)', admin_user_id;
    ELSE
        RAISE NOTICE '⚠ admin@gmail.com not found - create user first in Supabase Auth';
    END IF;
END $$;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'defect-images',
    'defect-images',
    true,
    10485760,  -- 10MB limit
    ARRAY['image/jpeg', 'image/png', 'image/jpg']
)
ON CONFLICT (id) DO UPDATE
SET
    public = true,
    file_size_limit = 10485760,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/jpg'];


DROP POLICY IF EXISTS "authenticated users can upload defect images" ON storage.objects;
DROP POLICY IF EXISTS "authenticated users can view defect images" ON storage.objects;
DROP POLICY IF EXISTS "authenticated users can update defect images" ON storage.objects;
DROP POLICY IF EXISTS "authenticated users can delete defect images" ON storage.objects;


-- Only authenticated users can upload
CREATE POLICY "authenticated users can upload defect images"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'defect-images');

-- Only authenticated users can view
CREATE POLICY "authenticated users can view defect images"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'defect-images');

-- Only authenticated users can update
CREATE POLICY "authenticated users can update defect images"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'defect-images')
WITH CHECK (bucket_id = 'defect-images');

-- Only authenticated users can delete
CREATE POLICY "authenticated users can delete defect images"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'defect-images');

-- =====================================================================
-- Site Images bucket (building front-view photos)
-- =====================================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'site-images',
    'site-images',
    true,
    10485760,
    ARRAY['image/jpeg', 'image/png', 'image/jpg', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET
    public = true,
    file_size_limit = 10485760,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/jpg', 'image/webp'];

DROP POLICY IF EXISTS "authenticated users can upload site images" ON storage.objects;
DROP POLICY IF EXISTS "authenticated users can view site images" ON storage.objects;
DROP POLICY IF EXISTS "authenticated users can update site images" ON storage.objects;
DROP POLICY IF EXISTS "authenticated users can delete site images" ON storage.objects;

CREATE POLICY "authenticated users can upload site images"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'site-images');

CREATE POLICY "authenticated users can view site images"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'site-images');

CREATE POLICY "authenticated users can update site images"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'site-images')
WITH CHECK (bucket_id = 'site-images');

CREATE POLICY "authenticated users can delete site images"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'site-images');

NOTIFY pgrst, 'reload schema';