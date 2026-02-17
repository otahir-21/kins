import 'package:flutter/material.dart';
import 'package:kins_app/core/responsive/responsive.dart';
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
    final base = typo ?? AppPostTypography.fromBase(Theme.of(context).textTheme);
    final headerName = base.headerName.copyWith(fontSize: Responsive.fontSize(context, 15));
    final headerMeta = base.headerMeta.copyWith(fontSize: Responsive.fontSize(context, 15));
    final headerTime = base.headerTime.copyWith(fontSize: Responsive.fontSize(context, 13));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
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
