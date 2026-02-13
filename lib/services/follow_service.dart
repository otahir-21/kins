import 'package:flutter/foundation.dart';
import 'package:kins_app/core/network/backend_api_client.dart';

/// Public user profile from follow API.
class FollowUserInfo {
  final String id;
  final String? name;
  final String? username;
  final String? profilePictureUrl;
  final String? bio;
  final int followerCount;
  final int followingCount;
  final bool isFollowedByMe;

  FollowUserInfo({
    required this.id,
    this.name,
    this.username,
    this.profilePictureUrl,
    this.bio,
    this.followerCount = 0,
    this.followingCount = 0,
    this.isFollowedByMe = false,
  });

  factory FollowUserInfo.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? json['_id']?.toString() ?? '';
    return FollowUserInfo(
      id: id,
      name: json['name']?.toString(),
      username: json['username']?.toString(),
      profilePictureUrl: json['profilePictureUrl']?.toString(),
      bio: json['bio']?.toString(),
      followerCount: (json['followerCount'] ?? 0) as int,
      followingCount: (json['followingCount'] ?? 0) as int,
      isFollowedByMe: json['isFollowedByMe'] == true,
    );
  }
}

/// Follow status response.
class FollowStatusResponse {
  final bool following;
  final int followerCount;
  final int followingCount;
  final FollowUserInfo? user;

  FollowStatusResponse({
    required this.following,
    this.followerCount = 0,
    this.followingCount = 0,
    this.user,
  });
}

/// Paginated list response.
class FollowListResponse {
  final List<FollowUserInfo> items;
  final int page;
  final int limit;
  final int total;
  final bool hasMore;

  FollowListResponse({
    required this.items,
    this.page = 1,
    this.limit = 20,
    this.total = 0,
    this.hasMore = false,
  });
}

/// Backend Follow API (GET/POST/DELETE /users/:userId/follow, followers, following).
class FollowService {
  FollowService._();

  /// GET /users/:userId - Public profile.
  static Future<FollowUserInfo?> getPublicProfile(String userId) async {
    try {
      final res = await BackendApiClient.get('/users/$userId');
      if (res['success'] != true) return null;
      final user = res['user'];
      if (user is! Map<String, dynamic>) return null;
      return FollowUserInfo.fromJson(Map<String, dynamic>.from(user));
    } catch (e) {
      debugPrint('❌ FollowService.getPublicProfile: $e');
      return null;
    }
  }

  /// GET /users/:userId/follow/status - Follow status + user profile.
  static Future<FollowStatusResponse?> getFollowStatus(String userId) async {
    try {
      final res = await BackendApiClient.get('/users/$userId/follow/status');
      if (res['success'] != true) return null;
      FollowUserInfo? user;
      final u = res['user'];
      if (u is Map<String, dynamic>) {
        user = FollowUserInfo.fromJson(Map<String, dynamic>.from(u));
      }
      return FollowStatusResponse(
        following: res['following'] == true,
        followerCount: (res['followerCount'] ?? 0) as int,
        followingCount: (res['followingCount'] ?? 0) as int,
        user: user,
      );
    } catch (e) {
      debugPrint('❌ FollowService.getFollowStatus: $e');
      return null;
    }
  }

  /// POST /users/:userId/follow - Follow a user.
  static Future<FollowStatusResponse?> follow(String userId) async {
    try {
      final res = await BackendApiClient.post('/users/$userId/follow');
      if (res['success'] != true) return null;
      return FollowStatusResponse(
        following: res['following'] == true,
        followerCount: (res['followerCount'] ?? 0) as int,
        followingCount: (res['followingCount'] ?? 0) as int,
      );
    } catch (e) {
      debugPrint('❌ FollowService.follow: $e');
      rethrow;
    }
  }

  /// DELETE /users/:userId/follow - Unfollow a user.
  static Future<FollowStatusResponse?> unfollow(String userId) async {
    try {
      final res = await BackendApiClient.delete('/users/$userId/follow');
      if (res['success'] != true) return null;
      return FollowStatusResponse(
        following: res['following'] == true,
        followerCount: (res['followerCount'] ?? 0) as int,
        followingCount: (res['followingCount'] ?? 0) as int,
      );
    } catch (e) {
      debugPrint('❌ FollowService.unfollow: $e');
      rethrow;
    }
  }

  /// GET /users/:userId/followers - Paginated followers.
  static Future<FollowListResponse> getFollowers(String userId, {int page = 1, int limit = 20}) async {
    try {
      final res = await BackendApiClient.get('/users/$userId/followers?page=$page&limit=$limit');
      if (res['success'] != true) return FollowListResponse(items: []);
      final list = res['followers'] as List<dynamic>? ?? [];
      final items = list
          .whereType<Map<String, dynamic>>()
          .map((e) => FollowUserInfo.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final pag = res['pagination'] as Map<String, dynamic>?;
      final total = (pag?['total'] ?? 0) as int;
      final hasMore = (pag?['hasMore'] ?? (items.length >= limit)) as bool;
      return FollowListResponse(
        items: items,
        page: (pag?['page'] ?? page) as int,
        limit: (pag?['limit'] ?? limit) as int,
        total: total,
        hasMore: hasMore,
      );
    } catch (e) {
      debugPrint('❌ FollowService.getFollowers: $e');
      return FollowListResponse(items: []);
    }
  }

  /// GET /users/:userId/following - Paginated following.
  static Future<FollowListResponse> getFollowing(String userId, {int page = 1, int limit = 20}) async {
    try {
      final res = await BackendApiClient.get('/users/$userId/following?page=$page&limit=$limit');
      if (res['success'] != true) return FollowListResponse(items: []);
      final list = res['following'] as List<dynamic>? ?? [];
      final items = list
          .whereType<Map<String, dynamic>>()
          .map((e) => FollowUserInfo.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final pag = res['pagination'] as Map<String, dynamic>?;
      final total = (pag?['total'] ?? 0) as int;
      final hasMore = (pag?['hasMore'] ?? (items.length >= limit)) as bool;
      return FollowListResponse(
        items: items,
        page: (pag?['page'] ?? page) as int,
        limit: (pag?['limit'] ?? limit) as int,
        total: total,
        hasMore: hasMore,
      );
    } catch (e) {
      debugPrint('❌ FollowService.getFollowing: $e');
      return FollowListResponse(items: []);
    }
  }
}
