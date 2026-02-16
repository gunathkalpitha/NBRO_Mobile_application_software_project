-- ============================================================================
-- SEED DATA AND ADMIN SETUP
-- ============================================================================
-- This file contains admin profile setup, seed data, and storage configuration.

-- Set admin role if admin@gmail.com exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM auth.users WHERE email = 'admin@gmail.com') THEN
        UPDATE auth.users 
        SET raw_user_meta_data = raw_user_meta_data || '{"role": "admin", "full_name": "Administrator"}'::jsonb
        WHERE email = 'admin@gmail.com';
        RAISE NOTICE 'Updated admin@gmail.com with admin role metadata';
    END IF;
END $$;

-- Ensure admin@gmail.com has a profile with admin role
INSERT INTO public.profiles (id, email, full_name, role, is_active)
SELECT 
    id,
    email,
    COALESCE(raw_user_meta_data->>'full_name', 'Administrator'),
    'admin',
    true
FROM auth.users
WHERE email = 'admin@gmail.com'
ON CONFLICT (id) DO UPDATE
SET 
    role = 'admin',
    is_active = true,
    full_name = COALESCE(EXCLUDED.full_name, profiles.full_name);

-- Create profiles for any auth users that don't have one yet
INSERT INTO public.profiles (id, email, full_name, role, is_active)
SELECT 
    u.id,
    u.email,
    COALESCE(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'name', 'Officer'),
    COALESCE(u.raw_user_meta_data->>'role', 'officer'),
    true
FROM auth.users u
WHERE NOT EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = u.id
)
AND u.email != 'admin@gmail.com';

-- STORAGE CONFIGURATION
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'inspection-photos', 
    'inspection-photos', 
    true,
    10485760,
    NULL
)
ON CONFLICT (id) DO UPDATE 
SET 
    public = true,
    file_size_limit = 10485760,
    allowed_mime_types = NULL;

DROP POLICY IF EXISTS "Allow public uploads to inspection-photos" ON storage.objects;
DROP POLICY IF EXISTS "Allow public access to inspection-photos" ON storage.objects;
DROP POLICY IF EXISTS "Allow public deletes to inspection-photos" ON storage.objects;
DROP POLICY IF EXISTS "Allow public updates to inspection-photos" ON storage.objects;

CREATE POLICY "Allow public uploads to inspection-photos"
ON storage.objects FOR INSERT TO public
WITH CHECK (bucket_id = 'inspection-photos');

CREATE POLICY "Allow public access to inspection-photos"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'inspection-photos');

CREATE POLICY "Allow public updates to inspection-photos"
ON storage.objects FOR UPDATE TO public
USING (bucket_id = 'inspection-photos')
WITH CHECK (bucket_id = 'inspection-photos');

CREATE POLICY "Allow public deletes to inspection-photos"
ON storage.objects FOR DELETE TO public
USING (bucket_id = 'inspection-photos');

-- VERIFY AND CREATE ADMIN PROFILE
DO $$
DECLARE
    admin_user_id UUID;
BEGIN
    SELECT id INTO admin_user_id FROM auth.users WHERE email = 'admin@gmail.com';
    IF admin_user_id IS NOT NULL THEN
        INSERT INTO profiles (id, email, full_name, role, is_active)
        VALUES (admin_user_id, 'admin@gmail.com', 'Administrator', 'admin', true)
        ON CONFLICT (id) DO UPDATE SET role = 'admin', full_name = 'Administrator', is_active = true;
        RAISE NOTICE '✓ Admin profile created for admin@gmail.com (ID: %)', admin_user_id;
    ELSE
        RAISE NOTICE '⚠ admin@gmail.com not found - create user first in Supabase Auth';
    END IF;
END $$;

-- SYNC EXISTING SITES TO INSPECTIONS (if any exist)
INSERT INTO inspections (
    site_id,
    user_id,
    building_reference_no,
    site_name,
    site_location,
    inspection_date,
    total_defects,
    defects_with_photos,
    sync_status
)
SELECT 
    s.id,
    s.created_by,
    s.building_reference_no,
    s.owner_name,
    s.site_address,
    CURRENT_DATE,
    COALESCE(COUNT(DISTINCT d.defect_id), 0),
    COALESCE(COUNT(DISTINCT CASE WHEN d.photo_path IS NOT NULL THEN d.defect_id END), 0),
    s.sync_status
FROM sites s
LEFT JOIN defects d ON d.building_reference_no = s.building_reference_no
WHERE NOT EXISTS (
    SELECT 1 FROM inspections i 
    WHERE i.building_reference_no = s.building_reference_no
)
GROUP BY s.id, s.created_by, s.building_reference_no, s.owner_name, s.site_address, s.sync_status;

-- COMPLETION
DO $$ 
BEGIN 
    RAISE NOTICE '========================================';
    RAISE NOTICE '✓✓✓ SCHEMA COMPLETE! ✓✓✓';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Tables: profiles, sites, defects, defect_media, inspections';
    RAISE NOTICE 'RLS: STRICT user isolation + admin bypass';
    RAISE NOTICE 'Storage: inspection-photos bucket ready';
    RAISE NOTICE '';
    RAISE NOTICE 'Next: Login with admin@gmail.com in Flutter app!';
    RAISE NOTICE '========================================';
END $$;
