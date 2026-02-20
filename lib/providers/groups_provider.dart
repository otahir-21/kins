import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kins_app/repositories/groups_repository.dart';

/// Groups list for home screen (GET /groups, same API as Chat tab).
final homeGroupsProvider = FutureProvider.autoDispose<GroupsListResponse>((ref) async {
  return GroupsRepository.getGroups(page: 1, limit: 20);
});
