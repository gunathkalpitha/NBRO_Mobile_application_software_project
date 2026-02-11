-- ============================================================================
-- FIX ADMIN PROFILE AND MISSING USER PROFILES
-- ============================================================================
-- Run this in Supabase SQL Editor to fix missing profiles
-- ============================================================================

-- 1. Ensure admin@gmail.com has a profile with admin role
INSERT INTO public.profiles (id, email, full_name, role, is_active)
SELECT 
    id,
    email,
    COALESCE(raw_user_meta_data->>'full_name', 'Administrator'),
    'admin',
    true
FROM auth.users
WHERE email = 'admin@gmail.com'
ON CONFLICT (id) DO UPDATE
SET 
    role = 'admin',
    is_active = true,
    full_name = COALESCE(EXCLUDED.full_name, profiles.full_name);

-- 2. Create profiles for any auth users that don't have one yet
INSERT INTO public.profiles (id, email, full_name, role, is_active)
SELECT 
    u.id,
    u.email,
    COALESCE(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'name', 'Officer'),
    COALESCE(u.raw_user_meta_data->>'role', 'officer'),
    true
FROM auth.users u
WHERE NOT EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = u.id
)
AND u.email != 'admin@gmail.com';

-- 3. Verify the results
SELECT 
    p.email,
    p.full_name,
    p.role,
    p.is_active,
    p.created_at
FROM public.profiles p
ORDER BY p.role DESC, p.created_at;
