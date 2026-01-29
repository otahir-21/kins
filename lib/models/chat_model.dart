import 'package:cloud_firestore/cloud_firestore.dart';

/// Message status derived from chat's lastDeliveredAtBy / lastSeenAtBy.
/// We do not store status per message to keep Firebase writes low.
enum MessageStatus {
  sending,
  sent,
  delivered,
  seen,
}

/// A single chat message.
class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime? createdAt;
  final bool isLocalPending; // true while sending (optimistic)

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.createdAt,
    this.isLocalPending = false,
  });

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'text': text,
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      };

  factory ChatMessage.fromFirestore(String id, Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    return ChatMessage(
      id: id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      isLocalPending: false,
    );
  }

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? text,
    DateTime? createdAt,
    bool? isLocalPending,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      isLocalPending: isLocalPending ?? this.isLocalPending,
    );
  }
}

/// Resolve status for a message I sent: other user's lastDeliveredAt/lastSeenAt >= message time.
MessageStatus messageStatusForSender({
  required DateTime? messageCreatedAt,
  required String otherUserId,
  required Map<String, dynamic>? lastDeliveredAtBy,
  required Map<String, dynamic>? lastSeenAtBy,
}) {
  if (messageCreatedAt == null) return MessageStatus.sending;
  final deliveredAt = lastDeliveredAtBy?[otherUserId];
  final seenAt = lastSeenAtBy?[otherUserId];
  final deliveredTs = deliveredAt is Timestamp ? deliveredAt.toDate() : null;
  final seenTs = seenAt is Timestamp ? seenAt.toDate() : null;
  final delivered = deliveredTs != null && !messageCreatedAt.isAfter(deliveredTs);
  final seen = seenTs != null && !messageCreatedAt.isAfter(seenTs);
  if (seen) return MessageStatus.seen;
  if (delivered) return MessageStatus.delivered;
  return MessageStatus.sent;
}

/// A chat conversation (1:1 for now).
class ChatConversation {
  final String id;
  final List<String> participantIds;
  final DateTime? lastMessageAt;
  final String lastMessageText;
  final String? lastMessageSenderId;
  final Map<String, dynamic> lastDeliveredAtBy;
  final Map<String, dynamic> lastSeenAtBy;
  final DateTime? createdAt;

  const ChatConversation({
    required this.id,
    required this.participantIds,
    this.lastMessageAt,
    this.lastMessageText = '',
    this.lastMessageSenderId,
    this.lastDeliveredAtBy = const {},
    this.lastSeenAtBy = const {},
    this.createdAt,
  });

  /// The other participant's user ID (for 1:1). Empty if not found.
  String otherParticipantId(String myUid) {
    final list = participantIds.where((id) => id != myUid).toList();
    return list.isNotEmpty ? list.first : '';
  }

  /// Whether there are unread messages (last message from other user after our lastSeenAt).
  /// Returns 0 or 1; for exact count we'd need a count query (extra reads).
  int unreadCountFor(String myUid) {
    if (lastMessageSenderId == myUid) return 0;
    final seenAt = lastSeenAtBy[myUid];
    if (seenAt == null) return lastMessageText.isNotEmpty ? 1 : 0;
    final seen = seenAt is Timestamp ? seenAt.toDate() : null;
    if (seen == null) return 1;
    return lastMessageAt != null && lastMessageAt!.isAfter(seen) ? 1 : 0;
  }

  factory ChatConversation.fromFirestore(String id, Map<String, dynamic> data) {
    final pids = data['participantIds'] as List<dynamic>?;
    final lastAt = data['lastMessageAt'];
    final created = data['createdAt'];
    return ChatConversation(
      id: id,
      participantIds: (pids ?? []).map((e) => e.toString()).toList(),
      lastMessageAt: lastAt is Timestamp ? lastAt.toDate() : null,
      lastMessageText: data['lastMessageText'] as String? ?? '',
      lastMessageSenderId: data['lastMessageSenderId'] as String?,
      lastDeliveredAtBy: Map<String, dynamic>.from(data['lastDeliveredAtBy'] as Map? ?? {}),
      lastSeenAtBy: Map<String, dynamic>.from(data['lastSeenAtBy'] as Map? ?? {}),
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}
