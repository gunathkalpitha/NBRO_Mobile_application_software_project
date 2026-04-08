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
      INSERT INTO public.profile (id,full_name,role)
       VALUES (
        NEW.id,
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



