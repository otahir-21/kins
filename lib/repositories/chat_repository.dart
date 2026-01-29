import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:kins_app/models/chat_model.dart';

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _chatsCollection = 'chats';
  static const String _messagesSubcollection = 'messages';
  static const int _messagesLimit = 30;
  static const int _chatsListLimit = 50;

  /// Deterministic 1:1 chat ID so we can get-or-create without a query.
  static String chatIdForUsers(String uid1, String uid2) {
    final list = [uid1, uid2]..sort();
    return '${list[0]}_${list[1]}';
  }

  /// Epoch timestamp for new chats (no messages yet). Firestore orderBy requires the field to exist.
  static final Timestamp _epochTimestamp = Timestamp.fromDate(DateTime.utc(1970, 1, 1));

  /// Get existing 1:1 chat or create it. Returns chat ID.
  Future<String> getOrCreate1v1Chat(String uid1, String uid2) async {
    final cid = chatIdForUsers(uid1, uid2);
    final ref = _firestore.collection(_chatsCollection).doc(cid);
    final doc = await ref.get();
    if (doc.exists) return cid;
    final participantIds = [uid1, uid2]..sort();
    await ref.set({
      'participantIds': participantIds,
      'lastMessageAt': _epochTimestamp, // required for orderBy; no message yet
      'lastMessageText': '',
      'lastMessageSenderId': null,
      'lastDeliveredAtBy': {},
      'lastSeenAtBy': {},
      'createdAt': FieldValue.serverTimestamp(),
    });
    debugPrint('✅ Chat created: $cid');
    return cid;
  }

  /// Stream of chat list for current user. Sorted by lastMessageAt in memory to avoid composite index.
  Stream<List<ChatConversation>> streamChats(String myUid) {
    return _firestore
        .collection(_chatsCollection)
        .where('participantIds', arrayContains: myUid)
        .limit(_chatsListLimit)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => ChatConversation.fromFirestore(doc.id, doc.data()))
              .toList();
          list.sort((a, b) {
            final aTime = a.lastMessageAt ?? DateTime.utc(1970);
            final bTime = b.lastMessageAt ?? DateTime.utc(1970);
            return bTime.compareTo(aTime); // newest first
          });
          return list;
        });
  }

  /// Stream of messages for a chat (paginated, newest first). Detach when leaving screen.
  Stream<List<ChatMessage>> streamMessages(String chatId, {int limit = _messagesLimit}) {
    return _firestore
        .collection(_chatsCollection)
        .doc(chatId)
        .collection(_messagesSubcollection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ChatMessage.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  /// Send a text message. Updates chat doc last-message fields in same batch (1 write for message + 1 for chat).
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
  }) async {
    final chatRef = _firestore.collection(_chatsCollection).doc(chatId);
    final messagesRef = chatRef.collection(_messagesSubcollection);
    final messageRef = messagesRef.doc();

    final batch = _firestore.batch();
    batch.set(messageRef, {
      'senderId': senderId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(chatRef, {
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageText': text,
      'lastMessageSenderId': senderId,
    });
    await batch.commit();
    debugPrint('✅ Message sent in chat $chatId');
  }

  /// Mark chat as delivered for this user (e.g. when they open the chat). One write.
  Future<void> markDelivered(String chatId, String userId) async {
    await _firestore.collection(_chatsCollection).doc(chatId).update({
      'lastDeliveredAtBy.$userId': FieldValue.serverTimestamp(),
    });
  }

  /// Mark chat as seen for this user (when they open the chat). One write.
  Future<void> markSeen(String chatId, String userId) async {
    await _firestore.collection(_chatsCollection).doc(chatId).update({
      'lastSeenAtBy.$userId': FieldValue.serverTimestamp(),
    });
  }

  /// Mark both delivered and seen in one write (when user opens chat).
  Future<void> markDeliveredAndSeen(String chatId, String userId) async {
    await _firestore.collection(_chatsCollection).doc(chatId).update({
      'lastDeliveredAtBy.$userId': FieldValue.serverTimestamp(),
      'lastSeenAtBy.$userId': FieldValue.serverTimestamp(),
    });
  }

  /// Get chat doc once (for lastDeliveredAtBy / lastSeenAtBy to show ticks).
  Future<ChatConversation?> getChatOnce(String chatId) async {
    final doc = await _firestore.collection(_chatsCollection).doc(chatId).get();
    if (!doc.exists) return null;
    return ChatConversation.fromFirestore(doc.id, doc.data()!);
  }

  /// Stream chat doc (for live delivery/seen updates).
  Stream<ChatConversation?> streamChat(String chatId) {
    return _firestore
        .collection(_chatsCollection)
        .doc(chatId)
        .snapshots()
        .map((doc) => doc.exists ? ChatConversation.fromFirestore(doc.id, doc.data()!) : null);
  }
}
