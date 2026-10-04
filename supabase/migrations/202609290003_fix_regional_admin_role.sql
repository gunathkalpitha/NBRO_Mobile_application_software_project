-- 1. Add missing created_by column to profile table
ALTER TABLE IF EXISTS public.profile
ADD COLUMN IF NOT EXISTS created_by UUID;

-- 2. Update existing admin profiles
UPDATE public.profile
SET role = 'admin'
WHERE id IN (
    SELECT id FROM auth.users
    WHERE email = 'mainadminnbro@gmail.com'
       OR email = 'admin@gmail.com'
       OR email LIKE 'admin.%'
);

-- 3. Notify Schema Reload
NOTIFY pgrst, 'reload schema';
