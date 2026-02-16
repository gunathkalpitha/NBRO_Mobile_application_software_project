-- ============================================================================
-- FUNCTIONS AND TRIGGERS
-- ============================================================================
-- This file contains all CREATE FUNCTION, CREATE TRIGGER, and procedural code.

-- Utility functions
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

-- Triggers for updated_at and location
CREATE TRIGGER update_profiles_updated_at 
    BEFORE UPDATE ON profiles
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sites_updated_at 
    BEFORE UPDATE ON sites
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_site_location_trigger
    BEFORE INSERT OR UPDATE OF latitude, longitude ON sites
    FOR EACH ROW
    EXECUTE FUNCTION update_site_location();

CREATE TRIGGER update_defects_updated_at 
    BEFORE UPDATE ON defects
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_inspections_updated_at 
    BEFORE UPDATE ON inspections
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Admin and helper functions
CREATE OR REPLACE FUNCTION public.get_user_role(user_id UUID)
RETURNS TEXT AS $$
DECLARE
    user_role TEXT;
BEGIN
    SELECT role INTO user_role FROM public.profiles WHERE id = user_id;
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
    FROM public.profiles
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

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

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

CREATE TRIGGER update_inspection_counts_on_defect_change
    AFTER INSERT OR UPDATE OR DELETE ON defects
    FOR EACH ROW 
    EXECUTE FUNCTION public.update_inspection_defect_counts();

-- Auto-create inspections from sites
CREATE OR REPLACE FUNCTION public.auto_create_inspection()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO inspections (
        site_id,
        user_id,
        building_reference_no,
        site_name,
        site_location,
        inspection_date,
        total_defects,
        defects_with_photos,
        sync_status
    ) VALUES (
        NEW.id,
        NEW.created_by,
        NEW.building_reference_no,
        NEW.owner_name,
        NEW.site_address,
        CURRENT_DATE,
        0,
        0,
        NEW.sync_status
    )
    ON CONFLICT (building_reference_no) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

ALTER TABLE inspections DROP CONSTRAINT IF EXISTS uk_inspections_building_ref;
ALTER TABLE inspections ADD CONSTRAINT uk_inspections_building_ref 
    UNIQUE (building_reference_no);

DROP TRIGGER IF EXISTS auto_create_inspection_trigger ON sites;
CREATE TRIGGER auto_create_inspection_trigger
    AFTER INSERT ON sites
    FOR EACH ROW 
    EXECUTE FUNCTION public.auto_create_inspection();
