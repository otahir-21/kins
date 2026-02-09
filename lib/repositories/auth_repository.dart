import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/utils/storage_service.dart';
import 'package:kins_app/models/user_model.dart';

/// Phone auth via backend API (send-otp / verify-otp). JWT stored locally.
/// No Firebase Phone Auth.
class AuthRepository {
  static String get _baseUrl => AppConstants.apiBaseUrl;

  /// POST /auth/send-otp — request OTP for [phoneNumber].
  Future<void> sendOTP(String phoneNumber) async {
    final uri = Uri.parse('$_baseUrl${AppConstants.sendOtpPath}');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phoneNumber}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✅ OTP sent to $phoneNumber');
        return;
      }

      final body = _tryDecode(response.body);
      final message = body?['message'] ?? body?['error'] ?? response.body;
      throw Exception(message ?? 'Failed to send OTP');
    } on Exception catch (e) {
      debugPrint('❌ sendOTP error: $e');
      rethrow;
    }
  }

  /// POST /auth/verify-otp — verify [otp] for [phoneNumber]. Returns user and stores JWT.
  Future<UserModel> verifyOTP(String phoneNumber, String otp) async {
    final uri = Uri.parse('$_baseUrl${AppConstants.verifyOtpPath}');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phoneNumber, 'code': otp}),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        final body = _tryDecode(response.body);
        final message = body?['message'] ?? body?['error'] ?? response.body;
        throw Exception(message ?? 'Invalid OTP');
      }

      final body = _tryDecode(response.body) as Map<String, dynamic>?;
      if (body == null) throw Exception('Invalid response');

      // Backend returns accessToken (JWT); fallback to token
      final token = (body['accessToken'] ?? body['token']) as String?;
      final userMap = body['user'] as Map<String, dynamic>?;
      if (token == null || token.isEmpty || userMap == null) {
        throw Exception('Missing token or user in response');
      }
      // expiresIn (optional) can be used for token refresh later

      final userId = userMap['id']?.toString() ?? userMap['userId']?.toString() ?? '';
      final phone = userMap['phoneNumber']?.toString() ?? userMap['phone']?.toString() ?? phoneNumber;

      final userModel = UserModel(
        uid: userId,
        phoneNumber: phone,
        createdAt: userMap['createdAt'] != null ? DateTime.tryParse(userMap['createdAt'].toString()) : null,
      );

      await StorageService.setString(AppConstants.keyJwtToken, token);
      await StorageService.setString(AppConstants.keyUserId, userId);
      await StorageService.setString(AppConstants.keyUserPhoneNumber, phone);

      debugPrint('✅ OTP verified, user: $userId');
      return userModel;
    } on Exception catch (e) {
      debugPrint('❌ verifyOTP error: $e');
      rethrow;
    }
  }

  static dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  /// Sign out: clear JWT and user data (no Firebase).
  Future<void> signOut() async {
    await StorageService.remove(AppConstants.keyJwtToken);
    await StorageService.remove(AppConstants.keyUserId);
    await StorageService.remove(AppConstants.keyUserPhoneNumber);
  }

  bool isAuthenticated() {
    final token = StorageService.getString(AppConstants.keyJwtToken);
    final userId = StorageService.getString(AppConstants.keyUserId);
    return (token != null && token.isNotEmpty) && (userId != null && userId.isNotEmpty);
  }

  String? getStoredUserId() => StorageService.getString(AppConstants.keyUserId);
  String? getStoredToken() => StorageService.getString(AppConstants.keyJwtToken);
}
