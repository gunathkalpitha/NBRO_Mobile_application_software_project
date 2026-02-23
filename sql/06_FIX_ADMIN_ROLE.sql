-- ============================================
-- FIX ADMIN ROLE - Run this in Supabase Dashboard
-- ============================================
-- Go to: Supabase Dashboard → SQL Editor → New Query
-- Paste this ENTIRE script and click RUN

-- Step 1: Check what's currently in the profiles table
SELECT 
  id, 
  email, 
  role, 
  is_active, 
  created_at 
FROM public.profiles 
ORDER BY created_at DESC;

-- Step 2: Find your admin user from auth.users and fix the profile
-- IMPORTANT: Replace 'your.admin@email.com' with your ACTUAL admin email
DO $$
DECLARE
  admin_user_id UUID;
  admin_email TEXT := 'admin@gmail.com';  -- <-- CHANGE THIS TO YOUR EMAIL
BEGIN
  -- Find the user ID
  SELECT id INTO admin_user_id 
  FROM auth.users 
  WHERE email = admin_email;
  
  IF admin_user_id IS NULL THEN
    RAISE EXCEPTION 'User with email % not found in auth.users', admin_email;
  ELSE
    RAISE NOTICE 'Found user ID: %', admin_user_id;
    
    -- Insert or update the profile
    INSERT INTO public.profiles (
      id, 
      email, 
      role, 
      is_active, 
      full_name, 
      created_at, 
      updated_at
    ) VALUES (
      admin_user_id,
      admin_email,
      'admin',
      true,
      'System Administrator',
      NOW(),
      NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
      role = 'admin',
      is_active = true,
      email = admin_email,
      updated_at = NOW();
    
    RAISE NOTICE 'SUCCESS: Admin profile updated for email: %', admin_email;
  END IF;
END $$;

-- Step 3: Verify the fix worked
SELECT 
  id, 
  email, 
  role, 
  is_active 
FROM public.profiles 
WHERE role = 'admin';

-- Step 4: Check is_admin() function works
-- (This will only work AFTER you login with the admin account)
-- SELECT public.is_admin();
