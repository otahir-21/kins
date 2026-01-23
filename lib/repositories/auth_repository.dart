import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kins_app/core/utils/storage_service.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/models/user_model.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;

  // Send OTP to phone number
  Future<void> sendOTP(String phoneNumber) async {
    _verificationId = null;
    final completer = Completer<void>();
    
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _auth.signInWithCredential(credential);
            if (!completer.isCompleted) {
              completer.complete();
            }
          } catch (e) {
            if (!completer.isCompleted) {
              completer.completeError(e);
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          String errorMessage = e.message ?? 'Verification failed';
          
          // Provide user-friendly error messages
          if (e.code == 'internal-error') {
            errorMessage = 'Phone number not registered for testing. Please add test phone numbers in Firebase Console.';
            debugPrint('❌ Firebase Verification Failed: ${e.code} - ${e.message}');
            debugPrint('💡 To test with new numbers, add them in Firebase Console → Authentication → Sign-in method → Phone → Phone numbers for testing');
          } else if (e.code == 'invalid-phone-number') {
            errorMessage = 'Invalid phone number format. Please check and try again.';
          } else if (e.code == 'too-many-requests') {
            errorMessage = 'Too many requests. Please try again later.';
          } else if (e.code == 'quota-exceeded') {
            errorMessage = 'SMS quota exceeded. Please try again later or add test numbers in Firebase Console.';
          }
          
          debugPrint('❌ Firebase Verification Failed: ${e.code} - ${e.message}');
          if (!completer.isCompleted) {
            completer.completeError(Exception(errorMessage));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          // Store verification ID for later use
          _verificationId = verificationId;
          StorageService.setString('verification_id', verificationId);
          debugPrint('✅ OTP Code Sent - Verification ID stored');
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          StorageService.setString('verification_id', verificationId);
        },
        timeout: const Duration(seconds: 60),
      );
      
      // Wait for the verification process to complete
      await completer.future;
      debugPrint('✅ OTP sending process completed');
    } catch (e) {
      debugPrint('❌ Failed to send OTP: $e');
      throw Exception('Failed to send OTP: ${e.toString()}');
    }
  }

  // Verify OTP
  Future<UserModel> verifyOTP(String otp) async {
    final verificationId = _verificationId ?? StorageService.getString('verification_id');
    if (verificationId == null) {
      throw Exception('Verification ID not found. Please request OTP again.');
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );

    try {
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      
      if (user == null) {
        throw Exception('User authentication failed');
      }

      final userModel = UserModel(
        uid: user.uid,
        phoneNumber: user.phoneNumber ?? '',
        createdAt: DateTime.now(),
      );

      // Save user data locally
      await StorageService.setString(AppConstants.keyUserId, user.uid);
      await StorageService.setString(
        AppConstants.keyUserPhoneNumber,
        user.phoneNumber ?? '',
      );

      debugPrint('✅ OTP Verified - User authenticated: ${user.uid}');
      return userModel;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ OTP Verification Failed: ${e.code} - ${e.message}');
      throw Exception('OTP verification failed: ${e.message}');
    }
  }

  // Get verification ID
  String? getVerificationId() {
    return _verificationId ?? StorageService.getString('verification_id');
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    await StorageService.remove(AppConstants.keyUserId);
    await StorageService.remove(AppConstants.keyUserPhoneNumber);
  }

  // Check if user is authenticated
  bool isAuthenticated() {
    return _auth.currentUser != null;
  }
}
