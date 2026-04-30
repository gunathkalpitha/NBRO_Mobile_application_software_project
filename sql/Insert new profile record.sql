BEGIN;

INSERT INTO profile(id, full_name, role)
VALUES(
  'cc8eefc8-6473-43a7-8530-f5f9202f3581',
  'Government Officer',
  'admin'
)
ON CONFLICT (id) DO NOTHING;
COMMIT;

BEGIN;

INSERT INTO site (
  site_id,
  user_id,
  created_by,
  owner_name,
  owner_contact,
  location,
  building_ref,
  distance_from_row,
  address
)
VALUES (
  '2d8d26f5-290d-4895-b4f6-8b4dc2e7d7e7',
  'cc8eefc8-6473-43a7-8530-f5f9202f3581',
  'cc8eefc8-6473-43a7-8530-f5f9202f3581',
  'Mr. Perera',
  '0771234567',
  ST_SetSRID(ST_MakePoint(79.8612, 6.9271), 4326),
  'BR-TEST-001',
  15.5,
  'Colombo 07'
)
ON CONFLICT (building_ref) DO NOTHING
RETURNING site_id;
COMMIT;

BEGIN;

WITH target_site AS (
  SELECT site_id
  FROM site
  WHERE building_ref = 'BR-TEST-001'
  LIMIT 1
)
INSERT INTO general_observation (site_id, type, present_condition, approx_age)
SELECT
  target_site.site_id,
  'Structural',
  'Good',
  '10-15 years'
FROM target_site;

COMMIT;

BEGIN;

WITH target_site AS (
  SELECT site_id
  FROM site
  WHERE building_ref = 'BR-TEST-001'
  LIMIT 1
)
INSERT INTO external_services (site_id, pipe_born_water_supply, sewage_waste, electricity_source)
SELECT
  target_site.site_id,
  'Available',
  'Connected',
  'Grid'
FROM target_site;

COMMIT;

BEGIN;

WITH new_building AS (
  INSERT INTO main_building (site_id, no_floors)
  SELECT site_id, '3'
  FROM site
  WHERE building_ref = 'BR-TEST-001'
  LIMIT 1
  RETURNING building_id
)
INSERT INTO specification (building_id, is_used, element_type, element_properties, floor_details)
SELECT 
  building_id,
  TRUE,
  'Concrete',
  '{"material":"cement","strength":"M25"}',
  '{"floor1":"Living Room","floor2":"Bedrooms","floor3":"Roof"}'
FROM new_building;

COMMIT;

BEGIN;

WITH new_ancillary AS (
  INSERT INTO ancillary_building (site_id, building_type)
  SELECT site_id, 'Garage'
  FROM site
  WHERE building_ref = 'BR-TEST-001'
  LIMIT 1
  RETURNING structure_id
),
new_detail_type AS (
  INSERT INTO detail_type (structure_id, name)
  SELECT structure_id, 'Wall'
  FROM new_ancillary
  RETURNING detail_type_id
)
INSERT INTO building_detail (detail_type_id, front, left_side, right_side, rear)
SELECT detail_type_id, TRUE, FALSE, TRUE, FALSE
FROM new_detail_type;

COMMIT;

BEGIN;

WITH target_site AS (
  SELECT site_id
  FROM site
  WHERE building_ref = 'BR-TEST-001'
  LIMIT 1
),
new_defect AS (
  INSERT INTO defects (
    site_id,
    notation,
    defect_category,
    floor_level,
    location_description,
    length_mm,
    width_mm,
    photo_path,
    photo_url,
    remarks,
    created_by
  )
  SELECT
    target_site.site_id,
    'C',
    'buildingFloor',
    'Ground',
    'Near window',
    1500,
    200,
    '/images/defect.jpg',
    'http://example.com/defect.jpg',
    'Crack near window',
    'cc8eefc8-6473-43a7-8530-f5f9202f3581'
  FROM target_site
  RETURNING defect_id, site_id
)
INSERT INTO defect_media (
  defect_id,
  site_id,
  storage_path,
  storage_url,
  file_name,
  file_size,
  mime_type,
  created_by,
  uploaded_by
)
SELECT
  defect_id,
  site_id,
  '/images/defect.jpg',
  'http://example.com/defect.jpg',
  'defect.jpg',
  1024,
  'image/jpeg',
  'cc8eefc8-6473-43a7-8530-f5f9202f3581',
  'cc8eefc8-6473-43a7-8530-f5f9202f3581'
FROM new_defect;

COMMIT;


ALTER TABLE site
ADD COLUMN IF NOT EXISTS sections_status JSONB DEFAULT '{
    "general_observation": false,
    "external_services": false,
    "main_building": false,
    "ancillary_building": false,
    "defects": false
}'::jsonb;


CREATE OR REPLACE FUNCTION public.get_site_completion(p_site_id UUID)
RETURNS TABLE (
    site_id UUID,
    owner_name TEXT,
    building_ref TEXT,
    sync_status TEXT,
    general_observation_complete BOOLEAN,
    external_services_complete BOOLEAN,
    main_building_complete BOOLEAN,
    ancillary_building_complete BOOLEAN,
    defects_complete BOOLEAN,
    is_fully_complete BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.site_id,
        s.owner_name,
        s.building_ref,
        s.sync_status,
        COALESCE((s.sections_status->>'general_observation')::boolean, false),
        COALESCE((s.sections_status->>'external_services')::boolean, false),
        COALESCE((s.sections_status->>'main_building')::boolean, false),
        COALESCE((s.sections_status->>'ancillary_building')::boolean, false),
        COALESCE((s.sections_status->>'defects')::boolean, false),
        (
            COALESCE((s.sections_status->>'general_observation')::boolean, false) AND
            COALESCE((s.sections_status->>'external_services')::boolean, false) AND
            COALESCE((s.sections_status->>'main_building')::boolean, false) AND
            COALESCE((s.sections_status->>'ancillary_building')::boolean, false) AND
            COALESCE((s.sections_status->>'defects')::boolean, false)
        ) as is_fully_complete
    FROM site s
    WHERE s.site_id = p_site_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;


-- ============================================================================
-- INSERT TRANSACTIONS
-- ============================================================================

CREATE OR REPLACE FUNCTION insert_full_site(
  p_user_id UUID,
  p_owner_name TEXT,
  p_owner_contact TEXT,
  p_longitude DOUBLE PRECISION,
  p_latitude DOUBLE PRECISION,
  p_building_ref TEXT,
  p_distance_from_row DOUBLE PRECISION,
  p_address TEXT,
  p_type TEXT,
  p_present_condition TEXT,
  p_approx_age TEXT,
  p_pipe_born_water TEXT,
  p_sewage_waste TEXT,
  p_electricity_source TEXT,
  p_no_floors TEXT
)
RETURNS UUID AS $$
DECLARE
  v_site_id UUID;
BEGIN
  INSERT INTO site (user_id, owner_name, owner_contact, location, building_ref, distance_from_row, address)
  VALUES (
    p_user_id, p_owner_name, p_owner_contact,
    ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326),
    p_building_ref, p_distance_from_row, p_address
  )
  RETURNING site_id INTO v_site_id;

  INSERT INTO general_observation (site_id, type, present_condition, approx_age)
  VALUES (v_site_id, p_type, p_present_condition, p_approx_age);

  INSERT INTO external_services (site_id, pipe_born_water_supply, sewage_waste, electricity_source)
  VALUES (v_site_id, p_pipe_born_water, p_sewage_waste, p_electricity_source);

  INSERT INTO main_building (site_id, no_floors)
  VALUES (v_site_id, p_no_floors);

  RETURN v_site_id;

EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'insert_full_site failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION insert_defect_with_details(
  p_site_id UUID,
  p_notation TEXT,
  p_defect_category TEXT,
  p_floor_level TEXT DEFAULT NULL,
  p_location_description TEXT DEFAULT NULL,
  p_length_mm DOUBLE PRECISION DEFAULT 0,
  p_width_mm DOUBLE PRECISION DEFAULT NULL,
  p_remarks TEXT DEFAULT NULL,
  p_image_url TEXT DEFAULT NULL,
  p_image_path TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_defect_id UUID;
BEGIN
  -- Check site exists
  IF NOT EXISTS (SELECT 1 FROM site WHERE site_id = p_site_id) THEN
    RAISE EXCEPTION 'Site with id % not found', p_site_id;
  END IF;

  INSERT INTO defects (
    site_id, 
    notation, 
    defect_category, 
    floor_level, 
    location_description, 
    length_mm, 
    width_mm, 
    remarks, 
    photo_url, 
    photo_path
  )
  VALUES (
    p_site_id, 
    p_notation, 
    p_defect_category, 
    p_floor_level, 
    p_location_description, 
    p_length_mm, 
    p_width_mm, 
    p_remarks, 
    p_image_url, 
    p_image_path
  )
  RETURNING defect_id INTO v_defect_id;

  RETURN v_defect_id;

EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'insert_defect_with_details failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION insert_ancillary_with_details(
  p_site_id UUID,
  p_building_type TEXT,
  p_detail_name TEXT,
  p_front BOOLEAN,
  p_left_side BOOLEAN,
  p_right_side BOOLEAN,
  p_rear BOOLEAN
)
RETURNS UUID AS $$
DECLARE
  v_structure_id UUID;
  v_detail_type_id UUID;
BEGIN
  -- Check site exists
  IF NOT EXISTS (SELECT 1 FROM site WHERE site_id = p_site_id) THEN
    RAISE EXCEPTION 'Site with id % not found', p_site_id;
  END IF;

  INSERT INTO ancillary_building (site_id, building_type)
  VALUES (p_site_id, p_building_type)
  RETURNING structure_id INTO v_structure_id;

  INSERT INTO detail_type (structure_id, name)
  VALUES (v_structure_id, p_detail_name)
  RETURNING detail_type_id INTO v_detail_type_id;

  INSERT INTO building_detail (detail_type_id, front, left_side, right_side, rear)
  VALUES (v_detail_type_id, p_front, p_left_side, p_right_side, p_rear);

  RETURN v_structure_id;

EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'insert_ancillary_with_details failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;


-- ============================================================================
-- UPDATE TRANSACTIONS
-- ============================================================================

CREATE OR REPLACE FUNCTION update_site_details(
  p_site_id UUID,
  p_owner_name TEXT,
  p_owner_contact TEXT,
  p_address TEXT,
  p_distance_from_row DOUBLE PRECISION,
  p_type TEXT,
  p_present_condition TEXT,
  p_approx_age TEXT,
  p_pipe_born_water TEXT,
  p_sewage_waste TEXT,
  p_electricity_source TEXT
)
RETURNS VOID AS $$
BEGIN
  -- Update site
  UPDATE site
  SET
    owner_name = p_owner_name,
    owner_contact = p_owner_contact,
    address = p_address,
    distance_from_row = p_distance_from_row
  WHERE site_id = p_site_id;

  -- Improvement 1: Check if site was actually found
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Site with id % not found', p_site_id;
  END IF;

  -- Update general observation
  UPDATE general_observation
  SET
    type = p_type,
    present_condition = p_present_condition,
    approx_age = p_approx_age
  WHERE site_id = p_site_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'General observation for site % not found', p_site_id;
  END IF;

  -- Update external services
  UPDATE external_services
  SET
    pipe_born_water_supply = p_pipe_born_water,
    sewage_waste = p_sewage_waste,
    electricity_source = p_electricity_source
  WHERE site_id = p_site_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'External services for site % not found', p_site_id;
  END IF;

EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'update_site_details failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION update_defect_details(
  p_defect_id UUID,
  p_remarks TEXT,
  p_length TEXT,
  p_width TEXT,
  p_image_url TEXT,
  p_image_path TEXT
)
RETURNS VOID AS $$
DECLARE
  v_info_id UUID;
BEGIN
  -- Update defect info
  UPDATE defect_info
  SET remarks = p_remarks, length = p_length, width = p_width
  WHERE defect_id = p_defect_id
  RETURNING info_id INTO v_info_id;

  -- Improvement 1: Check if defect was actually found
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Defect with id % not found', p_defect_id;
  END IF;

  -- Update defect image
  UPDATE defect_image
  SET image_url = p_image_url, image_path = p_image_path
  WHERE info_id = v_info_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Defect image for defect % not found', p_defect_id;
  END IF;

EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'update_defect_details failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;


-- ============================================================================
-- DELETE TRANSACTIONS
-- Improvement 2: Rely on ON DELETE CASCADE instead of manual deletes
-- Make sure your foreign keys are defined with ON DELETE CASCADE
-- which they already are in your schema for defects, defect_info, defect_image
-- ============================================================================

CREATE OR REPLACE FUNCTION delete_site(p_site_id UUID)
RETURNS VOID AS $$
BEGIN
  -- Improvement 1: Check site exists before deleting
  IF NOT EXISTS (SELECT 1 FROM site WHERE site_id = p_site_id) THEN
    RAISE EXCEPTION 'Site with id % not found', p_site_id;
  END IF;

  -- Improvement 2: Single delete — CASCADE handles all children automatically
  DELETE FROM site WHERE site_id = p_site_id;

EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'delete_site failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION delete_defect(p_defect_id UUID)
RETURNS VOID AS $$
BEGIN
  -- Improvement 1: Check defect exists before deleting
  IF NOT EXISTS (SELECT 1 FROM defects WHERE defect_id = p_defect_id) THEN
    RAISE EXCEPTION 'Defect with id % not found', p_defect_id;
  END IF;

  -- Improvement 2: Single delete — CASCADE handles defect_info and defect_image
  DELETE FROM defects WHERE defect_id = p_defect_id;

EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'delete_defect failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;


