# Google Maps API Key Setup

## Required for Map Feature

The map screen requires a Google Maps API key to work. Follow these steps:

## 1. Get Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select or create a project
3. Enable **Maps SDK for Android** and **Maps SDK for iOS**
4. Go to **APIs & Services** → **Credentials**
5. Click **Create Credentials** → **API Key**
6. Copy your API key

## 2. Android Setup

### Update AndroidManifest.xml

The file `android/app/src/main/AndroidManifest.xml` already has a placeholder:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
```

**Replace `YOUR_GOOGLE_MAPS_API_KEY` with your actual API key.**

## 3. iOS Setup

### Update AppDelegate.swift

Add this to `ios/Runner/AppDelegate.swift` in the `didFinishLaunchingWithOptions` method:

```swift
GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
```

**Replace `YOUR_GOOGLE_MAPS_API_KEY` with your actual API key.**

Don't forget to import:
```swift
import GoogleMaps
```

## 4. Restrict API Key (Recommended)

For security, restrict your API key:

1. Go to Google Cloud Console → **APIs & Services** → **Credentials**
2. Click on your API key
3. Under **Application restrictions**:
   - For Android: Add your package name: `com.metatech.kins_app`
   - For iOS: Add your bundle ID: `com.metatech.kinsApp`
4. Under **API restrictions**:
   - Restrict to: **Maps SDK for Android** and **Maps SDK for iOS**

## 5. Test

After adding the API key:
1. Rebuild the app: `flutter clean && flutter run`
2. Navigate to the map screen
3. Map should load with your location

## Troubleshooting

### Map shows blank/gray
- Check API key is correct
- Verify Maps SDK is enabled in Google Cloud Console
- Check API key restrictions

### "API key not valid" error
- Verify API key is correct
- Check API restrictions allow Maps SDK
- Ensure billing is enabled (Google Maps requires billing)

---

**Note**: Google Maps requires a billing account, but they provide $200 free credit per month (usually covers most usage).
