import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:kins_app/models/chat_model.dart';
import 'package:kins_app/models/group_chat_message.dart';

const String _conversationsCollection = 'conversations';
const String _messagesSubcollection = 'messages';
const String _storageConversationsPath = 'chat/conversations';

/// 1:1 direct chat using Firestore conversations/{conversationId}/messages
/// and Storage chat/conversations/{conversationId}/. conversationId = sorted uid1_uid2.
class DirectChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Deterministic conversation id so both users use the same doc.
  static String conversationIdFor(String uid1, String uid2) {
    final list = [uid1, uid2]..sort();
    return '${list[0]}_${list[1]}';
  }

  DocumentReference<Map<String, dynamic>> _conversationRef(String conversationId) {
    return _firestore.collection(_conversationsCollection).doc(conversationId);
  }

  CollectionReference<Map<String, dynamic>> _messagesRef(String conversationId) {
    return _conversationRef(conversationId).collection(_messagesSubcollection);
  }

  static final Timestamp _epochTimestamp = Timestamp.fromDate(DateTime.utc(1970, 1, 1));

  /// Get or create 1:1 conversation. Returns conversationId.
  Future<String> getOrCreateConversation(String uid1, String uid2) async {
    final cid = conversationIdFor(uid1, uid2);
    final ref = _conversationRef(cid);
    final doc = await ref.get();
    if (doc.exists) return cid;
    final participantIds = [uid1, uid2]..sort();
    await ref.set({
      'participantIds': participantIds,
      'lastMessageAt': _epochTimestamp,
      'lastMessageText': '',
      'lastMessageSenderId': null,
      'lastDeliveredAtBy': {},
      'lastSeenAtBy': {},
      'updatedAt': _epochTimestamp,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (kDebugMode) debugPrint('[DirectChatRepository] Conversation created: $cid');
    return cid;
  }

  /// Stream conversation list for current user (for Chats tab).
  Stream<List<ChatConversation>> streamConversations(String myUid) {
    return _firestore
        .collection(_conversationsCollection)
        .where('participantIds', arrayContains: myUid)
        .orderBy('updatedAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChatConversation.fromFirestore(d.id, d.data()))
            .toList());
  }

  /// Stream messages (newest first for reverse ListView).
  Stream<List<GroupChatMessage>> streamMessages(String conversationId) {
    if (conversationId.isEmpty) return Stream.value([]);
    return _messagesRef(conversationId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => GroupChatMessage.fromFirestore(d.id, d.data()))
            .toList());
  }

  /// Send text message and update conversation doc.
  Future<void> sendTextMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    if (conversationId.isEmpty || senderId.isEmpty) return;
    final ref = _messagesRef(conversationId).doc();
    final convRef = _conversationRef(conversationId);
    final batch = _firestore.batch();
    batch.set(ref, {
      'senderId': senderId,
      'type': 'text',
      'content': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(convRef, {
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageText': text.trim(),
      'lastMessageSenderId': senderId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
    if (kDebugMode) debugPrint('[DirectChatRepository] Sent text in $conversationId');
  }

  /// Upload bytes to Storage then add message. Path: chat/conversations/{conversationId}/
  Future<void> sendMediaMessageWithBytes({
    required String conversationId,
    required String senderId,
    required String type,
    required Uint8List bytes,
    required String fileName,
    required String ext,
    String? caption,
  }) async {
    if (conversationId.isEmpty || senderId.isEmpty) return;
    if (bytes.isEmpty) throw Exception('File is empty.');
    if (kDebugMode) debugPrint('[DirectChatRepository] sendMediaMessageWithBytes: ${bytes.length} bytes');
    final name = '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(0x7FFFFFFF).toRadixString(36)}.$ext';
    final path = '$_storageConversationsPath/$conversationId/$name';
    final storageRef = _storage.ref().child(path);
    final contentType = _contentTypeFor(type, ext);
    final metadata = SettableMetadata(contentType: contentType);
    await storageRef.putData(bytes, metadata).timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw Exception('Upload timed out. Try a smaller image.'),
    );
    final mediaUrl = await storageRef.getDownloadURL().timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('Getting URL timed out.'),
    );
    final convRef = _conversationRef(conversationId);
    final msgRef = _messagesRef(conversationId).doc();
    final preview = type == 'image' ? 'Photo' : (type == 'video' ? 'Video' : 'Document');
    final batch = _firestore.batch();
    batch.set(msgRef, {
      'senderId': senderId,
      'type': type,
      'mediaUrl': mediaUrl,
      'fileName': fileName,
      if (caption != null && caption.isNotEmpty) 'content': caption,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(convRef, {
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageText': preview,
      'lastMessageSenderId': senderId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
    if (kDebugMode) debugPrint('[DirectChatRepository] Sent $type in $conversationId');
  }

  static String? _contentTypeFor(String type, String ext) {
    if (type == 'image') {
      switch (ext) {
        case 'png': return 'image/png';
        case 'gif': return 'image/gif';
        case 'webp': return 'image/webp';
        default: return 'image/jpeg';
      }
    }
    if (type == 'video') {
      if (ext == 'mov') return 'video/quicktime';
      return 'video/mp4';
    }
    return null;
  }

  Future<void> markDeliveredAndSeen(String conversationId, String userId) async {
    if (conversationId.isEmpty) return;
    await _conversationRef(conversationId).set({
      'lastDeliveredAtBy.$userId': FieldValue.serverTimestamp(),
      'lastSeenAtBy.$userId': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<ChatConversation?> getConversationOnce(String conversationId) async {
    final doc = await _conversationRef(conversationId).get();
    if (!doc.exists) return null;
    return ChatConversation.fromFirestore(doc.id, doc.data()!);
  }

  Stream<ChatConversation?> streamConversation(String conversationId) {
    return _conversationRef(conversationId)
        .snapshots()
        .map((doc) => doc.exists ? ChatConversation.fromFirestore(doc.id, doc.data()!) : null);
  }
}
