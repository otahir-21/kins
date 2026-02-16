import 'package:flutter/material.dart';
import 'package:kins_app/core/theme/app_theme.dart';

/// Reusable post header — exact copy of Poll post header layout.
/// Spacing, font sizes, and structure match PollPostWidget.
class PostHeader extends StatelessWidget {
  final String authorName;
  final String username;
  final String timeAgo;
  final String? avatarUrl;
  final VoidCallback onMore;

  const PostHeader({
    super.key,
    required this.authorName,
    required this.username,
    required this.timeAgo,
    this.avatarUrl,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).extension<AppPostTypography>();
    final headerName = typo?.headerName ?? const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black);
    final headerMeta = typo?.headerMeta ?? const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Color(0xFF8E8E93));
    final headerTime = typo?.headerTime ?? const TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFF8E8E93));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade200,
            image: avatarUrl != null && avatarUrl!.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(avatarUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: avatarUrl == null || avatarUrl!.isEmpty
              ? Icon(Icons.person, size: 17, color: Colors.grey.shade400)
              : null,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(text: authorName, style: headerName),
                        const TextSpan(text: ' '),
                        TextSpan(text: username, style: headerMeta),
                        const TextSpan(text: ' '),
                        TextSpan(text: timeAgo, style: headerTime),
                      ],
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: onMore,
                child: const Icon(
                  Icons.more_vert,
                  size: 20,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
