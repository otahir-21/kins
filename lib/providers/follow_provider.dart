import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kins_app/repositories/follow_repository.dart';
import 'package:kins_app/services/follow_service.dart';

export 'package:kins_app/services/follow_service.dart' show FollowUserInfo, FollowStatusResponse, FollowListResponse;

final followRepositoryProvider = Provider<FollowRepository>((ref) {
  return FollowRepository();
});

/// Follower count for current user (from GET /me, not a separate call).
/// Use Profile screen's _fetchUser which gets counts from /me.

/// Followers list for a user (paginated). Param: userId.
final followersListProvider = FutureProvider.autoDispose.family<FollowListResponse, String>((ref, userId) async {
  final repo = ref.watch(followRepositoryProvider);
  return repo.getFollowers(userId, page: 1, limit: 50);
});

/// Following list for a user (paginated). Param: userId.
final followingListProvider = FutureProvider.autoDispose.family<FollowListResponse, String>((ref, userId) async {
  final repo = ref.watch(followRepositoryProvider);
  return repo.getFollowing(userId, page: 1, limit: 50);
});
