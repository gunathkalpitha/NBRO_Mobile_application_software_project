CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE profile(
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'officer' CHECK (role IN ('admin', 'officer')),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW() 
);

CREATE TABLE site(
  site_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profile(id) ON DELETE RESTRICT,
  owner_name TEXT,
  owner_contact TEXT,
  location GEOGRAPHY(POINT, 4326),
  building_ref TEXT UNIQUE,
  distance_from_row DOUBLE PRECISION,
  address TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW() 
);

CREATE TABLE general_observation(
  observation_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  site_id UUID NOT NULL REFERENCES site(site_id) ON DELETE RESTRICT,
  type TEXT,
  present_condition TEXT,
  approx_age TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW() 
);

CREATE TABLE external_services(
  service_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  site_id UUID NOT NULL REFERENCES site(site_id) ON DELETE RESTRICT,
  pipe_born_water_supply TEXT,
  sewage_waste TEXT,
  electricity_source TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW() 
);

CREATE TABLE ancillary_building(
  structure_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  site_id UUID NOT NULL REFERENCES site(site_id) ON DELETE RESTRICT,
  building_type TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW() 
);

CREATE TABLE detail_type(
  detail_type_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  structure_id UUID NOT NULL REFERENCES ancillary_building(structure_id) ON DELETE CASCADE,
  name TEXT NOT NULL
);

CREATE TABLE building_detail(
  building_detail_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  detail_type_id UUID NOT NULL REFERENCES detail_type(detail_type_id) ON DELETE CASCADE,
  
  front BOOLEAN DEFAULT FALSE,
  left_side BOOLEAN DEFAULT FALSE,
  right_side BOOLEAN DEFAULT FALSE,
  rear BOOLEAN DEFAULT FALSE
);

CREATE TABLE main_building(
  building_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  site_id UUID NOT NULL REFERENCES site(site_id) ON DELETE RESTRICT,
  no_floors TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW() 
);

CREATE TABLE specification(
  spec_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  building_id UUID REFERENCES main_building(building_id) ON DELETE CASCADE,
  is_used BOOLEAN,
  element_type TEXT,
  element_properties JSONB,
  floor_details JSONB
);

CREATE TABLE defects(
  defect_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  site_id UUID REFERENCES site(site_id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW() 
);

CREATE TABLE defect_info(
  info_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  defect_id UUID REFERENCES defects(defect_id) ON DELETE CASCADE,
  remarks TEXT,
  length TEXT,
  width TEXT
);

CREATE TABLE defect_image(
  image_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  info_id UUID REFERENCES defect_info(info_id) ON DELETE CASCADE,
  image_url TEXT,
  image_path TEXT
);

CREATE INDEX idx_site_id ON site(user_id);
CREATE INDEX idx_general_observation_id ON general_observation(site_id);
CREATE INDEX idx_external_services_id ON external_services(site_id);
CREATE INDEX idx_ancillary_building_id ON ancillary_building(site_id);
CREATE INDEX idx_details_type_id ON detail_type(structure_id);
CREATE INDEX idx_building_details_details_id ON building_detail(detail_type_id);
CREATE INDEX idx_main_building ON main_building(site_id);
CREATE INDEX idx_specification ON specification(building_id);
CREATE INDEX idx_defects ON defects(site_id);
CREATE INDEX idx_defect_info ON defect_info(defect_id);
CREATE INDEX idx_defect_image ON defect_image(info_id);



CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = NOW();
   RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_site_updated_at
BEFORE UPDATE ON site
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_general_observation_at
BEFORE UPDATE ON general_observation
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_profile_updaate_at
BEFORE UPDATE ON profile
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ancillary_building_at
BEFORE UPDATE ON ancillary_building
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_main_building_at
BEFORE UPDATE ON main_building
FOR EACH ROW 
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_defects_at
BEFORE UPDATE ON defects
FOR EACH ROW 
EXECUTE FUNCTION update_updated_at_column();


ALTER TABLE site
ADD COLUMN latitude DOUBLE PRECISION,
ADD COLUMN longitude DOUBLE PRECISION;
