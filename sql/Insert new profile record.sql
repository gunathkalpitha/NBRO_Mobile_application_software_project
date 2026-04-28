BEGIN;

INSERT INTO profile(id, full_name, role, email)
VALUES(
  'cc8eefc8-6473-43a7-8530-f5f9202f3581',
  'Government Officer',
  'admin',
  'officer@gov.lk'
)
ON CONFLICT (id) DO NOTHING;
COMMIT;

BEGIN;

INSERT INTO site (
  user_id,
  owner_name,
  owner_contact,
  location,
  building_ref,
  distance_from_row,
  address
)
VALUES (
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

INSERT INTO general_observation (site_id, type, present_condition, approx_age)
VALUES (
  '2d8d26f5-290d-4895-b4f6-8b4dc2e7d7e7',
  'Structural',
  'Good',
  '10-15 years'
);

COMMIT;

BEGIN;

INSERT INTO external_services (site_id, pipe_born_water_supply, sewage_waste, electricity_source)
VALUES (
  '2d8d26f5-290d-4895-b4f6-8b4dc2e7d7e7',
  'Available',
  'Connected',
  'Grid'
);

COMMIT;

BEGIN;

WITH new_building AS (
  INSERT INTO main_building (site_id, no_floors)
  VALUES (
    '2d8d26f5-290d-4895-b4f6-8b4dc2e7d7e7',
    '3'
  )
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
  VALUES (
    '2d8d26f5-290d-4895-b4f6-8b4dc2e7d7e7',
    'Garage'
  )
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

WITH new_defect AS (
  INSERT INTO defects (site_id)
  VALUES (
    '2d8d26f5-290d-4895-b4f6-8b4dc2e7d7e7'
  )
  RETURNING defect_id
),
new_defect_info AS (
  INSERT INTO defect_info (defect_id, remarks, length, width)
  SELECT defect_id, 'Crack near window', '1.5m', '0.2m'
  FROM new_defect
  RETURNING info_id
)
INSERT INTO defect_image (info_id, image_url, image_path)
SELECT info_id, 'http://example.com/defect.jpg', '/images/defect.jpg'
FROM new_defect_info;

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
        -- check sections_status flags
        COALESCE((s.sections_status->>'general_observation')::boolean, false),
        COALESCE((s.sections_status->>'external_services')::boolean, false),
        COALESCE((s.sections_status->>'main_building')::boolean, false),
        COALESCE((s.sections_status->>'ancillary_building')::boolean, false),
        COALESCE((s.sections_status->>'defects')::boolean, false),
        -- is fully complete only if all sections are done
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
  p_remarks TEXT,
  p_length TEXT,
  p_width TEXT,
  p_image_url TEXT,
  p_image_path TEXT
)
RETURNS UUID AS $$
DECLARE
  v_defect_id UUID;
  v_info_id UUID;
BEGIN
  -- Check site exists
  IF NOT EXISTS (SELECT 1 FROM site WHERE site_id = p_site_id) THEN
    RAISE EXCEPTION 'Site with id % not found', p_site_id;
  END IF;

  INSERT INTO defects (site_id)
  VALUES (p_site_id)
  RETURNING defect_id INTO v_defect_id;

  INSERT INTO defect_info (defect_id, remarks, length, width)
  VALUES (v_defect_id, p_remarks, p_length, p_width)
  RETURNING info_id INTO v_info_id;

  INSERT INTO defect_image (info_id, image_url, image_path)
  VALUES (v_info_id, p_image_url, p_image_path);

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


