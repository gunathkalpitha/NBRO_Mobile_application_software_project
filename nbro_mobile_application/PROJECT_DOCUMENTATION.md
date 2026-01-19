# NBRO Field Surveyor - Project Documentation

## Project Overview
NBRO Field Surveyor is a field data collection app for the National Building Research Organisation (NBRO) to record structural defects (cracks, damp patches, wall separations) in buildings. The app follows Clean Architecture with offline-first capabilities using Flutter, Drift/SQLite, Supabase, and PowerSync.

## Tech Stack
- **Frontend**: Flutter 3.9.2+
- **State Management**: BLoC (flutter_bloc)
- **Local Storage**: Drift (SQLite) with SQLCipher encryption
- **Backend**: Supabase
- **Real-time Sync**: PowerSync
- **Authentication**: Biometric (local_auth) + Email/Password
- **Utilities**: Geolocator (GPS), ImagePicker (Camera), Permission Handler

## Project Structure

```
lib/
├── main.dart                          # App entry point with Supabase init
├── core/
│   ├── theme/
│   │   └── app_theme.dart            # NBRO branding colors & theme
│   ├── security/                      # Encryption & biometrics logic
│   └── network/                       # Network connectivity handling
├── data/
│   ├── local/
│   │   └── database/                 # Drift database schema & DAOs
│   ├── remote/                        # Supabase API clients
│   └── repositories/                 # Repository implementations
├── domain/
│   ├── models/
│   │   └── inspection.dart           # Inspection, Defect, User models
│   ├── repositories/                 # Abstract repository contracts
│   └── usecases/                     # Business logic operations
├── presentation/
│   ├── screens/
│   │   ├── splash_screen.dart        # 3-second splash screen
│   │   ├── login_screen.dart         # Biometric + Email/Password login
│   │   ├── dashboard_screen.dart     # Main dashboard with inspection list
│   │   └── site_inspection_wizard.dart # Multi-step inspection form
│   ├── widgets/
│   │   ├── sync_status_indicator.dart # Online/Offline sync status
│   │   └── defect_capture_card.dart  # Defect photo & details capture
│   └── state/
│       └── inspection_bloc.dart      # InspectionBloc with events/states
└── assets/
    ├── images/
    └── icons/
```

## Key Features Implemented

### 1. Project Initialization ✅
- Supabase initialization in main.dart
- BLoC provider setup for state management
- NBRO branding theme with colors (#003366 primary)
- Navigation routing (/login, /dashboard)

### 2. Authentication ✅
- **Splash Screen**: 3-second intro with gradient and loading indicator
- **Login Screen**: 
  - Email/Password authentication fields
  - Biometric authentication (Fingerprint/FaceID)
  - Password visibility toggle
  - Forgot password support (TODO)

### 3. State Management ✅
- **InspectionBloc** tracks:
  - List of inspections with sync status
  - Pending inspection count
  - Real-time sync operations
- **Events**: LoadInspections, CreateInspection, AddDefect, SyncInspections
- **States**: Loading, Loaded, Error, Syncing

### 4. Dashboard Screen ✅
- **Header**: Sync status indicator (Online/Pending/Syncing)
- **Stats Card**: Total, Pending, and Synced inspection counts
- **Recent Inspections**: ListView with:
  - Site address
  - Defect count
  - Created date
  - Sync status badge (Synced/Pending/Error)
- **FAB**: "Start New Inspection" button

### 5. Multi-Step Inspection Wizard ✅
**Step 1: Site Information**
- Address input (required)
- Auto-GPS location capture button
- Location display with coordinates

**Step 2: Building Materials**
- Checkboxes for primary materials (Brick, Concrete, Timber, Steel, etc.)
- Custom "Other" materials input field

**Step 3: Defect Capture**
- Camera photo capture
- Defect type dropdown
- Length (mm) and Width (mm) numeric inputs
- Optional remarks/notes field
- Defect list with remove option
- Save button triggers inspection creation

### 6. Defect Capture Card ✅
- Camera integration for photo capture
- Defect type selection dropdown
- Dimension inputs (Length × Width in mm)
- Optional remarks text field
- Photo preview with delete option
- Form validation before submission
- Debug print statements for tracking

### 7. Utilities & Widgets ✅
- **Sync Status Indicator**: Shows online/offline status in AppBar
- **NBRO Colors**: Consistent branding throughout (#003366, #FF6B35, etc.)
- **Theme System**: Material 3 with custom elevatedButton, textField, etc.

## Domain Models

### Inspection
```dart
class Inspection {
  final String id;
  final String siteAddress;
  final double? latitude;
  final double? longitude;
  final List<Defect> defects;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  // ... more fields
}
```

### Defect
```dart
class Defect {
  final String id;
  final String inspectionId;
  final DefectType type;
  final double lengthMm;
  final double widthMm;
  final String? photoPath;
  // ... more fields
}
```

### DefectType Enum
- Crack
- DampPatch
- WallSeparation
- Spalling
- Efflorescence
- Other

### SyncStatus Enum
- Pending (not synced)
- Syncing (in progress)
- Synced (completed)
- Error (sync failed)

## Next Steps / TODO

### Phase 2: Backend Integration
- [ ] Implement Drift database schema and migrations
- [ ] Create SQLCipher encryption for local DB
- [ ] Implement Supabase authentication provider
- [ ] Set up PowerSync synchronization logic
- [ ] Create data repository implementations

### Phase 3: Advanced Features
- [ ] Offline data queuing
- [ ] Conflict resolution for offline edits
- [ ] Photo compression and cloud upload
- [ ] Inspection detail view and edit
- [ ] Reports and data export
- [ ] Map view for inspection locations
- [ ] PDF report generation

### Phase 4: Testing & Deployment
- [ ] Unit tests for BLoCs and repositories
- [ ] Widget tests for UI screens
- [ ] Integration tests with Supabase
- [ ] Android/iOS native configuration
- [ ] Play Store and App Store deployment

## Running the App

### Prerequisites
1. Flutter 3.9.2+
2. Dart 3.3+
3. Android Studio or Xcode (for emulators)
4. Supabase project created

### Setup
```bash
# Get dependencies
flutter pub get

# Run code generation (for Drift)
flutter pub run build_runner build

# Run the app
flutter run
```

### Environment Configuration
Update `lib/main.dart` with your Supabase credentials:
```dart
const String SUPABASE_URL = 'https://your-project.supabase.co';
const String SUPABASE_ANON_KEY = 'your-anon-key';
```

## Debugging Tips
- Check logs with: `flutter logs`
- Debug prints include timestamps and component names
- Enable Supabase debug mode in main.dart (debug: true)
- Use Flutter DevTools: `flutter pub global activate devtools` → `devtools`

## Color Scheme (NBRO Branding)
- **Primary**: #003366 (Navy Blue)
- **Primary Light**: #1A5A96
- **Primary Dark**: #001F3F
- **Accent**: #FF6B35 (Orange)
- **Success**: #28A745 (Green)
- **Warning**: #FFC107 (Amber)
- **Error**: #DC3545 (Red)

## File Size & Performance Notes
- Images should be compressed (max 1024px, 85% quality)
- Use `const` constructors where possible
- Implement lazy loading for inspection lists
- Consider pagination for large datasets

## API Integration Notes
- **Supabase URL**: Set during Supabase project creation
- **Anon Key**: Found in Supabase project settings
- **Database**: Create tables: inspections, defects, users, photos
- **Auth**: Enable email/password and optional OAuth providers
- **Storage**: Bucket for defect photos

## Permissions Required
- Camera (for defect photos)
- Location (for GPS coordinates)
- File storage (for local database and photos)
- Biometrics (for fingerprint/face ID)

## Known Limitations
- Biometric auth fallback to email/password not yet implemented
- Photo sync to cloud storage pending backend setup
- Inspection editing/deletion pending database schema
- Offline sync conflict resolution pending PowerSync setup
