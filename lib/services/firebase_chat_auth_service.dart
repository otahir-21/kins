import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/network/backend_api_client.dart';
import 'package:kins_app/core/utils/storage_service.dart';

/// Ensures the user is signed in to Firebase with a custom token for group chat (Firestore/Storage).
/// Call when opening any chat screen (or app start if in chat section). Uses GET /me/firebase-token.
/// Stores a flag so we don't call the backend on every screen; if token expires, re-fetches and signs in again.
class FirebaseChatAuthService {
  static bool get _isMarkedSignedIn =>
      StorageService.getBool(AppConstants.keyFirebaseChatSignedIn) == true;

  static Future<void> _setMarkedSignedIn(bool value) async {
    await StorageService.setBool(AppConstants.keyFirebaseChatSignedIn, value);
  }

  /// Call before using Firestore/Storage for group chat. Signs in with custom token if needed.
  /// If token has expired, clears the flag and fetches a new token once.
  static Future<void> ensureFirebaseSignedIn() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null && _isMarkedSignedIn) {
      if (kDebugMode) debugPrint('[FirebaseChatAuth] Already signed in (${auth.currentUser!.uid})');
      return;
    }

    try {
      final token = await BackendApiClient.getFirebaseCustomToken();
      final cred = await auth.signInWithCustomToken(token);
      if (cred.user != null) {
        await _setMarkedSignedIn(true);
        if (kDebugMode) debugPrint('[FirebaseChatAuth] Signed in with custom token (${cred.user!.uid})');
        return;
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) debugPrint('[FirebaseChatAuth] Auth error: ${e.code} - ${e.message}');
      await _setMarkedSignedIn(false);
      // Retry once with a fresh token (e.g. token expired)
      try {
        final token = await BackendApiClient.getFirebaseCustomToken();
        final cred = await auth.signInWithCustomToken(token);
        if (cred.user != null) {
          await _setMarkedSignedIn(true);
          if (kDebugMode) debugPrint('[FirebaseChatAuth] Re-signed in after auth error');
          return;
        }
      } catch (e2) {
        if (kDebugMode) debugPrint('[FirebaseChatAuth] Re-sign-in failed: $e2');
        rethrow;
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FirebaseChatAuth] ensureFirebaseSignedIn failed: $e');
        final msg = e.toString();
        if (!msg.contains('FIREBASE_') && !msg.contains('not configured')) {
          debugPrint('[FirebaseChatAuth] Ensure backend has GET /api/v1/me/firebase-token (JWT required).');
        }
      }
      rethrow;
    }
  }
}
