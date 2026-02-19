import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kins_app/models/group_chat_message.dart';
import 'package:kins_app/repositories/group_chat_repository.dart';

final groupChatRepositoryProvider = Provider<GroupChatRepository>((ref) => GroupChatRepository());

final groupMessagesStreamProvider = StreamProvider.autoDispose.family<List<GroupChatMessage>, String>((ref, groupId) {
  return ref.watch(groupChatRepositoryProvider).streamMessages(groupId);
});
