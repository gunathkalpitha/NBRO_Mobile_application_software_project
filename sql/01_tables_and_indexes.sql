-- ============================================================================
-- TABLES AND INDEXES
-- ============================================================================
-- This file contains all CREATE TABLE, ALTER TABLE, and CREATE INDEX statements.

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

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;

-- TABLE 1: profiles
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

-- TABLE 2: sites
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

-- TABLE 3: defects
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

-- TABLE 4: defect_media
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

-- TABLE 5: inspections
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
