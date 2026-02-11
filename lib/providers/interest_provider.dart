import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kins_app/models/interest_model.dart';
import 'package:kins_app/repositories/interest_repository.dart';

// Interest Repository Provider
final interestRepositoryProvider = Provider<InterestRepository>((ref) {
  return InterestRepository();
});

// Interest State
class InterestState {
  final bool isLoading;
  final String? error;
  final List<InterestModel> interests;
  final Set<String> selectedInterestIds;

  InterestState({
    this.isLoading = false,
    this.error,
    this.interests = const [],
    this.selectedInterestIds = const {},
  });

  InterestState copyWith({
    bool? isLoading,
    String? error,
    List<InterestModel>? interests,
    Set<String>? selectedInterestIds,
  }) {
    return InterestState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      interests: interests ?? this.interests,
      selectedInterestIds: selectedInterestIds ?? this.selectedInterestIds,
    );
  }

  List<InterestModel> get selectedInterests {
    return interests
        .where((interest) => selectedInterestIds.contains(interest.id))
        .toList();
  }
}

// Interest Notifier
class InterestNotifier extends StateNotifier<InterestState> {
  final InterestRepository _repository;

  InterestNotifier(this._repository) : super(InterestState());

  /// Load master list from GET /interests and, when [userId] is set, user's selection from GET /me/interests.
  Future<void> loadInterests([String? userId]) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final interests = await _repository.getInterests();
      Set<String> selected = state.selectedInterestIds;
      if (userId != null && userId.isNotEmpty) {
        final ids = await _repository.getUserInterests(userId);
        selected = ids.toSet();
      }
      state = state.copyWith(
        interests: interests,
        selectedInterestIds: selected,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('❌ Failed to load interests: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load interests: ${e.toString()}',
      );
    }
  }

  void toggleInterest(String interestId) {
    final currentSelected = Set<String>.from(state.selectedInterestIds);
    
    if (currentSelected.contains(interestId)) {
      currentSelected.remove(interestId);
    } else {
      currentSelected.add(interestId);
    }

    state = state.copyWith(selectedInterestIds: currentSelected);
  }

  Future<void> saveUserInterests(String userId) async {
    if (state.selectedInterestIds.isEmpty) {
      state = state.copyWith(error: 'Please select at least one interest');
      return;
    }

    try {
      await _repository.saveUserInterests(
        userId: userId,
        interestIds: state.selectedInterestIds.toList(),
      );
      debugPrint('✅ User interests saved successfully');
    } catch (e) {
      debugPrint('❌ Failed to save user interests: $e');
      state = state.copyWith(
        error: 'Failed to save interests: ${e.toString()}',
      );
      rethrow;
    }
  }
}

// Interest Provider
final interestProvider =
    StateNotifierProvider<InterestNotifier, InterestState>((ref) {
  final repository = ref.watch(interestRepositoryProvider);
  return InterestNotifier(repository);
});
