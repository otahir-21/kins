import 'package:firebase_auth/firebase_auth.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/utils/secure_storage_service.dart';
import 'package:kins_app/core/utils/storage_service.dart';

/// Current user id: from storage (set by backend login) or Firebase uid.
String get currentUserId {
  final stored = StorageService.getString(AppConstants.keyUserId);
  if (stored != null && stored.isNotEmpty) return stored;
  if (AppConstants.useFirebaseAuth) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) return uid;
  }
  return '';
}

/// Current user phone number from local storage.
String? get currentUserPhone =>
    StorageService.getString(AppConstants.keyUserPhoneNumber);

/// JWT token from secure storage (set after backend login).
String? get jwtToken => SecureStorageService.getJwtTokenSync();

/// Headers for authenticated API calls: Authorization: Bearer <JWT>.
Map<String, String> get authHeaders => {
  'Authorization': 'Bearer ${jwtToken ?? ''}',
  'Content-Type': 'application/json',
};
