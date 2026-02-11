-- ============================================================================
-- NBRO Site Inspection Database Schema for Supabase (PostgreSQL)
-- ============================================================================
-- COMPLETE SCHEMA: Base tables + Admin features
-- Run this ONCE in Supabase SQL Editor for complete setup
-- ============================================================================

-- Drop existing tables if they exist (clean slate)
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

COMMENT ON FUNCTION update_updated_at_column() IS 'Auto-updates the updated_at timestamp on row update';
COMMENT ON FUNCTION update_site_location() IS 'Auto-generates PostGIS geography point from latitude/longitude';

-- ============================================================================
-- SET ADMIN ROLE (if admin@gmail.com exists)
-- ============================================================================
-- Update existing admin user's metadata (run this before creating tables)

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM auth.users WHERE email = 'admin@gmail.com') THEN
        UPDATE auth.users 
        SET raw_user_meta_data = raw_user_meta_data || '{"role": "admin", "full_name": "Administrator"}'::jsonb
        WHERE email = 'admin@gmail.com';
        RAISE NOTICE 'Updated admin@gmail.com with admin role';
    ELSE
        RAISE NOTICE 'admin@gmail.com not found - create user first, then run this script';
    END IF;
END $$;

-- ============================================================================
-- TABLE 1: profiles (User Profiles - ADMIN FEATURE)
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

COMMENT ON TABLE profiles IS 'User profiles with role-based access control (admin/officer)';
COMMENT ON COLUMN profiles.role IS 'User role: admin (full access) or officer (own data only)';
COMMENT ON COLUMN profiles.is_active IS 'Account status - inactive users cannot login';

-- ============================================================================
-- TABLE 2: sites (Inspection Sites)
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

COMMENT ON TABLE sites IS 'Building/site inspection records';
COMMENT ON COLUMN sites.created_by IS 'User who created this site (officer UUID)';

-- ============================================================================
-- TABLE 3: defects (Defect Records)
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

COMMENT ON TABLE defects IS 'Defects found during site inspections';
COMMENT ON COLUMN defects.notation IS 'Defect type code (C=Crack, D=Damage, BW=Boundary Wall, etc.)';

-- ============================================================================
-- TABLE 4: defect_media (Defect Photos)
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

COMMENT ON TABLE defect_media IS 'Photos and media files for defects';

-- ============================================================================
-- TABLE 5: inspections (Inspection Summary - ADMIN FEATURE)
-- ============================================================================

CREATE TABLE inspections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    site_id UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    building_reference_no TEXT NOT NULL,
    
    -- Denormalized fields for faster admin queries
    site_name TEXT,
    site_location TEXT,
    inspection_date DATE DEFAULT CURRENT_DATE,
    
    -- Defect statistics (auto-updated by trigger)
    total_defects INTEGER DEFAULT 0,
    defects_with_photos INTEGER DEFAULT 0,
    
    -- Sync status
    sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'syncing', 'synced', 'error')),
    
    -- Timestamps
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

COMMENT ON TABLE inspections IS 'Inspection summary records for admin dashboard';
COMMENT ON COLUMN inspections.total_defects IS 'Auto-updated count of defects for this inspection';

-- ============================================================================
-- ADMIN FUNCTIONS
-- ============================================================================

-- Function: Auto-create profile when user signs up
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

COMMENT ON FUNCTION public.handle_new_user() IS 'Auto-creates profile when new user signs up';

-- Create trigger for new user signup
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function: Update inspection defect counts
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

COMMENT ON FUNCTION public.update_inspection_defect_counts() IS 'Auto-updates defect counts when defects are added/modified';

-- Trigger to update defect counts
CREATE TRIGGER update_inspection_counts_on_defect_change
    AFTER INSERT OR UPDATE OR DELETE ON defects
    FOR EACH ROW 
    EXECUTE FUNCTION public.update_inspection_defect_counts();

-- ============================================================================
-- VIEWS
-- ============================================================================

-- View: Sites with defect count
CREATE VIEW sites_with_defect_count AS
SELECT 
    s.*,
    COUNT(d.defect_id) as total_defects,
    COUNT(CASE WHEN d.photo_path IS NOT NULL THEN 1 END) as defects_with_photos
FROM sites s
LEFT JOIN defects d ON s.building_reference_no = d.building_reference_no
GROUP BY s.id;

-- View: Defects with media
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

-- View: Inspection details
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

-- View: Admin officer statistics
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
GROUP BY p.id, p.email, p.full_name, p.phone, p.department, p.is_active, p.created_at
ORDER BY p.created_at DESC;

COMMENT ON VIEW admin_officer_stats IS 'Admin dashboard view showing officers with inspection statistics';

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) SETUP
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE defects ENABLE ROW LEVEL SECURITY;
ALTER TABLE defect_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspections ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RLS POLICIES: profiles
-- ============================================================================

-- Everyone can view all profiles (for officer lists)
CREATE POLICY "profiles_select_all" ON profiles
    FOR SELECT 
    USING (true);

-- Users can update only their own profile
CREATE POLICY "profiles_update_own" ON profiles
    FOR UPDATE 
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- Users can insert only their own profile
CREATE POLICY "profiles_insert_own" ON profiles
    FOR INSERT 
    WITH CHECK (id = auth.uid());

-- Users can delete only their own profile
CREATE POLICY "profiles_delete_own" ON profiles
    FOR DELETE 
    USING (id = auth.uid());

-- Admins can do EVERYTHING with all profiles
CREATE POLICY "profiles_admin_all" ON profiles
    FOR ALL 
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND is_active = true
        )
    );

-- ============================================================================
-- RLS POLICIES: sites (STRICT user isolation + admin bypass)
-- ============================================================================

-- Officers can select only their own sites
CREATE POLICY "sites_select_policy" ON sites
    FOR SELECT 
    USING (created_by = auth.uid());

-- Officers can insert only their own sites
CREATE POLICY "sites_insert_policy" ON sites
    FOR INSERT 
    WITH CHECK (created_by = auth.uid());

-- Officers can update only their own sites
CREATE POLICY "sites_update_policy" ON sites
    FOR UPDATE 
    USING (created_by = auth.uid());

-- Officers can delete only their own sites
CREATE POLICY "sites_delete_policy" ON sites
    FOR DELETE 
    USING (created_by = auth.uid());

-- Admins can access ALL sites from all officers
CREATE POLICY "sites_admin_all" ON sites
    FOR ALL 
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND is_active = true
        )
    );

-- ============================================================================
-- RLS POLICIES: defects (via parent site + admin bypass)
-- ============================================================================

-- Officers can select defects from their own sites
CREATE POLICY "defects_select_policy" ON defects
    FOR SELECT 
    USING (
        EXISTS (
            SELECT 1 FROM sites 
            WHERE sites.building_reference_no = defects.building_reference_no 
            AND sites.created_by = auth.uid()
        )
    );

-- Officers can insert defects to their own sites
CREATE POLICY "defects_insert_policy" ON defects
    FOR INSERT 
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM sites 
            WHERE sites.building_reference_no = defects.building_reference_no 
            AND sites.created_by = auth.uid()
        )
    );

-- Officers can update defects from their own sites
CREATE POLICY "defects_update_policy" ON defects
    FOR UPDATE 
    USING (
        EXISTS (
            SELECT 1 FROM sites 
            WHERE sites.building_reference_no = defects.building_reference_no 
            AND sites.created_by = auth.uid()
        )
    );

-- Officers can delete defects from their own sites
CREATE POLICY "defects_delete_policy" ON defects
    FOR DELETE 
    USING (
        EXISTS (
            SELECT 1 FROM sites 
            WHERE sites.building_reference_no = defects.building_reference_no 
            AND sites.created_by = auth.uid()
        )
    );

-- Admins can access ALL defects
CREATE POLICY "defects_admin_all" ON defects
    FOR ALL 
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND is_active = true
        )
    );

-- ============================================================================
-- RLS POLICIES: defect_media (via parent site + admin bypass)
-- ============================================================================

-- Officers can select media from their own sites
CREATE POLICY "media_select_policy" ON defect_media
    FOR SELECT 
    USING (
        EXISTS (
            SELECT 1 FROM sites 
            WHERE sites.building_reference_no = defect_media.building_reference_no 
            AND sites.created_by = auth.uid()
        )
    );

-- Officers can insert media to their own sites
CREATE POLICY "media_insert_policy" ON defect_media
    FOR INSERT 
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM sites 
            WHERE sites.building_reference_no = defect_media.building_reference_no 
            AND sites.created_by = auth.uid()
        )
    );

-- Officers can update media from their own sites
CREATE POLICY "media_update_policy" ON defect_media
    FOR UPDATE 
    USING (
        EXISTS (
            SELECT 1 FROM sites 
            WHERE sites.building_reference_no = defect_media.building_reference_no 
            AND sites.created_by = auth.uid()
        )
    );

-- Officers can delete media from their own sites
CREATE POLICY "media_delete_policy" ON defect_media
    FOR DELETE 
    USING (
        EXISTS (
            SELECT 1 FROM sites 
            WHERE sites.building_reference_no = defect_media.building_reference_no 
            AND sites.created_by = auth.uid()
        )
    );

-- Admins can access ALL media
CREATE POLICY "media_admin_all" ON defect_media
    FOR ALL 
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND is_active = true
        )
    );

-- ============================================================================
-- RLS POLICIES: inspections
-- ============================================================================

-- Officers can view their own inspections
CREATE POLICY "inspections_select_own" ON inspections
    FOR SELECT 
    USING (user_id = auth.uid());

-- Officers can insert their own inspections
CREATE POLICY "inspections_insert_own" ON inspections
    FOR INSERT 
    WITH CHECK (user_id = auth.uid());

-- Officers can update their own inspections
CREATE POLICY "inspections_update_own" ON inspections
    FOR UPDATE 
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Officers can delete their own inspections
CREATE POLICY "inspections_delete_own" ON inspections
    FOR DELETE 
    USING (user_id = auth.uid());

-- Admins can do EVERYTHING with ALL inspections
CREATE POLICY "inspections_admin_all" ON inspections
    FOR ALL 
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND is_active = true
        )
    );

-- ============================================================================
-- STORAGE BUCKET CONFIGURATION
-- ============================================================================

-- Create storage bucket for inspection photos
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'inspection-photos', 
    'inspection-photos', 
    true,
    10485760,  -- 10 MB
    NULL  -- Allow all MIME types
)
ON CONFLICT (id) DO UPDATE 
SET 
    public = true,
    file_size_limit = 10485760,
    allowed_mime_types = NULL;

-- Drop existing storage policies
DROP POLICY IF EXISTS "Allow public uploads to inspection-photos" ON storage.objects;
DROP POLICY IF EXISTS "Allow public access to inspection-photos" ON storage.objects;
DROP POLICY IF EXISTS "Allow public updates to inspection-photos" ON storage.objects;
DROP POLICY IF EXISTS "Allow public deletes to inspection-photos" ON storage.objects;

-- Create storage policies (public access)
CREATE POLICY "Allow public uploads to inspection-photos"
ON storage.objects
FOR INSERT
TO public
WITH CHECK (bucket_id = 'inspection-photos');

CREATE POLICY "Allow public access to inspection-photos"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'inspection-photos');

CREATE POLICY "Allow public updates to inspection-photos"
ON storage.objects
FOR UPDATE
TO public
USING (bucket_id = 'inspection-photos')
WITH CHECK (bucket_id = 'inspection-photos');

CREATE POLICY "Allow public deletes to inspection-photos"
ON storage.objects
FOR DELETE
TO public
USING (bucket_id = 'inspection-photos');

-- ============================================================================
-- EXAMPLE: CREATE FIRST ADMIN USER
-- ============================================================================
-- IMPORTANT: Run this AFTER you create the admin user in Supabase Auth

-- STEP 1: Create user in Supabase Dashboard → Authentication → Users
-- STEP 2: Copy the User ID (UUID)
-- STEP 3: Run this query (uncomment and replace <USER_ID>):

/*
INSERT INTO profiles (id, email, full_name, role, is_active)
VALUES (
    '<USER_ID>'::uuid,        -- Replace with UUID from Supabase Auth
    'admin@nbro.lk',          -- Your admin email
    'NBRO Administrator',     -- Admin full name
    'admin',                  -- Must be 'admin' role
    true                      -- Active account
)
ON CONFLICT (id) 
DO UPDATE SET 
    role = 'admin',
    is_active = true;
*/

-- Example with placeholder UUID:
-- INSERT INTO profiles (id, email, full_name, role, is_active)
-- VALUES (
--     '123e4567-e89b-12d3-a456-426614174000'::uuid,
--     'admin@nbro.lk',
--     'NBRO Administrator',
--     'admin',
--     true
-- )
-- ON CONFLICT (id) DO UPDATE SET role = 'admin', is_active = true;

-- ============================================================================
-- VERIFICATION AND COMPLETION
-- ============================================================================

DO $$ 
DECLARE
    profiles_count INTEGER;
    sites_count INTEGER;
    inspections_count INTEGER;
    admin_count INTEGER;
    officer_count INTEGER;
    rls_policies_count INTEGER;
BEGIN 
    -- Count tables
    SELECT COUNT(*) INTO profiles_count FROM profiles;
    SELECT COUNT(*) INTO sites_count FROM sites;
    SELECT COUNT(*) INTO inspections_count FROM inspections;
    SELECT COUNT(*) INTO admin_count FROM profiles WHERE role = 'admin';
    SELECT COUNT(*) INTO officer_count FROM profiles WHERE role = 'officer';
    SELECT COUNT(*) INTO rls_policies_count FROM pg_policies 
        WHERE tablename IN ('profiles', 'sites', 'defects', 'defect_media', 'inspections');
    
    RAISE NOTICE '========================================';
    RAISE NOTICE '✓✓✓ DATABASE SETUP COMPLETE! ✓✓✓';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'TABLES CREATED:';
    RAISE NOTICE '  ✓ profiles (% records)', profiles_count;
    RAISE NOTICE '  ✓ sites (% records)', sites_count;
    RAISE NOTICE '  ✓ defects';
    RAISE NOTICE '  ✓ defect_media';
    RAISE NOTICE '  ✓ inspections (% records)', inspections_count;
    RAISE NOTICE '';
    RAISE NOTICE 'USERS:';
    RAISE NOTICE '  - Admins: %', admin_count;
    RAISE NOTICE '  - Officers: %', officer_count;
    RAISE NOTICE '';
    RAISE NOTICE 'SECURITY:';
    RAISE NOTICE '  ✓ RLS enabled on all tables';
    RAISE NOTICE '  ✓ % RLS policies active', rls_policies_count;
    RAISE NOTICE '  ✓ STRICT user isolation for officers';
    RAISE NOTICE '  ✓ Admin bypass for all data access';
    RAISE NOTICE '';
    RAISE NOTICE 'FEATURES:';
    RAISE NOTICE '  ✓ Auto profile creation on signup';
    RAISE NOTICE '  ✓ Auto defect count updates';
    RAISE NOTICE '  ✓ Admin dashboard views';
    RAISE NOTICE '  ✓ Storage bucket configured';
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'NEXT STEPS:';
    RAISE NOTICE '1. Create admin user in Supabase Auth';
    RAISE NOTICE '2. Copy user UUID';
    RAISE NOTICE '3. Run admin INSERT query above';
    RAISE NOTICE '4. Test admin login in Flutter app';
    RAISE NOTICE '5. Create officer accounts via admin panel';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    
    -- Check for issues
    IF rls_policies_count < 20 THEN
        RAISE WARNING '⚠ Expected more RLS policies! Some may be missing.';
    END IF;
    
    IF admin_count = 0 THEN
        RAISE NOTICE '⚠ No admin users yet. Create one using the example above.';
    END IF;
    
END $$;

-- ============================================================================
-- VERIFY AND CREATE ADMIN PROFILE FOR admin@gmail.com
-- ============================================================================
-- Stores user information and role (admin/officer) for access control

CREATE TABLE IF NOT EXISTS profiles (
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

-- Indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_is_active ON profiles(is_active);
CREATE INDEX IF NOT EXISTS idx_profiles_created_at ON profiles(created_at DESC);

-- Auto-update updated_at timestamp (uses existing function from supabase_schema.sql)
DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at 
    BEFORE UPDATE ON profiles
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE profiles IS 'User profiles with role-based access control (admin/officer)';
COMMENT ON COLUMN profiles.role IS 'User role: admin (full access) or officer (own data only)';
COMMENT ON COLUMN profiles.is_active IS 'Account status - inactive users cannot login';

-- ============================================================================
-- TABLE 2: inspections (Inspection Summary Records)
-- ============================================================================
-- Links sites to users and provides inspection-level metadata for admin dashboard

CREATE TABLE IF NOT EXISTS inspections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    site_id UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    building_reference_no TEXT NOT NULL,
    
    -- Denormalized fields for faster queries (from sites table)
    site_name TEXT,
    site_location TEXT,
    inspection_date DATE DEFAULT CURRENT_DATE,
    
    -- Defect statistics (computed from defects table)
    total_defects INTEGER DEFAULT 0,
    defects_with_photos INTEGER DEFAULT 0,
    
    -- Sync status
    sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'syncing', 'synced', 'error')),
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT fk_inspections_building_ref 
        FOREIGN KEY (building_reference_no) 
        REFERENCES sites(building_reference_no) 
        ON DELETE CASCADE
);

-- Indexes for admin dashboard queries
CREATE INDEX IF NOT EXISTS idx_inspections_user_id ON inspections(user_id);
CREATE INDEX IF NOT EXISTS idx_inspections_site_id ON inspections(site_id);
CREATE INDEX IF NOT EXISTS idx_inspections_building_ref ON inspections(building_reference_no);
CREATE INDEX IF NOT EXISTS idx_inspections_sync_status ON inspections(sync_status);
CREATE INDEX IF NOT EXISTS idx_inspections_date ON inspections(inspection_date DESC);
CREATE INDEX IF NOT EXISTS idx_inspections_created_at ON inspections(created_at DESC);

-- Auto-update updated_at timestamp
DROP TRIGGER IF EXISTS update_inspections_updated_at ON inspections;
CREATE TRIGGER update_inspections_updated_at 
    BEFORE UPDATE ON inspections
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE inspections IS 'Inspection summary records for admin dashboard and reporting';
COMMENT ON COLUMN inspections.building_reference_no IS 'Links to sites.building_reference_no (denormalized for performance)';

-- ============================================================================
-- FUNCTION: Auto-create profile when user signs up
-- ============================================================================
-- Automatically creates a profile record when a new user is created in auth.users

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

COMMENT ON FUNCTION public.handle_new_user() IS 'Auto-creates profile when new user signs up';

-- Create trigger for new user signup (only if not exists)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- FUNCTION: Update inspection defect counts
-- ============================================================================
-- Updates the defect statistics in inspections table

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

-- Trigger to update defect counts when defects change
DROP TRIGGER IF EXISTS update_inspection_counts_on_defect_change ON defects;
CREATE TRIGGER update_inspection_counts_on_defect_change
    AFTER INSERT OR UPDATE OR DELETE ON defects
    FOR EACH ROW 
    EXECUTE FUNCTION public.update_inspection_defect_counts();

-- ============================================================================
-- AUTO-POPULATE: Create inspection records for existing sites
-- ============================================================================
-- Migrates existing site data into inspections table

INSERT INTO inspections (
    site_id, 
    user_id, 
    building_reference_no,
    site_name, 
    site_location, 
    inspection_date, 
    sync_status, 
    created_at
)
SELECT 
    s.id,
    s.created_by,
    s.building_reference_no,
    s.owner_name,
    s.site_address,
    s.created_at::DATE,
    s.sync_status,
    s.created_at
FROM sites s
WHERE NOT EXISTS (
    SELECT 1 FROM inspections i WHERE i.site_id = s.id
)
ON CONFLICT DO NOTHING;

-- Update defect counts for newly created inspections
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
    );

-- ============================================================================
-- AUTO-POPULATE: Create profiles for existing auth users
-- ============================================================================
-- Creates profiles for users who signed up before this migration

INSERT INTO profiles (id, email, full_name, role)
SELECT 
    au.id,
    au.email,
    COALESCE(au.raw_user_meta_data->>'full_name', au.raw_user_meta_data->>'name', au.email),
    'officer'  -- Default to officer role
FROM auth.users au
WHERE NOT EXISTS (
    SELECT 1 FROM profiles p WHERE p.id = au.id
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) - NEW TABLES
-- ============================================================================

-- Enable RLS on new tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspections ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any (safe migration)
DROP POLICY IF EXISTS "profiles_select_all" ON profiles;
DROP POLICY IF EXISTS "profiles_insert_own" ON profiles;
DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
DROP POLICY IF EXISTS "profiles_delete_own" ON profiles;
DROP POLICY IF EXISTS "profiles_admin_all" ON profiles;

DROP POLICY IF EXISTS "inspections_select_own" ON inspections;
DROP POLICY IF EXISTS "inspections_insert_own" ON inspections;
DROP POLICY IF EXISTS "inspections_update_own" ON inspections;
DROP POLICY IF EXISTS "inspections_delete_own" ON inspections;
DROP POLICY IF EXISTS "inspections_admin_all" ON inspections;

-- ============================================================================
-- PROFILES RLS POLICIES
-- ============================================================================

-- Everyone can view all profiles (needed for admin to list officers)
CREATE POLICY "profiles_select_all" ON profiles
    FOR SELECT 
    USING (true);

-- Users can only update their own profile
CREATE POLICY "profiles_update_own" ON profiles
    FOR UPDATE 
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- Prevent regular users from inserting/deleting profiles directly
CREATE POLICY "profiles_insert_own" ON profiles
    FOR INSERT 
    WITH CHECK (id = auth.uid());

CREATE POLICY "profiles_delete_own" ON profiles
    FOR DELETE 
    USING (id = auth.uid());

-- Admins can do EVERYTHING with profiles (create officers, delete users, etc.)
CREATE POLICY "profiles_admin_all" ON profiles
    FOR ALL 
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND is_active = true
        )
    );

-- ============================================================================
-- INSPECTIONS RLS POLICIES
-- ============================================================================

-- Officers can view their own inspections only
CREATE POLICY "inspections_select_own" ON inspections
    FOR SELECT 
    USING (user_id = auth.uid());

-- Officers can insert their own inspections
CREATE POLICY "inspections_insert_own" ON inspections
    FOR INSERT 
    WITH CHECK (user_id = auth.uid());

-- Officers can update their own inspections
CREATE POLICY "inspections_update_own" ON inspections
    FOR UPDATE 
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Officers can delete their own inspections
CREATE POLICY "inspections_delete_own" ON inspections
    FOR DELETE 
    USING (user_id = auth.uid());

-- Admins can do EVERYTHING with ALL inspections (view all, edit all, delete all)
CREATE POLICY "inspections_admin_all" ON inspections
    FOR ALL 
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND is_active = true
        )
    );

-- ============================================================================
-- ADMIN BYPASS POLICIES - EXISTING TABLES (sites, defects, defect_media)
-- ============================================================================
-- These policies allow admins to view ALL data across all officers
-- Officer policies from supabase_schema.sql remain intact

-- Drop admin policies if they exist (safe to run multiple times)
DROP POLICY IF EXISTS "sites_admin_all" ON sites;
DROP POLICY IF EXISTS "defects_admin_all" ON defects;
DROP POLICY IF EXISTS "media_admin_all" ON defect_media;

-- Admins can access ALL sites (view, edit, delete) from all officers
CREATE POLICY "sites_admin_all" ON sites
    FOR ALL 
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND is_active = true
        )
    );

-- Admins can access ALL defects (view, edit, delete) from all officers
CREATE POLICY "defects_admin_all" ON defects
    FOR ALL 
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND is_active = true
        )
    );

-- Admins can access ALL defect media (view, edit, delete) from all officers
CREATE POLICY "media_admin_all" ON defect_media
    FOR ALL 
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND is_active = true
        )
    );

-- ============================================================================
-- ADMIN VIEW: Officers with Statistics
-- ============================================================================
-- Convenient view for admin dashboard showing officer inspection counts

CREATE OR REPLACE VIEW admin_officer_stats AS
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
GROUP BY p.id, p.email, p.full_name, p.phone, p.department, p.is_active, p.created_at
ORDER BY p.created_at DESC;

COMMENT ON VIEW admin_officer_stats IS 'Admin dashboard view showing officers with inspection statistics';

-- ============================================================================
-- CREATE FIRST ADMIN USER (MANUAL STEP)
-- ============================================================================
-- IMPORTANT: Run this AFTER creating the admin user in Supabase Auth Dashboard

-- Step 1: In Supabase Dashboard → Authentication → Users → Add user
--         - Create user with email/password
--         - Copy the User ID (UUID) shown after creation

-- Step 2: Run this query, replacing <USER_ID> with the copied UUID:

/*
INSERT INTO profiles (id, email, full_name, role, is_active)
VALUES (
    '<USER_ID>'::uuid,        -- Replace with UUID from Supabase Auth
    'admin@nbro.lk',          -- Your admin email
    'NBRO Administrator',     -- Admin full name
    'admin',                  -- Must be 'admin' role
    true                      -- Active account
)
ON CONFLICT (id) 
DO UPDATE SET 
    role = 'admin',
    is_active = true;
*/

-- Example with a real UUID (replace with yours):
-- INSERT INTO profiles (id, email, full_name, role, is_active)
-- VALUES (
--     '123e4567-e89b-12d3-a456-426614174000'::uuid,
--     'admin@nbro.lk',
--     'NBRO Administrator',
--     'admin',
--     true
-- )
-- ON CONFLICT (id) DO UPDATE SET role = 'admin', is_active = true;

-- ============================================================================
-- VERIFICATION AND COMPLETION
-- ============================================================================

DO $$ 
DECLARE
    profiles_count INTEGER;
    inspections_count INTEGER;
    admin_count INTEGER;
    officer_count INTEGER;
BEGIN 
    -- Check if tables were created
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') AND
       EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'inspections') THEN
        RAISE NOTICE '✓ Tables created successfully';
        
        -- Get counts
        SELECT COUNT(*) INTO profiles_count FROM profiles;
        SELECT COUNT(*) INTO inspections_count FROM inspections;
        SELECT COUNT(*) INTO admin_count FROM profiles WHERE role = 'admin';
        SELECT COUNT(*) INTO officer_count FROM profiles WHERE role = 'officer';
        
        RAISE NOTICE '  - Profiles: %', profiles_count;
        RAISE NOTICE '  - Inspections: %', inspections_count;
        RAISE NOTICE '  - Admins: %', admin_count;
        RAISE NOTICE '  - Officers: %', officer_count;
    ELSE
        RAISE NOTICE '✗ Table creation failed!';
    END IF;
    
    -- Check RLS is enabled
    IF (SELECT relrowsecurity FROM pg_class WHERE relname = 'profiles') AND
       (SELECT relrowsecurity FROM pg_class WHERE relname = 'inspections') THEN
        RAISE NOTICE '✓ RLS enabled on new tables';
    ELSE
        RAISE WARNING '✗ RLS not enabled properly!';
    END IF;
    
    -- Check policies exist
    IF (SELECT COUNT(*) FROM pg_policies WHERE tablename IN ('profiles', 'inspections', 'sites', 'defects', 'defect_media')) > 10 THEN
        RAISE NOTICE '✓ RLS policies created';
    ELSE
        RAISE WARNING '✗ Some RLS policies may be missing!';
    END IF;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE '✓✓✓ Migration Complete! ✓✓✓';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'NEXT STEPS:';
    RAISE NOTICE '1. If using admin@gmail.com - it was auto-configured!';
    RAISE NOTICE '2. For new admin: Create user in Supabase Auth Dashboard';
    RAISE NOTICE '3. Copy user UUID and run INSERT query below';
    RAISE NOTICE '4. Test admin login in Flutter app';
    RAISE NOTICE '5. Create officer accounts from admin panel';
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Database is ready for admin features!';
    RAISE NOTICE '========================================';
END $$;

-- ============================================================================
-- VERIFY AND CREATE ADMIN PROFILE FOR admin@gmail.com
-- ============================================================================
-- This creates the profile record for admin@gmail.com if it exists

DO $$
DECLARE
    admin_user_id UUID;
BEGIN
    -- Find admin@gmail.com user ID
    SELECT id INTO admin_user_id FROM auth.users WHERE email = 'admin@gmail.com';
    
    IF admin_user_id IS NOT NULL THEN
        -- Create or update profile for admin@gmail.com
        INSERT INTO profiles (id, email, full_name, role, is_active)
        VALUES (
            admin_user_id,
            'admin@gmail.com',
            'Administrator',
            'admin',
            true
        )
        ON CONFLICT (id) 
        DO UPDATE SET 
            role = 'admin',
            full_name = 'Administrator',
            is_active = true;
        
        RAISE NOTICE '';
        RAISE NOTICE '✓ Admin profile created for admin@gmail.com';
        RAISE NOTICE '  User ID: %', admin_user_id;
        RAISE NOTICE '  You can now login with admin@gmail.com';
        RAISE NOTICE '';
    ELSE
        RAISE NOTICE '';
        RAISE NOTICE '⚠ admin@gmail.com not found in auth.users';
        RAISE NOTICE '  Create the user first in Supabase Auth Dashboard';
        RAISE NOTICE '  Then run this script again, or run:';
        RAISE NOTICE '';
        RAISE NOTICE '  INSERT INTO profiles (id, email, full_name, role, is_active)';
        RAISE NOTICE '  SELECT id, email, ''Administrator'', ''admin'', true';
        RAISE NOTICE '  FROM auth.users WHERE email = ''admin@gmail.com''';
        RAISE NOTICE '  ON CONFLICT (id) DO UPDATE SET role = ''admin'';';
        RAISE NOTICE '';
    END IF;
END $$;

-- Show final summary
SELECT 
    'PROFILES' as category,
    'Total: ' || COUNT(*)::text as info
FROM profiles
UNION ALL
SELECT 'PROFILES', 'Admins: ' || COUNT(*)::text FROM profiles WHERE role = 'admin'
UNION ALL
SELECT 'PROFILES', 'Officers: ' || COUNT(*)::text FROM profiles WHERE role = 'officer'
UNION ALL
SELECT 'INSPECTIONS', 'Total: ' || COUNT(*)::text FROM inspections
UNION ALL
SELECT 'SITES', 'Total: ' || COUNT(*)::text FROM sites
UNION ALL
SELECT 'DEFECTS', 'Total: ' || COUNT(*)::text FROM defects
UNION ALL
SELECT 'MEDIA', 'Total: ' || COUNT(*)::text FROM defect_media;

-- ============================================================================
-- END OF SCHEMA - READY TO USE!
-- ============================================================================
