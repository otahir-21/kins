import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kins_app/models/chat_model.dart';
import 'package:kins_app/models/group_chat_message.dart';
import 'package:kins_app/repositories/chat_repository.dart';
import 'package:kins_app/repositories/direct_chat_repository.dart';
import 'package:kins_app/services/follow_service.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) => ChatRepository());

/// 1:1 direct chat (Firestore conversations/). Use this for Chats tab and conversation screen.
final directChatRepositoryProvider = Provider<DirectChatRepository>((ref) => DirectChatRepository());

/// Stream of 1:1 conversations for the Chats tab (conversations where participantIds contains myUid).
final myChatsStreamProvider = StreamProvider.autoDispose<List<ChatConversation>>((ref) {
  final uid = currentUserId;
  if (uid.isEmpty) return Stream.value([]);
  return ref.watch(directChatRepositoryProvider).streamConversations(uid);
});

final chatConversationProvider =
    FutureProvider.autoDispose.family<ChatConversation?, String>((ref, chatId) async {
  return ref.watch(directChatRepositoryProvider).getConversationOnce(chatId);
});

final chatStreamProvider = StreamProvider.autoDispose.family<ChatConversation?, String>((ref, chatId) {
  return ref.watch(directChatRepositoryProvider).streamConversation(chatId);
});

/// Stream of messages for a 1:1 conversation (conversationId = chatId).
final directMessagesStreamProvider = StreamProvider.autoDispose.family<List<GroupChatMessage>, String>((ref, conversationId) {
  return ref.watch(directChatRepositoryProvider).streamMessages(conversationId);
});

/// Other user's display info (name, avatar) by userId. Uses GET /users/:userId, fallback GET /users/:userId/follow/status.
final otherUserByIdProvider =
    FutureProvider.autoDispose.family<FollowUserInfo?, String>((ref, userId) async {
  if (userId.isEmpty) return null;
  final profile = await FollowService.getPublicProfile(userId);
  if (profile != null) return profile;
  final status = await FollowService.getFollowStatus(userId);
  return status?.user;
});
