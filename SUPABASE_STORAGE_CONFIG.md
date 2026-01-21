# Supabase Storage Configuration Guide

## Problem
Storage upload fails with error: `mime type image/jpeg is not supported`

## Solution: Configure Storage Bucket

### Step 1: Create Storage Bucket (if not exists)

1. Go to Supabase Dashboard
2. Navigate to **Storage** in the left sidebar
3. Click **New bucket**
4. Enter bucket name: `inspection-photos`
5. Set bucket to **Public** (for easy photo access)
6. Click **Create bucket**

### Step 2: Configure Allowed MIME Types

1. Click on the `inspection-photos` bucket
2. Click the **Settings** icon (gear icon)
3. Scroll to **Allowed MIME types**
4. Add the following MIME types:
   ```
   image/jpeg
   image/jpg
   image/png
   image/webp
   ```
5. Click **Save**

### Step 3: Configure File Size Limit

1. In the same settings page
2. Set **Maximum file size** to at least `10 MB` (10485760 bytes)
3. Click **Save**

### Step 4: Set Up Storage Policies

If your bucket is **Private**, you need to add policies:

1. Go to **Storage** → **Policies**
2. Add policy for **SELECT** (download/view):
   ```sql
   CREATE POLICY "Public Access"
   ON storage.objects FOR SELECT
   USING ( bucket_id = 'inspection-photos' );
   ```

3. Add policy for **INSERT** (upload):
   ```sql
   CREATE POLICY "Authenticated users can upload"
   ON storage.objects FOR INSERT
   WITH CHECK (
     bucket_id = 'inspection-photos'
     AND auth.role() = 'authenticated'
   );
   ```

4. Add policy for **DELETE**:
   ```sql
   CREATE POLICY "Users can delete own photos"
   ON storage.objects FOR DELETE
   USING (
     bucket_id = 'inspection-photos'
     AND auth.role() = 'authenticated'
   );
   ```

### Alternative: Make Bucket Public

If you want simpler configuration:

1. Go to Storage → `inspection-photos`
2. Click **Settings**
3. Toggle **Public bucket** to ON
4. This allows anyone to view photos (but only authenticated users can upload if you have the INSERT policy)

## Verification

After configuration:
1. Hot restart your Flutter app (press `R` in terminal)
2. Try creating an inspection with a photo
3. The upload should now succeed

## Bucket Structure

Photos will be organized as:
```
inspection-photos/
  └── defects/
      └── {defect-id}/
          └── defect_{defect-id}_{timestamp}.jpg
```

## Troubleshooting

If you still get errors:

1. **Check bucket exists**: Ensure `inspection-photos` bucket is created
2. **Check MIME types**: Verify `image/jpeg` is in allowed list
3. **Check policies**: Ensure authenticated users have INSERT permission
4. **Check file size**: Ensure max file size is adequate (10MB+)
