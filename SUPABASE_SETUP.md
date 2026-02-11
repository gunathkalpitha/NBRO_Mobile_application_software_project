# NBRO Mobile Application - Supabase Setup

## 📁 Database Schema

**File:** `supabase_schema.sql`

This is the complete database schema for the NBRO Site Inspection application.

### What it contains:
- ✅ All database tables (profiles, sites, defects, defect_media, inspections)
- ✅ Admin and Officer roles with Row Level Security (RLS)
- ✅ Automatic triggers and functions
- ✅ Storage bucket configuration
- ✅ Admin profile auto-creation

### How to use:

1. **Open Supabase Dashboard**
   - Go to your project at supabase.com
   - Navigate to SQL Editor

2. **Run the Schema**
   - Copy entire content of `supabase_schema.sql`
   - Paste into SQL Editor
   - Click "Run"
   - Wait for success message

3. **Create Admin User**
   - Go to Authentication → Users
   - Click "Add User"
   - Email: `admin@gmail.com`
   - Password: (choose a secure password)
   - Confirm email

4. **Login to Mobile App**
   - Install and run the Flutter app
   - Login with admin@gmail.com credentials
   - Access Admin Panel for full system management

---

## 🔐 User Roles

### Admin (`admin@gmail.com`)
- View all inspections from all officers
- Manage officers (view, add, deactivate)
- Access admin dashboard with statistics
- Full read/write access to all data

### Officer (e.g., `test@gmail.com`)
- Create site inspections
- Record defects with photos
- View own inspections only
- Upload and sync data to cloud

---

## 🗂️ Database Structure

```
profiles         → User accounts (admin/officer)
├── sites        → Building/site information
    ├── defects  → Structural defects found
        └── defect_media → Photos and annotations
    └── inspections → Inspection records
```

---

## ⚙️ Key Features

✅ **Row Level Security (RLS)**
- Officers can only see their own data
- Admins can see all data
- Automatic permission enforcement

✅ **Real-time Sync**
- Automatic data synchronization
- Offline support with pending status
- Conflict resolution

✅ **Photo Storage**
- Automatic upload to Supabase Storage
- Public access for viewing
- Optimized for mobile bandwidth

---

## 🔧 Troubleshooting

### Admin cannot see inspections?
1. Logout from app completely
2. Close app (swipe away)
3. Restart app: `flutter run`
4. Login again as admin@gmail.com

### Schema update needed?
```sql
-- Run the schema again (it will drop and recreate tables)
-- WARNING: This deletes all existing data!
```

---

## 📱 Flutter App Commands

```bash
# Install dependencies
flutter pub get

# Run on device/emulator
flutter run

# Check for issues
flutter analyze

# Clean build
flutter clean
flutter pub get
flutter run
```

---

**Last Updated:** February 12, 2026  
**Database:** PostgreSQL (Supabase)  
**Framework:** Flutter 3.x
