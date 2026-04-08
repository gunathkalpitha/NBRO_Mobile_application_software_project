DO $$
DECLARE
    admin_user_id UUID;
BEGIN
    SELECT id INTO admin_user_id FROM auth.users WHERE email = 'admin@gmail.com';
    IF admin_user_id IS NOT NULL THEN
        INSERT INTO public.profile (id, full_name, role, is_active)
        VALUES (admin_user_id, 'Administrator', 'admin', true)
        ON CONFLICT (id) DO UPDATE 
        SET role = 'admin', 
            full_name = 'Administrator', 
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
