# Google Maps API Key Setup - REQUIRED

## ⚠️ IMPORTANT: Maps Won't Work Without This!

Your app is currently showing blank/grey maps because the Google Maps API key is not configured.

## Quick Setup Steps

### 1. Get Your Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable these APIs:
   - **Maps SDK for Android**
   - **Maps SDK for iOS**
4. Go to **APIs & Services** → **Credentials**
5. Click **Create Credentials** → **API Key**
6. Copy your API key

### 2. Configure Android

**File:** `android/app/src/main/AndroidManifest.xml`

Find this line (around line 58):
```xml
android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
```

**Replace `YOUR_GOOGLE_MAPS_API_KEY` with your actual API key.**

### 3. Configure iOS

**File:** `ios/Runner/AppDelegate.swift`

Find this line (around line 19):
```swift
GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
```

**Replace `YOUR_GOOGLE_MAPS_API_KEY` with your actual API key.**

### 4. Restart Your App

After adding the API key:
```bash
flutter clean
flutter pub get
flutter run
```

## Security (Recommended)

Restrict your API key for security:

1. In Google Cloud Console → **APIs & Services** → **Credentials**
2. Click on your API key
3. Under **Application restrictions**:
   - **Android:** Add package name: `com.metatech.kins_app`
   - **iOS:** Add bundle ID: `com.metatech.kinsApp`
4. Under **API restrictions**:
   - Select: **Maps SDK for Android** and **Maps SDK for iOS**

## Troubleshooting

### Map Still Shows Blank/Grey
- ✅ Verify API key is correct (no extra spaces)
- ✅ Check Maps SDK is enabled in Google Cloud Console
- ✅ Ensure billing is enabled (Google Maps requires billing, but provides $200/month free credit)
- ✅ Rebuild app: `flutter clean && flutter run`

### "API key not valid" Error
- ✅ Double-check API key spelling
- ✅ Verify API restrictions allow Maps SDK
- ✅ Check application restrictions match your package name/bundle ID

## Cost

Google Maps provides **$200 free credit per month**, which typically covers:
- ~28,000 map loads
- ~100,000 map interactions

Most apps stay within the free tier.

---

**After setup, your maps will show real-world data!** 🗺️
