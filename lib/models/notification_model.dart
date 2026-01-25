class NotificationModel {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderProfilePicture;
  final String type; // liked_post, commented_post, followed_you, message, etc.
  final String action; // "Liked your post", "Commented on your post", etc.
  final DateTime timestamp;
  final String? relatedPostId;
  final String? postThumbnail;
  final bool read;

  NotificationModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderProfilePicture,
    required this.type,
    required this.action,
    required this.timestamp,
    this.relatedPostId,
    this.postThumbnail,
    this.read = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'senderProfilePicture': senderProfilePicture,
      'type': type,
      'action': action,
      'timestamp': timestamp.toIso8601String(),
      'relatedPostId': relatedPostId,
      'postThumbnail': postThumbnail,
      'read': read,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderProfilePicture: map['senderProfilePicture'],
      type: map['type'] ?? '',
      action: map['action'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
      relatedPostId: map['relatedPostId'],
      postThumbnail: map['postThumbnail'],
      read: map['read'] ?? false,
    );
  }

  factory NotificationModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return NotificationModel(
      id: id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderProfilePicture: data['senderProfilePicture'],
      type: data['type'] ?? '',
      action: data['action'] ?? '',
      timestamp: data['timestamp']?.toDate() ?? DateTime.now(),
      relatedPostId: data['relatedPostId'],
      postThumbnail: data['postThumbnail'],
      read: data['read'] ?? false,
    );
  }

  NotificationModel copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderProfilePicture,
    String? type,
    String? action,
    DateTime? timestamp,
    String? relatedPostId,
    String? postThumbnail,
    bool? read,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderProfilePicture: senderProfilePicture ?? this.senderProfilePicture,
      type: type ?? this.type,
      action: action ?? this.action,
      timestamp: timestamp ?? this.timestamp,
      relatedPostId: relatedPostId ?? this.relatedPostId,
      postThumbnail: postThumbnail ?? this.postThumbnail,
      read: read ?? this.read,
    );
  }
}
