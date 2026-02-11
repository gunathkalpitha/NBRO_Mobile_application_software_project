-- ============================================================================
-- NBRO Site Inspection Database Schema for Supabase (PostgreSQL)
-- ============================================================================
-- COMPLETE SCHEMA: Base tables + Admin features + RLS policies
-- 
-- USAGE:
-- 1. Open Supabase Dashboard → SQL Editor
-- 2. Copy and paste this ENTIRE file
-- 3. Click "Run" to execute
-- 4. Wait for success message
-- 5. Create admin user in Supabase Auth (email: admin@gmail.com)
-- 6. Login to mobile app as admin@gmail.com
--
-- NOTE: This is a CLEAN INSTALL - drops existing tables and recreates everything
-- ============================================================================

-- Drop existing tables if they exist (clean installation)
DROP TABLE IF EXISTS defect_media CASCADE;
DROP TABLE IF EXISTS defects CASCADE;
DROP TABLE IF EXISTS inspections CASCADE;
DROP TABLE IF EXISTS sites CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;

-- Drop existing views
DROP VIEW IF EXISTS admin_officer_stats CASCADE;
DROP VIEW IF EXISTS inspection_details CASCADE;
DROP VIEW IF EXISTS defects_with_media CASCADE;
DROP VIEW IF EXISTS sites_with_defect_count CASCADE;

-- Drop existing functions
DROP FUNCTION IF EXISTS update_inspection_defect_counts() CASCADE;
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS update_site_location() CASCADE;
DROP FUNCTION IF EXISTS is_admin() CASCADE;
DROP FUNCTION IF EXISTS get_user_role(UUID) CASCADE;

-- Drop existing triggers
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================================================
-- UTILITY FUNCTIONS (Create these first)
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE OR REPLACE FUNCTION update_site_location()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        NEW.location = ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SET ADMIN ROLE (if admin@gmail.com exists)
-- ============================================================================

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM auth.users WHERE email = 'admin@gmail.com') THEN
        UPDATE auth.users 
        SET raw_user_meta_data = raw_user_meta_data || '{"role": "admin", "full_name": "Administrator"}'::jsonb
        WHERE email = 'admin@gmail.com';
        RAISE NOTICE 'Updated admin@gmail.com with admin role metadata';
    END IF;
END $$;

-- ============================================================================
-- TABLE 1: profiles (User Profiles - NEW FOR ADMIN)
-- ============================================================================

CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    role TEXT NOT NULL DEFAULT 'officer' CHECK (role IN ('admin', 'officer')),
    phone TEXT,
    department TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_profiles_email ON profiles(email);
CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_profiles_is_active ON profiles(is_active);
CREATE INDEX idx_profiles_created_at ON profiles(created_at DESC);

CREATE TRIGGER update_profiles_updated_at 
    BEFORE UPDATE ON profiles
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- TABLE 2: sites
-- ============================================================================

CREATE TABLE sites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    building_reference_no TEXT UNIQUE NOT NULL,
    
    owner_name TEXT NOT NULL,
    owner_contact TEXT,
    site_address TEXT NOT NULL,
    
    location GEOGRAPHY(POINT, 4326),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    distance_from_row DOUBLE PRECISION,
    
    age_of_structure INTEGER,
    type_of_structure TEXT,
    present_condition TEXT,
    
    has_pipe_borne_water BOOLEAN DEFAULT FALSE,
    water_source TEXT,
    has_electricity BOOLEAN DEFAULT FALSE,
    electricity_source TEXT,
    has_sewage_waste BOOLEAN DEFAULT FALSE,
    sewage_type TEXT,
    
    number_of_floors TEXT,
    
    wall_materials JSONB,
    door_materials JSONB,
    floor_materials JSONB,
    roof_materials JSONB,
    finishes JSONB,
    roof_covering TEXT,
    
    ancillary_structures JSONB,
    building_photo_url TEXT,
    
    sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'syncing', 'synced', 'error')),
    remarks TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID NOT NULL DEFAULT auth.uid()
);

CREATE INDEX idx_sites_building_ref ON sites(building_reference_no);
CREATE INDEX idx_sites_sync_status ON sites(sync_status);
CREATE INDEX idx_sites_created_at ON sites(created_at DESC);
CREATE INDEX idx_sites_location ON sites USING GIST(location);
CREATE INDEX idx_sites_created_by ON sites(created_by);

CREATE TRIGGER update_sites_updated_at 
    BEFORE UPDATE ON sites
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_site_location_trigger
    BEFORE INSERT OR UPDATE OF latitude, longitude ON sites
    FOR EACH ROW
    EXECUTE FUNCTION update_site_location();

-- ============================================================================
-- TABLE 3: defects
-- ============================================================================

CREATE TABLE defects (
    defect_id TEXT PRIMARY KEY DEFAULT ('D-' || EXTRACT(EPOCH FROM NOW())::TEXT),
    building_reference_no TEXT NOT NULL,
    
    notation TEXT NOT NULL CHECK (
        notation IN (
            'C', 'BC', 'CC', 'FC', 'SC', 'TC', 'SP', 
            'D', 'WD', 'BD', 'CD', 'FD', 'DD', 'TD', 'GD', 'PD', 'RD', 'DP',
            'BWC', 'BWS', 'BWD', 'BWDP'
        )
    ),
    defect_category TEXT NOT NULL CHECK (
        defect_category IN ('buildingFloor', 'boundaryWall')
    ),
    
    floor_level TEXT,
    location_description TEXT,
    
    length_mm DOUBLE PRECISION NOT NULL CHECK (length_mm > 0),
    width_mm DOUBLE PRECISION CHECK (width_mm IS NULL OR width_mm > 0),
    
    photo_path TEXT,
    photo_url TEXT,
    remarks TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT fk_defects_site 
        FOREIGN KEY (building_reference_no) 
        REFERENCES sites(building_reference_no) 
        ON DELETE CASCADE
);

CREATE INDEX idx_defects_building_ref ON defects(building_reference_no);
CREATE INDEX idx_defects_notation ON defects(notation);
CREATE INDEX idx_defects_category ON defects(defect_category);
CREATE INDEX idx_defects_floor_level ON defects(floor_level);
CREATE INDEX idx_defects_created_at ON defects(created_at DESC);

CREATE TRIGGER update_defects_updated_at 
    BEFORE UPDATE ON defects
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- TABLE 4: defect_media
-- ============================================================================

CREATE TABLE defect_media (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    defect_id TEXT NOT NULL,
    building_reference_no TEXT NOT NULL,
    
    storage_path TEXT NOT NULL,
    storage_url TEXT,
    file_name TEXT NOT NULL,
    file_size INTEGER CHECK (file_size IS NULL OR file_size > 0),
    mime_type TEXT DEFAULT 'image/jpeg',
    
    width_px INTEGER,
    height_px INTEGER,
    
    has_annotations BOOLEAN DEFAULT FALSE,
    annotation_data JSONB,
    
    uploaded_at TIMESTAMPTZ DEFAULT NOW(),
    uploaded_by UUID,
    
    CONSTRAINT chk_image_dimensions CHECK (
        (width_px IS NULL AND height_px IS NULL) OR 
        (width_px > 0 AND height_px > 0)
    ),
    CONSTRAINT fk_media_defect 
        FOREIGN KEY (defect_id) 
        REFERENCES defects(defect_id) 
        ON DELETE CASCADE,
    CONSTRAINT fk_media_site 
        FOREIGN KEY (building_reference_no) 
        REFERENCES sites(building_reference_no) 
        ON DELETE CASCADE
);

CREATE INDEX idx_defect_media_defect_id ON defect_media(defect_id);
CREATE INDEX idx_defect_media_building_ref ON defect_media(building_reference_no);
CREATE INDEX idx_defect_media_uploaded_at ON defect_media(uploaded_at DESC);
CREATE INDEX idx_defect_media_uploaded_by ON defect_media(uploaded_by);

-- ============================================================================
-- TABLE 5: inspections (NEW FOR ADMIN)
-- ============================================================================

CREATE TABLE inspections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    site_id UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    building_reference_no TEXT NOT NULL,
    
    site_name TEXT,
    site_location TEXT,
    inspection_date DATE DEFAULT CURRENT_DATE,
    
    total_defects INTEGER DEFAULT 0,
    defects_with_photos INTEGER DEFAULT 0,
    
    sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'syncing', 'synced', 'error')),
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT fk_inspections_building_ref 
        FOREIGN KEY (building_reference_no) 
        REFERENCES sites(building_reference_no) 
        ON DELETE CASCADE
);

CREATE INDEX idx_inspections_user_id ON inspections(user_id);
CREATE INDEX idx_inspections_site_id ON inspections(site_id);
CREATE INDEX idx_inspections_building_ref ON inspections(building_reference_no);
CREATE INDEX idx_inspections_sync_status ON inspections(sync_status);
CREATE INDEX idx_inspections_date ON inspections(inspection_date DESC);
CREATE INDEX idx_inspections_created_at ON inspections(created_at DESC);

CREATE TRIGGER update_inspections_updated_at 
    BEFORE UPDATE ON inspections
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- ADMIN FUNCTIONS
-- ============================================================================

-- Helper function to get user role (bypasses RLS to prevent infinite recursion)
CREATE OR REPLACE FUNCTION public.get_user_role(user_id UUID)
RETURNS TEXT AS $$
DECLARE
    user_role TEXT;
BEGIN
    SELECT role INTO user_role FROM public.profiles WHERE id = user_id;
    RETURN user_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to check if current user is admin (with better error handling)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
DECLARE
    user_role TEXT;
    user_active BOOLEAN;
BEGIN
    -- Get role and active status
    SELECT role, is_active INTO user_role, user_active
    FROM public.profiles
    WHERE id = auth.uid();
    
    -- Return true only if admin and active
    RETURN (user_role = 'admin' AND user_active = true);
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Auto-create profile when new user is created
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, role)
    VALUES (
        NEW.id, 
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', ''),
        COALESCE(NEW.raw_user_meta_data->>'role', 'officer')
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Update inspection defect counts when defects change
CREATE OR REPLACE FUNCTION public.update_inspection_defect_counts()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE inspections i
    SET 
        total_defects = (
            SELECT COUNT(*) 
            FROM defects d 
            WHERE d.building_reference_no = i.building_reference_no
        ),
        defects_with_photos = (
            SELECT COUNT(*) 
            FROM defects d 
            WHERE d.building_reference_no = i.building_reference_no 
            AND d.photo_path IS NOT NULL
        ),
        updated_at = NOW()
    WHERE i.building_reference_no = COALESCE(NEW.building_reference_no, OLD.building_reference_no);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER update_inspection_counts_on_defect_change
    AFTER INSERT OR UPDATE OR DELETE ON defects
    FOR EACH ROW 
    EXECUTE FUNCTION public.update_inspection_defect_counts();

-- ============================================================================
-- FIX ADMIN PROFILE AND MISSING USER PROFILES
-- ============================================================================

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

-- ============================================================================
-- VIEWS
-- ============================================================================

CREATE VIEW sites_with_defect_count AS
SELECT 
    s.*,
    COUNT(d.defect_id) as total_defects,
    COUNT(CASE WHEN d.photo_path IS NOT NULL THEN 1 END) as defects_with_photos
FROM sites s
LEFT JOIN defects d ON s.building_reference_no = d.building_reference_no
GROUP BY s.id;

CREATE VIEW defects_with_media AS
SELECT 
    d.*,
    s.site_address,
    COUNT(dm.id) as media_count,
    ARRAY_AGG(dm.storage_url) FILTER (WHERE dm.storage_url IS NOT NULL) as photo_urls
FROM defects d
JOIN sites s ON d.building_reference_no = s.building_reference_no
LEFT JOIN defect_media dm ON d.defect_id = dm.defect_id
GROUP BY d.defect_id, d.building_reference_no, s.site_address;

CREATE VIEW inspection_details AS
SELECT 
    s.id as site_uuid,
    s.building_reference_no,
    s.owner_name,
    s.site_address,
    s.latitude,
    s.longitude,
    s.sync_status,
    s.created_at as site_created_at,
    d.defect_id,
    d.notation,
    d.defect_category,
    d.floor_level,
    d.length_mm,
    d.width_mm,
    d.remarks as defect_remarks,
    COUNT(dm.id) as photo_count
FROM sites s
LEFT JOIN defects d ON s.building_reference_no = d.building_reference_no
LEFT JOIN defect_media dm ON d.defect_id = dm.defect_id
GROUP BY s.id, d.defect_id;

CREATE VIEW admin_officer_stats AS
SELECT 
    p.id,
    p.email,
    p.full_name,
    p.phone,
    p.department,
    p.is_active,
    p.created_at,
    COUNT(DISTINCT i.id) as total_inspections,
    COUNT(DISTINCT s.id) as total_sites,
    COUNT(DISTINCT d.defect_id) as total_defects,
    MAX(i.created_at) as last_inspection_date
FROM profiles p
LEFT JOIN inspections i ON i.user_id = p.id
LEFT JOIN sites s ON s.created_by = p.id
LEFT JOIN defects d ON d.building_reference_no = s.building_reference_no
WHERE p.role = 'officer'
GROUP BY p.id
ORDER BY p.created_at DESC;

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE defects ENABLE ROW LEVEL SECURITY;
ALTER TABLE defect_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspections ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "profiles_select_all" ON profiles FOR SELECT USING (true);
CREATE POLICY "profiles_update_own" ON profiles FOR UPDATE USING (id = auth.uid());
CREATE POLICY "profiles_insert_own" ON profiles FOR INSERT WITH CHECK (id = auth.uid());
CREATE POLICY "profiles_admin_all" ON profiles FOR ALL USING (public.is_admin());

-- Sites policies - officers
CREATE POLICY "sites_select_policy" ON sites FOR SELECT USING (created_by = auth.uid());
CREATE POLICY "sites_insert_policy" ON sites FOR INSERT WITH CHECK (created_by = auth.uid());
CREATE POLICY "sites_update_policy" ON sites FOR UPDATE USING (created_by = auth.uid());
CREATE POLICY "sites_delete_policy" ON sites FOR DELETE USING (created_by = auth.uid());

-- Sites policy - admins
CREATE POLICY "sites_admin_all" ON sites FOR ALL USING (public.is_admin());

-- Defects policies - officers
CREATE POLICY "defects_select_policy" ON defects FOR SELECT USING (
    EXISTS (SELECT 1 FROM sites WHERE sites.building_reference_no = defects.building_reference_no AND sites.created_by = auth.uid())
);
CREATE POLICY "defects_insert_policy" ON defects FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM sites WHERE sites.building_reference_no = defects.building_reference_no AND sites.created_by = auth.uid())
);
CREATE POLICY "defects_update_policy" ON defects FOR UPDATE USING (
    EXISTS (SELECT 1 FROM sites WHERE sites.building_reference_no = defects.building_reference_no AND sites.created_by = auth.uid())
);
CREATE POLICY "defects_delete_policy" ON defects FOR DELETE USING (
    EXISTS (SELECT 1 FROM sites WHERE sites.building_reference_no = defects.building_reference_no AND sites.created_by = auth.uid())
);

-- Defects policy - admins
CREATE POLICY "defects_admin_all" ON defects FOR ALL USING (public.is_admin());

-- Media policies - officers
CREATE POLICY "media_select_policy" ON defect_media FOR SELECT USING (
    EXISTS (SELECT 1 FROM sites WHERE sites.building_reference_no = defect_media.building_reference_no AND sites.created_by = auth.uid())
);
CREATE POLICY "media_insert_policy" ON defect_media FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM sites WHERE sites.building_reference_no = defect_media.building_reference_no AND sites.created_by = auth.uid())
);
CREATE POLICY "media_update_policy" ON defect_media FOR UPDATE USING (
    EXISTS (SELECT 1 FROM sites WHERE sites.building_reference_no = defect_media.building_reference_no AND sites.created_by = auth.uid())
);
CREATE POLICY "media_delete_policy" ON defect_media FOR DELETE USING (
    EXISTS (SELECT 1 FROM sites WHERE sites.building_reference_no = defect_media.building_reference_no AND sites.created_by = auth.uid())
);

-- Media policy - admins
CREATE POLICY "media_admin_all" ON defect_media FOR ALL USING (public.is_admin());

-- Inspections policies - officers (own data only)
CREATE POLICY "inspections_select_own" ON inspections FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "inspections_insert_own" ON inspections FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "inspections_update_own" ON inspections FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "inspections_delete_own" ON inspections FOR DELETE USING (user_id = auth.uid());

-- Inspections policies - admins (all data)
CREATE POLICY "inspections_admin_select" ON inspections FOR SELECT USING (public.is_admin());
CREATE POLICY "inspections_admin_insert" ON inspections FOR INSERT WITH CHECK (public.is_admin());
CREATE POLICY "inspections_admin_update" ON inspections FOR UPDATE USING (public.is_admin());
CREATE POLICY "inspections_admin_delete" ON inspections FOR DELETE USING (public.is_admin());

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT ON profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;

-- ============================================================================
-- STORAGE CONFIGURATION
-- ============================================================================

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

-- ============================================================================
-- AUTO-CREATE INSPECTIONS FROM SITES
-- ============================================================================
-- When officers upload sites, automatically create inspection records
-- This keeps the inspections table synced with sites

CREATE OR REPLACE FUNCTION public.auto_create_inspection()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert inspection record when a new site is created
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
    ) VALUES (
        NEW.id,
        NEW.created_by,
        NEW.building_reference_no,
        NEW.owner_name,
        NEW.site_address,
        CURRENT_DATE,
        0,
        0,
        NEW.sync_status
    )
    ON CONFLICT (building_reference_no) DO NOTHING;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add unique constraint to prevent duplicates
ALTER TABLE inspections DROP CONSTRAINT IF EXISTS uk_inspections_building_ref;
ALTER TABLE inspections ADD CONSTRAINT uk_inspections_building_ref 
    UNIQUE (building_reference_no);

-- Create trigger to auto-create inspections
DROP TRIGGER IF EXISTS auto_create_inspection_trigger ON sites;
CREATE TRIGGER auto_create_inspection_trigger
    AFTER INSERT ON sites
    FOR EACH ROW 
    EXECUTE FUNCTION public.auto_create_inspection();

-- ============================================================================
-- VERIFY AND CREATE ADMIN PROFILE
-- ============================================================================

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

-- ============================================================================
-- SYNC EXISTING SITES TO INSPECTIONS (if any exist)
-- ============================================================================

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

-- ============================================================================
-- COMPLETION
-- ============================================================================

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
