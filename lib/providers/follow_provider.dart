import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:kins_app/repositories/follow_repository.dart';

final followRepositoryProvider = Provider<FollowRepository>((ref) {
  return FollowRepository();
});

/// Stream follower count for current user (for profile).
final myFollowerCountStreamProvider = StreamProvider<int>((ref) {
  final uid = currentUserId;
  if (uid.isEmpty) return Stream.value(0);
  return ref.watch(followRepositoryProvider).streamFollowerCount(uid);
});

/// Stream following count for current user (for profile).
final myFollowingCountStreamProvider = StreamProvider<int>((ref) {
  final uid = currentUserId;
  if (uid.isEmpty) return Stream.value(0);
  return ref.watch(followRepositoryProvider).streamFollowingCount(uid);
});

/// Stream followers list for a user (param: userId).
final followersListStreamProvider = StreamProvider.autoDispose.family<List<FollowUserInfo>, String>((ref, userId) {
  return ref.watch(followRepositoryProvider).streamFollowers(userId);
});

/// Stream following list for a user (param: userId).
final followingListStreamProvider = StreamProvider.autoDispose.family<List<FollowUserInfo>, String>((ref, userId) {
  return ref.watch(followRepositoryProvider).streamFollowing(userId);
});
