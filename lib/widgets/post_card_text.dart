import 'package:flutter/material.dart';
import 'package:kins_app/core/responsive/responsive.dart';
import 'package:kins_app/core/theme/app_theme.dart';
import 'package:kins_app/models/post_model.dart';
import 'package:kins_app/widgets/post_header.dart';
import 'package:kins_app/widgets/post_interaction_bar.dart';

/// Text post card — matches Poll/Image layout structure.
/// Uses shared PostHeader and PostInteractionBar.
class PostCardText extends StatefulWidget {
  final PostModel post;
  final VoidCallback onLike;
  final void Function(PostModel post) onComment;
  final void Function(PostModel post) onShare;
  final VoidCallback onMore;

  const PostCardText({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onMore,
  });

  @override
  State<PostCardText> createState() => _PostCardTextState();
}

class _PostCardTextState extends State<PostCardText> {
  void _handleLike() => widget.onLike();

  String _getTimeAgo() {
    final diff = DateTime.now().difference(widget.post.createdAt);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }

  String _extractUsername() {
    final name = widget.post.authorName;
    final atIndex = name.indexOf('@');
    if (atIndex != -1 && atIndex < name.length - 1) return name.substring(atIndex);
    return '@${name.toLowerCase().replaceAll(' ', '')}';
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.post.text ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PostHeader(
            authorName: widget.post.authorName,
            username: _extractUsername(),
            timeAgo: _getTimeAgo(),
            avatarUrl: widget.post.authorPhotoUrl,
            onMore: widget.onMore,
          ),
          const SizedBox(height: 0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: Responsive.spacing(context, 50)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (text.isNotEmpty) ...[
                      Text(
                        text,
                        style: Theme.of(context).extension<AppPostTypography>()?.postBody ??
                            TextStyle(fontSize: Responsive.fontSize(context, 18), fontWeight: FontWeight.w400, height: 1.5, color: Colors.black),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: PostInteractionBar(
                        post: widget.post,
                        onLike: (_) => _handleLike(),
                        onComment: widget.onComment,
                        onShare: widget.onShare,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Divider(
                      height: 1,
                      thickness: 0.8,
                      color: Color(0xFFE5E5E5),
                    ),
                    const SizedBox(height: 0),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
