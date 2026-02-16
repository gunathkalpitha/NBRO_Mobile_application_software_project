# Quick Troubleshooting Checklist

## Before Testing

### 1. Code is Updated
```bash
# Verify latest code is in place
cd e:\Projects\software project NBRO\Mobile_Application\nbro_mobile_application
git status  # Should show no critical changes

# Run analysis
flutter analyze
# Expected: "No issues found!"

# Get dependencies
flutter pub get
```

### 2. Edge Function is Deployed
```bash
supabase functions deploy create-officer
# Expected: "Deployed Functions on project bazelkzuwxcrmapbuzyp: create-officer"

# Check function exists in dashboard:
# https://supabase.com/dashboard/project/bazelkzuwxcrmapbuzyp/functions
```

### 3. Environment Variables are Set
```bash
# In Supabase Dashboard → Functions → create-officer → Settings
# Must have:
# SUPABASE_URL = https://bazelkzuwxcrmapbuzyp.supabase.co
# SUPABASE_SERVICE_ROLE_KEY = your-service-role-key (looks like eyJ...)
```

### 4. Database is Ready
```sql
-- Run in Supabase SQL Editor to verify:
SELECT * FROM information_schema.tables 
WHERE table_name IN ('profiles', 'users');
-- Should return 2 rows

SELECT * FROM information_schema.triggers 
WHERE trigger_name = 'handle_new_user';
-- Should return 1 row
```

---

## Testing Steps

### Step 1: Clean Build
```bash
cd e:\Projects\software project NBRO\Mobile_Application\nbro_mobile_application
flutter clean
flutter pub get
flutter run
```

### Step 2: Log In
- Email: admin@gmail.com
- Password: (your password)

### Step 3: Navigate to Officer Management
- After login, find "Manage Officers" screen
- Should load existing officers list

### Step 4: Create Test Officer
1. Click "Add Officer" button
2. Fill form:
   - Email: `testOfficer@example.com`
   - Full Name: `Test Officer`
   - Password: Toggle auto-generate ON
3. Click "Create Officer"
4. Should see success dialog

### Step 5: Verify Success
```sql
-- In Supabase SQL Editor:
SELECT id, email, full_name, role, created_at 
FROM profiles 
WHERE email = 'testOfficer@example.com';

-- Expected:
-- id: a UUID
-- email: testOfficer@example.com
-- full_name: Test Officer
-- role: officer
-- created_at: current timestamp
```

### Step 6: Test Officer Login
1. Log out from admin account
2. Log in with new officer email: `testOfficer@example.com`
3. Password: (from success dialog)
4. Should log in successfully

---

## Common Issues & Fixes

| Issue | Cause | Fix |
|-------|-------|-----|
| 401 Invalid JWT | Using wrong authentication method | Verify code uses `supabase.functions.invoke()` not direct HTTP |
| Officer created but can't log in | Profile not created | Check trigger exists: `SELECT * FROM information_schema.triggers WHERE trigger_name = 'handle_new_user'` |
| CORS Error | Function CORS headers missing | Verify Edge Function has corsHeaders set |
| Server error 500 | SERVICE_ROLE_KEY missing | Add env var in Supabase Functions settings |
| Not logged in error | User session invalid | Log out and log in again in app |

---

## Key Configuration Values

Save these somewhere safe:

```
Supabase Project ID: bazelkzuwxcrmapbuzyp
Supabase URL: https://bazelkzuwxcrmapbuzyp.supabase.co
Anon Key: sb_publishable_5Bnp_FgN1eleESr03wE6tg_ZqrRqptl
Service Role Key: eyJ... (ask team owner)
```

---

## If Still Having Issues

### 1. Check Function Logs
- Go to: https://supabase.com/dashboard/project/bazelkzuwxcrmapbuzyp/functions
- Click "create-officer" function
- Check "Logs" tab for error messages
- Look for lines with `[create-officer]`

### 2. Test Edge Function Directly
```bash
# Using curl (on Windows PowerShell):
$token = 'your-jwt-token'  # Get from app's currentSession
$body = @{
    email = 'test@example.com'
    fullName = 'Test User'
    password = 'Test123456'
} | ConvertTo-Json

Invoke-WebRequest -Uri 'https://bazelkzuwxcrmapbuzyp.supabase.co/functions/v1/create-officer' `
  -Method POST `
  -Headers @{
    'Authorization' = "Bearer $token"
    'Content-Type' = 'application/json'
  } `
  -Body $body
```

### 3. Check Flutter Console
- When creating officer, look for debugPrint messages:
  - `Creating officer: email=...`
  - `Response status: 200`
  - `Officer created successfully`

### 4. Verify Supabase Connection
```bash
# Run in app terminal:
flutter run -v  # Verbose logging
```

---

## Success Indicators

✅ After officer creation:
- [ ] Success dialog appears with email and password
- [ ] Officer appears in list on same screen
- [ ] Can query officer via SQL: `SELECT * FROM profiles WHERE email='...' AND role='officer'`
- [ ] Officer can log in with provided credentials
- [ ] Officer's profile loads correctly

---

## Contact / Notes

If any step fails:
1. Note which step failed
2. Check the error message in Flutter console
3. Review the logs from Edge Function in Supabase Dashboard
4. Compare your implementation with [OFFICER_CREATION_FIX.md](OFFICER_CREATION_FIX.md)
