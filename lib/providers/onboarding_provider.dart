import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kins_app/core/utils/storage_service.dart';
import 'package:kins_app/core/constants/app_constants.dart';

// Onboarding State Provider
final onboardingCompletedProvider = StateProvider<bool>((ref) {
  return StorageService.getBool(AppConstants.keyOnboardingCompleted) ?? false;
});

// Onboarding Notifier
class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier() : super(false) {
    _loadOnboardingStatus();
  }

  Future<void> _loadOnboardingStatus() async {
    final completed =
        StorageService.getBool(AppConstants.keyOnboardingCompleted) ?? false;
    state = completed;
  }

  Future<void> completeOnboarding() async {
    await StorageService.setBool(AppConstants.keyOnboardingCompleted, true);
    state = true;
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, bool>((ref) {
  return OnboardingNotifier();
});
