CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE IF NOT EXISTS profile(
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'officer' CHECK (role IN ('admin', 'officer')),
  is_active BOOLEAN DEFAULT true,
  must_change_password BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW() 
);

CREATE TABLE IF NOT EXISTS site(
  site_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profile(id) ON DELETE RESTRICT,
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

CREATE TABLE IF NOT EXISTS general_observation(
  observation_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  site_id UUID NOT NULL REFERENCES site(site_id) ON DELETE RESTRICT,
  type TEXT,
  present_condition TEXT,
  approx_age TEXT,
  sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'syncing', 'synced', 'error')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW() 
);

CREATE TABLE IF NOT EXISTS external_services(
  service_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  site_id UUID NOT NULL REFERENCES site(site_id) ON DELETE RESTRICT,
  pipe_born_water_supply TEXT,
  sewage_waste TEXT,
  electricity_source TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW() 
);

CREATE TABLE IF NOT EXISTS ancillary_building(
  structure_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  site_id UUID NOT NULL REFERENCES site(site_id) ON DELETE RESTRICT,
  building_type TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW() 
);

CREATE TABLE IF NOT EXISTS detail_type(
  detail_type_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  structure_id UUID NOT NULL REFERENCES ancillary_building(structure_id) ON DELETE CASCADE,
  name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS building_detail(
  building_detail_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  detail_type_id UUID NOT NULL REFERENCES detail_type(detail_type_id) ON DELETE CASCADE,
  
  front BOOLEAN DEFAULT FALSE,
  left_side BOOLEAN DEFAULT FALSE,
  right_side BOOLEAN DEFAULT FALSE,
  rear BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS main_building(
  building_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  site_id UUID NOT NULL REFERENCES site(site_id) ON DELETE RESTRICT,
  no_floors TEXT,
  sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'syncing', 'synced', 'error')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW() 
);

CREATE TABLE IF NOT EXISTS specification(
  spec_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  building_id UUID REFERENCES main_building(building_id) ON DELETE CASCADE,
  is_used BOOLEAN,
  element_type TEXT,
  element_properties JSONB,
  floor_details JSONB
);

CREATE TABLE IF NOT EXISTS defects(
  defect_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  site_id UUID REFERENCES site(site_id) ON DELETE CASCADE,
  sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'syncing', 'synced', 'error')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW() 
);

CREATE TABLE IF NOT EXISTS defect_info(
  info_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  defect_id UUID REFERENCES defects(defect_id) ON DELETE CASCADE,
  remarks TEXT,
  length TEXT,
  width TEXT
);

CREATE TABLE IF NOT EXISTS defect_image(
  image_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  info_id UUID REFERENCES defect_info(info_id) ON DELETE CASCADE,
  image_url TEXT,
  image_path TEXT,
  sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'syncing', 'synced', 'error')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_site_id ON site(user_id);
CREATE INDEX IF NOT EXISTS idx_general_observation_id ON general_observation(site_id);
CREATE INDEX IF NOT EXISTS idx_external_services_id ON external_services(site_id);
CREATE INDEX IF NOT EXISTS idx_ancillary_building_id ON ancillary_building(site_id);
CREATE INDEX IF NOT EXISTS idx_details_type_id ON detail_type(structure_id);
CREATE INDEX IF NOT EXISTS idx_building_details_details_id ON building_detail(detail_type_id);
CREATE INDEX IF NOT EXISTS idx_main_building ON main_building(site_id);
CREATE INDEX IF NOT EXISTS idx_specification ON specification(building_id);
CREATE INDEX IF NOT EXISTS idx_defects ON defects(site_id);
CREATE INDEX IF NOT EXISTS idx_defect_info ON defect_info(defect_id);
CREATE INDEX IF NOT EXISTS idx_defect_image ON defect_image(info_id);
CREATE INDEX IF NOT EXISTS idx_site_sync_status ON site(sync_status);
CREATE INDEX IF NOT EXISTS idx_site_building_ref ON site(building_ref);
CREATE INDEX IF NOT EXISTS idx_profile_role ON profile(role);
CREATE INDEX IF NOT EXISTS idx_profile_is_active ON profile(is_active);
CREATE INDEX IF NOT EXISTS idx_profile_must_change_password ON profile(must_change_password) WHERE must_change_password = true;



CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = NOW();
   RETURN NEW;
END;
$$ language 'plpgsql';

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

-- ============================================================================
-- Fix Foreign Key Constraints for Cascade Delete
-- ============================================================================
-- Drop existing constraints that use ON DELETE RESTRICT
ALTER TABLE general_observation DROP CONSTRAINT IF EXISTS general_observation_site_id_fkey;
ALTER TABLE external_services DROP CONSTRAINT IF EXISTS external_services_site_id_fkey;
ALTER TABLE ancillary_building DROP CONSTRAINT IF EXISTS ancillary_building_site_id_fkey;
ALTER TABLE main_building DROP CONSTRAINT IF EXISTS main_building_site_id_fkey;

-- Add new constraints with ON DELETE CASCADE
ALTER TABLE general_observation 
ADD CONSTRAINT general_observation_site_id_fkey 
FOREIGN KEY (site_id) REFERENCES site(site_id) ON DELETE CASCADE;

ALTER TABLE external_services 
ADD CONSTRAINT external_services_site_id_fkey 
FOREIGN KEY (site_id) REFERENCES site(site_id) ON DELETE CASCADE;

ALTER TABLE ancillary_building 
ADD CONSTRAINT ancillary_building_site_id_fkey 
FOREIGN KEY (site_id) REFERENCES site(site_id) ON DELETE CASCADE;

ALTER TABLE main_building 
ADD CONSTRAINT main_building_site_id_fkey 
FOREIGN KEY (site_id) REFERENCES site(site_id) ON DELETE CASCADE;