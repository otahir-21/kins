import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/utils/storage_service.dart';
import 'package:kins_app/services/backend_auth_service.dart';
import 'package:kins_app/models/auth_result.dart';
import 'package:kins_app/models/google_profile_data.dart';
import 'package:kins_app/models/user_model.dart';
import 'package:kins_app/repositories/auth_repository_interface.dart';

/// Firebase Phone Auth. Used when [AppConstants.useFirebaseAuth] is true.
/// Stores verificationId between sendOTP and verifyOTP; persists uid/phone to storage for app consistency.
class FirebaseAuthRepository implements AuthRepositoryInterface {
  String? _verificationId;

  @override
  Future<void> sendOTP(String phoneNumber) async {
    final completer = Completer<void>();
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) {
          if (!completer.isCompleted) {
            completer.completeError(
              Exception('Verification completed automatically - sign in via verifyOTP with code'),
            );
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!completer.isCompleted) {
            completer.completeError(Exception(e.message ?? e.code));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          if (!completer.isCompleted) completer.complete();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          if (!completer.isCompleted) completer.complete();
        },
        timeout: const Duration(seconds: 120),
      );
      await completer.future;
      debugPrint('✅ [Firebase] OTP sent to $phoneNumber');
    } on Exception catch (e) {
      debugPrint('❌ [Firebase] sendOTP error: $e');
      rethrow;
    }
  }

  @override
  Future<UserModel> verifyOTP(String phoneNumber, String otp) async {
    final vid = _verificationId;
    if (vid == null || vid.isEmpty) {
      throw Exception('No verification ID. Please request OTP again.');
    }
    try {
      final credential = PhoneAuthProvider.credential(verificationId: vid, smsCode: otp);
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) throw Exception('Firebase sign-in returned no user');

      final uid = user.uid;
      final phone = user.phoneNumber ?? phoneNumber;

      await StorageService.setString(AppConstants.keyUserId, uid);
      await StorageService.setString(AppConstants.keyUserPhoneNumber, phone);
      // No JWT for Firebase path; token storage left empty

      debugPrint('✅ [Firebase] OTP verified, user: $uid');
      return UserModel(
        uid: uid,
        phoneNumber: phone,
        createdAt: null,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [Firebase] verifyOTP error: ${e.message}');
      throw Exception(e.message ?? e.code);
    } on Exception catch (e) {
      debugPrint('❌ [Firebase] verifyOTP error: $e');
      rethrow;
    }
  }

  @override
  Future<GoogleSignInResult?> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('✅ [Firebase] Google sign-in cancelled');
        return null;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw Exception('Google sign-in did not return an id token');
      }

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) throw Exception('Firebase sign-in returned no user');

      final uid = user.uid;
      final phone = user.phoneNumber ?? '';
      await StorageService.setString(AppConstants.keyUserId, uid);
      if (phone.isNotEmpty) {
        await StorageService.setString(AppConstants.keyUserPhoneNumber, phone);
      }

      debugPrint('✅ [Firebase] Google sign-in success: $uid');

      final userModel = UserModel(
        uid: uid,
        phoneNumber: phone,
        name: user.displayName,
        createdAt: null,
      );

      final googleProfile = GoogleProfileData(
        name: user.displayName,
        email: user.email,
        phoneNumber: user.phoneNumber?.isNotEmpty == true ? user.phoneNumber : null,
        dateOfBirth: null,
      );

      return GoogleSignInResult(user: userModel, googleProfile: googleProfile);
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [Firebase] Google sign-in error: ${e.message}');
      throw Exception(e.message ?? e.code);
    } on Exception catch (e) {
      debugPrint('❌ [Firebase] Google sign-in error: $e');
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    await BackendAuthService.clearSession();
  }

  @override
  bool isAuthenticated() {
    return FirebaseAuth.instance.currentUser != null;
  }

  @override
  String? getStoredUserId() {
    return FirebaseAuth.instance.currentUser?.uid ?? StorageService.getString(AppConstants.keyUserId);
  }

  @override
  String? getStoredToken() => null;
}
