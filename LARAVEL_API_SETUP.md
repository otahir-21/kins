# Laravel API Setup Guide for KINS App

## Project Structure

You need **separate projects** for Flutter and Laravel:

```
GitHub/
├── kins_app/                    # Flutter mobile app (current project)
│   ├── lib/
│   ├── ios/
│   ├── android/
│   └── ...
│
└── kins_api/                    # Laravel backend API (new project)
    ├── app/
    ├── routes/
    ├── database/
    └── ...
```

## Why Separate Projects?

1. **Different Technologies**: 
   - Flutter = Dart (mobile/frontend)
   - Laravel = PHP (backend/API)

2. **Different Deployment**:
   - Flutter app → Mobile devices (iOS/Android)
   - Laravel API → Web server (hosting)

3. **Different Dependencies**:
   - Flutter uses `pubspec.yaml` (Dart packages)
   - Laravel uses `composer.json` (PHP packages)

4. **Better Organization**:
   - Clear separation of concerns
   - Independent version control
   - Easier to maintain and scale

## Creating Laravel API Project

### Option 1: Create New Laravel Project (Recommended)

```bash
cd /Users/alihusnain/Documents/GitHub

# Create Laravel project
composer create-project laravel/laravel kins_api

# Or if you prefer specific version
composer create-project laravel/laravel kins_api "^10.0"
```

### Option 2: Use Existing Laravel Project

If you already have a Laravel project, you can use that and add KINS-specific routes.

## Recommended Laravel API Structure

```
kins_api/
├── app/
│   ├── Http/
│   │   ├── Controllers/
│   │   │   ├── Api/
│   │   │   │   ├── AuthController.php      # Phone OTP auth
│   │   │   │   ├── UserController.php      # User management
│   │   │   │   └── ...
│   │   ├── Middleware/
│   │   │   └── ApiAuth.php                 # API authentication
│   │   └── Requests/
│   │       └── VerifyOtpRequest.php        # Validation
│   ├── Models/
│   │   ├── User.php
│   │   └── ...
│   └── Services/
│       └── AuthService.php                  # Business logic
├── routes/
│   └── api.php                             # API routes
├── database/
│   ├── migrations/
│   └── seeders/
└── config/
    └── cors.php                            # CORS configuration
```

## Connecting Flutter to Laravel API

### 1. Add HTTP Package to Flutter

Add to `kins_app/pubspec.yaml`:
```yaml
dependencies:
  http: ^1.1.0
  dio: ^5.4.0  # Alternative to http, more features
```

### 2. Create API Service in Flutter

Create `lib/services/api_service.dart`:
```dart
import 'package:dio/dio.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://your-api-domain.com/api',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  // Add interceptors for auth token, etc.
}
```

### 3. Laravel API Endpoints Needed

For KINS app, you'll need:

```
POST   /api/auth/send-otp          # Send OTP (if using Laravel instead of Firebase)
POST   /api/auth/verify-otp        # Verify OTP
POST   /api/auth/logout            # Logout
GET    /api/user/profile           # Get user profile
PUT    /api/user/profile           # Update profile
```

## Hybrid Approach (Recommended)

You can use **both Firebase and Laravel**:

1. **Firebase**: Handle phone authentication (OTP)
2. **Laravel API**: Handle business logic, data storage, additional features

**Flow**:
```
Flutter App
    ↓
Firebase Auth (Phone OTP) → Get Firebase Token
    ↓
Laravel API (Send Firebase Token) → Verify & Create User
    ↓
Laravel API (Business Logic) → Store data, handle features
```

## Next Steps

1. **Create Laravel project** (if you want me to set it up)
2. **Configure CORS** for Flutter app
3. **Set up API authentication** (Firebase token verification)
4. **Create API endpoints** for your features
5. **Update Flutter app** to call Laravel APIs

Would you like me to:
- ✅ Create a Laravel API project structure?
- ✅ Set up API service in Flutter?
- ✅ Create sample API endpoints?
- ✅ Set up Firebase token verification in Laravel?

Let me know what you'd like to do!
