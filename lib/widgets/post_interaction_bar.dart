import 'package:flutter/material.dart';
import 'package:kins_app/core/theme/app_theme.dart';
import 'package:kins_app/models/post_model.dart';

/// Shared interaction bar for all post types (text, image, video, poll).
/// Reads post.isLiked and post.likesCount from API - no per-post HTTP calls.
/// Uses asset icons from assets/InteractionButton/.
class PostInteractionBar extends StatelessWidget {
  final PostModel post;
  final void Function(PostModel post) onLike;
  final void Function(PostModel post) onComment;
  final void Function(PostModel post) onShare;

  const PostInteractionBar({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onShare,
  });

  static const String _likeIcon = 'assets/InteractionButton/likeIcon.png';
  static const String _commentIcon = 'assets/InteractionButton/commendIcon.png';
  static const String _shareIcon = 'assets/InteractionButton/shareIcon.png';

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _buildButton(
          context: context,
          onTap: () => onLike(post),
          iconPath: _likeIcon,
          count: post.likesCount,
        ),
        const SizedBox(width: 25),
        _buildButton(
          context: context,
          onTap: () => onComment(post),
          iconPath: _commentIcon,
          count: post.commentsCount,
        ),
        const SizedBox(width: 25),
        _buildButton(
          context: context,
          onTap: () => onShare(post),
          iconPath: _shareIcon,
          count: post.sharesCount,
        ),
      ],
    );
  }

  static Widget _buildButton({
    required BuildContext context,
    required VoidCallback onTap,
    required String iconPath,
    required int count,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            iconPath,
            width: 18,
            height: 18,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              width: 18,
              height: 18,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            count.toString(),
            style: Theme.of(context).extension<AppPostTypography>()?.interactionCount ??
                const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.black),
          ),
        ],
      ),
    );
  }
}
