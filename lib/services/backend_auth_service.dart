import 'package:flutter/foundation.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/network/backend_api_client.dart';
import 'package:kins_app/core/utils/secure_storage_service.dart';
import 'package:kins_app/core/utils/storage_service.dart';
import 'package:kins_app/models/user_profile_status.dart';

/// Result of backend login: token stored; use [profileStatus] for navigation.
class BackendLoginResult {
  BackendLoginResult({
    required this.profileStatus,
    required this.backendUserId,
  });
  final UserProfileStatus profileStatus;
  final String backendUserId;
}

/// Auth and profile from backend API. Use after Firebase (phone/Google/Apple) success.
class BackendAuthService {
  /// Call after successful frontend auth. Sends POST /auth/login, stores JWT and userId.
  /// Returns profile status for navigation (About you / Interests / Discover).
  static Future<BackendLoginResult> login({
    required String provider,
    required String providerUserId,
    String? phoneNumber,
    String? email,
    String? name,
    String? profilePictureUrl,
  }) async {
    final body = <String, dynamic>{
      'provider': provider,
      'providerUserId': providerUserId,
    };
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      body['phoneNumber'] = phoneNumber;
    }
    if (email != null && email.isNotEmpty) {
      body['email'] = email;
    }
    if (name != null && name.isNotEmpty) {
      body['name'] = name;
    }
    if (profilePictureUrl != null && profilePictureUrl.isNotEmpty) {
      body['profilePictureUrl'] = profilePictureUrl;
    }

    final response = await BackendApiClient.post(
      '/auth/login',
      body: body,
      useAuth: false,
    );

    debugPrint('🔵 POST /auth/login response: $response');

    if (response['success'] == false) {
      final err = (response['error'] ?? response['message'])?.toString() ?? 'Login failed';
      throw Exception(_userFriendlyLoginError(err));
    }

    final token = response['token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Login failed. Please try again.');
    }
    await SecureStorageService.setJwt(token);

    final user = response['user'];
    String backendUserId = providerUserId;
    if (user is Map<String, dynamic>) {
      final id = user['id'] ?? user['_id'];
      if (id != null) backendUserId = id.toString();
      await StorageService.setString(AppConstants.keyUserId, backendUserId);
      final phone = user['phoneNumber'] as String?;
      if (phone != null && phone.isNotEmpty) {
        await StorageService.setString(AppConstants.keyUserPhoneNumber, phone);
      }
    } else {
      await StorageService.setString(AppConstants.keyUserId, backendUserId);
    }

    // Always use GET /me to decide where to go (login response often has minimal user; profile is in DB).
    final profileStatus = await getProfileStatus();
    return BackendLoginResult(profileStatus: profileStatus, backendUserId: backendUserId);
  }

  /// GET /me and map to [UserProfileStatus]. Use for post-login and splash.
  /// Onboarding = backend data only (name + interests); no local state.
  static Future<UserProfileStatus> getProfileStatus() async {
    try {
      final me = await BackendApiClient.get('/me');
      debugPrint('🔵 GET /me response: $me');
      
      // Backend returns {success: true, user: {...}}, extract user object
      final user = me['user'] is Map<String, dynamic> ? me['user'] as Map<String, dynamic> : me;
      UserProfileStatus? status = _profileStatusFromMe(user);
      debugPrint('🔵 Profile status from /me: hasProfile=${status?.hasProfile}, hasInterests=${status?.hasInterests}');
      
      if (status != null && !status.hasInterests) {
        debugPrint('🔵 Fetching GET /me/interests...');
        final raw = await BackendApiClient.get('/me/interests');
        debugPrint('🔵 GET /me/interests response: $raw');
        final list = raw['interests'] ?? raw['interestIds'];
        if (list is List && list.isNotEmpty) {
          debugPrint('🔵 Found ${list.length} interests from /me/interests');
          status = UserProfileStatus(
            exists: status.exists,
            hasProfile: status.hasProfile,
            hasInterests: true,
            userId: status.userId,
            phoneNumber: status.phoneNumber,
          );
        } else {
          debugPrint('🔵 No interests found in /me/interests');
        }
      }
      
      debugPrint('🔵 FINAL profile status: exists=${status?.exists}, hasProfile=${status?.hasProfile}, hasInterests=${status?.hasInterests}, needsProfile=${status?.needsProfile}, needsInterests=${status?.needsInterests}, isComplete=${status?.isComplete}');
      return status ?? UserProfileStatus(exists: false);
    } catch (e) {
      debugPrint('❌ BackendAuthService getProfileStatus: $e');
      return UserProfileStatus(exists: false);
    }
  }

  /// Onboarding is backend-driven only: onboarded = name NOT empty AND interests.length > 0.
  /// Do NOT use email/dateOfBirth for navigation; only name + interests.
  static UserProfileStatus? _profileStatusFromMe(Map<String, dynamic>? me) {
    if (me == null) return null;
    final id = me['id'] ?? me['_id'];
    final userId = id?.toString();
    final nameValue = me['name'];
    final hasName = (nameValue as String? ?? '').trim().isNotEmpty;
    final interests = me['interests'];
    final hasInterests = interests is List && interests.isNotEmpty;
    final phoneNumber = me['phoneNumber'] as String?;
    
    debugPrint('🔵 _profileStatusFromMe: name="$nameValue" (hasName=$hasName), interests=$interests (hasInterests=$hasInterests)');
    
    return UserProfileStatus(
      exists: true,
      hasProfile: hasName,
      hasInterests: hasInterests,
      userId: userId,
      phoneNumber: phoneNumber,
    );
  }

  static String _userFriendlyLoginError(String serverError) {
    if (serverError.contains('buffering timed out') ||
        serverError.contains('timed out') ||
        serverError.contains('ECONNREFUSED') ||
        serverError.contains('connection')) {
      return 'Server is temporarily unavailable. Please try again in a moment.';
    }
    return serverError.length > 120 ? 'Server error. Please try again.' : serverError;
  }

  /// Sign out: clear JWT and local user id/phone (call Firebase signOut separately).
  static Future<void> clearSession() async {
    await SecureStorageService.deleteJwt();
    await StorageService.remove(AppConstants.keyUserId);
    await StorageService.remove(AppConstants.keyUserPhoneNumber);
  }

  /// Delete user account: calls DELETE /me to hard delete from MongoDB, then clears local session.
  /// Does NOT delete Firebase auth (Firebase auth deletion is not needed per requirement).
  static Future<void> deleteAccount() async {
    try {
      final response = await BackendApiClient.delete('/me');
      debugPrint('🔵 DELETE /me response: $response');
      
      if (response['success'] != true) {
        final err = (response['error'] ?? response['message'])?.toString() ?? 'Delete failed';
        throw Exception(err);
      }
      
      // Clear local session after successful deletion
      await clearSession();
      debugPrint('✅ Account deleted successfully');
    } catch (e) {
      debugPrint('❌ BackendAuthService deleteAccount: $e');
      rethrow;
    }
  }
}
