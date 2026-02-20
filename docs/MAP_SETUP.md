# Map setup – what you need to show the map

## What the app already has

- **SDK:** `google_maps_flutter` in `pubspec.yaml`.
- **Map widget:** Home screen and Nearby Kins screen use `GoogleMap` with:
  - Dubai default camera (25.2048, 55.2708).
  - Your location (blue dot) when permission is granted.
  - Rounded corners, “LIVING” and “Dubai Hills Mall” overlays.
  - Tap opens full map (Nearby Kins).
- **Location:** `geolocator` and `LocationService` to get current position; camera moves to it when available.
- **Permissions:**
  - **Android:** `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` in `AndroidManifest.xml`.
  - **iOS:** `NSLocationWhenInUseUsageDescription` (and related) in `Info.plist`.

---

## What is missing (why the map may not show)

### 1. **Google Maps API key (required)**

Without a **real** API key, map tiles often do not load (blank or grey map).

**Current placeholders:**

- **Android:** `android/app/src/main/AndroidManifest.xml`  
  - `android:value="YOUR_GOOGLE_MAPS_API_KEY"`  
  - Replace with your key.

- **iOS:** `ios/Runner/AppDelegate.swift`  
  - `GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")`  
  - Replace with the same key (or a separate iOS key if you use two).

**How to get a key:**

1. Go to [Google Cloud Console](https://console.cloud.google.com/).
2. Create or select a project.
3. Enable:
   - **Maps SDK for Android**
   - **Maps SDK for iOS**
4. **Credentials** → Create credentials → **API key**.
5. (Recommended) Restrict the key by app (Android package name / iOS bundle ID) and by API (Maps SDK for Android / iOS).
6. Put the key in:
   - `AndroidManifest.xml`: `android:value="YOUR_ACTUAL_KEY"`.
   - `AppDelegate.swift`: `GMSServices.provideAPIKey("YOUR_ACTUAL_KEY")`.

After this, the map should load on both platforms (assuming network and permissions are OK).

---

### 2. **Optional: match the reference design**

Your reference image has more than the current implementation:

| In the image                         | In the app now                          |
|--------------------------------------|-----------------------------------------|
| Dubai Hills Park (tree icon)         | Not shown                               |
| Angel Cakes (restaurant icon)        | Not shown                               |
| Dubai Hills Mall (bag icon)          | Shown as overlay label only             |
| LIVING (blue pin)                    | Shown as overlay label                  |
| Roads (D65, D63, area names)         | From Google Maps once key is set        |

To get closer to the image you can:

- Add **markers** for each POI (e.g. `Marker` with `position`, `icon`).
- Use **custom marker icons** (e.g. tree, cutlery, bag) via `BitmapDescriptor` (asset or bytes).
- Store POI data (name, lat/lng, icon type) in code or from a backend and build `markers` from that.

Functionally, the map will show as soon as the **API key** is set; the rest is optional polish.

---

## Checklist

- [ ] Replace `YOUR_GOOGLE_MAPS_API_KEY` in **Android** (`AndroidManifest.xml`).
- [ ] Replace `YOUR_GOOGLE_MAPS_API_KEY` in **iOS** (`AppDelegate.swift`).
- [ ] Enable **Maps SDK for Android** and **Maps SDK for iOS** in Google Cloud.
- [ ] (Optional) Add POI markers and custom icons to match the reference design.
