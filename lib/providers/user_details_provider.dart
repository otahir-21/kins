import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kins_app/repositories/user_details_repository.dart';
import 'package:kins_app/services/bunny_cdn_service.dart';
import 'package:kins_app/config/bunny_cdn_config.dart';
import 'dart:io';

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
  final String? gender;
  final File? documentFile;
  final bool nameFilled;
  final bool genderFilled;
  final bool documentSelected;
  final String? documentUrl;
  final bool isSubmitting;

  UserDetailsState({
    this.isLoading = false,
    this.error,
    this.name,
    this.gender,
    this.documentFile,
    this.nameFilled = false,
    this.genderFilled = false,
    this.documentSelected = false,
    this.documentUrl,
    this.isSubmitting = false,
  });

  UserDetailsState copyWith({
    bool? isLoading,
    String? error,
    String? name,
    String? gender,
    File? documentFile,
    bool? nameFilled,
    bool? genderFilled,
    bool? documentSelected,
    String? documentUrl,
    bool? isSubmitting,
  }) {
    return UserDetailsState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      documentFile: documentFile ?? this.documentFile,
      nameFilled: nameFilled ?? this.nameFilled,
      genderFilled: genderFilled ?? this.genderFilled,
      documentSelected: documentSelected ?? this.documentSelected,
      documentUrl: documentUrl ?? this.documentUrl,
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

  void setGender(String gender) {
    state = state.copyWith(
      gender: gender,
      genderFilled: gender.trim().isNotEmpty,
      error: null,
    );
  }

  void setDocumentFile(File? file) {
    state = state.copyWith(
      documentFile: file,
      documentSelected: file != null,
      error: null,
    );
  }

  Future<void> submitUserDetails(String userId) async {
    if (state.name == null || state.name!.trim().isEmpty) {
      state = state.copyWith(error: 'Please enter your name');
      return;
    }

    if (state.gender == null || state.gender!.trim().isEmpty) {
      state = state.copyWith(error: 'Please select your gender');
      return;
    }

    state = state.copyWith(isSubmitting: true, error: null);

    try {
      String? documentUrl;

      // Upload document if provided
      if (state.documentFile != null) {
        debugPrint('📤 Uploading document to Bunny CDN...');
        documentUrl = await _repository.uploadDocument(
          userId: userId,
          documentFile: state.documentFile!,
        );
      }

      // Save user details to Firestore
      debugPrint('💾 Saving user details to Firestore...');
      await _repository.saveUserDetails(
        userId: userId,
        name: state.name!,
        gender: state.gender!,
        documentUrl: documentUrl,
      );

      state = state.copyWith(
        isSubmitting: false,
        documentUrl: documentUrl,
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
