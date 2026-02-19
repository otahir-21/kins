import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kins_app/core/network/backend_api_client.dart';

/// Response from GET /api/v1/groups
class GroupsListResponse {
  final List<GroupListItem> groups;
  final GroupsPagination pagination;

  const GroupsListResponse({
    required this.groups,
    required this.pagination,
  });

  static GroupsListResponse fromJson(Map<String, dynamic> json) {
    final list = json['groups'];
    final groups = list is List
        ? (list as List)
            .map((e) => GroupListItem.fromJson(
                e is Map<String, dynamic> ? e : <String, dynamic>{}))
            .toList()
        : <GroupListItem>[];
    final pag = json['pagination'];
    final pagination = pag is Map<String, dynamic>
        ? GroupsPagination.fromJson(pag)
        : GroupsPagination(page: 1, limit: 20, total: 0, hasMore: false);
    return GroupsListResponse(groups: groups, pagination: pagination);
  }
}

class GroupListItem {
  final String id;
  final String name;
  final String description;
  final String type; // interactive | updates_only
  final int memberCount;
  final String? imageUrl;
  final bool isMember;

  const GroupListItem({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.memberCount,
    this.imageUrl,
    required this.isMember,
  });

  static GroupListItem fromJson(Map<String, dynamic> json) {
    return GroupListItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? 'interactive',
      memberCount: (json['memberCount'] is int)
          ? json['memberCount'] as int
          : int.tryParse(json['memberCount']?.toString() ?? '0') ?? 0,
      imageUrl: json['imageUrl']?.toString(),
      isMember: json['isMember'] == true,
    );
  }
}

class GroupsPagination {
  final int page;
  final int limit;
  final int total;
  final bool hasMore;

  const GroupsPagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.hasMore,
  });

  static GroupsPagination fromJson(Map<String, dynamic> json) {
    return GroupsPagination(
      page: (json['page'] is int) ? json['page'] as int : int.tryParse(json['page']?.toString() ?? '1') ?? 1,
      limit: (json['limit'] is int) ? json['limit'] as int : int.tryParse(json['limit']?.toString() ?? '20') ?? 20,
      total: (json['total'] is int) ? json['total'] as int : int.tryParse(json['total']?.toString() ?? '0') ?? 0,
      hasMore: json['hasMore'] == true,
    );
  }
}

/// Response from POST /api/v1/groups (create group)
class CreateGroupResponse {
  final String id;
  final String name;
  final String description;
  final String type;
  final int memberCount;
  final String? imageUrl;

  const CreateGroupResponse({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.memberCount,
    this.imageUrl,
  });

  static CreateGroupResponse fromJson(Map<String, dynamic> json) {
    return CreateGroupResponse(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? 'interactive',
      memberCount: (json['memberCount'] is int)
          ? json['memberCount'] as int
          : int.tryParse(json['memberCount']?.toString() ?? '1') ?? 1,
      imageUrl: json['imageUrl']?.toString(),
    );
  }
}

/// Single group detail (GET /api/v1/groups/:groupId). Response has top-level [group] and [members].
class GroupDetailResponse {
  final String id;
  final String name;
  final String description;
  final String type;
  final int memberCount;
  final String? imageUrl;
  final bool isMember;
  final bool isAdmin;
  final List<GroupMemberInfo> members;

  const GroupDetailResponse({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.memberCount,
    this.imageUrl,
    this.isMember = false,
    this.isAdmin = false,
    required this.members,
  });

  /// Full API response: { group: { ... }, members: [ ... ] } or { success, group, members }.
  static GroupDetailResponse fromApiResponse(Map<String, dynamic> json) {
    final group = json['group'];
    final groupMap = group is Map<String, dynamic> ? group as Map<String, dynamic> : <String, dynamic>{};
    final list = json['members'];
    final members = list is List
        ? (list as List)
            .map((e) => GroupMemberInfo.fromJson(
                e is Map<String, dynamic> ? e : <String, dynamic>{}))
            .toList()
        : <GroupMemberInfo>[];
    return GroupDetailResponse(
      id: groupMap['id']?.toString() ?? '',
      name: groupMap['name']?.toString() ?? '',
      description: groupMap['description']?.toString() ?? '',
      type: groupMap['type']?.toString() ?? 'interactive',
      memberCount: (groupMap['memberCount'] is int)
          ? groupMap['memberCount'] as int
          : int.tryParse(groupMap['memberCount']?.toString() ?? '0') ?? 0,
      imageUrl: groupMap['imageUrl']?.toString(),
      isMember: groupMap['isMember'] == true,
      isAdmin: groupMap['isAdmin'] == true,
      members: members,
    );
  }
}

class GroupMemberInfo {
  final String id;
  final String name;
  final String? profilePictureUrl;
  final bool isAdmin;

  const GroupMemberInfo({
    required this.id,
    required this.name,
    this.profilePictureUrl,
    this.isAdmin = false,
  });

  static GroupMemberInfo fromJson(Map<String, dynamic> json) {
    return GroupMemberInfo(
      id: json['id']?.toString() ?? json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? json['username']?.toString() ?? 'Member',
      profilePictureUrl: json['profilePictureUrl']?.toString(),
      isAdmin: json['isAdmin'] == true,
    );
  }
}

/// Repository for groups API: GET list and POST create.
class GroupsRepository {
  /// GET /api/v1/groups with optional query params.
  /// [memberMe] = true => member=me
  /// [search] => search= or q=
  /// [type] => interactive or updates_only
  /// [page], [limit] for pagination (limit max 50).
  static Future<GroupsListResponse> getGroups({
    bool memberMe = false,
    String? search,
    String? type,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.clamp(1, 50).toString(),
    };
    if (memberMe) params['member'] = 'me';
    if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();
    if (type != null && type.isNotEmpty) params['type'] = type;
    final path = Uri(path: '/groups', queryParameters: params).toString();
    final json = await BackendApiClient.get(path);
    final success = json['success'] == true;
    if (!success) {
      throw Exception(json['error']?.toString() ?? json['message']?.toString() ?? 'Failed to load groups');
    }
    return GroupsListResponse.fromJson(json);
  }

  /// POST /api/v1/groups (multipart: name, description, type, image).
  /// [type] must be 'interactive' or 'updates_only'.
  static Future<CreateGroupResponse> createGroup({
    required String name,
    required String type,
    String description = '',
    File? image,
  }) async {
    final fields = <String, String>{
      'name': name.trim(),
      'type': type,
      if (description.trim().isNotEmpty) 'description': description.trim(),
    };
    List<http.MultipartFile>? files;
    if (image != null && await image.exists()) {
      final bytes = await image.readAsBytes();
      final name = image.path.split(RegExp(r'[/\\]')).last;
      if (name.isNotEmpty) {
        files = [
          http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename: name,
          ),
        ];
      }
    }
    final json = await BackendApiClient.postMultipart(
      '/groups',
      fields: fields,
      files: files,
    );
    final success = json['success'] == true;
    if (!success) {
      throw Exception(json['error']?.toString() ?? json['message']?.toString() ?? 'Failed to create group');
    }
    final group = json['group'];
    if (group is! Map<String, dynamic>) {
      throw Exception('Invalid create group response');
    }
    return CreateGroupResponse.fromJson(group);
  }

  /// POST /api/v1/groups/:groupId/avatar - Upload group image only (admins). Use this instead of sending image on PUT.
  /// Body: multipart/form-data with file in field [image]. Response: { success, group: { ..., imageUrl } }.
  static Future<void> uploadGroupAvatar(String groupId, File image) async {
    if (groupId.isEmpty || groupId == 'new' || !await image.exists()) {
      throw Exception('Invalid group or image');
    }
    final path = image.path;
    final rawName = path.split(RegExp(r'[/\\]')).last;
    final isPng = rawName.toLowerCase().endsWith('.png');
    final mimeType = http.MediaType(
      'image',
      isPng ? 'png' : 'jpeg',
    );
    final files = [
      await http.MultipartFile.fromPath(
        'image',
        path,
        filename: rawName.isNotEmpty && rawName.contains('.') ? rawName : 'image.jpg',
        contentType: mimeType,
      ),
    ];
    if (kDebugMode) {
      debugPrint('[GroupsRepository.uploadGroupAvatar] POST /groups/$groupId/avatar field=image path=$path');
    }
    final json = await BackendApiClient.postMultipart(
      '/groups/$groupId/avatar',
      files: files,
    );
    if (json['success'] != true) {
      throw Exception(
        json['error']?.toString() ?? json['message']?.toString() ?? 'Failed to upload group image',
      );
    }
    if (kDebugMode) {
      final group = json['group'];
      if (group is Map<String, dynamic>) {
        debugPrint('[GroupsRepository.uploadGroupAvatar] group.imageUrl = ${group['imageUrl']}');
      }
    }
  }

  /// PUT /api/v1/groups/:groupId - Update name, description, type only (JSON, no file). For image use [uploadGroupAvatar].
  static Future<void> updateGroup({
    required String groupId,
    required String name,
    required String description,
    required String type,
    File? image,
  }) async {
    if (groupId.isEmpty || groupId == 'new') {
      throw Exception('Invalid group');
    }
    if (kDebugMode) {
      debugPrint('[GroupsRepository.updateGroup] groupId=$groupId hasImage=${image != null && image.existsSync()}');
    }
    try {
      if (image != null && await image.exists()) {
        await uploadGroupAvatar(groupId, image);
      }
      final body = <String, dynamic>{
        'name': name.trim(),
        'type': type,
        'description': description.trim(),
      };
      if (kDebugMode) {
        debugPrint('[GroupsRepository.updateGroup] PUT /groups/$groupId (JSON) name, type, description');
      }
      final json = await BackendApiClient.put(
        '/groups/$groupId',
        body: body,
      );
      if (json['success'] != true) {
        throw Exception(
          json['error']?.toString() ?? json['message']?.toString() ?? 'Failed to update group',
        );
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[GroupsRepository.updateGroup] Error: $e');
        debugPrint('[GroupsRepository.updateGroup] Stack: $stack');
      }
      rethrow;
    }
  }

  /// GET /api/v1/groups/:groupId - Group detail + members. Response: group (id, name, description, type, memberCount, imageUrl, isMember, isAdmin), members (array).
  static Future<GroupDetailResponse?> getGroup(String groupId) async {
    if (groupId.isEmpty || groupId == 'new') return null;
    try {
      final json = await BackendApiClient.get('/groups/$groupId');
      if (json['success'] != true) return null;
      if (json['group'] is! Map<String, dynamic>) return null;
      return GroupDetailResponse.fromApiResponse(json);
    } catch (_) {
      return null;
    }
  }

  /// POST /api/v1/groups/:groupId/members - Add users to group.
  /// Body: {"userId": "..."} or {"userIds": ["id1", "id2"]}
  static Future<void> addGroupMembers(String groupId, List<String> userIds) async {
    if (groupId.isEmpty || groupId == 'new') {
      throw Exception('Invalid group');
    }
    if (userIds.isEmpty) return;
    final body = userIds.length == 1
        ? <String, dynamic>{'userId': userIds.first}
        : <String, dynamic>{'userIds': userIds};
    final json = await BackendApiClient.post(
      '/groups/$groupId/members',
      body: body,
    );
    if (json['success'] != true) {
      throw Exception(
        json['error']?.toString() ?? json['message']?.toString() ?? 'Failed to add members',
      );
    }
  }

  /// POST /api/v1/groups/:groupId/join - Current user joins the group.
  static Future<void> joinGroup(String groupId) async {
    if (groupId.isEmpty || groupId == 'new') {
      throw Exception('Invalid group');
    }
    final json = await BackendApiClient.post('/groups/$groupId/join');
    if (json['success'] != true) {
      throw Exception(
        json['error']?.toString() ?? json['message']?.toString() ?? 'Failed to join group',
      );
    }
  }

  /// DELETE /api/v1/groups/:groupId - Delete group (admins only). Response: { success: true, message: "Group deleted." }
  static Future<void> deleteGroup(String groupId) async {
    if (groupId.isEmpty || groupId == 'new') {
      throw Exception('Invalid group');
    }
    final json = await BackendApiClient.delete('/groups/$groupId');
    if (json['success'] != true) {
      throw Exception(
        json['error']?.toString() ?? json['message']?.toString() ?? 'Failed to delete group',
      );
    }
  }
}
