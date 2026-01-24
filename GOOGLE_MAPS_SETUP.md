# Google Maps Setup Guide

This application now includes Google Maps functionality to display inspection site locations.

## Features Added

1. **Dashboard - Total Sites Map**: Click on the "Total Sites" card in the dashboard to view all inspection sites on a map
2. **Inspection Details - GPS Location Map**: Click on the GPS Coordinates in the Key Information section to view the specific site location on a map

## Required: Google Maps API Key Setup

To use the map features, you need to obtain a Google Maps API key and configure it for both Android and iOS platforms.

### Step 1: Get Google Maps API Key

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the following APIs:
   - Maps SDK for Android
   - Maps SDK for iOS
4. Go to **Credentials** → **Create Credentials** → **API Key**
5. Copy your API key
6. (Recommended) Restrict your API key:
   - For Android: Add your app's package name and SHA-1 certificate fingerprint
   - For iOS: Add your app's bundle identifier

### Step 2: Configure Android

1. Open `android/app/src/main/AndroidManifest.xml`
2. Replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` with your actual API key:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_ACTUAL_API_KEY_HERE" />
```

### Step 3: Configure iOS

1. Open `ios/Runner/AppDelegate.swift`
2. Add the following import at the top:

```swift
import GoogleMaps
```

3. Add this line in the `application` method before `GeneratedPluginRegistrant.register`:

```swift
GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY_HERE")
```

Example:
```swift
import UIKit
import Flutter
import GoogleMaps  // Add this

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_ACTUAL_API_KEY_HERE")  // Add this
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

4. Update `ios/Podfile` to set minimum iOS version to 14.0:

```ruby
platform :ios, '14.0'
```

### Step 4: Test the Implementation

1. Get your package name (SHA-1):
   ```bash
   cd android
   ./gradlew signingReport
   ```

2. Add package restrictions in Google Cloud Console

3. Run the app:
   ```bash
   flutter run
   ```

## Map Features

### All Sites Map (Dashboard)
- Shows all inspection sites with GPS coordinates
- Blue markers for all sites
- Red marker for the currently selected site
- Tap on markers to view site information
- Bottom card shows site details and "View Full Details" button

### Single Site Map (Inspection Details)
- Shows the location of a specific inspection site
- Zoomed in view (zoom level 16)
- Tap to view the site information card

### Map Controls
- **My Location**: Shows your current location on the map
- **Zoom Controls**: Zoom in/out buttons
- **Compass**: Indicates map orientation
- **Marker Info Windows**: Tap markers to see site ID and owner name

## Troubleshooting

### Map shows gray screen
- Check if your API key is correctly configured
- Verify that Maps SDK is enabled in Google Cloud Console
- Check internet connection
- Review API key restrictions

### "Authorization failure" error
- Your API key restrictions might be too strict
- Make sure your app's package name and SHA-1 fingerprint are added
- Wait a few minutes after creating/modifying the API key

### Markers not showing
- Ensure inspections have valid latitude and longitude values
- Check that coordinates are within valid ranges (-90 to 90 for latitude, -180 to 180 for longitude)

## Location Permissions

The app already has location permissions configured:
- Android: `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION`
- iOS: Location permissions are handled by the geolocator package

## API Key Security

**Important**: Never commit your actual API key to version control!

Options for securing your API key:
1. Use environment variables
2. Store in a separate config file (add to .gitignore)
3. Use API key restrictions in Google Cloud Console
4. Implement backend proxy for API calls

## Cost Considerations

Google Maps API has usage limits:
- Free tier: $200 credit per month
- Maps SDK for Android: ~$7 per 1000 map loads
- Monitor usage in Google Cloud Console

## Additional Resources

- [Google Maps Platform Documentation](https://developers.google.com/maps/documentation)
- [google_maps_flutter Package](https://pub.dev/packages/google_maps_flutter)
- [API Key Best Practices](https://developers.google.com/maps/api-security-best-practices)
