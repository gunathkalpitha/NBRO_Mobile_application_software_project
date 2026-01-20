-- ============================================================================
-- NBRO Site Inspection Database Schema for Supabase (PostgreSQL)
-- ============================================================================
-- Clean installation script - Run this in Supabase SQL Editor
-- ============================================================================

-- Drop existing tables if they exist (clean slate)
DROP TABLE IF EXISTS defect_media CASCADE;
DROP TABLE IF EXISTS defects CASCADE;
DROP TABLE IF EXISTS sites CASCADE;

-- Drop existing views
DROP VIEW IF EXISTS inspection_details CASCADE;
DROP VIEW IF EXISTS defects_with_media CASCADE;
DROP VIEW IF EXISTS sites_with_defect_count CASCADE;

-- Drop existing functions
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS update_site_location() CASCADE;

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
-- TABLE 1: sites
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
    created_by UUID
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
-- TABLE 2: defects
-- ============================================================================

CREATE TABLE defects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    site_id UUID NOT NULL,
    
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
        FOREIGN KEY (site_id) 
        REFERENCES sites(id) 
        ON DELETE CASCADE
);

CREATE INDEX idx_defects_site_id ON defects(site_id);
CREATE INDEX idx_defects_notation ON defects(notation);
CREATE INDEX idx_defects_category ON defects(defect_category);
CREATE INDEX idx_defects_floor_level ON defects(floor_level);
CREATE INDEX idx_defects_created_at ON defects(created_at DESC);

CREATE TRIGGER update_defects_updated_at 
    BEFORE UPDATE ON defects
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- TABLE 3: defect_media
-- ============================================================================

CREATE TABLE defect_media (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    defect_id UUID NOT NULL,
    site_id UUID NOT NULL,
    
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
        REFERENCES defects(id) 
        ON DELETE CASCADE,
    CONSTRAINT fk_media_site 
        FOREIGN KEY (site_id) 
        REFERENCES sites(id) 
        ON DELETE CASCADE
);

CREATE INDEX idx_defect_media_defect_id ON defect_media(defect_id);
CREATE INDEX idx_defect_media_site_id ON defect_media(site_id);
CREATE INDEX idx_defect_media_uploaded_at ON defect_media(uploaded_at DESC);
CREATE INDEX idx_defect_media_uploaded_by ON defect_media(uploaded_by);

-- ============================================================================
-- VIEWS
-- ============================================================================

CREATE VIEW sites_with_defect_count AS
SELECT 
    s.*,
    COUNT(d.id) as total_defects,
    COUNT(CASE WHEN d.photo_path IS NOT NULL THEN 1 END) as defects_with_photos
FROM sites s
LEFT JOIN defects d ON s.id = d.site_id
GROUP BY s.id;

CREATE VIEW defects_with_media AS
SELECT 
    d.*,
    s.building_reference_no,
    s.site_address,
    COUNT(dm.id) as media_count,
    ARRAY_AGG(dm.storage_url) FILTER (WHERE dm.storage_url IS NOT NULL) as photo_urls
FROM defects d
JOIN sites s ON d.site_id = s.id
LEFT JOIN defect_media dm ON d.id = dm.defect_id
GROUP BY d.id, s.building_reference_no, s.site_address;

CREATE VIEW inspection_details AS
SELECT 
    s.id as site_id,
    s.building_reference_no,
    s.owner_name,
    s.site_address,
    s.latitude,
    s.longitude,
    s.sync_status,
    s.created_at as site_created_at,
    d.id as defect_id,
    d.notation,
    d.defect_category,
    d.floor_level,
    d.length_mm,
    d.width_mm,
    d.remarks as defect_remarks,
    COUNT(dm.id) as photo_count
FROM sites s
LEFT JOIN defects d ON s.id = d.site_id
LEFT JOIN defect_media dm ON d.id = dm.defect_id
GROUP BY s.id, d.id;

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE defects ENABLE ROW LEVEL SECURITY;
ALTER TABLE defect_media ENABLE ROW LEVEL SECURITY;

-- Sites policies
CREATE POLICY "sites_select_policy" ON sites
    FOR SELECT USING (created_by = auth.uid() OR created_by IS NULL);

CREATE POLICY "sites_insert_policy" ON sites
    FOR INSERT WITH CHECK (created_by = auth.uid() OR created_by IS NULL);

CREATE POLICY "sites_update_policy" ON sites
    FOR UPDATE USING (created_by = auth.uid() OR created_by IS NULL);

CREATE POLICY "sites_delete_policy" ON sites
    FOR DELETE USING (created_by = auth.uid() OR created_by IS NULL);

-- Defects policies
CREATE POLICY "defects_select_policy" ON defects
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM sites 
            WHERE sites.id = defects.site_id 
            AND (sites.created_by = auth.uid() OR sites.created_by IS NULL)
        )
    );

CREATE POLICY "defects_insert_policy" ON defects
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM sites 
            WHERE sites.id = defects.site_id 
            AND (sites.created_by = auth.uid() OR sites.created_by IS NULL)
        )
    );

CREATE POLICY "defects_update_policy" ON defects
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM sites 
            WHERE sites.id = defects.site_id 
            AND (sites.created_by = auth.uid() OR sites.created_by IS NULL)
        )
    );

CREATE POLICY "defects_delete_policy" ON defects
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM sites 
            WHERE sites.id = defects.site_id 
            AND (sites.created_by = auth.uid() OR sites.created_by IS NULL)
        )
    );

-- Media policies
CREATE POLICY "media_select_policy" ON defect_media
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM sites 
            WHERE sites.id = defect_media.site_id 
            AND (sites.created_by = auth.uid() OR sites.created_by IS NULL)
        )
    );

CREATE POLICY "media_insert_policy" ON defect_media
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM sites 
            WHERE sites.id = defect_media.site_id 
            AND (sites.created_by = auth.uid() OR sites.created_by IS NULL)
        )
    );

CREATE POLICY "media_update_policy" ON defect_media
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM sites 
            WHERE sites.id = defect_media.site_id 
            AND (sites.created_by = auth.uid() OR sites.created_by IS NULL)
        )
    );

CREATE POLICY "media_delete_policy" ON defect_media
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM sites 
            WHERE sites.id = defect_media.site_id 
            AND (sites.created_by = auth.uid() OR sites.created_by IS NULL)
        )
    );

-- ============================================================================
-- SCHEMA READY FOR USE
-- ============================================================================
DO $$ 
BEGIN 
    RAISE NOTICE 'Schema created successfully!';
    RAISE NOTICE 'Tables: sites, defects, defect_media';
    RAISE NOTICE 'Views: sites_with_defect_count, defects_with_media, inspection_details';
    RAISE NOTICE 'RLS Policies: Enabled on all tables';
END $$;