# Admin Setup Guide

This guide will help you set up the admin functionality for the NBRO Mobile Application.

## Prerequisites

- Supabase project: `https://bazelkzuwxcrmapbuzyp.supabase.co`
- Supabase Dashboard access
- Admin credentials ready

## Step 1: Run the Database Migration

1. Open your Supabase Dashboard: https://supabase.com/dashboard/project/bazelkzuwxcrmapbuzyp
2. Go to **SQL Editor** (left sidebar)
3. Click **New Query**
4. Copy all contents from `supabase_admin_migration.sql`
5. Paste into the SQL Editor
6. Click **Run** (or press Ctrl+Enter)
7. Wait for success message: "Admin Migration Complete!"

### What this migration does:

✅ Creates `profiles` table to store user information (email, full_name, role)
✅ Creates `inspections` table to track inspections separately from sites
✅ Sets up Row Level Security (RLS) policies for admin access
✅ Allows admins to view ALL users and inspections (bypasses RLS user isolation)
✅ Allows officers to only see their own data
✅ Auto-creates profiles when new users sign up
✅ Populates inspections from existing sites data

## Step 2: Create Your Admin User

### Option A: Create New Admin User via Supabase Dashboard

1. In Supabase Dashboard, go to **Authentication** → **Users**
2. Click **Add user** → **Create new user**
3. Enter admin credentials:
   - Email: `admin@nbro.lk` (or your preferred email)
   - Password: (choose a strong password)
   - Check "Auto Confirm User" ✓
4. Click **Create user**
5. **Copy the User ID** (UUID) that appears

### Option B: Use Existing User as Admin

1. In Supabase Dashboard, go to **Authentication** → **Users**
2. Find your existing user
3. **Copy their User ID** (UUID)

### Step 3: Set User as Admin

1. Go to **SQL Editor** in Supabase
2. Run this query (replace `<USER_ID>` with the copied UUID):

```sql
INSERT INTO profiles (id, email, full_name, role)
VALUES (
    '<USER_ID>'::uuid,  -- Replace with actual UUID
    'admin@nbro.lk',    -- Replace with admin email
    'NBRO Administrator',
    'admin'
)
ON CONFLICT (id) 
DO UPDATE SET role = 'admin';
```

Example:
```sql
INSERT INTO profiles (id, email, full_name, role)
VALUES (
    '123e4567-e89b-12d3-a456-426614174000'::uuid,
    'admin@nbro.lk',
    'NBRO Administrator',
    'admin'
)
ON CONFLICT (id) 
DO UPDATE SET role = 'admin';
```

3. Click **Run**
4. You should see "Success. No rows returned"

## Step 4: Verify Setup

Run these verification queries in SQL Editor:

```sql
-- Check profiles table
SELECT * FROM profiles;

-- Check admin users
SELECT id, email, full_name, role 
FROM profiles 
WHERE role = 'admin';

-- Check inspections
SELECT COUNT(*) as inspection_count FROM inspections;

-- Check RLS policies
SELECT schemaname, tablename, policyname 
FROM pg_policies 
WHERE tablename IN ('profiles', 'inspections')
ORDER BY tablename, policyname;
```

Expected results:
- You should see your admin user with `role = 'admin'`
- Inspections should be populated from existing sites
- You should see multiple RLS policies for profiles and inspections

## Step 5: Test Admin Login

1. **Build and run the app:**
   ```bash
   flutter run
   ```

2. **Sign in with admin credentials:**
   - Email: `admin@nbro.lk` (or your admin email)
   - Password: (the password you set)

3. **You should be redirected to Admin Dashboard** with 4 tabs:
   - 📊 Dashboard - Overview stats
   - 👥 Officers - Manage inspection officers
   - 📋 Inspections - View all inspections
   - 👤 Profile - Admin settings

4. **Test admin features:**
   - ✅ View statistics on Dashboard
   - ✅ Create new officer account (Officers tab → Add User)
   - ✅ View all officers and their inspection counts
   - ✅ View all inspections (Inspections tab)
   - ✅ Change admin password (Profile tab)
   - ✅ Remove an officer (Officers tab → Remove button)

## Step 6: Create Officer Accounts

As admin, you can now create officer accounts:

1. Go to **Officers** tab in admin panel
2. Click **➕ Add User** button
3. Fill in officer details:
   - Email: `officer1@nbro.lk`
   - Full Name: `John Doe`
4. Click **Create**
5. **Copy the generated password** and share with the officer
6. Officer can login and change their password later

## Troubleshooting

### Issue: "profiles table does not exist"

**Solution:** Run the migration again. Make sure you copied the entire SQL file.

### Issue: Admin sees no officers

**Solution:** 
1. Check if profiles table has data: `SELECT * FROM profiles;`
2. If empty, officers need to sign in at least once to create their profiles
3. Or manually create profiles for existing auth users

### Issue: Admin cannot see officer inspections

**Solution:**
1. Verify admin role: `SELECT role FROM profiles WHERE id = auth.uid();`
2. Should return `'admin'`
3. If not, run the "Set User as Admin" query again

### Issue: Navigation shows black screen

**Solution:** This is already fixed in the code. Make sure you're running the latest version.

## Security Notes

⚠️ **Important Security Considerations:**

1. **Admin Password**: Choose a strong password for admin account
2. **Officer Password**: Generated passwords are shown only once - make sure to save them
3. **RLS Policies**: Admins can see ALL data - handle admin credentials carefully
4. **Production**: Change default admin email before deploying to production
5. **Supabase Service Role Key**: Keep your service role key secret (needed for admin.createUser)

## Database Schema Overview

```
auth.users (Supabase Auth)
    └── id (UUID)

profiles (NEW)
    ├── id → auth.users.id
    ├── email
    ├── full_name
    └── role ('admin' | 'officer')

inspections (NEW)
    ├── id (UUID)
    ├── site_id → sites.id
    ├── user_id → auth.users.id
    ├── site_name
    ├── site_location
    ├── inspection_date
    └── sync_status

sites (existing)
    └── created_by → auth.users.id

defects (existing)
    └── inspector_id → auth.users.id

defect_media (existing)
    └── created_by → auth.users.id
```

## RLS Policy Summary

| Table | Policy | Who | Access |
|-------|--------|-----|--------|
| profiles | select_all | Everyone | View all profiles |
| profiles | update_own | Users | Update own profile only |
| profiles | admin_all | Admins | Full access to all profiles |
| inspections | select_own | Officers | View own inspections |
| inspections | [CRUD]_own | Officers | Manage own inspections |
| inspections | admin_all | Admins | Full access to all inspections |
| sites, defects, defect_media | admin_all | Admins | Full access for reporting |

## Next Steps

- ✅ Database migration complete
- ✅ Admin user created
- ✅ Admin panel tested
- 📝 Create officer accounts for your team
- 📝 Test full inspection workflow (officer creates site → admin views it)
- 📝 Set up backups in Supabase
- 📝 Configure production environment variables

## Support

If you encounter issues:
1. Check Supabase logs: Dashboard → Logs
2. Check app logs in Flutter console
3. Verify RLS policies are active
4. Ensure Supabase URL and anon key are correct in app

---

**Last Updated:** 2025
**App Version:** NBRO Mobile Application v1.0
