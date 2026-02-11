import 'package:flutter/material.dart';
import 'package:kins_app/models/post_model.dart';

/// Text post card matching Figma design exactly
class PostCardText extends StatefulWidget {
  final PostModel post;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onRepost;
  final VoidCallback onMore;

  const PostCardText({
    super.key,
    required this.post,
    required this.isLiked,
    required this.onLike,
    required this.onComment,
    required this.onRepost,
    required this.onMore,
  });

  @override
  State<PostCardText> createState() => _PostCardTextState();
}

class _PostCardTextState extends State<PostCardText> with SingleTickerProviderStateMixin {
  late AnimationController _likeAnimationController;
  late Animation<double> _likeScaleAnimation;

  @override
  void initState() {
    super.initState();
    _likeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _likeScaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _likeAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    super.dispose();
  }

  void _handleLike() {
    // Animate like button
    _likeAnimationController.forward().then((_) {
      _likeAnimationController.reverse();
    });
    widget.onLike();
  }

  String _getTimeAgo() {
    final now = DateTime.now();
    final postTime = widget.post.createdAt;
    final diff = now.difference(postTime);
    
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }

  String _extractUsername() {
    // Extract username from author name (e.g., "Jawaher @jawaherabdelhamid")
    final name = widget.post.authorName;
    final atIndex = name.indexOf('@');
    if (atIndex != -1 && atIndex < name.length - 1) {
      return name.substring(atIndex);
    }
    return '@${name.toLowerCase().replaceAll(' ', '')}';
  }

  @override
  Widget build(BuildContext context) {
    final authorAvatar = widget.post.authorPhotoUrl;
    final authorName = widget.post.authorName;
    final text = widget.post.text ?? '';
    final likesCount = widget.post.likesCount;
    final commentsCount = widget.post.commentsCount;
    final sharesCount = widget.post.sharesCount;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ========================================
          // HEADER SECTION
          // ========================================
          Row(
            children: [
              // Profile Image - 48x48
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade200,
                ),
                child: authorAvatar != null && authorAvatar.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          authorAvatar,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.person,
                            size: 24,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: 24,
                        color: Colors.grey.shade400,
                      ),
              ),
              const SizedBox(width: 12),
              
              // Name + Username + Time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name - FontWeight.w600, FontSize 18, Color #111111
                    Text(
                      authorName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111111),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    
                    // Username + Time - FontSize 14, Color #7A7A7A
                    Text(
                      '${_extractUsername()} · ${_getTimeAgo()}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF7A7A7A),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // 3-dot menu - Icon size 20, Color #999999
              IconButton(
                icon: const Icon(
                  Icons.more_horiz,
                  size: 20,
                  color: Color(0xFF999999),
                ),
                onPressed: widget.onMore,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 0.1, // Disable splash
                highlightColor: Colors.transparent,
                splashColor: Colors.transparent,
              ),
            ],
          ),
          
          // ========================================
          // CONTENT SECTION
          // ========================================
          if (text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              text,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Color(0xFF000000),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // ========================================
          // INTERACTION BUTTON ROW
          // ========================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Like Button
              _InteractionButton(
                icon: widget.isLiked ? Icons.favorite : Icons.favorite_border,
                iconColor: widget.isLiked ? const Color(0xFFE53935) : Colors.black,
                count: likesCount,
                onTap: _handleLike,
                scaleAnimation: _likeScaleAnimation,
              ),
              
              // Comment Button
              _InteractionButton(
                icon: Icons.chat_bubble_outline,
                iconColor: Colors.black,
                count: commentsCount,
                onTap: widget.onComment,
              ),
              
              // Repost Button
              _InteractionButton(
                icon: Icons.repeat,
                iconColor: Colors.black,
                count: sharesCount,
                onTap: widget.onRepost,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Interaction button with icon and count
class _InteractionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final int count;
  final VoidCallback onTap;
  final Animation<double>? scaleAnimation;

  const _InteractionButton({
    required this.icon,
    required this.iconColor,
    required this.count,
    required this.onTap,
    this.scaleAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 26,
              color: iconColor,
            ),
            const SizedBox(width: 8),
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF444444),
              ),
            ),
          ],
        ),
      ),
    );

    // Apply scale animation if provided (for like button)
    if (scaleAnimation != null) {
      return ScaleTransition(
        scale: scaleAnimation!,
        child: button,
      );
    }

    return button;
  }
}
