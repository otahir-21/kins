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
  final List<String> votedUsers; // List of user IDs who voted

  PollData({
    required this.question,
    required this.options,
    this.totalVotes = 0,
    this.endTime,
    this.votedUsers = const [],
  });

  Map<String, dynamic> toMap() => {
        'question': question,
        'options': options.map((o) => o.toMap()).toList(),
        'totalVotes': totalVotes,
        'endTime': endTime?.toIso8601String(),
        'votedUsers': votedUsers,
      };

  factory PollData.fromMap(Map<String, dynamic> map) {
    final optionsList = map['options'] as List<dynamic>? ?? [];
    final votedUsersList = map['votedUsers'] as List<dynamic>? ?? [];
    return PollData(
      question: map['question'] ?? '',
      options: optionsList.map((e) => PollOption.fromMap(e as Map<String, dynamic>)).toList(),
      totalVotes: (map['totalVotes'] ?? 0) as int,
      endTime: map['endTime'] != null ? DateTime.tryParse(map['endTime'].toString()) : null,
      votedUsers: votedUsersList.map((id) => id.toString()).toList(),
    );
  }
}

/// Poll result option (from backend pollResults - includes vote count)
class PollResultOption {
  final String text;
  final int index;
  final int votes;

  PollResultOption({
    required this.text,
    required this.index,
    this.votes = 0,
  });

  factory PollResultOption.fromJson(Map<String, dynamic> json) => PollResultOption(
        text: json['text']?.toString() ?? '',
        index: (json['index'] ?? 0) as int,
        votes: (json['votes'] ?? json['count'] ?? 0) as int,
      );
}

/// Post model for feed (text, image, video, poll)
/// All engagement data (isLiked, likesCount, userVote, pollResults) comes from /feed API - no N+1 calls.
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
  final bool isLiked;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int viewsCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final PollData? poll;
  /// User's vote option index (null if not voted). From /feed API.
  final int? userVote;
  /// Poll results with vote counts. From /feed API. Used instead of fetching poll separately.
  final List<PollResultOption>? pollResults;

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
    this.isLiked = false,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.viewsCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.poll,
    this.userVote,
    this.pollResults,
  });

  bool get isPoll => type == PostType.poll;

  PostModel copyWith({
    bool? isLiked,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
  }) {
    return PostModel(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorPhotoUrl: authorPhotoUrl,
      type: type,
      text: text,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      topics: topics,
      isLiked: isLiked ?? this.isLiked,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      viewsCount: viewsCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
      poll: poll,
      userVote: userVote,
      pollResults: pollResults,
    );
  }
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
      'isLiked': isLiked,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'viewsCount': viewsCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      if (poll != null) 'poll': poll!.toMap(),
      'userVote': userVote,
      if (pollResults != null) 'pollResults': pollResults!.map((o) => {'text': o.text, 'index': o.index, 'votes': o.votes}).toList(),
    };
  }

  /// Parse PostModel from backend JSON (no Firebase dependency)
  factory PostModel.fromJson(Map<String, dynamic> json) {
    PostType type;
    try {
      type = PostType.values.firstWhere(
        (e) => e.name == (json['type'] ?? 'text'),
        orElse: () => PostType.text,
      );
    } catch (_) {
      type = PostType.text;
    }

    PollData? pollData;
    if (json['poll'] != null && json['poll'] is Map) {
      pollData = PollData.fromMap(Map<String, dynamic>.from(json['poll'] as Map));
    }

    // Parse dates from ISO8601 strings
    DateTime createdAt;
    try {
      createdAt = json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now();
    } catch (_) {
      createdAt = DateTime.now();
    }

    DateTime? updatedAt;
    try {
      updatedAt = json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'].toString())
          : null;
    } catch (_) {
      updatedAt = null;
    }

    List<PollResultOption>? pollResults;
    if (json['pollResults'] is List) {
      pollResults = (json['pollResults'] as List)
          .map((e) => PollResultOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return PostModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      authorId: json['authorId']?.toString() ?? '',
      authorName: json['authorName']?.toString() ?? 'Anonymous',
      authorPhotoUrl: json['authorPhotoUrl']?.toString(),
      type: type,
      text: json['text']?.toString(),
      mediaUrl: json['mediaUrl']?.toString(),
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      topics: json['topics'] is List 
          ? List<String>.from((json['topics'] as List).map((e) => e.toString()))
          : [],
      isLiked: json['isLiked'] == true,
      likesCount: (json['likesCount'] ?? 0) as int,
      commentsCount: (json['commentsCount'] ?? 0) as int,
      sharesCount: (json['sharesCount'] ?? 0) as int,
      viewsCount: (json['viewsCount'] ?? 0) as int,
      createdAt: createdAt,
      updatedAt: updatedAt,
      poll: pollData,
      userVote: json['userVote'] != null ? (json['userVote'] as num).toInt() : null,
      pollResults: pollResults,
    );
  }

  /// Parse PostModel from Firestore (for other features that still use Firebase)
  /// 
  /// NOTE: This method is NOT used by the feed feature.
  /// The feed uses fromJson() to parse data from the backend API.
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

    // Import needed for Timestamp
    // ignore: depend_on_referenced_packages
    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];

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
      isLiked: data['isLiked'] == true,
      likesCount: (data['likesCount'] ?? 0) as int,
      commentsCount: (data['commentsCount'] ?? 0) as int,
      sharesCount: (data['sharesCount'] ?? 0) as int,
      viewsCount: (data['viewsCount'] ?? 0) as int,
      createdAt: createdAt != null && createdAt.toString().isNotEmpty
          ? (createdAt.runtimeType.toString().contains('Timestamp')
              ? DateTime.fromMillisecondsSinceEpoch(createdAt.seconds * 1000)
              : DateTime.now())
          : DateTime.now(),
      updatedAt: updatedAt != null && updatedAt.toString().isNotEmpty
          ? (updatedAt.runtimeType.toString().contains('Timestamp')
              ? DateTime.fromMillisecondsSinceEpoch(updatedAt.seconds * 1000)
              : null)
          : null,
      poll: pollData,
      userVote: data['userVote'] != null ? (data['userVote'] as num).toInt() : null,
      pollResults: null,
    );
  }
}
