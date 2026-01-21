# Fix Instructions for UUID Error

## Problem
The application was trying to insert defects with `"H-7"` (building reference number) into a UUID field, causing a PostgreSQL error: `invalid input syntax for type uuid: "H-7"`.

## Root Cause
The database schema had a mismatch with the application code:
- **Database**: Used UUID foreign keys (`defects.site_id` → `sites.id`)
- **Application**: Uses text-based identifiers (`building_reference_no`)

## Solution Applied

### 1. Code Changes (Already Applied)
✅ Updated `Defect.toJson()` to use `defect_id` and `building_reference_no`
✅ Updated `Defect.fromJson()` to match database field names
✅ Updated `InspectionBloc` to reload data after creating inspection
✅ Updated `InspectionRepository.getInspections()` to load defects with each inspection

### 2. Database Migration (YOU NEED TO DO THIS)

**Steps to fix your Supabase database:**

1. **Open Supabase Dashboard**
   - Go to your project at https://supabase.com
   - Navigate to SQL Editor

2. **Run the Migration Script**
   - Open the file: `migration_fix_defects.sql`
   - Copy the entire contents
   - Paste into Supabase SQL Editor
   - Click "Run" to execute

   ⚠️ **Warning**: This will drop and recreate the `defects` and `defect_media` tables. Any existing defect data will be lost.

3. **Verify the Migration**
   After running the script, verify:
   - `defects` table has column `defect_id` (TEXT) instead of `id` (UUID)
   - `defects` table has column `building_reference_no` (TEXT) instead of `site_id` (UUID)
   - Foreign key constraint references `sites(building_reference_no)`

### 3. Flutter App Restart (YOU NEED TO DO THIS)

The code changes won't take effect until you restart the app:

**Option A: Hot Restart (Faster)**
```powershell
# In VS Code, press: Ctrl + Shift + F5
# Or in terminal:
r
```

**Option B: Full Restart**
```powershell
# Stop the current app
flutter run
```

## Verification

After completing all steps, test by:
1. Create a new inspection
2. Add one or more defects
3. Complete the inspection
4. Return to dashboard
5. Verify:
   - ✅ No error message appears
   - ✅ Inspection shows correct defect count
   - ✅ Dashboard loads successfully

## Database Schema Changes Summary

### Before:
```sql
CREATE TABLE defects (
    id UUID PRIMARY KEY,
    site_id UUID NOT NULL,
    FOREIGN KEY (site_id) REFERENCES sites(id)
);
```

### After:
```sql
CREATE TABLE defects (
    defect_id TEXT PRIMARY KEY,
    building_reference_no TEXT NOT NULL,
    FOREIGN KEY (building_reference_no) REFERENCES sites(building_reference_no)
);
```

## Files Modified
- ✅ `lib/domain/models/inspection.dart` - Fixed Defect JSON field names
- ✅ `lib/presentation/state/inspection_bloc.dart` - Added database reload after create
- ✅ `lib/data/repositories/inspection_repository.dart` - Load defects with inspections
- ✅ `supabase_schema.sql` - Updated schema to match application design
- ✅ `migration_fix_defects.sql` - **NEW** - Migration script to run in Supabase

## Next Steps
1. Run the migration script in Supabase SQL Editor
2. Hot restart the Flutter app (Press `r` in the terminal or Ctrl+Shift+F5)
3. Test creating a new inspection with defects
