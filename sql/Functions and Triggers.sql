CREATE OR REPLACE FUNCTION update_site_location()
RETURNS TRIGGER AS $$
BEGIN
      IF NEW.latitude is NOT NULL AND NEW.longitude IS NOT NULL THEN
      NEW.location = ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_site_location_trigger ON SITE;
CREATE TRIGGER update_site_location_trigger
    BEFORE INSERT OR UPDATE OF latitude, longitude ON site
    FOR EACH ROW
    EXECUTE FUNCTION update_site_location();


CREATE OR REPLACE FUNCTION public.get_user_role(user_id UUID)
RETURNS TEXT AS $$
DECLARE
  user_role TEXT;
BEGIN
  SELECT role INTO user_role
  FROM public.profile
  WHERE id=user_id;
  RETURN user_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
DECLARE 
  user_role TEXT;
  user_active BOOLEAN;
BEGIN
    SELECT role, is_active INTO user_role, user_active
    FROM public.profile
    WHERE id = auth.uid();
    RETURN (user_role = 'admin' AND user_active = true);
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN 
            INSERT INTO public.profile (id, full_name, role, is_active)
       VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', ''),
                COALESCE(NEW.raw_user_meta_data->>'role', 'officer'),
                true
      )
            ON CONFLICT (id) DO UPDATE
            SET full_name = COALESCE(EXCLUDED.full_name, public.profile.full_name),
                    role = COALESCE(EXCLUDED.role, public.profile.role),
                    is_active = true;
      RETURN NEW;
  END;
  $$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


CREATE OR REPLACE FUNCTION public.get_sites_by_officer(p_user_id UUID)
RETURNS TABLE (
    site_id UUID,
    owner_name TEXT,
    address TEXT,
    building_ref TEXT,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.site_id,
        s.owner_name,
        s.address,
        s.building_ref,
        s.created_at
    FROM site s
    WHERE s.user_id = p_user_id
    ORDER BY s.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.insert_full_site(
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
    INSERT INTO public.site (
        user_id,
        owner_name,
        owner_contact,
        building_ref,
        distance_from_row,
        address,
        latitude,
        longitude
    ) VALUES (
        p_user_id,
        p_owner_name,
        p_owner_contact,
        p_building_ref,
        p_distance_from_row,
        p_address,
        p_latitude,
        p_longitude
    )
    RETURNING site_id INTO v_site_id;

    INSERT INTO public.general_observation (site_id, type, present_condition, approx_age)
    VALUES (v_site_id, p_type, p_present_condition, p_approx_age);

    INSERT INTO public.external_services (site_id, pipe_born_water_supply, sewage_waste, electricity_source)
    VALUES (v_site_id, p_pipe_born_water, p_sewage_waste, p_electricity_source);

    INSERT INTO public.main_building (site_id, no_floors)
    VALUES (v_site_id, p_no_floors);

    RETURN v_site_id;
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'insert_full_site failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.insert_defect_with_details(
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
    v_info_id UUID;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.site WHERE site_id = p_site_id) THEN
        RAISE EXCEPTION 'Site with id % not found', p_site_id;
    END IF;

    INSERT INTO public.defects (
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.get_site_summary(p_site_id UUID)
RETURNS TABLE (
    site_id UUID,
    owner_name TEXT,
    address TEXT,
    building_ref TEXT,
    total_defects BIGINT,
    total_defect_images BIGINT,
    has_main_building BOOLEAN,
    has_general_observation BOOLEAN,
    has_external_services BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.site_id,
        s.owner_name,
        s.address,
        s.building_ref,
        COUNT(DISTINCT d.defect_id) as total_defects,
        COUNT(DISTINCT di.image_id) as total_defect_images,
        EXISTS(SELECT 1 FROM main_building mb WHERE mb.site_id = s.site_id) as has_main_building,
        EXISTS(SELECT 1 FROM general_observation go WHERE go.site_id = s.site_id) as has_general_observation,
        EXISTS(SELECT 1 FROM external_services es WHERE es.site_id = s.site_id) as has_external_services
    FROM site s
    LEFT JOIN defects d ON d.site_id = s.site_id
    LEFT JOIN defect_info dfi ON dfi.defect_id = d.defect_id
    LEFT JOIN defect_image di ON di.info_id = dfi.info_id
    WHERE s.site_id = p_site_id
    GROUP BY s.site_id, s.owner_name, s.address, s.building_ref;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;






