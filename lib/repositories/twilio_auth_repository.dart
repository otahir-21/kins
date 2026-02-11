import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/utils/storage_service.dart';
import 'package:kins_app/models/auth_result.dart';
import 'package:kins_app/models/user_model.dart';
import 'package:kins_app/repositories/auth_repository_interface.dart';

/// Twilio-based phone auth: backend send-otp / verify-otp. JWT stored in secure storage.
/// Used when [AppConstants.useFirebaseAuth] is false.
class TwilioAuthRepository implements AuthRepositoryInterface {
  static String get _baseUrl => AppConstants.apiBaseUrl;

  @override
  Future<void> sendOTP(String phoneNumber) async {
    final uri = Uri.parse('$_baseUrl${AppConstants.sendOtpPath}');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phoneNumber}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✅ [Twilio] OTP sent to $phoneNumber');
        return;
      }

      final body = _tryDecode(response.body);
      final message = body?['message'] ?? body?['error'] ?? response.body;
      throw Exception(message ?? 'Failed to send OTP');
    } on Exception catch (e) {
      debugPrint('❌ [Twilio] sendOTP error: $e');
      rethrow;
    }
  }

  @override
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

      final token = (body['accessToken'] ?? body['token']) as String?;
      final userMap = body['user'] as Map<String, dynamic>?;
      if (token == null || token.isEmpty || userMap == null) {
        throw Exception('Missing token or user in response');
      }

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

      debugPrint('✅ [Twilio] OTP verified, user: $userId');
      return userModel;
    } on Exception catch (e) {
      debugPrint('❌ [Twilio] verifyOTP error: $e');
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

  @override
  Future<GoogleSignInResult?> signInWithGoogle() async {
    return null;
  }

  @override
  Future<void> signOut() async {
    await StorageService.remove(AppConstants.keyJwtToken);
    await StorageService.remove(AppConstants.keyUserId);
    await StorageService.remove(AppConstants.keyUserPhoneNumber);
  }

  @override
  bool isAuthenticated() {
    final token = StorageService.getString(AppConstants.keyJwtToken);
    final userId = StorageService.getString(AppConstants.keyUserId);
    return (token != null && token.isNotEmpty) && (userId != null && userId.isNotEmpty);
  }

  @override
  String? getStoredUserId() => StorageService.getString(AppConstants.keyUserId);

  @override
  String? getStoredToken() => StorageService.getString(AppConstants.keyJwtToken);
}
