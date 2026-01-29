import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kins_app/models/chat_model.dart';
import 'package:kins_app/models/user_model.dart';
import 'package:kins_app/providers/user_details_provider.dart';
import 'package:kins_app/repositories/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) => ChatRepository());

final myChatsStreamProvider = StreamProvider.autoDispose<List<ChatConversation>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(chatRepositoryProvider).streamChats(uid);
});

final chatConversationProvider =
    FutureProvider.autoDispose.family<ChatConversation?, String>((ref, chatId) async {
  return ref.watch(chatRepositoryProvider).getChatOnce(chatId);
});

final chatStreamProvider = StreamProvider.autoDispose.family<ChatConversation?, String>((ref, chatId) {
  return ref.watch(chatRepositoryProvider).streamChat(chatId);
});

/// Other user's display info (name, avatar) by userId. Used in chat list and conversation.
final otherUserByIdProvider =
    FutureProvider.autoDispose.family<UserModel?, String>((ref, userId) async {
  if (userId.isEmpty) return null;
  final repo = ref.watch(userDetailsRepositoryProvider);
  return repo.getUserDetails(userId);
});
