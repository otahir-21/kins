import 'package:cloud_firestore/cloud_firestore.dart';

/// Post types: text, image, video, poll
enum PostType {
  text,
  image,
  video,
  poll,
}

/// Poll option with text and vote count
class PollOption {
  final String text;
  final int index;
  final int count;

  PollOption({
    required this.text,
    required this.index,
    this.count = 0,
  });

  Map<String, dynamic> toMap() => {
        'text': text,
        'index': index,
        'count': count,
      };

  factory PollOption.fromMap(Map<String, dynamic> map) => PollOption(
        text: map['text'] ?? '',
        index: (map['index'] ?? 0) as int,
        count: (map['count'] ?? 0) as int,
      );
}

/// Poll data embedded in a post
class PollData {
  final String question;
  final List<PollOption> options;
  final int totalVotes;
  final DateTime? endTime;

  PollData({
    required this.question,
    required this.options,
    this.totalVotes = 0,
    this.endTime,
  });

  Map<String, dynamic> toMap() => {
        'question': question,
        'options': options.map((o) => o.toMap()).toList(),
        'totalVotes': totalVotes,
        'endTime': endTime?.toIso8601String(),
      };

  factory PollData.fromMap(Map<String, dynamic> map) {
    final optionsList = map['options'] as List<dynamic>? ?? [];
    return PollData(
      question: map['question'] ?? '',
      options: optionsList.map((e) => PollOption.fromMap(e as Map<String, dynamic>)).toList(),
      totalVotes: (map['totalVotes'] ?? 0) as int,
      endTime: map['endTime'] != null ? DateTime.tryParse(map['endTime'].toString()) : null,
    );
  }
}

/// Post model for feed (text, image, video, poll)
class PostModel {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final PostType type;
  final String? text;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final List<String> topics;
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final PollData? poll;

  PostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.type,
    this.text,
    this.mediaUrl,
    this.thumbnailUrl,
    this.topics = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.poll,
  });

  bool get isPoll => type == PostType.poll;
  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'type': type.name,
      'text': text,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'topics': topics,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      if (poll != null) 'poll': poll!.toMap(),
    };
  }

  factory PostModel.fromFirestore(String id, Map<String, dynamic> data) {
    PostType type;
    try {
      type = PostType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'text'),
        orElse: () => PostType.text,
      );
    } catch (_) {
      type = PostType.text;
    }

    PollData? pollData;
    if (data['poll'] != null && data['poll'] is Map) {
      pollData = PollData.fromMap(Map<String, dynamic>.from(data['poll'] as Map));
    }

    return PostModel(
      id: id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorPhotoUrl: data['authorPhotoUrl'],
      type: type,
      text: data['text'],
      mediaUrl: data['mediaUrl'],
      thumbnailUrl: data['thumbnailUrl'],
      topics: List<String>.from(data['topics'] ?? []),
      likesCount: (data['likesCount'] ?? 0) as int,
      commentsCount: (data['commentsCount'] ?? 0) as int,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      poll: pollData,
    );
  }
}
