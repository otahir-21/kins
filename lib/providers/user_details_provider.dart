import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kins_app/repositories/user_details_repository.dart';
import 'package:kins_app/services/bunny_cdn_service.dart';
import 'package:kins_app/config/bunny_cdn_config.dart';

// Bunny CDN Configuration Provider
final bunnyCDNServiceProvider = Provider<BunnyCDNService?>((ref) {
  // Option 1: Try environment variables first (for production)
  const envStorageZone = String.fromEnvironment('BUNNY_STORAGE_ZONE', defaultValue: '');
  const envApiKey = String.fromEnvironment('BUNNY_API_KEY', defaultValue: '');
  const envCdnHostname = String.fromEnvironment('BUNNY_CDN_HOSTNAME', defaultValue: '');

  // Option 2: Use config file (for development)
  final storageZoneName = envStorageZone.isNotEmpty 
      ? envStorageZone 
      : BunnyCDNConfig.storageZoneName;
  final apiKey = envApiKey.isNotEmpty 
      ? envApiKey 
      : BunnyCDNConfig.apiKey;
  final cdnHostname = envCdnHostname.isNotEmpty 
      ? envCdnHostname 
      : BunnyCDNConfig.cdnHostname;

  // Check if configuration is complete
  if (storageZoneName == 'YOUR_STORAGE_ZONE_NAME' || 
      storageZoneName.isEmpty || 
      apiKey.isEmpty || 
      cdnHostname.isEmpty) {
    debugPrint('⚠️ Bunny CDN not configured. Document upload will be disabled.');
    debugPrint('💡 Please update lib/config/bunny_cdn_config.dart with your storage zone name.');
    return null;
  }

  return BunnyCDNService(
    storageZoneName: storageZoneName,
    apiKey: apiKey,
    cdnHostname: cdnHostname,
  );
});

// User Details Repository Provider
final userDetailsRepositoryProvider = Provider<UserDetailsRepository>((ref) {
  final bunnyCDN = ref.watch(bunnyCDNServiceProvider);
  return UserDetailsRepository(bunnyCDN: bunnyCDN);
});

// User Details State
class UserDetailsState {
  final bool isLoading;
  final String? error;
  final String? name;
  final String? email;
  final DateTime? dateOfBirth;
  final bool nameFilled;
  final bool emailFilled;
  final bool dobFilled;
  final bool isSubmitting;

  UserDetailsState({
    this.isLoading = false,
    this.error,
    this.name,
    this.email,
    this.dateOfBirth,
    this.nameFilled = false,
    this.emailFilled = false,
    this.dobFilled = false,
    this.isSubmitting = false,
  });

  UserDetailsState copyWith({
    bool? isLoading,
    String? error,
    String? name,
    String? email,
    DateTime? dateOfBirth,
    bool? nameFilled,
    bool? emailFilled,
    bool? dobFilled,
    bool? isSubmitting,
  }) {
    return UserDetailsState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      name: name ?? this.name,
      email: email ?? this.email,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      nameFilled: nameFilled ?? this.nameFilled,
      emailFilled: emailFilled ?? this.emailFilled,
      dobFilled: dobFilled ?? this.dobFilled,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

// User Details Notifier
class UserDetailsNotifier extends StateNotifier<UserDetailsState> {
  final UserDetailsRepository _repository;

  UserDetailsNotifier(this._repository) : super(UserDetailsState());

  void setName(String name) {
    state = state.copyWith(
      name: name,
      nameFilled: name.trim().isNotEmpty,
      error: null,
    );
  }

  void setEmail(String email) {
    state = state.copyWith(
      email: email,
      emailFilled: email.trim().isNotEmpty && email.contains('@'),
      error: null,
    );
  }

  void setDateOfBirth(DateTime dateOfBirth) {
    state = state.copyWith(
      dateOfBirth: dateOfBirth,
      dobFilled: true,
      error: null,
    );
  }

  Future<void> submitUserDetails(String userId) async {
    if (state.name == null || state.name!.trim().isEmpty) {
      state = state.copyWith(error: 'Please enter your full name');
      return;
    }

    if (state.email == null || state.email!.trim().isEmpty) {
      state = state.copyWith(error: 'Please enter your email');
      return;
    }

    if (state.dateOfBirth == null) {
      state = state.copyWith(error: 'Please select your date of birth');
      return;
    }

    state = state.copyWith(isSubmitting: true, error: null);

    try {
      // Save user details to Firestore
      debugPrint('💾 Saving user details to Firestore...');
      await _repository.saveUserDetails(
        userId: userId,
        name: state.name!,
        email: state.email!,
        dateOfBirth: state.dateOfBirth!,
      );

      state = state.copyWith(
        isSubmitting: false,
      );

      debugPrint('✅ User details saved successfully');
    } catch (e) {
      debugPrint('❌ Failed to submit user details: $e');
      state = state.copyWith(
        isSubmitting: false,
        error: 'Failed to save: ${e.toString()}',
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// User Details Provider
final userDetailsProvider =
    StateNotifierProvider<UserDetailsNotifier, UserDetailsState>((ref) {
  final repository = ref.watch(userDetailsRepositoryProvider);
  return UserDetailsNotifier(repository);
});
