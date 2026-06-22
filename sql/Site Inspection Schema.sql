-- NBRO schema (no FOREIGN KEY constraints)
-- Run this in Supabase SQL Editor after taking a backup.

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;

-- Profile table (no FK to auth.users here)
CREATE TABLE IF NOT EXISTS profile (
  id UUID PRIMARY KEY,
  full_name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'officer' CHECK (role IN ('admin', 'officer')),
  is_active BOOLEAN DEFAULT true,
  must_change_password BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Site table (no FK to profile)
CREATE TABLE IF NOT EXISTS site (
  site_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL,
  owner_name TEXT,
  owner_contact TEXT,
  location GEOGRAPHY(POINT, 4326),
  building_ref TEXT UNIQUE,
  distance_from_row DOUBLE PRECISION,
  address TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  building_photo_url TEXT,
  building_photo_path TEXT,
  sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'syncing', 'synced', 'error')),
  sections_status JSONB DEFAULT '{"general_observation": false, "external_services": false, "main_building": false, "ancillary_building": false, "defects": false}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- General observation (no FK constraint)
CREATE TABLE IF NOT EXISTS general_observation (
  observation_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  site_id UUID NOT NULL,
  type TEXT,
  present_condition TEXT,
  approx_age TEXT,
  sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'syncing', 'synced', 'error')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- External services (no FK)
CREATE TABLE IF NOT EXISTS external_services (
  service_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  site_id UUID NOT NULL,
  pipe_born_water_supply TEXT,
  sewage_waste TEXT,
  electricity_source TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ancillary building (no FK)
CREATE TABLE IF NOT EXISTS ancillary_building (
  structure_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  site_id UUID NOT NULL,
  building_type TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Detail type (no FK)
CREATE TABLE IF NOT EXISTS detail_type (
  detail_type_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  structure_id UUID NOT NULL,
  name TEXT NOT NULL
);

-- Building detail (no FK)
CREATE TABLE IF NOT EXISTS building_detail (
  building_detail_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  detail_type_id UUID NOT NULL,
  front BOOLEAN DEFAULT FALSE,
  left_side BOOLEAN DEFAULT FALSE,
  right_side BOOLEAN DEFAULT FALSE,
  rear BOOLEAN DEFAULT FALSE
);

-- Main building (no FK)
CREATE TABLE IF NOT EXISTS main_building (
  building_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  site_id UUID NOT NULL,
  no_floors TEXT,
  sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'syncing', 'synced', 'error')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Specification (no FK)
CREATE TABLE IF NOT EXISTS specification (
  spec_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  building_id UUID,
  is_used BOOLEAN,
  element_type TEXT,
  element_properties JSONB,
  floor_details JSONB
);

-- Defects (no FK)
CREATE TABLE IF NOT EXISTS defects (
  defect_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  site_id UUID,
  sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'syncing', 'synced', 'error')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add missing columns to defects table
ALTER TABLE IF EXISTS defects
ADD COLUMN IF NOT EXISTS notation TEXT,
ADD COLUMN IF NOT EXISTS defect_category TEXT,
ADD COLUMN IF NOT EXISTS floor_level TEXT,
ADD COLUMN IF NOT EXISTS location_description TEXT,
ADD COLUMN IF NOT EXISTS length_mm NUMERIC,
ADD COLUMN IF NOT EXISTS width_mm NUMERIC,
ADD COLUMN IF NOT EXISTS photo_path TEXT,
ADD COLUMN IF NOT EXISTS photo_url TEXT,
ADD COLUMN IF NOT EXISTS remarks TEXT;

-- Defect info (no FK)
CREATE TABLE IF NOT EXISTS defect_info (
  info_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  defect_id UUID,
  remarks TEXT,
  length TEXT,
  width TEXT
);

-- Defect image (no FK)
CREATE TABLE IF NOT EXISTS defect_image (
  image_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  info_id UUID,
  image_url TEXT,
  image_path TEXT,
  sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'syncing', 'synced', 'error')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Optional legacy tables (if you have defect_media)
CREATE TABLE IF NOT EXISTS defect_media (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  defect_id UUID,
  building_reference_no TEXT,
  storage_path TEXT NOT NULL,
  storage_url TEXT,
  file_name TEXT NOT NULL,
  file_size INTEGER,
  mime_type TEXT DEFAULT 'image/jpeg',
  width_px INTEGER,
  height_px INTEGER,
  has_annotations BOOLEAN DEFAULT FALSE,
  annotation_data JSONB,
  uploaded_at TIMESTAMPTZ DEFAULT NOW(),
  uploaded_by UUID
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_site_user_id ON site(user_id);
CREATE INDEX IF NOT EXISTS idx_general_observation_site_id ON general_observation(site_id);
CREATE INDEX IF NOT EXISTS idx_external_services_site_id ON external_services(site_id);
CREATE INDEX IF NOT EXISTS idx_ancillary_building_site_id ON ancillary_building(site_id);
CREATE INDEX IF NOT EXISTS idx_detail_type_structure_id ON detail_type(structure_id);
CREATE INDEX IF NOT EXISTS idx_building_detail_type_id ON building_detail(detail_type_id);
CREATE INDEX IF NOT EXISTS idx_main_building_site_id ON main_building(site_id);
CREATE INDEX IF NOT EXISTS idx_specification_building_id ON specification(building_id);
CREATE INDEX IF NOT EXISTS idx_defects_site_id ON defects(site_id);
CREATE INDEX IF NOT EXISTS idx_defect_info_defect_id ON defect_info(defect_id);
CREATE INDEX IF NOT EXISTS idx_defect_image_info_id ON defect_image(info_id);
CREATE INDEX IF NOT EXISTS idx_site_sync_status ON site(sync_status);
CREATE INDEX IF NOT EXISTS idx_site_building_ref ON site(building_ref);
CREATE INDEX IF NOT EXISTS idx_profile_role ON profile(role);
CREATE INDEX IF NOT EXISTS idx_profile_is_active ON profile(is_active);
CREATE INDEX IF NOT EXISTS idx_profile_must_change_password ON profile(must_change_password) WHERE must_change_password = true;

-- Update timestamp trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

-- Attach triggers to tables
DROP TRIGGER IF EXISTS update_site_updated_at ON site;
CREATE TRIGGER update_site_updated_at
BEFORE UPDATE ON site
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_general_observation_at ON general_observation;
CREATE TRIGGER update_general_observation_at
BEFORE UPDATE ON general_observation
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_profile_updated_at ON profile;
CREATE TRIGGER update_profile_updated_at
BEFORE UPDATE ON profile
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_ancillary_building_at ON ancillary_building;
CREATE TRIGGER update_ancillary_building_at
BEFORE UPDATE ON ancillary_building
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_external_services_at ON external_services;
CREATE TRIGGER update_external_services_at
BEFORE UPDATE ON external_services
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_main_building_at ON main_building;
CREATE TRIGGER update_main_building_at
BEFORE UPDATE ON main_building
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_defects_at ON defects;
CREATE TRIGGER update_defects_at
BEFORE UPDATE ON defects
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_defect_image_at ON defect_image;
CREATE TRIGGER update_defect_image_at
BEFORE UPDATE ON defect_image
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

