import 'package:firebase_auth/firebase_auth.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/utils/storage_service.dart';

/// Current user id: from Firebase when [useFirebaseAuth], else from storage (Twilio).
String get currentUserId {
  if (AppConstants.useFirebaseAuth) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) return uid;
  }
  return StorageService.getString(AppConstants.keyUserId) ?? '';
}

/// Current user phone number from local storage.
String? get currentUserPhone =>
    StorageService.getString(AppConstants.keyUserPhoneNumber);

/// JWT token: from secure storage when Twilio; null when Firebase auth.
String? get jwtToken {
  if (AppConstants.useFirebaseAuth) return null;
  return StorageService.getString(AppConstants.keyJwtToken);
}

/// Headers for authenticated API calls: Authorization: Bearer <accessToken>.
Map<String, String> get authHeaders => {
  'Authorization': 'Bearer ${jwtToken ?? ''}',
  'Content-Type': 'application/json',
};
