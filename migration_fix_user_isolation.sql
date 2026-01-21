-- Migration: Fix User Isolation
-- This removes the NULL bypass from RLS policies to enforce proper user data isolation
-- Run this AFTER updating the app code to ensure created_by is always set

-- Drop existing RLS policies
DROP POLICY IF EXISTS "Users can only access their own sites" ON sites;
DROP POLICY IF EXISTS "Users can only access their own defects" ON defects;
DROP POLICY IF EXISTS "Users can only access their own defect media" ON defect_media;

-- Recreate sites policy WITHOUT NULL bypass
CREATE POLICY "Users can only access their own sites"
ON sites
FOR ALL
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());

-- Recreate defects policy WITHOUT NULL bypass
CREATE POLICY "Users can only access their own defects"
ON defects
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM sites
    WHERE sites.building_reference_no = defects.building_reference_no
    AND sites.created_by = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM sites
    WHERE sites.building_reference_no = defects.building_reference_no
    AND sites.created_by = auth.uid()
  )
);

-- Recreate defect_media policy WITHOUT NULL bypass
CREATE POLICY "Users can only access their own defect media"
ON defect_media
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM defects d
    JOIN sites s ON s.building_reference_no = d.building_reference_no
    WHERE d.defect_id = defect_media.defect_id
    AND s.created_by = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM defects d
    JOIN sites s ON s.building_reference_no = d.building_reference_no
    WHERE d.defect_id = defect_media.defect_id
    AND s.created_by = auth.uid()
  )
);

-- Update any existing NULL created_by values (optional - only if you want to keep old data)
-- You can either delete old data or assign them to a default user
-- Option 1: Delete inspections with NULL created_by
-- DELETE FROM sites WHERE created_by IS NULL;

-- Option 2: Assign to a specific user (replace with actual user UUID)
-- UPDATE sites SET created_by = '00000000-0000-0000-0000-000000000000' WHERE created_by IS NULL;

-- Verify RLS policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
AND tablename IN ('sites', 'defects', 'defect_media')
ORDER BY tablename, policyname;
