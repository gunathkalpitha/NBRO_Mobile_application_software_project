-- ============================================
-- POPULATE INSPECTIONS TABLE FROM EXISTING SITES
-- ============================================
-- This script creates inspection records from existing sites
-- so they appear in the Admin Inspection Management page

-- Run this in Supabase Dashboard → SQL Editor

-- First, check what's currently in the inspections table
SELECT COUNT(*) as current_inspection_count FROM public.inspections;

-- Show all sites that don't have an inspection record yet
SELECT 
  s.id as site_id,
  s.building_reference_no,
  s.owner_name,
  s.site_address,
  s.created_by,
  s.created_at,
  COUNT(d.defect_id) as total_defects,
  COUNT(d.photo_url) FILTER (WHERE d.photo_url IS NOT NULL) as defects_with_photos
FROM public.sites s
LEFT JOIN public.defects d ON s.building_reference_no = d.building_reference_no
WHERE NOT EXISTS (
  SELECT 1 FROM public.inspections i 
  WHERE i.building_reference_no = s.building_reference_no
)
GROUP BY s.id, s.building_reference_no, s.owner_name, s.site_address, s.created_by, s.created_at
ORDER BY s.created_at DESC;

-- Insert missing inspection records
INSERT INTO public.inspections (
  site_id,
  user_id,
  building_reference_no,
  site_name,
  site_location,
  inspection_date,
  total_defects,
  defects_with_photos,
  sync_status,
  created_at,
  updated_at
)
SELECT 
  s.id as site_id,
  s.created_by as user_id,
  s.building_reference_no,
  s.owner_name as site_name,
  s.site_address as site_location,
  s.created_at::date as inspection_date,
  COUNT(d.defect_id) as total_defects,
  COUNT(d.photo_url) FILTER (WHERE d.photo_url IS NOT NULL) as defects_with_photos,
  s.sync_status,
  s.created_at,
  s.updated_at
FROM public.sites s
LEFT JOIN public.defects d ON s.building_reference_no = d.building_reference_no
WHERE NOT EXISTS (
  SELECT 1 FROM public.inspections i 
  WHERE i.building_reference_no = s.building_reference_no
)
GROUP BY s.id, s.building_reference_no, s.owner_name, s.site_address, s.created_by, s.created_at, s.sync_status, s.updated_at;

-- Verify the results
SELECT 
  i.id,
  i.building_reference_no,
  i.site_name,
  i.site_location,
  i.inspection_date,
  i.total_defects,
  i.defects_with_photos,
  p.email as officer_email,
  p.full_name as officer_name
FROM public.inspections i
LEFT JOIN public.profiles p ON i.user_id = p.id
ORDER BY i.created_at DESC;

-- Show summary
SELECT 
  'Total inspections' as metric,
  COUNT(*) as count
FROM public.inspections
UNION ALL
SELECT 
  'Total sites' as metric,
  COUNT(*) as count
FROM public.sites
UNION ALL
SELECT 
  'Total defects' as metric,
  COUNT(*) as count
FROM public.defects;
