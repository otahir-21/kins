import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/models/auth_result.dart';
import 'package:kins_app/models/user_model.dart';
import 'package:kins_app/repositories/auth_repository.dart';
import 'package:kins_app/repositories/firebase_auth_repository.dart';
import 'package:kins_app/repositories/twilio_auth_repository.dart';
import 'package:kins_app/services/backend_auth_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AppConstants.useFirebaseAuth ? FirebaseAuthRepository() : TwilioAuthRepository();
});

class AuthState {
  final bool isLoading;
  final String? error;
  final UserModel? user;

  AuthState({this.isLoading = false, this.error, this.user});

  AuthState copyWith({bool? isLoading, String? error, UserModel? user}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(AuthState());

  Future<void> sendOTP(String phoneNumber) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authRepository.sendOTP(phoneNumber);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString(),
      );
    }
  }

  Future<void> verifyOTP(String phoneNumber, String otp) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authRepository.verifyOTP(phoneNumber, otp);
      state = state.copyWith(isLoading: false, user: user);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString(),
      );
    }
  }

  /// Google Sign-In. Returns result on success (caller handles navigation); null if cancelled.
  /// On error, sets state.error.
  Future<GoogleSignInResult?> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _authRepository.signInWithGoogle();
      state = state.copyWith(isLoading: false);
      if (result != null) {
        state = state.copyWith(user: result.user);
      }
      return result;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString(),
      );
      rethrow;
    }
  }

  /// Delete user account from backend (hard delete from MongoDB).
  /// Does not delete Firebase auth as per requirement.
  Future<void> deleteAccount() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await BackendAuthService.deleteAccount();
      state = state.copyWith(isLoading: false, user: null);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString(),
      );
      rethrow;
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
