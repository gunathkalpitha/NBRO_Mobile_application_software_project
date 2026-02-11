-- ============================================================================
-- DIAGNOSE ADMIN INSPECTION ACCESS ISSUE
-- ============================================================================
-- Run this WHILE LOGGED IN AS ADMIN to diagnose the problem
-- ============================================================================

-- TEST 1: Check current user and their auth.uid()
SELECT 
    auth.uid() as my_user_id,
    auth.email() as my_email;

-- TEST 2: Check if current user has admin profile
SELECT 
    id,
    email,
    full_name,
    role,
    is_active
FROM profiles
WHERE id = auth.uid();

-- TEST 3: Test the is_admin() function directly
SELECT public.is_admin() as am_i_admin;

-- TEST 4: Count total inspections in database (bypassing RLS)
-- This requires running with service_role or disabling RLS temporarily
SELECT COUNT(*) as total_inspections FROM inspections;

-- TEST 5: Try to select inspections as admin (this uses RLS)
SELECT 
    id,
    site_name,
    user_id,
    inspection_date,
    created_at
FROM inspections
ORDER BY created_at DESC
LIMIT 5;

-- TEST 6: Check which user owns the inspection
SELECT 
    i.id,
    i.site_name,
    i.user_id,
    p.email as officer_email,
    p.full_name as officer_name
FROM inspections i
LEFT JOIN profiles p ON p.id = i.user_id;

-- TEST 7: Verify RLS policies on inspections
SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'inspections'
ORDER BY policyname;

-- ============================================================================
-- EXPECTED RESULTS WHEN LOGGED IN AS ADMIN
-- ============================================================================
-- TEST 1: Should show your admin user ID and email
-- TEST 2: Should show role='admin' and is_active=true
-- TEST 3: Should return TRUE
-- TEST 4: Should show total count of inspections (e.g., 1)
-- TEST 5: Should show all inspections including officer's inspections
-- TEST 6: Should show inspection with test@gmail.com
-- TEST 7: Should show inspections_admin_all and inspections_select_own policies

-- ============================================================================
-- IF ADMIN CANNOT SEE INSPECTIONS
-- ============================================================================
-- Problem indicators:
-- - TEST 3 returns FALSE or NULL: Admin profile is wrong
-- - TEST 5 returns 0 rows but TEST 4 shows count > 0: RLS policy issue
-- - TEST 2 shows role != 'admin': Profile not set correctly
