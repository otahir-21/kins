/// Comment model for post comments and replies
class CommentModel {
  final String id;
  final String userId;
  final String userName;
  final String? userUsername;
  final String? userProfilePictureUrl;
  final String postId;
  final String content;
  final String? parentCommentId;
  final int likesCount;
  final int repliesCount;
  final bool isActive;
  final bool isLikedByMe;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CommentModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userUsername,
    this.userProfilePictureUrl,
    required this.postId,
    required this.content,
    this.parentCommentId,
    this.likesCount = 0,
    this.repliesCount = 0,
    this.isActive = true,
    this.isLikedByMe = false,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isReply => parentCommentId != null;
  bool get isTopLevel => parentCommentId == null;

  /// Parse CommentModel from backend JSON
  factory CommentModel.fromJson(Map<String, dynamic> json) {
    // Parse user object if it exists
    final userObj = json['userId'] as Map<String, dynamic>?;
    final userId = userObj?['_id']?.toString() ?? json['userId']?.toString() ?? '';
    final userName = userObj?['name']?.toString() ?? 'Anonymous';
    final userUsername = userObj?['username']?.toString();
    final userProfilePictureUrl = userObj?['profilePictureUrl']?.toString();

    // Parse dates
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

    return CommentModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      userId: userId,
      userName: userName,
      userUsername: userUsername,
      userProfilePictureUrl: userProfilePictureUrl,
      postId: json['postId']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      parentCommentId: json['parentCommentId']?.toString(),
      likesCount: (json['likesCount'] ?? 0) as int,
      repliesCount: (json['repliesCount'] ?? 0) as int,
      isActive: json['isActive'] == true,
      isLikedByMe: json['isLikedByMe'] == true,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'postId': postId,
      'content': content,
      'parentCommentId': parentCommentId,
      'likesCount': likesCount,
      'repliesCount': repliesCount,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
