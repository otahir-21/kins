import 'package:flutter/foundation.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/network/backend_api_client.dart';

/// Public user profile from follow API.
class FollowUserInfo {
  final String id;
  final String? name;
  final String? username;
  /// Backend may send this (name → username → "User"); use in chat list/header.
  final String? displayName;
  final String? profilePictureUrl;
  final String? bio;
  final int followerCount;
  final int followingCount;
  final bool isFollowedByMe;

  FollowUserInfo({
    required this.id,
    this.name,
    this.username,
    this.displayName,
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
      displayName: json['displayName']?.toString(),
      profilePictureUrl: json['profilePictureUrl']?.toString(),
      bio: json['bio']?.toString(),
      followerCount: (json['followerCount'] ?? 0) as int,
      followingCount: (json['followingCount'] ?? 0) as int,
      isFollowedByMe: json['isFollowedByMe'] == true,
    );
  }

  /// Display name for chat/list: use backend displayName when present, else name → username → 'User'.
  String get displayNameForChat {
    if (displayName != null && displayName!.trim().isNotEmpty) return displayName!.trim();
    if (name != null && name!.trim().isNotEmpty) return name!.trim();
    if (username != null && username!.trim().isNotEmpty) return username!.trim();
    return 'User';
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
  /// Expects { success: true, user: { id, name, username, displayName, profilePictureUrl, ... } }.
  /// If backend returns user fields at top level (no "user" wrapper), we parse that too.
  static Future<FollowUserInfo?> getPublicProfile(String userId) async {
    final path = '/users/$userId';
    final url = '${AppConstants.apiV1BaseUrl}$path';
    if (kDebugMode) debugPrint('🔵 [getPublicProfile] GET $url');
    try {
      final res = await BackendApiClient.get(path);
      if (kDebugMode) {
        debugPrint('🔵 [getPublicProfile] response keys: ${res.keys.join(', ')}');
        debugPrint('🔵 [getPublicProfile] success=${res['success']}');
        if (res['user'] is Map) {
          final u = res['user'] as Map;
          debugPrint('🔵 [getPublicProfile] user.displayName=${u['displayName']} user.name=${u['name']} user.username=${u['username']}');
        }
      }
      if (res['success'] != true) {
        if (kDebugMode) debugPrint('❌ [getPublicProfile] success != true, returning null');
        return null;
      }
      // Backend may use "user" or "data" for the profile object
      Map<String, dynamic>? userMap = res['user'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(res['user'] as Map<String, dynamic>)
          : (res['data'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(res['data'] as Map<String, dynamic>)
              : null);
      if (userMap == null && (res['name'] != null || res['username'] != null || res['id'] != null || res['_id'] != null)) {
        userMap = Map<String, dynamic>.from(res);
      }
      if (userMap == null) {
        if (kDebugMode) debugPrint('❌ [getPublicProfile] no user/data object in response');
        return null;
      }
      if ((userMap['id'] == null || userMap['id'].toString().isEmpty) && (userMap['_id'] == null || userMap['_id'].toString().isEmpty)) {
        userMap = Map<String, dynamic>.from(userMap)..['id'] = userId;
      }
      final info = FollowUserInfo.fromJson(userMap);
      if (kDebugMode) debugPrint('🔵 [getPublicProfile] parsed displayNameForChat=${info.displayNameForChat}');
      return info;
    } catch (e) {
      debugPrint('❌ [getPublicProfile] $url -> $e');
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
