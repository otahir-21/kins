# KINS App

A Flutter social networking application for mothers, featuring Firebase Phone OTP Authentication, user profile management, interest-based content discovery, map-based social discovery, and comprehensive notification system. Built with clean architecture principles.

## 🎯 Features

### Authentication & Onboarding
- ✅ Splash Screen with session management
- ✅ 3 Onboarding Screens
- ✅ Phone Number Authentication with OTP (GCC countries only)
- ✅ OTP Verification with automatic session check
- ✅ Session Management (returns users to appropriate screen based on profile completion)

### User Profile Management
- ✅ Profile Completion (Name, Email, Date of Birth)
- ✅ Interest Selection (multiple interests from Firebase)
- ✅ User Profile stored in Cloud Firestore
- ✅ Profile completion tracking

### Social Discovery
- ✅ Map-based Nearby Kins Discovery
- ✅ GPS Location Sharing
- ✅ Location Visibility Toggle (Settings)
- ✅ Distance-based Filtering (1km, 5km, 10km, 25km, 50km)
- ✅ Marker Clustering for Performance
- ✅ Profile Preview Cards (slides up from bottom)
- ✅ Real-time Location Updates

### Notifications
- ✅ Firebase Cloud Messaging (FCM) Integration
- ✅ Notification Screen with Grouped Display
- ✅ Unread Notification Counts
- ✅ Real-time Notification Updates

### Home & Navigation
- ✅ Home Screen with Dashboard
- ✅ Drawer Navigation (Profile, Settings, Notifications, Logout)
- ✅ Marketplace, Ask Expert, Join Group Screens (placeholders)
- ✅ Settings Screen with Location Privacy Toggle

### Data Management
- ✅ Cloud Firestore for user data, interests, locations, notifications
- ✅ Bunny CDN Integration for file storage (optional)
- ✅ Local Storage with SharedPreferences
- ✅ State Management with Riverpod
- ✅ Navigation with GoRouter

## 📱 App Flow

### New User Flow
```
Splash → Phone Auth → OTP Verification → 
Profile Details (Name, Email, DOB) → 
Interest Selection → Home
```

### Returning User Flow
```
Splash → Phone Auth → OTP Verification → 
[Check Profile Status]
  ├─ Missing Profile → Profile Details
  ├─ Missing Interests → Interest Selection
  └─ Complete → Home
```

## 📂 Project Structure

```
lib/
├── config/
│   └── bunny_cdn_config.dart          # Bunny CDN credentials
├── core/
│   ├── constants/
│   │   └── app_constants.dart          # Routes, storage keys
│   ├── theme/
│   │   └── app_theme.dart              # App theme
│   └── utils/
│       └── storage_service.dart        # SharedPreferences wrapper
├── models/
│   ├── user_model.dart                 # User data model
│   ├── interest_model.dart             # Interest data model
│   ├── kin_location_model.dart         # Location data model
│   ├── notification_model.dart         # Notification data model
│   └── user_profile_status.dart        # Profile completion status
├── repositories/
│   ├── auth_repository.dart            # Firebase Auth repository
│   ├── user_details_repository.dart    # User profile repository
│   ├── interest_repository.dart        # Interests repository
│   ├── location_repository.dart        # Location repository
│   └── notification_repository.dart    # Notifications repository
├── providers/
│   ├── auth_provider.dart              # Auth state management
│   ├── onboarding_provider.dart        # Onboarding state
│   ├── user_details_provider.dart      # User details state
│   ├── interest_provider.dart          # Interests state
│   └── notification_provider.dart      # Notifications state
├── services/
│   ├── bunny_cdn_service.dart          # Bunny CDN file upload
│   ├── location_service.dart           # GPS location service
│   └── fcm_service.dart                # Firebase Cloud Messaging
├── routes/
│   └── app_router.dart                 # GoRouter configuration
├── screens/
│   ├── splash/
│   │   └── splash_screen.dart
│   ├── onboarding/
│   │   └── onboarding_screen.dart
│   ├── auth/
│   │   ├── phone_auth_screen.dart
│   │   └── otp_verification_screen.dart
│   ├── user_details/
│   │   ├── user_details_screen.dart
│   │   └── user_details_success_screen.dart
│   ├── interests/
│   │   └── interests_screen.dart
│   ├── home/
│   │   └── home_screen.dart
│   ├── map/
│   │   └── nearby_kins_screen.dart
│   ├── notifications/
│   │   └── notifications_screen.dart
│   └── dummy/
│       └── dummy_screen.dart           # Placeholder screens
├── firebase_options.dart                # Firebase configuration
└── main.dart                            # App entry point
```

## 🚀 Setup Instructions

### 1. Install Dependencies

```bash
cd kins_app
flutter pub get
```

### 2. Firebase Setup

#### Option A: Using FlutterFire CLI (Recommended)

1. Install FlutterFire CLI:
```bash
dart pub global activate flutterfire_cli
```

2. Configure Firebase:
```bash
flutterfire configure
```

This will automatically generate the `firebase_options.dart` file with your Firebase project credentials.

#### Option B: Manual Setup

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable Phone Authentication:
   - Go to Authentication > Sign-in method
   - Enable Phone provider
   - **Important for Testing**: Add test phone numbers in Phone provider settings
     - Scroll to "Phone numbers for testing"
     - Add phone numbers with verification codes (e.g., `+971507276822` → Code: `123456`)
3. Enable Cloud Firestore:
   - Go to Firestore Database
   - Create database (start in test mode for development)
   - See `FIRESTORE_SETUP.md` for detailed instructions
4. Enable Cloud Messaging:
   - Go to Cloud Messaging
   - See `FCM_ANDROID_IOS_SETUP.md` for platform-specific setup
5. Add your app to Firebase:
   - For Android: Add Android app and download `google-services.json`
   - For iOS: Add iOS app and download `GoogleService-Info.plist`
6. Update Firestore Security Rules:
   - See `FIRESTORE_SECURITY_RULES.md` for complete rules
   - Copy rules to Firebase Console → Firestore Database → Rules

### 3. Android Configuration

1. Place `google-services.json` in `android/app/`
2. Update `android/app/build.gradle.kts`:
```kotlin
dependencies {
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
    implementation 'com.google.firebase:firebase-messaging'
}
```
3. Add location permissions to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```
4. Add Google Maps API key to `AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
```

### 4. iOS Configuration

1. Place `GoogleService-Info.plist` in `ios/Runner/`
2. Open `ios/Runner.xcworkspace` in Xcode
3. Ensure the file is added to the Runner target
4. Add location permissions to `Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show nearby kins</string>
```
5. Add Google Maps API key to `AppDelegate.swift`:
```swift
GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
```
6. Run `pod install` in `ios/` directory

### 5. Bunny CDN Configuration (Optional)

1. Copy `lib/config/bunny_cdn_config.dart.example` to `lib/config/bunny_cdn_config.dart`
2. Fill in your Bunny CDN credentials
3. See `BUNNY_CDN_SETUP.md` for detailed instructions

**⚠️ Important**: Never commit `bunny_cdn_config.dart` with real credentials!

### 6. Google Maps API Key

1. Get API key from [Google Cloud Console](https://console.cloud.google.com/)
2. Enable Maps SDK for Android and iOS
3. Add API key to Android and iOS configurations (see above)
4. See `GOOGLE_MAPS_SETUP.md` for detailed instructions

### 7. Firestore Data Structure

Create the following collections in Firestore:

#### `interests` Collection
```
interests/
  {interestId}/
    id: string
    name: string
    isActive: boolean
    createdAt: timestamp
    updatedAt: timestamp
```

#### `users` Collection
```
users/
  {userId}/
    phoneNumber: string
    name: string
    email: string
    dateOfBirth: string (ISO8601)
    interests: [interestId1, interestId2, ...]
    location: {
      latitude: number
      longitude: number
      isVisible: boolean
      updatedAt: timestamp
    }
    interestsUpdatedAt: timestamp
    updatedAt: timestamp
```

### 8. Run the App

```bash
flutter run
```

## 🔐 Security Rules

Update Firestore Security Rules in Firebase Console. See `FIRESTORE_SECURITY_RULES.md` for complete rules.

## 📱 Screens & Routes

| Route | Screen | Description |
|-------|--------|-------------|
| `/` | Splash | Initial screen, checks session |
| `/onboarding` | Onboarding | 3-page onboarding flow |
| `/phone-auth` | Phone Auth | Phone number input (GCC only) |
| `/otp-verification` | OTP Verification | 6-digit code input |
| `/user-details` | Profile Details | Name, Email, DOB form |
| `/interests` | Interests | Interest selection screen |
| `/home` | Home | Main dashboard |
| `/nearby-kins` | Nearby Kins | Map-based discovery |
| `/notifications` | Notifications | Notification list |
| `/profile` | Profile | User profile (placeholder) |
| `/settings` | Settings | App settings |
| `/marketplace` | Marketplace | Marketplace (placeholder) |
| `/ask-expert` | Ask Expert | Expert Q&A (placeholder) |
| `/join-group` | Join Group | Groups (placeholder) |

## 🗄️ Firestore Collections

### `users` Collection
- User profiles with phone number, name, email, DOB
- Selected interests array
- Location data with visibility settings

### `interests` Collection
- Available interests for selection
- Active/inactive status

### `notifications` Subcollection
- User-specific notifications
- Read/unread status
- Timestamps

## 📦 Dependencies

### Core
- `flutter_riverpod: ^2.5.1` - State management
- `go_router: ^14.0.0` - Navigation

### Firebase
- `firebase_core: ^3.0.0` - Firebase initialization
- `firebase_auth: ^5.0.0` - Phone OTP authentication
- `cloud_firestore: ^5.0.0` - Firestore database
- `firebase_messaging: ^15.0.0` - Push notifications

### Location & Maps
- `google_maps_flutter: ^2.5.0` - Google Maps integration
- `geolocator: ^12.0.0` - GPS location services
- `geocoding: ^3.0.0` - Geocoding services

### Utilities
- `shared_preferences: ^2.2.2` - Local storage
- `file_picker: ^8.0.0` - File selection
- `http: ^1.2.0` - HTTP requests (Bunny CDN)
- `intl_phone_field: ^3.2.0` - Phone number input (GCC filtered)
- `pin_code_fields: ^8.0.1` - OTP input
- `intl: ^0.19.0` - Internationalization

## 📚 Documentation

- `PROJECT_SUMMARY.md` - Complete project overview
- `CRM_INTEGRATION_GUIDE.md` - Node.js CRM integration guide
- `QUICK_START_NODEJS.md` - Quick Node.js setup
- `FIRESTORE_SETUP.md` - Firestore setup instructions
- `FIRESTORE_SECURITY_RULES.md` - Security rules configuration
- `BUNNY_CDN_SETUP.md` - Bunny CDN configuration guide
- `FCM_ANDROID_IOS_SETUP.md` - FCM platform setup
- `GOOGLE_MAPS_SETUP.md` - Google Maps API setup
- `RECAPTCHA_GUIDE.md` - reCAPTCHA information
- `ARCHITECTURE.md` - Architecture documentation

## 🔄 Key Features Details

### Session Management
- After OTP verification, checks if phone number exists in Firestore
- Navigates to appropriate screen based on profile completion:
  - New user → Profile Details
  - Missing profile → Profile Details
  - Missing interests → Interest Selection
  - Complete → Home

### Interest Selection
- Fetches interests from Firestore `interests` collection
- Filters by `isActive: true`
- Allows multiple selections
- Saves selected interest IDs to user profile
- Real-time visual feedback with overlapping chips

### Map Discovery
- Shows nearby users on Google Maps
- Filters by distance (1km, 5km, 10km, 25km, 50km)
- Location visibility toggle in Settings
- Marker clustering for performance
- Profile preview cards on marker tap

### Notifications
- Firebase Cloud Messaging integration
- Real-time notification updates
- Grouped by date
- Unread count tracking
- Notification screen with empty state

## 🎨 Design

- Material Design 3
- Clean, modern UI
- Purple/pink gradient accents
- Responsive layouts
- Loading states and error handling

## 🚧 Future Enhancements

- [ ] User profile screen
- [ ] Marketplace functionality
- [ ] Ask Expert Q&A system
- [ ] Group joining and management
- [ ] Chat/messaging system
- [ ] Feed based on selected interests
- [ ] Advanced filtering options

## 📝 Notes

- The app uses clean architecture pattern for maintainability
- All authentication logic is centralized in repositories
- State is managed through Riverpod providers
- Navigation is handled declaratively with GoRouter
- Location data is stored in Firestore with privacy controls
- Phone number filtering is limited to GCC countries (UAE, Saudi Arabia, Kuwait, Qatar, Bahrain, Oman)

## 🤝 Contributing

1. Follow the existing code structure
2. Use Riverpod for state management
3. Follow clean architecture principles
4. Add proper error handling
5. Update documentation for new features

## 📄 License

[Add your license here]

---

**Last Updated**: January 2026  
**Version**: 1.0.0  
**Firebase Project**: kins-b4afb
