import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kins_app/core/network/backend_api_client.dart';
import 'package:kins_app/models/user_model.dart';
import 'package:kins_app/models/user_profile_status.dart';
import 'package:kins_app/services/backend_auth_service.dart';
import 'package:kins_app/services/bunny_cdn_service.dart';

/// User profile and "About you" data from backend API (GET /me, PUT /me/about).
/// No Firebase Firestore.
class UserDetailsRepository {
  final BunnyCDNService? _bunnyCDN;

  UserDetailsRepository({BunnyCDNService? bunnyCDN}) : _bunnyCDN = bunnyCDN;

  /// No backend endpoint for availability; return true. Backend will return error on PUT if taken.
  Future<bool> checkUsernameAvailable(String username, {String? currentUserId}) async {
    final norm = username.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (norm.isEmpty || norm.length < 2) return false;
    return true;
  }

  Future<bool> checkEmailAvailable(String email, {String? currentUserId}) async {
    final norm = email.trim().toLowerCase();
    if (norm.isEmpty || !norm.contains('@')) return false;
    return true;
  }

  Future<bool> checkPhoneAvailable(String phone, {String? currentUserId}) async {
    final norm = phone.replaceAll(RegExp(r'\D'), '');
    if (norm.length < 8) return false;
    return true;
  }

  /// Save user details via PUT /me/about.
  Future<void> saveUserDetails({
    required String userId,
    required String name,
    required String email,
    required DateTime dateOfBirth,
    String? username,
    String? phoneNumber,
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'dateOfBirth': _formatDateOfBirth(dateOfBirth),
      };
      if (username != null && username.trim().isNotEmpty) {
        body['username'] = username.trim();
      }
      await BackendApiClient.put('/me/about', body: body);
      debugPrint('✅ User details saved via PUT /me/about');
    } catch (e) {
      debugPrint('❌ Failed to save user details: $e');
      rethrow;
    }
  }

  static String _formatDateOfBirth(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Upload document to Bunny CDN then set documentUrl via PUT /me/about.
  Future<String> uploadDocument({
    required String userId,
    required File documentFile,
  }) async {
    if (_bunnyCDN == null) {
      throw Exception('Bunny CDN service not configured');
    }
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${userId}_$timestamp.pdf';
      final documentUrl = await _bunnyCDN.uploadFile(
        file: documentFile,
        fileName: fileName,
        path: 'documents/',
      );
      await BackendApiClient.put('/me/about', body: {'documentUrl': documentUrl});
      debugPrint('✅ Document uploaded and saved: $documentUrl');
      return documentUrl;
    } catch (e) {
      debugPrint('❌ Failed to upload document: $e');
      rethrow;
    }
  }

  /// Get current user via GET /me. [userId] ignored (auth from JWT).
  Future<UserModel?> getUserDetails(String userId) async {
    try {
      final me = await BackendApiClient.get('/me');
      return _userModelFromMe(me);
    } catch (e) {
      debugPrint('❌ Failed to get user details: $e');
      rethrow;
    }
  }

  /// Get raw /me response for edit profile. Returns user map or empty.
  Future<Map<String, dynamic>> getMeRaw() async {
    try {
      final me = await BackendApiClient.get('/me');
      final user = me['user'];
      if (user is! Map<String, dynamic>) return <String, dynamic>{};
      return Map<String, dynamic>.from(user);
    } catch (e) {
      debugPrint('❌ Failed to get /me: $e');
      rethrow;
    }
  }

  /// Partial update via PUT /me/about. Sends only the fields provided in [body].
  Future<void> updateProfilePartial(Map<String, dynamic> body) async {
    if (body.isEmpty) return;
    try {
      await BackendApiClient.put('/me/about', body: body);
      debugPrint('✅ Profile updated via PUT /me/about');
    } catch (e) {
      debugPrint('❌ Failed to update profile: $e');
      rethrow;
    }
  }

  static UserModel? _userModelFromMe(Map<String, dynamic>? me) {
    if (me == null) return null;
    final id = me['id'] ?? me['_id'];
    final uid = id?.toString() ?? '';
    final phoneNumber = me['phoneNumber'] as String? ?? '';
    return UserModel(
      uid: uid,
      phoneNumber: phoneNumber,
      name: me['name'] as String?,
      gender: me['gender'] as String?,
      documentUrl: me['documentUrl'] as String?,
      status: me['status'] as String?,
      profilePictureUrl: me['profilePictureUrl'] as String?,
      bio: me['bio'] as String?,
      createdAt: me['createdAt'] != null ? DateTime.tryParse(me['createdAt'].toString()) : null,
    );
  }

  /// Update user status via PUT /me/about.
  Future<void> updateUserStatus({
    required String userId,
    required String status,
  }) async {
    try {
      await BackendApiClient.put('/me/about', body: {'status': status});
      debugPrint('✅ User status updated: $status');
    } catch (e) {
      debugPrint('❌ Failed to update user status: $e');
      rethrow;
    }
  }

  /// Profile status for [uid] (current user). Other users not supported by API.
  Future<UserProfileStatus> checkUserByUid(String uid) async {
    return BackendAuthService.getProfileStatus();
  }

  /// No API to look up by phone; return not found. Auth flow uses BackendAuthService.login.
  Future<UserProfileStatus> checkUserByPhoneNumber(String phoneNumber) async {
    return UserProfileStatus(exists: false, phoneNumber: phoneNumber);
  }

  /// Update bio via PUT /me/about.
  Future<void> updateBio({required String userId, required String bio}) async {
    try {
      await BackendApiClient.put('/me/about', body: {'bio': bio});
      debugPrint('✅ Bio updated');
    } catch (e) {
      debugPrint('❌ Failed to update bio: $e');
      rethrow;
    }
  }

  /// No-op; phone is set by backend at login.
  Future<void> savePhoneNumber({
    required String userId,
    required String phoneNumber,
  }) async {
    // Backend has phone from auth/login
  }
}
