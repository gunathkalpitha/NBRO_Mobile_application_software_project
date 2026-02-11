# EDGE FUNCTION SETUP GUIDE

This guide shows how to deploy the Edge Function for creating officer accounts securely.

## Prerequisites
- Supabase CLI installed: `npm install -g supabase`
- Supabase project linked

## Step 1: Link Your Supabase Project

```bash
# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref bazelkzuwxcrmapbuzyp
```

## Step 2: Deploy the Edge Function

```bash
# Navigate to your project root
cd "e:\Projects\software project NBRO\Mobile_Application\nbro_mobile_application"

# Deploy the create-officer function
supabase functions deploy create-officer
```

## Step 3: Run the SQL Migration

1. Go to Supabase Dashboard: https://supabase.com/dashboard/project/bazelkzuwxcrmapbuzyp
2. Navigate to **SQL Editor**
3. Open the file `fix_admin_profile.sql`
4. Copy all content and paste into SQL Editor
5. Click **Run** to execute

This will:
- Ensure admin@gmail.com has admin role
- Create profiles for any existing auth users
- Display all profiles for verification

## Step 4: Test the Edge Function

You can test the function manually:

```bash
curl -i --location --request POST \
  'https://bazelkzuwxcrmapbuzyp.supabase.co/functions/v1/create-officer' \
  --header 'Authorization: Bearer YOUR_SUPABASE_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --data '{"email":"test@example.com","fullName":"Test Officer","password":"test123"}'
```

## Step 5: Update Flutter App

The Flutter app has been updated to call this edge function automatically when creating officers.

## Edge Function Features

✅ **Secure**: Uses service_role key on backend only
✅ **Automatic**: Creates both auth user and profile
✅ **Validated**: Checks email format and password strength
✅ **Error Handling**: Cleans up on failure
✅ **CORS Enabled**: Works from Flutter mobile app

## Troubleshooting

### Function not found
- Ensure you've deployed: `supabase functions deploy create-officer`
- Check function list: `supabase functions list`

### Authentication error
- Verify your anon key in Flutter app
- Check RLS policies allow the operation

### Profile creation fails
- Run fix_admin_profile.sql to ensure admin has profile
- Check profiles table RLS policies

## Alternative: Manual Creation

If you prefer manual creation:
1. Go to Supabase Dashboard → Authentication → Users
2. Click "Add user" → "Create new user"
3. Enter email and password
4. Check "Auto Confirm User"  
5. Click "Create user"
6. The profile will be auto-created by the handle_new_user() trigger

## Security Notes

⚠️ **NEVER** expose service_role key in mobile app
✅ **ALWAYS** use Edge Functions for admin operations
✅ **ALWAYS** validate inputs on backend
