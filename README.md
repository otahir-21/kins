# KINS App

A Flutter application with Firebase Phone OTP Authentication, user profile management, and document upload functionality. Built with clean architecture principles.

## Features

- ✅ Splash Screen
- ✅ 3 Onboarding Screens
- ✅ Phone Number Authentication with OTP
- ✅ OTP Verification
- ✅ User Profile Management (Name, Gender)
- ✅ Document Upload (Emirates ID/Document ID - PDF)
- ✅ Bunny CDN Integration for file storage
- ✅ Cloud Firestore for data persistence
- ✅ State Management with Riverpod
- ✅ Navigation with GoRouter
- ✅ Local Storage with SharedPreferences
- ✅ Clean Architecture

## Project Structure

```
lib/
├── core/
│   ├── constants/
│   │   └── app_constants.dart      # App-wide constants
│   ├── theme/
│   │   └── app_theme.dart          # App theme configuration
│   └── utils/
│       └── storage_service.dart    # Local storage service
├── models/
│   └── user_model.dart             # User data model
├── repositories/
│   └── auth_repository.dart        # Firebase Auth repository
├── providers/
│   ├── auth_provider.dart          # Auth state management
│   └── onboarding_provider.dart    # Onboarding state management
├── routes/
│   └── app_router.dart             # GoRouter configuration
├── screens/
│   ├── splash/
│   │   └── splash_screen.dart
│   ├── onboarding/
│   │   └── onboarding_screen.dart
│   └── auth/
│       ├── phone_auth_screen.dart
│       ├── otp_verification_screen.dart
│       └── otp_verified_screen.dart
├── widgets/                        # Reusable widgets (future)
├── firebase_options.dart           # Firebase configuration
└── main.dart                       # App entry point
```

## Setup Instructions

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
2. Enable Phone Authentication in Firebase Console:
   - Go to Authentication > Sign-in method
   - Enable Phone provider
   - **Important for Testing**: Add test phone numbers in Phone provider settings
     - Scroll to "Phone numbers for testing"
     - Add phone numbers with verification codes (e.g., `+971507276822` → Code: `123456`)
     - See `FIREBASE_TEST_NUMBERS.md` for detailed instructions
3. Add your app to Firebase:
   - For Android: Add Android app and download `google-services.json`
   - For iOS: Add iOS app and download `GoogleService-Info.plist`
4. Update `lib/firebase_options.dart` with your Firebase credentials

### 3. Android Configuration

1. Place `google-services.json` in `android/app/`
2. Update `android/build.gradle`:
```gradle
dependencies {
    classpath 'com.google.gms:google-services:4.4.0'
}
```
3. Update `android/app/build.gradle`:
```gradle
apply plugin: 'com.google.gms.google-services'
```

### 4. iOS Configuration

1. Place `GoogleService-Info.plist` in `ios/Runner/`
2. Open `ios/Runner.xcworkspace` in Xcode
3. Ensure the file is added to the Runner target

### 5. Run the App

```bash
flutter run
```

## State Management

- **Riverpod**: Used for state management
  - `authProvider`: Manages authentication state
  - `onboardingProvider`: Manages onboarding completion status

## Navigation

- **GoRouter**: Handles all navigation
  - `/` - Splash Screen
  - `/onboarding` - Onboarding Screens
  - `/phone-auth` - Phone Number Entry
  - `/otp-verification` - OTP Verification
  - `/otp-verified` - Success Screen

## Local Storage

- **SharedPreferences**: Used for storing:
  - Onboarding completion status
  - User phone number
  - User ID
  - Verification ID

## Firestore Collections

The app stores user data in Firestore:

```
users/
  {userId}/
    name: string
    gender: string (male/female/other)
    documentUrl: string | null
    updatedAt: timestamp
    documents/
      {documentId}/
        url: string
        fileName: string
        uploadedAt: timestamp
        size: number
```

See `FIRESTORE_SETUP.md` for setup instructions.

## Bunny CDN Configuration

The app uses Bunny CDN for document storage. To configure:

1. Copy `lib/config/bunny_cdn_config.dart.example` to `lib/config/bunny_cdn_config.dart`
2. Fill in your Bunny CDN credentials
3. See `BUNNY_CDN_SETUP.md` for detailed instructions

**⚠️ Important**: Never commit `bunny_cdn_config.dart` with real credentials!

## Design

- Currently using black and white color scheme only
- Focus on functionality first, design will be enhanced later
- Material Design 3

## Dependencies

- `flutter_riverpod`: State management
- `go_router`: Navigation
- `firebase_core`: Firebase initialization
- `firebase_auth`: Phone OTP authentication
- `cloud_firestore`: Firestore database
- `shared_preferences`: Local storage
- `file_picker`: File selection
- `http`: HTTP requests (Bunny CDN)
- `intl_phone_field`: Phone number input
- `pin_code_fields`: OTP input

## Documentation

- `PROJECT_SUMMARY.md` - Complete project overview
- `CRM_INTEGRATION_GUIDE.md` - Node.js CRM integration guide
- `QUICK_START_NODEJS.md` - Quick Node.js setup
- `FIRESTORE_SETUP.md` - Firestore setup instructions
- `BUNNY_CDN_SETUP.md` - Bunny CDN configuration guide
- `RECAPTCHA_GUIDE.md` - reCAPTCHA information

## Next Steps

1. Set up Firebase project and configure authentication
2. Test phone OTP flow
3. Add error handling improvements
4. Enhance UI/UX design
5. Add additional features as needed

## Notes

- The app uses a clean architecture pattern for maintainability
- All authentication logic is centralized in the `AuthRepository`
- State is managed through Riverpod providers
- Navigation is handled declaratively with GoRouter
