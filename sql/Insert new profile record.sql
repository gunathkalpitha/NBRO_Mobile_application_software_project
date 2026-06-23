-- 1. Ensure the unique constraint exists for ON CONFLICT to work
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'site_building_ref_key') THEN
    ALTER TABLE site ADD CONSTRAINT site_building_ref_key UNIQUE (building_ref);
  END IF;
END $$;

-- 2. Add missing columns to existing site table
ALTER TABLE IF EXISTS site
ADD COLUMN IF NOT EXISTS building_photo_url TEXT,
ADD COLUMN IF NOT EXISTS building_photo_path TEXT,
ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS updated_by UUID,
ADD COLUMN IF NOT EXISTS sections_status JSONB DEFAULT '{"general_observation": false, "external_services": false, "main_building": false, "ancillary_building": false, "defects": false}'::jsonb;

-- 3. Insert Admin Profile
INSERT INTO profile(id, full_name, role)
VALUES(
  'cc8eefc8-6473-43a7-8530-f5f9202f3581',
  'Government Officer',
  'admin'
)
ON CONFLICT (id) DO UPDATE SET full_name = EXCLUDED.full_name;

-- 4. Insert Test Site
INSERT INTO site (
  site_id,
  user_id,
  owner_name,
  owner_contact,
  location,
  building_ref,
  distance_from_row,
  address,
  building_photo_url,
  latitude,
  longitude,
  updated_by,
  updated_at,
  sections_status
)
VALUES (
  '2d8d26f5-290d-4895-b4f6-8b4dc2e7d7e7',
  'cc8eefc8-6473-43a7-8530-f5f9202f3581',
  'Mr. Perera',
  '0771234567',
  ST_SetSRID(ST_MakePoint(79.8612, 6.9271), 4326),
  'BR-TEST-001',
  15.5,
  'Colombo 07',
  'https://images.unsplash.com/photo-1518780664697-55e3ad937233',
  6.9271,
  79.8612,
  'cc8eefc8-6473-43a7-8530-f5f9202f3581',
  NOW(),
  '{
    "general_observation": true,
    "external_services": true,
    "main_building": true,
    "ancillary_building": true,
    "defects": true
  }'::jsonb
)
ON CONFLICT (building_ref) DO UPDATE SET
  updated_by = EXCLUDED.updated_by,
  updated_at = EXCLUDED.updated_at,
  building_photo_url = EXCLUDED.building_photo_url;

-- 5. Insert General Observation (Fixes "Type")
INSERT INTO general_observation (site_id, type, present_condition, approx_age)
VALUES ('2d8d26f5-290d-4895-b4f6-8b4dc2e7d7e7', 'House', 'Permanent', '15')
ON CONFLICT (observation_id) DO NOTHING;

-- 6. Insert External Services (Fixes "Available")
INSERT INTO external_services (site_id, pipe_born_water_supply, sewage_waste, electricity_source)
VALUES (
  '2d8d26f5-290d-4895-b4f6-8b4dc2e7d7e7',
  'Available (Main Supply)',
  'Available (Septic Tank)',
  'Available (Main Supply)'
)
ON CONFLICT (service_id) DO NOTHING;

-- 7. Insert Main Building and Specifications (Fixes "Building Profile")
DO $$
DECLARE
  v_building_id UUID;
BEGIN
  INSERT INTO main_building (site_id, no_floors)
  VALUES ('2d8d26f5-290d-4895-b4f6-8b4dc2e7d7e7', 'G+2')
  ON CONFLICT (building_id) DO NOTHING
  RETURNING building_id INTO v_building_id;

  IF v_building_id IS NOT NULL THEN
    INSERT INTO specification (building_id, is_used, element_type)
    VALUES
      (v_building_id, TRUE, 'wall|Brick'),
      (v_building_id, TRUE, 'floor|Cement Rendered'),
      (v_building_id, TRUE, 'roof|Clay Tiles')
    ON CONFLICT (spec_id) DO NOTHING;
  END IF;
END $$;
