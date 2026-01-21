# User Isolation Fix - Implementation Guide

## Problem
Users can see each other's inspections because the `created_by` field in the database is always NULL. This happens because:
1. The Inspection model didn't have a `createdBy` field
2. The repository wasn't capturing the current user's ID when creating inspections
3. RLS policies had a NULL bypass clause (`OR created_by IS NULL`)

## Changes Made

### ✅ Code Changes (Completed)

#### 1. Updated Inspection Model
**File:** `lib/domain/models/inspection.dart`

Added `createdBy` field to track the user who created each inspection:
- Added `final String? createdBy;` property
- Updated constructor to accept `createdBy` parameter
- Updated `copyWith` method to include `createdBy`
- Updated `toJson` to include `'created_by': createdBy`
- Updated `fromJson` to read `createdBy: json['created_by']`

#### 2. Updated Repository
**File:** `lib/data/repositories/inspection_repository.dart`

Modified `createInspection` method to capture and set the current user's ID:
```dart
// Get current user ID
final currentUser = _supabase.auth.currentUser;
if (currentUser == null) {
  throw Exception('No authenticated user found');
}

// Add user ID to inspection
final inspectionWithUser = inspection.copyWith(
  createdBy: currentUser.id,
);
```

### ⚠️ Database Migration Required

#### 3. Update RLS Policies
**File:** `migration_fix_user_isolation.sql`

This migration script removes the NULL bypass from RLS policies. **You must run this SQL script in your Supabase SQL Editor:**

1. Go to Supabase Dashboard → SQL Editor
2. Copy the contents of `migration_fix_user_isolation.sql`
3. Run the script

**What it does:**
- Removes old RLS policies that allowed NULL `created_by` values
- Creates new strict policies that enforce `created_by = auth.uid()`
- Applies to `sites`, `defects`, and `defect_media` tables

**Important:** Run this AFTER deploying the updated app code, or existing inspections won't be accessible.

## Testing Steps

### 1. Clean Test (Recommended)
```sql
-- Delete old test data without created_by
DELETE FROM sites WHERE created_by IS NULL;
```

### 2. Create Test Users
Create two test accounts in Supabase:
- test1@example.com
- test2@example.com

### 3. Test Isolation
1. Login as test1@example.com
2. Create an inspection (e.g., H-TEST-001)
3. Log out and login as test2@example.com
4. Verify you **cannot** see H-TEST-001
5. Create a different inspection (e.g., H-TEST-002)
6. Log out and login back as test1@example.com
7. Verify you only see H-TEST-001 (not H-TEST-002)

## Expected Behavior After Fix

### Before (Current Behavior - BUG)
- User1 logs in, creates inspection H-001
- User2 logs in, sees inspection H-001 created by User1 ❌

### After (Fixed Behavior)
- User1 logs in, creates inspection H-001 with `created_by = user1_uuid`
- User2 logs in, sees ZERO inspections (cannot see User1's data) ✅
- User2 creates inspection H-002 with `created_by = user2_uuid`
- User1 still only sees H-001 ✅

## How It Works

### Authentication Flow
1. User logs in with Supabase Auth
2. Supabase creates an auth session with user UUID
3. User creates inspection via the app
4. Repository captures `Supabase.instance.client.auth.currentUser.id`
5. Inspection is saved with `created_by = <user_uuid>`

### Database Query Flow
1. User queries inspections (no explicit filtering needed)
2. Supabase RLS automatically applies `WHERE created_by = auth.uid()`
3. Only inspections created by the logged-in user are returned
4. Other users' data is completely invisible

### RLS Policy Example
```sql
CREATE POLICY "Users can only access their own sites"
ON sites
FOR ALL
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());
```

This policy ensures:
- `USING`: Users can only SELECT rows where `created_by` matches their UUID
- `WITH CHECK`: Users can only INSERT/UPDATE rows with their own UUID

## Troubleshooting

### "No authenticated user found" Error
**Cause:** User is not logged in
**Fix:** Ensure user goes through login screen before creating inspections

### Old Inspections Disappear
**Cause:** Existing inspections have NULL `created_by`
**Fix:** Either:
1. Delete old test data (recommended for development)
2. Assign old data to a specific user:
```sql
UPDATE sites SET created_by = '<your_user_uuid>' WHERE created_by IS NULL;
```

### User Still Sees Other Users' Data
**Cause:** RLS policies not applied yet
**Fix:** Run the `migration_fix_user_isolation.sql` script in Supabase

## Verification

To verify the fix is working, check the database:

```sql
-- Check that all new inspections have created_by set
SELECT building_reference_no, owner_name, created_by, created_at
FROM sites
ORDER BY created_at DESC;

-- Verify RLS policies are active
SELECT tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE schemaname = 'public'
AND tablename IN ('sites', 'defects', 'defect_media');
```

## Summary

✅ **Completed:**
- Added `createdBy` field to Inspection model
- Updated repository to capture current user ID
- Created migration script to update RLS policies

⚠️ **Next Step:**
- **Run `migration_fix_user_isolation.sql` in Supabase SQL Editor**

This fix ensures complete data isolation between users using Supabase's built-in Row Level Security (RLS) system.
