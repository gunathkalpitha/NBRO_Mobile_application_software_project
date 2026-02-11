-- ============================================================================
-- VERIFY INSPECTIONS AND ADMIN ACCESS
-- ============================================================================
-- Run this in Supabase SQL Editor to check if inspections exist and are accessible
-- ============================================================================

-- 1. Check if there are any inspections in the database
SELECT 
    COUNT(*) as total_inspections,
    COUNT(DISTINCT user_id) as unique_officers
FROM inspections;

-- 2. View all inspections with officer details
SELECT 
    i.id,
    i.site_name,
    i.site_location,
    i.inspection_date,
    i.total_defects,
    i.sync_status,
    i.created_at,
    p.full_name as officer_name,
    p.email as officer_email
FROM inspections i
LEFT JOIN profiles p ON p.id = i.user_id
ORDER BY i.inspection_date DESC;

-- 3. Count inspections per officer
SELECT 
    p.full_name,
    p.email,
    p.role,
    COUNT(i.id) as inspection_count
FROM profiles p
LEFT JOIN inspections i ON i.user_id = p.id
WHERE p.role = 'officer'
GROUP BY p.id, p.full_name, p.email, p.role
ORDER BY inspection_count DESC;

-- 4. Verify admin profile exists and is active
SELECT 
    id,
    email,
    full_name,
    role,
    is_active,
    created_at
FROM profiles
WHERE email = 'admin@gmail.com';

-- 5. Test is_admin() function
-- This should return TRUE when you're logged in as admin
SELECT public.is_admin() as am_i_admin;

-- 6. Check RLS policies on inspections table
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
WHERE tablename = 'inspections'
ORDER BY policyname;

-- ============================================================================
-- TROUBLESHOOTING
-- ============================================================================

-- If "No inspections found":
-- - Officers need to create inspections first
-- - Login as an officer and create a test inspection
-- - Inspections are created when officers submit defect forms

-- If "Admin can't see inspections":
-- - Verify is_admin() returns TRUE (query 5 above)
-- - Check admin profile exists with role='admin' (query 4 above)
-- - Verify RLS policy "inspections_admin_all" exists (query 6 above)

-- If officers appear but no inspections:
-- - This is normal if officers haven't created inspections yet
-- - Officers create inspections by:
--   1. Login as officer
--   2. Add new site
--   3. Add defects to site
--   4. Inspection is automatically created

-- ============================================================================
-- EXPECTED RESULTS
-- ============================================================================

-- Query 1: Should show count of total inspections
-- Query 2: Should list all inspections with officer names
-- Query 3: Should show each officer with their inspection count
-- Query 4: Should show admin@gmail.com with role='admin' and is_active=true
-- Query 5: Should return TRUE when logged in as admin
-- Query 6: Should show 5 RLS policies including "inspections_admin_all"
