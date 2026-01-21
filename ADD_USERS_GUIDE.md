# How to Add Users to Supabase Authentication

## Step 1: Go to Supabase Dashboard

1. Open https://supabase.com
2. Select your project (NBRO_Project)

## Step 2: Navigate to Authentication

1. Click **Authentication** in the left sidebar
2. Click **Users** tab

## Step 3: Add New User

1. Click the **Add user** button (top right)
2. Choose **Create new user**

## Step 4: Fill in User Details

Enter the following information:

- **Email**: `surveyor@nbro.gov.lk` (or any email you want)
- **Password**: `yourpassword123` (choose a secure password)
- **Auto Confirm User**: Toggle this **ON** ✅ (so user can login immediately)

Click **Create user**

## Step 5: Verify User Created

You should see the new user in the users list with:
- Email address
- Created date
- Status: Confirmed ✅

## Step 6: Test Login in App

1. Hot restart your Flutter app (press `R`)
2. On the login screen, enter:
   - Email: `surveyor@nbro.gov.lk`
   - Password: `yourpassword123`
3. Click **Sign In**
4. You should be logged in successfully! ✅

## Adding Multiple Users

Repeat steps 3-5 for each user you want to add. Example users:

**User 1: Field Surveyor**
- Email: `surveyor@nbro.gov.lk`
- Password: `Surveyor@2026`

**User 2: Site Inspector**
- Email: `inspector@nbro.gov.lk`
- Password: `Inspector@2026`

**User 3: Admin**
- Email: `admin@nbro.gov.lk`
- Password: `Admin@2026`

## Important Notes

⚠️ **Password Requirements:**
- Minimum 6 characters (Supabase default)
- Use strong passwords for production

⚠️ **Auto Confirm User:**
- Must be toggled ON for users to login immediately
- Without this, users would need to confirm their email first

✅ **No Signup Feature:**
- Users can only be added by you in the Supabase dashboard
- The app only has login functionality (no signup form)

## Troubleshooting

**If login fails:**
1. Check user is "Confirmed" in Supabase dashboard
2. Verify email is correct (no extra spaces)
3. Password is case-sensitive
4. Check Flutter console for error messages

**To reset a user's password:**
1. Go to Authentication → Users
2. Click on the user
3. Click **Reset Password**
4. Enter new password
5. Click **Update**
