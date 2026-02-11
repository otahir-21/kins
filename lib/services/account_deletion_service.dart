import 'package:flutter/foundation.dart';
import 'package:kins_app/repositories/auth_repository.dart';
import 'package:kins_app/services/backend_auth_service.dart';

/// Deletes the user's account from MongoDB backend (hard delete via DELETE /me API).
/// Does NOT delete Firebase Auth or Firestore data (all data is in MongoDB).
class AccountDeletionService {
  /// Delete account: calls backend DELETE /me API, clears local session, and signs out.
  Future<void> deleteAccount({
    required String userId,
    required AuthRepository authRepository,
  }) async {
    try {
      // 1. Delete from MongoDB backend (hard delete via DELETE /me)
      await BackendAuthService.deleteAccount();
      
      // 2. Sign out from Firebase Auth (if using Firebase)
      await authRepository.signOut();

      debugPrint('✅ Account deleted successfully for user: $userId');
    } catch (e) {
      debugPrint('❌ Account deletion error: $e');
      rethrow;
    }
  }
}
