import 'package:flutter/foundation.dart';
import 'package:kins_app/core/network/backend_api_client.dart';

/// User item for lists (e.g. add to group).
class UserListItem {
  final String id;
  final String name;
  final String? profilePictureUrl;

  const UserListItem({
    required this.id,
    required this.name,
    this.profilePictureUrl,
  });

  static UserListItem fromJson(Map<String, dynamic> json) {
    return UserListItem(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['username']?.toString() ?? 'User',
      profilePictureUrl: json['profilePictureUrl']?.toString(),
    );
  }
}

/// GET /api/v1/users - List users (for add-to-group, etc.). Query: page, limit, optional search.
class UsersRepository {
  static Future<List<UserListItem>> getUsers({
    int page = 1,
    int limit = 50,
    String? search,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    final path = Uri(path: '/users', queryParameters: params).toString();
    try {
      final response = await BackendApiClient.get(path);
      return _parseUserListFromResponse(response);
    } catch (e) {
      if (kDebugMode) debugPrint('UsersRepository.getUsers error: $e');
      return [];
    }
  }

  /// Try all ways to get a user list so the add-members dialog shows users on open.
  /// Tries: GET /users, then GET /users/search (no q). Parses Map or direct List.
  static Future<List<UserListItem>> getUsersForAddMember() async {
    // 1) GET /users?page=1&limit=100
    try {
      final list = await getUsers(limit: 100);
      if (list.isNotEmpty) {
        if (kDebugMode) debugPrint('UsersRepository.getUsersForAddMember: got ${list.length} from GET /users');
        return list;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('UsersRepository.getUsersForAddMember GET /users: $e');
    }
    // 2) GET /users/search (no query - some backends return all)
    try {
      final list = await searchUsers('');
      if (list.isNotEmpty) {
        if (kDebugMode) debugPrint('UsersRepository.getUsersForAddMember: got ${list.length} from GET /users/search');
        return list;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('UsersRepository.getUsersForAddMember GET /users/search: $e');
    }
    return [];
  }

  static List<UserListItem> _parseUserListFromResponse(dynamic response) {
    if (response == null) return [];
    if (response is List) {
      return response
          .map((e) => UserListItem.fromJson(
              e is Map<String, dynamic> ? e : <String, dynamic>{}))
          .where((u) => u.id.isNotEmpty)
          .toList();
    }
    if (response is! Map<String, dynamic>) return [];
    final json = response;
    if (json['success'] == false) return [];
    final list = json['users'] ?? json['data'] ?? json['result'];
    if (list is! List) return [];
    return list
        .map((e) => UserListItem.fromJson(
            e is Map<String, dynamic> ? e : <String, dynamic>{}))
        .where((u) => u.id.isNotEmpty)
        .toList();
  }

  /// GET /api/v1/users/search?q=... - Search users (for "Add people" in group).
  static Future<List<UserListItem>> searchUsers(String query) async {
    final q = query.trim();
    final path = q.isEmpty
        ? '/users/search'
        : Uri(path: '/users/search', queryParameters: {'q': q}).toString();
    try {
      final response = await BackendApiClient.get(path);
      return _parseUserListFromResponse(response);
    } catch (e) {
      if (kDebugMode) debugPrint('UsersRepository.searchUsers error: $e');
      return [];
    }
  }
}
