import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kins_app/repositories/auth_repository.dart';
import 'package:kins_app/models/user_model.dart';

// Auth Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// Auth State Provider
class AuthState {
  final bool isLoading;
  final String? error;
  final UserModel? user;
  final String? verificationId;

  AuthState({
    this.isLoading = false,
    this.error,
    this.user,
    this.verificationId,
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    UserModel? user,
    String? verificationId,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      user: user ?? this.user,
      verificationId: verificationId ?? this.verificationId,
    );
  }
}

// Auth Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(AuthState());

  Future<void> sendOTP(String phoneNumber) async {
    debugPrint('📱 Sending OTP to: $phoneNumber');
    state = state.copyWith(isLoading: true, error: null, verificationId: null);
    try {
      await _authRepository.sendOTP(phoneNumber);
      
      // Poll for verification ID (reCAPTCHA might take a moment)
      String? verificationId;
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        verificationId = _authRepository.getVerificationId();
        if (verificationId != null && verificationId.isNotEmpty) {
          debugPrint('✅ Verification ID received');
          break;
        }
      }
      
      if (verificationId == null || verificationId.isEmpty) {
        debugPrint('⚠️ Verification ID not found after polling');
      }
      
      state = state.copyWith(
        isLoading: false,
        verificationId: verificationId,
      );
    } catch (e) {
      debugPrint('❌ Send OTP Error in Provider: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        verificationId: null,
      );
    }
  }

  Future<void> verifyOTP(String otp) async {
    debugPrint('🔐 Verifying OTP...');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authRepository.verifyOTP(otp);
      debugPrint('✅ OTP Verified - User: ${user.uid}');
      state = state.copyWith(
        isLoading: false,
        user: user,
      );
    } catch (e) {
      debugPrint('❌ Verify OTP Error in Provider: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Auth Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepository);
});
