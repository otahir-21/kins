import 'package:flutter/material.dart';
import 'package:kins_app/core/theme/app_theme.dart';
import 'package:kins_app/models/post_model.dart';

/// Shared interaction bar for all post types (text, image, video, poll).
/// Uses asset icons from assets/InteractionButton/.
class PostInteractionBar extends StatefulWidget {
  final PostModel post;
  final bool initialIsLiked;
  final void Function(PostModel post) onLike;
  final void Function(PostModel post) onComment;
  final void Function(PostModel post) onShare;

  const PostInteractionBar({
    super.key,
    required this.post,
    required this.initialIsLiked,
    required this.onLike,
    required this.onComment,
    required this.onShare,
  });

  @override
  State<PostInteractionBar> createState() => _PostInteractionBarState();
}

class _PostInteractionBarState extends State<PostInteractionBar> {
  static const String _likeIcon = 'assets/InteractionButton/likeIcon.png';
  static const String _commentIcon = 'assets/InteractionButton/commendIcon.png';
  static const String _shareIcon = 'assets/InteractionButton/shareIcon.png';

  late bool _isLiked;
  late int _likesCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.initialIsLiked;
    _likesCount = widget.post.likesCount;
  }

  @override
  void didUpdateWidget(covariant PostInteractionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.initialIsLiked != widget.initialIsLiked) {
      _isLiked = widget.initialIsLiked;
      _likesCount = widget.post.likesCount;
    }
  }

  void _handleLike() {
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });
    widget.onLike(widget.post);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _buildButton(
          onTap: _handleLike,
          iconPath: _likeIcon,
          count: _likesCount,
        ),
        const SizedBox(width: 40),
        _buildButton(
          onTap: () => widget.onComment(widget.post),
          iconPath: _commentIcon,
          count: widget.post.commentsCount,
        ),
        const SizedBox(width: 40),
        _buildButton(
          onTap: () => widget.onShare(widget.post),
          iconPath: _shareIcon,
          count: widget.post.sharesCount,
        ),
      ],
    );
  }

  Widget _buildButton({
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
            width: 26,
            height: 26,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              width: 26,
              height: 26,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            count.toString(),
            style: Theme.of(context).extension<AppPostTypography>()?.interactionCount ??
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black),
          ),
        ],
      ),
    );
  }
}
