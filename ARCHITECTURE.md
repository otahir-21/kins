# KINS App Architecture

## Overview

The KINS app follows **Clean Architecture** principles with clear separation of concerns:

- **Models**: Data structures
- **Repositories**: Data access layer (Firebase, Local Storage)
- **Providers**: State management (Riverpod)
- **Screens**: UI layer
- **Routes**: Navigation configuration

## Architecture Layers

### 1. Core Layer (`lib/core/`)

**Constants** (`constants/app_constants.dart`)
- App-wide constants
- Route paths
- Storage keys

**Theme** (`theme/app_theme.dart`)
- Material Design 3 theme
- Black and white color scheme
- Consistent styling

**Utils** (`utils/storage_service.dart`)
- SharedPreferences wrapper
- Local storage operations

### 2. Models Layer (`lib/models/`)

**UserModel** (`user_model.dart`)
- User data structure
- Serialization methods
- Firebase-compatible format

### 3. Repository Layer (`lib/repositories/`)

**AuthRepository** (`auth_repository.dart`)
- Firebase Authentication operations
- Phone OTP sending
- OTP verification
- User session management
- Local storage integration

### 4. Provider Layer (`lib/providers/`)

**AuthProvider** (`auth_provider.dart`)
- Authentication state management
- OTP sending state
- OTP verification state
- Error handling

**OnboardingProvider** (`onboarding_provider.dart`)
- Onboarding completion status
- Persistence to local storage

### 5. Routes Layer (`lib/routes/`)

**AppRouter** (`app_router.dart`)
- GoRouter configuration
- Route definitions
- Navigation paths

### 6. Screens Layer (`lib/screens/`)

**Splash Screen** (`splash/splash_screen.dart`)
- Initial screen
- Navigation logic based on app state
- 2-second delay

**Onboarding Screens** (`onboarding/onboarding_screen.dart`)
- 3-page onboarding flow
- Page indicators
- Skip functionality
- Completion tracking

**Phone Auth Screen** (`auth/phone_auth_screen.dart`)
- Phone number input
- International phone field
- OTP sending

**OTP Verification Screen** (`auth/otp_verification_screen.dart`)
- 6-digit OTP input
- PIN code fields
- Resend OTP functionality

**OTP Verified Screen** (`auth/otp_verified_screen.dart`)
- Success confirmation
- User information display

## Data Flow

### Authentication Flow

```
User Input (Phone) 
  → PhoneAuthScreen 
  → AuthProvider.sendOTP() 
  → AuthRepository.sendOTP() 
  → Firebase Auth
  → OTP Sent
  → Navigate to OTPVerificationScreen
  → User Input (OTP)
  → AuthProvider.verifyOTP()
  → AuthRepository.verifyOTP()
  → Firebase Auth Verification
  → UserModel Created
  → Navigate to OtpVerifiedScreen
```

### Onboarding Flow

```
SplashScreen
  → Check OnboardingProvider
  → If not completed: Navigate to OnboardingScreen
  → User completes onboarding
  → OnboardingProvider.completeOnboarding()
  → Save to SharedPreferences
  → Navigate to PhoneAuthScreen
```

## State Management

### Riverpod Providers

1. **authProvider** (StateNotifierProvider)
   - State: `AuthState`
   - Methods: `sendOTP()`, `verifyOTP()`
   - Used by: PhoneAuthScreen, OtpVerificationScreen

2. **onboardingProvider** (StateNotifierProvider)
   - State: `bool` (completed status)
   - Methods: `completeOnboarding()`
   - Used by: SplashScreen, OnboardingScreen

## Navigation Flow

```
/ (Splash)
  ↓
/onboarding (if not completed)
  ↓
/phone-auth
  ↓
/otp-verification?phone=...
  ↓
/otp-verified
```

## Local Storage

**SharedPreferences Keys:**
- `onboarding_completed`: Boolean
- `user_phone_number`: String
- `user_id`: String
- `verification_id`: String (temporary)

## Firebase Integration

### Authentication
- Phone Number Authentication
- OTP Verification
- User Session Management

### Firestore (Future)
Currently not used, but structure ready:
```
users/
  {userId}/
    phoneNumber: string
    createdAt: timestamp
```

## Error Handling

- Repository layer throws exceptions
- Providers catch and store in state
- UI displays errors via SnackBar
- User-friendly error messages

## Testing Strategy (Future)

- Unit tests for repositories
- Widget tests for screens
- Integration tests for flows
- Provider tests for state management

## Future Enhancements

1. **Local Database**: Add Hive/Isar for complex data
2. **Firestore Integration**: Store user profiles
3. **Error Recovery**: Better error handling and retry logic
4. **Biometric Auth**: Add fingerprint/face ID
5. **Offline Support**: Cache data for offline access
6. **Analytics**: Add Firebase Analytics
7. **Crash Reporting**: Add Firebase Crashlytics

## Dependencies

- **State Management**: `flutter_riverpod`
- **Navigation**: `go_router`
- **Firebase**: `firebase_core`, `firebase_auth`
- **Storage**: `shared_preferences`
- **UI**: `intl_phone_field`, `pin_code_fields`

## Code Organization Principles

1. **Single Responsibility**: Each class has one purpose
2. **Dependency Injection**: Providers inject repositories
3. **Separation of Concerns**: UI, business logic, and data separated
4. **Reusability**: Common utilities in core layer
5. **Testability**: Clear interfaces for testing
