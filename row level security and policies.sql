ALTER TABLE profile ENABLE ROW LEVEL SECURITY;
ALTER TABLE site ENABLE ROW LEVEL SECURITY;
ALTER TABLE general_observation ENABLE ROW LEVEL SECURITY;
ALTER TABLE external_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE ancillary_building ENABLE ROW LEVEL SECURITY;
ALTER TABLE detail_type ENABLE ROW LEVEL SECURITY;
ALTER TABLE building_detail ENABLE ROW LEVEL SECURITY;
ALTER TABLE main_building ENABLE ROW LEVEL SECURITY;
ALTER TABLE specification ENABLE ROW LEVEL SECURITY;
ALTER TABLE defects ENABLE ROW LEVEL SECURITY;
ALTER TABLE defect_info ENABLE ROW LEVEL SECURITY;
ALTER TABLE defect_image ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profile_select_own" ON profile FOR SELECT USING (id = auth.uid());
CREATE POLICY "profile_update_own" ON profile FOR UPDATE USING (id = auth.uid()) WITH CHECK (id= auth.uid());
CREATE POLICY "profile_insert_own" ON profile FOR INSERT WITH CHECK (id = auth.uid());
CREATE POLICY "profile_admin_all" ON profile FOR ALL USING (public.is_admin());

CREATE POLICY "site_select_own" ON site FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "site_insert_own" ON site FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "site_update_own" ON site FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id= auth.uid());
CREATE POLICY "site_delete_own" ON site FOR DELETE USING (user_id = auth.uid());
CREATE POLICY "site_admin_all" ON site FOR ALL USING (public.is_admin());

CREATE POLICY "general_observation_select" ON general_observation FOR SELECT USING (
    EXISTS (SELECT 1 FROM site WHERE site.site_id = general_observation.site_id AND site.user_id = auth.uid())
);
CREATE POLICY "general_observation_insert" ON general_observation FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM site WHERE site.site_id = general_observation.site_id AND site.user_id = auth.uid())
);
CREATE POLICY "general_observation_update" ON general_observation FOR UPDATE
USING (
    EXISTS (SELECT 1 FROM site WHERE site.site_id = general_observation.site_id AND site.user_id = auth.uid())
)
WITH CHECK (
    EXISTS (SELECT 1 FROM site WHERE site.site_id = general_observation.site_id AND site.user_id = auth.uid())
);
CREATE POLICY "general_observation_delete" ON general_observation FOR DELETE USING (
    EXISTS (SELECT 1 FROM site WHERE site.site_id = general_observation.site_id AND site.user_id = auth.uid())
);
CREATE POLICY "general_observation_admin" ON general_observation FOR ALL USING (public.is_admin());


CREATE POLICY "external_services_select" ON external_services FOR SELECT USING (
    EXISTS (SELECT 1 FROM site WHERE site.site_id = external_services.site_id AND site.user_id = auth.uid())
);
CREATE POLICY "external_services_insert" ON external_services FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM site WHERE site.site_id = external_services.site_id AND site.user_id = auth.uid())
);
CREATE POLICY "external_services_update" ON external_services FOR UPDATE
USING (
    EXISTS (SELECT 1 FROM site WHERE site.site_id = external_services.site_id AND site.user_id = auth.uid())
)
WITH CHECK (
    EXISTS (SELECT 1 FROM site WHERE site.site_id = external_services.site_id AND site.user_id = auth.uid())
);
CREATE POLICY "external_services_delete" ON external_services FOR DELETE USING (
    EXISTS (SELECT 1 FROM site WHERE site.site_id = external_services.site_id AND site.user_id = auth.uid())
);
CREATE POLICY "external_services_admin" ON external_services FOR ALL USING (public.is_admin());


CREATE POLICY "ancillary_building_select" ON ancillary_building FOR SELECT USING (
    EXISTS (SELECT 1 FROM site WHERE site.site_id = ancillary_building.site_id AND site.user_id = auth.uid())
);
CREATE POLICY "ancillary_building_insert" ON ancillary_building FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM site WHERE site.site_id = ancillary_building.site_id AND site.user_id = auth.uid())
);
CREATE POLICY "ancillary_building_update" ON ancillary_building FOR UPDATE
USING (
    EXISTS (SELECT 1 FROM site WHERE site.site_id = ancillary_building.site_id AND site.user_id = auth.uid())
)
WITH CHECK (
    EXISTS (SELECT 1 FROM site WHERE site.site_id = ancillary_building.site_id AND site.user_id = auth.uid())
);
CREATE POLICY "ancillary_building_delete" ON ancillary_building FOR DELETE USING (
    EXISTS (SELECT 1 FROM site WHERE site.site_id = ancillary_building.site_id AND site.user_id = auth.uid())
);
CREATE POLICY "ancillary_building_admin" ON ancillary_building FOR ALL USING (public.is_admin());


CREATE POLICY "main_building_select" ON main_building FOR SELECT USING (
    EXISTS (SELECT 1 FROM site WHERE site.site_id = main_building.site_id AND site.user_id = auth.uid())
);
CREATE POLICY "main_building_insert" ON main_building FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM site WHERE site.site_id = main_building.site_id AND site.user_id = auth.uid())
);
CREATE POLICY "main_building_update" ON main_building FOR UPDATE
USING (
    EXISTS (SELECT 1 FROM site WHERE site.site_id = main_building.site_id AND site.user_id = auth.uid())
)
WITH CHECK (
    EXISTS (SELECT 1 FROM site WHERE site.site_id = main_building.site_id AND site.user_id = auth.uid())
);
CREATE POLICY "main_building_delete" ON main_building FOR DELETE USING (
    EXISTS (SELECT 1 FROM site WHERE site.site_id = main_building.site_id AND site.user_id = auth.uid())
);
CREATE POLICY "main_building_admin" ON main_building FOR ALL USING (public.is_admin());


CREATE POLICY "defects_select" ON defects FOR SELECT USING (
    EXISTS (SELECT 1 FROM site WHERE site.site_id = defects.site_id AND site.user_id = auth.uid())
);
CREATE POLICY "defects_insert" ON defects FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM site WHERE site.site_id = defects.site_id AND site.user_id = auth.uid())
);
CREATE POLICY "defects_update" ON defects FOR UPDATE
USING (
    EXISTS (SELECT 1 FROM site WHERE site.site_id = defects.site_id AND site.user_id = auth.uid())
)
WITH CHECK (
    EXISTS (SELECT 1 FROM site WHERE site.site_id = defects.site_id AND site.user_id = auth.uid())
);
CREATE POLICY "defects_delete" ON defects FOR DELETE USING (
    EXISTS (SELECT 1 FROM site WHERE site.site_id = defects.site_id AND site.user_id = auth.uid())
);
CREATE POLICY "defects_admin" ON defects FOR ALL USING (public.is_admin());



CREATE POLICY "detail_type_select" ON detail_type FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM ancillary_building ab
        JOIN site ON site.site_id = ab.site_id
        WHERE ab.structure_id = detail_type.structure_id AND site.user_id = auth.uid()
    )
);
CREATE POLICY "detail_type_insert" ON detail_type FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM ancillary_building ab
        JOIN site ON site.site_id = ab.site_id
        WHERE ab.structure_id = detail_type.structure_id AND site.user_id = auth.uid()
    )
);
CREATE POLICY "detail_type_update" ON detail_type FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM ancillary_building ab
        JOIN site ON site.site_id = ab.site_id
        WHERE ab.structure_id = detail_type.structure_id AND site.user_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM ancillary_building ab
        JOIN site ON site.site_id = ab.site_id
        WHERE ab.structure_id = detail_type.structure_id AND site.user_id = auth.uid()
    )
);
CREATE POLICY "detail_type_delete" ON detail_type FOR DELETE USING (
    EXISTS( SELECT 1 FROM ancillary_building ab
            JOIN site ON site.site_id=ab.site_id
            WHERE ab.structure_id = detail_type.structure_id AND site.user_id=auth.uid()
          )
);
CREATE POLICY "detail_type_admin" ON detail_type FOR ALL USING (public.is_admin());


-- Building detail (goes through detail_type → ancillary_building)
CREATE POLICY "building_detail_select" ON building_detail FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM detail_type dt
        JOIN ancillary_building ab ON ab.structure_id = dt.structure_id
        JOIN site ON site.site_id = ab.site_id
        WHERE dt.detail_type_id = building_detail.detail_type_id AND site.user_id = auth.uid()
    )
);
CREATE POLICY "building_detail_insert" ON building_detail FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM detail_type dt
        JOIN ancillary_building ab ON ab.structure_id = dt.structure_id
        JOIN site ON site.site_id = ab.site_id
        WHERE dt.detail_type_id = building_detail.detail_type_id AND site.user_id = auth.uid()
    )
);
CREATE POLICY "building_detail_update" ON building_detail FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM detail_type dt
        JOIN ancillary_building ab ON ab.structure_id = dt.structure_id
        JOIN site ON site.site_id = ab.site_id
        WHERE dt.detail_type_id = building_detail.detail_type_id AND site.user_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM detail_type dt
        JOIN ancillary_building ab ON ab.structure_id = dt.structure_id
        JOIN site ON site.site_id = ab.site_id
        WHERE dt.detail_type_id = building_detail.detail_type_id AND site.user_id = auth.uid()
    )
);
CREATE POLICY "building_detail_delete" ON building_detail FOR DELETE USING(
    EXISTS(SELECT 1 FROM detail_type dt
           JOIN ancillary_building ab ON ab.structure_id=dt.structure_id
           JOIN site ON site.site_id=ab.site_id
           WHERE dt.detail_type_id=building_detail.detail_type_id AND site.user_id=auth.uid()
    )
);
CREATE POLICY "building_detail_admin" ON building_detail FOR ALL USING (public.is_admin());

-- Specification (goes through main_building)
CREATE POLICY "specification_select" ON specification FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM main_building mb
        JOIN site ON site.site_id = mb.site_id
        WHERE mb.building_id = specification.building_id AND site.user_id = auth.uid()
    )
);
CREATE POLICY "specification_insert" ON specification FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM main_building mb
        JOIN site ON site.site_id = mb.site_id
        WHERE mb.building_id = specification.building_id AND site.user_id = auth.uid()
    )
);
CREATE POLICY "specification_update" ON specification FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM main_building mb
        JOIN site ON site.site_id = mb.site_id
        WHERE mb.building_id = specification.building_id AND site.user_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM main_building mb
        JOIN site ON site.site_id = mb.site_id
        WHERE mb.building_id = specification.building_id AND site.user_id = auth.uid()
    )
);
CREATE POLICY "specification_delete" ON specification FOR DELETE USING (
    EXISTS (
        SELECT 1 FROM main_building mb
        JOIN site ON site.site_id = mb.site_id
        WHERE mb.building_id = specification.building_id AND site.user_id = auth.uid()
    )
);
CREATE POLICY "specification_admin" ON specification FOR ALL USING (public.is_admin());

-- Defect info (goes through defects)
CREATE POLICY "defect_info_select" ON defect_info FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM defects d
        JOIN site ON site.site_id = d.site_id
        WHERE d.defect_id = defect_info.defect_id AND site.user_id = auth.uid()
    )
);
CREATE POLICY "defect_info_insert" ON defect_info FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM defects d
        JOIN site ON site.site_id = d.site_id
        WHERE d.defect_id = defect_info.defect_id AND site.user_id = auth.uid()
    )
);
CREATE POLICY "defect_info_update" ON defect_info FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM defects d
        JOIN site ON site.site_id = d.site_id
        WHERE d.defect_id = defect_info.defect_id AND site.user_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM defects d
        JOIN site ON site.site_id = d.site_id
        WHERE d.defect_id = defect_info.defect_id AND site.user_id = auth.uid()
    )
);
CREATE POLICY "defect_info_delete" ON defect_info FOR DELETE USING (
    EXISTS( SELECT 1 FROM defects d
            JOIN site ON d.site_id=site.site_id
            WHERE d.defect_id=defect_info.defect_id AND site.user_id=auth.uid())
);
CREATE POLICY "defect_info_admin" ON defect_info FOR ALL USING (public.is_admin());

-- Defect image (goes through defect_info → defects)
CREATE POLICY "defect_image_select" ON defect_image FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM defect_info dfi
        JOIN defects d ON d.defect_id = dfi.defect_id
        JOIN site ON site.site_id = d.site_id
        WHERE dfi.info_id = defect_image.info_id AND site.user_id = auth.uid()
    )
);
CREATE POLICY "defect_image_insert" ON defect_image FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM defect_info dfi
        JOIN defects d ON d.defect_id = dfi.defect_id
        JOIN site ON site.site_id = d.site_id
        WHERE dfi.info_id = defect_image.info_id AND site.user_id = auth.uid()
    )
);
CREATE POLICY "defect_image_update" ON defect_image FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM defect_info dfi
        JOIN defects d ON d.defect_id = dfi.defect_id
        JOIN site ON site.site_id = d.site_id
        WHERE dfi.info_id = defect_image.info_id AND site.user_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM defect_info dfi
        JOIN defects d ON d.defect_id = dfi.defect_id
        JOIN site ON site.site_id = d.site_id
        WHERE dfi.info_id = defect_image.info_id AND site.user_id = auth.uid()
    )
);
CREATE POLICY "defect_image_delete" ON defect_image FOR DELETE USING (
    EXISTS (
        SELECT 1 FROM defect_info dfi
        JOIN defects d ON d.defect_id = dfi.defect_id
        JOIN site ON site.site_id = d.site_id
        WHERE dfi.info_id = defect_image.info_id AND site.user_id = auth.uid()
    )
);
CREATE POLICY "defect_image_admin" ON defect_image FOR ALL USING (public.is_admin());


GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
