import 'package:cloud_firestore/cloud_firestore.dart';

/// Type of a group chat message.
enum GroupChatMessageType {
  text,
  image,
  video,
  doc,
  system,
}

/// A single message in a group chat (Firestore: groups/{groupId}/messages).
class GroupChatMessage {
  final String id;
  final String senderId;
  final GroupChatMessageType type;
  final String? content;
  final String? mediaUrl;
  final String? fileName;
  final DateTime? createdAt;
  final List<String> readBy;

  const GroupChatMessage({
    required this.id,
    required this.senderId,
    required this.type,
    this.content,
    this.mediaUrl,
    this.fileName,
    this.createdAt,
    this.readBy = const [],
  });

  static GroupChatMessageType _typeFromString(String? v) {
    switch (v?.toLowerCase()) {
      case 'image':
        return GroupChatMessageType.image;
      case 'video':
        return GroupChatMessageType.video;
      case 'doc':
        return GroupChatMessageType.doc;
      case 'system':
        return GroupChatMessageType.system;
      default:
        return GroupChatMessageType.text;
    }
  }

  factory GroupChatMessage.fromFirestore(String id, Map<String, dynamic> data) {
    final readByRaw = data['readBy'];
    final readByList = readByRaw is List
        ? (readByRaw).map((e) => e.toString()).toList()
        : <String>[];
    final createdAt = data['createdAt'];
    return GroupChatMessage(
      id: id,
      senderId: data['senderId']?.toString() ?? '',
      type: _typeFromString(data['type']?.toString()),
      content: data['content']?.toString(),
      mediaUrl: data['mediaUrl']?.toString(),
      fileName: data['fileName']?.toString(),
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      readBy: readByList,
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'senderId': senderId,
      'type': type.name,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
    if (content != null && content!.isNotEmpty) map['content'] = content;
    if (mediaUrl != null && mediaUrl!.isNotEmpty) map['mediaUrl'] = mediaUrl;
    if (fileName != null && fileName!.isNotEmpty) map['fileName'] = fileName;
    if (readBy.isNotEmpty) map['readBy'] = readBy;
    return map;
  }
}
