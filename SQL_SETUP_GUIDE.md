# 🗑️ Fix Database Foreign Key Constraints for Delete Operations

## Current Problem

When trying to delete an inspection from mobile or web app, you get:
- **Mobile**: `PostgrestException: invalid input syntax for type uuid: "H-0079"`
- **Web**: Similar UUID validation error

**Root Cause**: Database constraints are set to `ON DELETE RESTRICT`, so deletes fail. The cascade RPC function doesn't exist yet.

---

## 🚀 Solution: Execute SQL Migration in Supabase

### Step 1: Open Supabase SQL Editor
1. Go to **Supabase Console** for your project
2. Click **SQL Editor** on the left sidebar
3. Click **New Query**

### Step 2: Copy SQL Migration (CHOOSE ONE)

#### **Option A: Recommended - Fix Constraints** ⭐
This modifies the database schema to automatically cascade deletes.

```sql
-- Drop existing constraints that use ON DELETE RESTRICT
ALTER TABLE general_observation DROP CONSTRAINT IF EXISTS general_observation_site_id_fkey;
ALTER TABLE external_services DROP CONSTRAINT IF EXISTS external_services_site_id_fkey;
ALTER TABLE ancillary_building DROP CONSTRAINT IF EXISTS ancillary_building_site_id_fkey;
ALTER TABLE main_building DROP CONSTRAINT IF EXISTS main_building_site_id_fkey;

-- Add new constraints with ON DELETE CASCADE
ALTER TABLE general_observation 
ADD CONSTRAINT general_observation_site_id_fkey 
FOREIGN KEY (site_id) REFERENCES site(site_id) ON DELETE CASCADE;

ALTER TABLE external_services 
ADD CONSTRAINT external_services_site_id_fkey 
FOREIGN KEY (site_id) REFERENCES site(site_id) ON DELETE CASCADE;

ALTER TABLE ancillary_building 
ADD CONSTRAINT ancillary_building_site_id_fkey 
FOREIGN KEY (site_id) REFERENCES site(site_id) ON DELETE CASCADE;

ALTER TABLE main_building 
ADD CONSTRAINT main_building_site_id_fkey 
FOREIGN KEY (site_id) REFERENCES site(site_id) ON DELETE CASCADE;
```

**Pros:**
- ✅ Clean database design (CASCADE is standard)
- ✅ Single operation
- ✅ Automatic cascading deletes
- ✅ Production-ready

---

#### **Option B: Alternative - Create Function**
If you want a backup function (or can't modify constraints):

```sql
DROP FUNCTION IF EXISTS delete_site_cascade(UUID) CASCADE;

CREATE OR REPLACE FUNCTION delete_site_cascade(p_site_id UUID)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    deleted_site_id UUID,
    deleted_observations INTEGER,
    deleted_services INTEGER,
    deleted_buildings INTEGER,
    deleted_defects INTEGER
) AS $$
DECLARE
    v_obs_count INTEGER := 0;
    v_svc_count INTEGER := 0;
    v_bld_count INTEGER := 0;
    v_dft_count INTEGER := 0;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM site WHERE site_id = p_site_id) THEN
        RETURN QUERY SELECT false, 'Site not found', NULL::UUID, 0, 0, 0, 0;
        RETURN;
    END IF;

    DELETE FROM defect_image WHERE info_id IN (SELECT info_id FROM defect_info WHERE defect_id IN (SELECT defect_id FROM defects WHERE site_id = p_site_id));
    DELETE FROM defect_info WHERE defect_id IN (SELECT defect_id FROM defects WHERE site_id = p_site_id);
    DELETE FROM defects WHERE site_id = p_site_id;
    GET DIAGNOSTICS v_dft_count = ROW_COUNT;

    DELETE FROM specification WHERE building_id IN (SELECT building_id FROM main_building WHERE site_id = p_site_id);
    DELETE FROM main_building WHERE site_id = p_site_id;
    GET DIAGNOSTICS v_bld_count = ROW_COUNT;

    DELETE FROM building_detail WHERE detail_type_id IN (SELECT detail_type_id FROM detail_type WHERE structure_id IN (SELECT structure_id FROM ancillary_building WHERE site_id = p_site_id));
    DELETE FROM detail_type WHERE structure_id IN (SELECT structure_id FROM ancillary_building WHERE site_id = p_site_id);
    DELETE FROM ancillary_building WHERE site_id = p_site_id;

    DELETE FROM external_services WHERE site_id = p_site_id;
    GET DIAGNOSTICS v_svc_count = ROW_COUNT;

    DELETE FROM general_observation WHERE site_id = p_site_id;
    GET DIAGNOSTICS v_obs_count = ROW_COUNT;

    DELETE FROM site WHERE site_id = p_site_id;

    RETURN QUERY SELECT true, 'Site and all dependent records deleted successfully', p_site_id, v_obs_count, v_svc_count, v_bld_count, v_dft_count;

EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT false, 'Error deleting site: ' || SQLERRM, p_site_id, 0, 0, 0, 0;
END;
$$ LANGUAGE plpgsql;
```

---

### Step 3: Paste & Execute
1. Copy either Option A or Option B above
2. Paste into the Supabase SQL Editor query box
3. Click **Run**
4. Wait for success message

**Expected output:**
```
Execution succeeded
Query executed successfully
```

---

## ✅ After Executing SQL

### Restart Apps
**Mobile App:**
```
Press 'r' in the Flutter terminal to hot restart
Or run: flutter run
```

**Web App:**
```
Refresh browser: Ctrl+R or Cmd+R
Or restart dev server: Ctrl+C then npm run dev
```

---

## 🧪 Test Deletion

### On Mobile App:
1. Open Inspections Management
2. Find an inspection
3. Click Delete
4. Confirm deletion
5. Should see: `✓ Inspection deleted successfully`

### On Web App:
1. Go to Dashboard
2. Find an inspection card
3. Click [Delete] button
4. Confirm in the dialog
5. Inspection should disappear from dashboard

---

## 📋 Expected Console Output (After Fix)

### Success Case:
```
[Repository] 🗑️ Deleting inspection: H-0079
[Repository] Looking up site by building_ref: H-0079
[Repository] ✓ Found site_id: 2d8d26f5-290d-4895-b4f6-8b4dc2e7d7e7
[Repository] Attempting to use delete_site_cascade function...
[Repository] ! Cascade function not available (if you only ran Option A)
[Repository] Falling back to direct delete by site_id...
[Repository] ✓ Inspection deleted successfully: 2d8d26f5-290d-4895-b4f6-8b4dc2e7d7e7
```

### Or (if you ran Option B):
```
[Repository] ✓ Used cascade function: {success: true, message: '...', deleted_observations: 2, ...}
```

---

## 🔧 What Changed in Code

Both apps now properly handle deletion:
1. ✅ Converts building_ref (e.g., "H-0079") to site_id via lookup
2. ✅ Tries cascade RPC function if available
3. ✅ Falls back to direct delete (requires ON DELETE CASCADE)
4. ✅ Better error messages with logging

---

## ❓ FAQ

**Q: Which option should I choose?**
- **Production**: Use Option A (Constraints)
- **Both needed**: Run both A and B (they work together)

**Q: Will this affect existing data?**
- No, it only changes how future deletes work

**Q: What if it doesn't work?**
1. Check browser console (web) or logcat (mobile) for full error
2. Verify SQL execution completed successfully in Supabase
3. Restart both apps
4. Try deleting again

**Q: Can I undo this?**
- Yes, but not needed. The changes are safe and standard database practice.

---

## 🎉 Success Indicators

After executing the SQL and restarting apps:
- ✅ Delete button works on dashboard
- ✅ Delete button works in mobile app
- ✅ No UUID/constraint errors
- ✅ Inspection disappears immediately
- ✅ Stats update after deletion
- ✅ Console shows "deleted successfully"

---

**Questions?** Check the Supabase logs or browser console for specific error messages.

