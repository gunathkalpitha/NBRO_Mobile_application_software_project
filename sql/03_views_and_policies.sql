-- ============================================================================
-- VIEWS AND POLICIES
-- ============================================================================
-- This file contains all CREATE VIEW, RLS, and policy statements.

-- VIEWS
CREATE VIEW sites_with_defect_count AS
SELECT 
    s.*,
    COUNT(d.defect_id) as total_defects,
    COUNT(CASE WHEN d.photo_path IS NOT NULL THEN 1 END) as defects_with_photos
FROM sites s
LEFT JOIN defects d ON s.building_reference_no = d.building_reference_no
GROUP BY s.id;

CREATE VIEW defects_with_media AS
SELECT 
    d.*,
    s.site_address,
    COUNT(dm.id) as media_count,
    ARRAY_AGG(dm.storage_url) FILTER (WHERE dm.storage_url IS NOT NULL) as photo_urls
FROM defects d
JOIN sites s ON d.building_reference_no = s.building_reference_no
LEFT JOIN defect_media dm ON d.defect_id = dm.defect_id
GROUP BY d.defect_id, d.building_reference_no, s.site_address;

CREATE VIEW inspection_details AS
SELECT 
    s.id as site_uuid,
    s.building_reference_no,
    s.owner_name,
    s.site_address,
    s.latitude,
    s.longitude,
    s.sync_status,
    s.created_at as site_created_at,
    d.defect_id,
    d.notation,
    d.defect_category,
    d.floor_level,
    d.length_mm,
    d.width_mm,
    d.remarks as defect_remarks,
    COUNT(dm.id) as photo_count
FROM sites s
LEFT JOIN defects d ON s.building_reference_no = d.building_reference_no
LEFT JOIN defect_media dm ON d.defect_id = dm.defect_id
GROUP BY s.id, d.defect_id;

CREATE VIEW admin_officer_stats AS
SELECT 
    p.id,
    p.email,
    p.full_name,
    p.phone,
    p.department,
    p.is_active,
    p.created_at,
    COUNT(DISTINCT i.id) as total_inspections,
    COUNT(DISTINCT s.id) as total_sites,
    COUNT(DISTINCT d.defect_id) as total_defects,
    MAX(i.created_at) as last_inspection_date
FROM profiles p
LEFT JOIN inspections i ON i.user_id = p.id
LEFT JOIN sites s ON s.created_by = p.id
LEFT JOIN defects d ON d.building_reference_no = s.building_reference_no
WHERE p.role = 'officer'
GROUP BY p.id
ORDER BY p.created_at DESC;

-- RLS and POLICIES
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE defects ENABLE ROW LEVEL SECURITY;
ALTER TABLE defect_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select_all" ON profiles FOR SELECT USING (true);
CREATE POLICY "profiles_update_own" ON profiles FOR UPDATE USING (id = auth.uid());
CREATE POLICY "profiles_insert_own" ON profiles FOR INSERT WITH CHECK (id = auth.uid());
CREATE POLICY "profiles_admin_all" ON profiles FOR ALL USING (public.is_admin());

CREATE POLICY "sites_select_policy" ON sites FOR SELECT USING (created_by = auth.uid());
CREATE POLICY "sites_insert_policy" ON sites FOR INSERT WITH CHECK (created_by = auth.uid());
CREATE POLICY "sites_update_policy" ON sites FOR UPDATE USING (created_by = auth.uid());
CREATE POLICY "sites_delete_policy" ON sites FOR DELETE USING (created_by = auth.uid());
CREATE POLICY "sites_admin_all" ON sites FOR ALL USING (public.is_admin());

CREATE POLICY "defects_select_policy" ON defects FOR SELECT USING (
    EXISTS (SELECT 1 FROM sites WHERE sites.building_reference_no = defects.building_reference_no AND sites.created_by = auth.uid())
);
CREATE POLICY "defects_insert_policy" ON defects FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM sites WHERE sites.building_reference_no = defects.building_reference_no AND sites.created_by = auth.uid())
);
CREATE POLICY "defects_update_policy" ON defects FOR UPDATE USING (
    EXISTS (SELECT 1 FROM sites WHERE sites.building_reference_no = defects.building_reference_no AND sites.created_by = auth.uid())
);
CREATE POLICY "defects_delete_policy" ON defects FOR DELETE USING (
    EXISTS (SELECT 1 FROM sites WHERE sites.building_reference_no = defects.building_reference_no AND sites.created_by = auth.uid())
);
CREATE POLICY "defects_admin_all" ON defects FOR ALL USING (public.is_admin());

CREATE POLICY "media_select_policy" ON defect_media FOR SELECT USING (
    EXISTS (SELECT 1 FROM sites WHERE sites.building_reference_no = defect_media.building_reference_no AND sites.created_by = auth.uid())
);
CREATE POLICY "media_insert_policy" ON defect_media FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM sites WHERE sites.building_reference_no = defect_media.building_reference_no AND sites.created_by = auth.uid())
);
CREATE POLICY "media_update_policy" ON defect_media FOR UPDATE USING (
    EXISTS (SELECT 1 FROM sites WHERE sites.building_reference_no = defect_media.building_reference_no AND sites.created_by = auth.uid())
);
CREATE POLICY "media_delete_policy" ON defect_media FOR DELETE USING (
    EXISTS (SELECT 1 FROM sites WHERE sites.building_reference_no = defect_media.building_reference_no AND sites.created_by = auth.uid())
);
CREATE POLICY "media_admin_all" ON defect_media FOR ALL USING (public.is_admin());

CREATE POLICY "inspections_select_own" ON inspections FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "inspections_insert_own" ON inspections FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "inspections_update_own" ON inspections FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "inspections_delete_own" ON inspections FOR DELETE USING (user_id = auth.uid());
CREATE POLICY "inspections_admin_select" ON inspections FOR SELECT USING (public.is_admin());
CREATE POLICY "inspections_admin_insert" ON inspections FOR INSERT WITH CHECK (public.is_admin());
CREATE POLICY "inspections_admin_update" ON inspections FOR UPDATE USING (public.is_admin());
CREATE POLICY "inspections_admin_delete" ON inspections FOR DELETE USING (public.is_admin());

GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT ON profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
