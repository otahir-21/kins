import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/utils/storage_service.dart';

/// Current user id from local storage (set after backend verify-otp). No Firebase.
String get currentUserId =>
    StorageService.getString(AppConstants.keyUserId) ?? '';

/// Current user phone number from local storage.
String? get currentUserPhone =>
    StorageService.getString(AppConstants.keyUserPhoneNumber);

/// JWT token from secure storage (for API auth).
String? get jwtToken => StorageService.getString(AppConstants.keyJwtToken);

/// Headers for authenticated API calls: Authorization: Bearer <accessToken>.
Map<String, String> get authHeaders => {
  'Authorization': 'Bearer ${jwtToken ?? ''}',
  'Content-Type': 'application/json',
};
