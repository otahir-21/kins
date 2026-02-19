import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:kins_app/models/group_chat_message.dart';

const String _groupsCollection = 'groups';
const String _messagesSubcollection = 'messages';
const String _storageChatPath = 'chat';

/// Repository for group chat: Firestore groups/{groupId}/messages + Storage chat/{groupId}/...
class GroupChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _messagesRef(String groupId) {
    return _firestore.collection(_groupsCollection).doc(groupId).collection(_messagesSubcollection);
  }

  /// Real-time stream of messages, newest first (for ListView.reverse so latest shows at bottom).
  Stream<List<GroupChatMessage>> streamMessages(String groupId) {
    if (groupId.isEmpty) return Stream.value([]);
    return _messagesRef(groupId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => GroupChatMessage.fromFirestore(d.id, d.data()))
            .toList());
  }

  /// Send a text message.
  Future<void> sendTextMessage({
    required String groupId,
    required String senderId,
    required String text,
  }) async {
    if (groupId.isEmpty || senderId.isEmpty) return;
    final ref = _messagesRef(groupId).doc();
    await ref.set({
      'senderId': senderId,
      'type': 'text',
      'content': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (kDebugMode) debugPrint('[GroupChatRepository] Sent text message to $groupId');
  }

  /// Send a system message (e.g. "Alina added Sarah Al Sharif"). Persisted in Firestore.
  Future<void> sendSystemMessage({
    required String groupId,
    required String content,
  }) async {
    if (groupId.isEmpty) return;
    final ref = _messagesRef(groupId).doc();
    await ref.set({
      'senderId': '',
      'type': 'system',
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Upload bytes to Storage then add message. Use this when you have bytes (e.g. from picker or after reading file).
  Future<void> sendMediaMessageWithBytes({
    required String groupId,
    required String senderId,
    required String type,
    required Uint8List bytes,
    required String fileName,
    required String ext,
    String? caption,
  }) async {
    if (groupId.isEmpty || senderId.isEmpty) return;
    if (bytes.isEmpty) throw Exception('File is empty.');
    if (kDebugMode) debugPrint('[GroupChatRepository] sendMediaMessageWithBytes: ${bytes.length} bytes, type=$type');
    final name = '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(0x7FFFFFFF).toRadixString(36)}.$ext';
    final path = '$_storageChatPath/$groupId/$name';
    final storageRef = _storage.ref().child(path);
    final contentType = _contentTypeFor(type, ext);
    final metadata = SettableMetadata(contentType: contentType);
    if (kDebugMode) debugPrint('[GroupChatRepository] Uploading to $path ...');
    await storageRef.putData(bytes, metadata).timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw Exception('Upload timed out. Check your connection and try a smaller image.'),
    );
    if (kDebugMode) debugPrint('[GroupChatRepository] Upload done, getting URL ...');
    final mediaUrl = await storageRef.getDownloadURL().timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('Getting image URL timed out.'),
    );
    if (kDebugMode) debugPrint('[GroupChatRepository] Writing Firestore message ...');
    final docRef = _messagesRef(groupId).doc();
    await docRef.set({
      'senderId': senderId,
      'type': type,
      'mediaUrl': mediaUrl,
      'fileName': fileName,
      if (caption != null && caption.isNotEmpty) 'content': caption,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (kDebugMode) debugPrint('[GroupChatRepository] Sent $type message to $groupId');
  }

  /// Upload file to Storage at chat/{groupId}/{timestamp}_{random}.{ext}, then add message.
  Future<void> sendMediaMessage({
    required String groupId,
    required String senderId,
    required String type,
    required File file,
    String? caption,
  }) async {
    if (groupId.isEmpty || senderId.isEmpty) return;
    final path = file.path;
    if (!await file.exists()) {
      if (kDebugMode) debugPrint('[GroupChatRepository] sendMediaMessage: file does not exist $path');
      throw Exception('File no longer available. Try picking again.');
    }
    final ext = _extension(path);
    final fileName = path.split(RegExp(r'[/\\]')).last;
    if (kDebugMode) debugPrint('[GroupChatRepository] Reading file bytes: $path');
    final bytes = await file.readAsBytes();
    await sendMediaMessageWithBytes(
      groupId: groupId,
      senderId: senderId,
      type: type,
      bytes: bytes,
      fileName: fileName,
      ext: ext,
      caption: caption,
    );
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

  static String _extension(String path) {
    final i = path.lastIndexOf('.');
    if (i >= 0 && i < path.length - 1) return path.substring(i + 1).toLowerCase();
    return 'bin';
  }

  /// Optional: update groups/{groupId} lastMessage for list previews.
  Future<void> updateLastMessage({
    required String groupId,
    required String senderId,
    required String content,
  }) async {
    try {
      await _firestore.collection(_groupsCollection).doc(groupId).set({
        'lastMessage': {
          'senderId': senderId,
          'content': content,
          'createdAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('[GroupChatRepository] updateLastMessage failed: $e');
    }
  }
}
