import 'package:flutter/foundation.dart';
import 'package:kins_app/services/follow_service.dart';

/// Follow operations via backend API (no Firebase).
class FollowRepository {
  /// Get follow status for a user (current user's relationship).
  Future<FollowStatusResponse?> getFollowStatus(String userId) async {
    try {
      return await FollowService.getFollowStatus(userId);
    } catch (e) {
      debugPrint('❌ FollowRepository.getFollowStatus: $e');
      return null;
    }
  }

  /// Follow a user.
  Future<FollowStatusResponse?> follow(String userId) async {
    try {
      return await FollowService.follow(userId);
    } catch (e) {
      debugPrint('❌ FollowRepository.follow: $e');
      rethrow;
    }
  }

  /// Unfollow a user.
  Future<FollowStatusResponse?> unfollow(String userId) async {
    try {
      return await FollowService.unfollow(userId);
    } catch (e) {
      debugPrint('❌ FollowRepository.unfollow: $e');
      rethrow;
    }
  }

  /// Get paginated followers list.
  Future<FollowListResponse> getFollowers(String userId, {int page = 1, int limit = 20}) async {
    try {
      return await FollowService.getFollowers(userId, page: page, limit: limit);
    } catch (e) {
      debugPrint('❌ FollowRepository.getFollowers: $e');
      return FollowListResponse(items: []);
    }
  }

  /// Get paginated following list.
  Future<FollowListResponse> getFollowing(String userId, {int page = 1, int limit = 20}) async {
    try {
      return await FollowService.getFollowing(userId, page: page, limit: limit);
    } catch (e) {
      debugPrint('❌ FollowRepository.getFollowing: $e');
      return FollowListResponse(items: []);
    }
  }
}
