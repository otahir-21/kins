import 'package:flutter/material.dart';
import 'package:kins_app/core/responsive/responsive.dart';

/// Standard app header used on Discover, Chats, and other main screens.
/// Top row: optional [leading], avatar + [name] + [subtitle], optional [trailing].
/// Use [onTitleTap] for profile/settings navigation.
class AppHeader extends StatelessWidget {
  /// Left widget (e.g. menu IconButton to open drawer). If null, reserves space to keep center aligned.
  final Widget? leading;

  /// Display name (e.g. user name or screen title).
  final String name;

  /// Optional subtitle (e.g. location).
  final String? subtitle;

  /// Optional profile/avatar image URL.
  final String? profileImageUrl;

  /// Called when the center (avatar + name + subtitle) is tapped.
  final VoidCallback? onTitleTap;

  /// Right widget (e.g. notification bell). If null, no trailing widget.
  final Widget? trailing;

  static const Color _greyMeta = Color(0xFF8E8E93);

  const AppHeader({
    super.key,
    this.leading,
    required this.name,
    this.subtitle,
    this.profileImageUrl,
    this.onTitleTap,
    this.trailing,
  });

  /// Standard drawer menu button. Use as [leading] when the screen has a [Drawer].
  static Widget drawerButton(BuildContext context) {
    return IconButton(
      onPressed: () => Scaffold.of(context).openDrawer(),
      icon: const Icon(Icons.menu, size: 20),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      style: IconButton.styleFrom(
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: Responsive.screenPaddingH(context)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: leading or reserved space
          SizedBox(
            width: 30,
            height: 48,
            child: leading != null
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: leading,
                  )
                : null,
          ),
          // Center: avatar + name + location
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildCenter(context),
            ),
          ),
          // Right: trailing
          if (trailing != null) trailing!,
        ],
      ),
    );
  }

  Widget _buildCenter(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 35,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade200,
            image: profileImageUrl != null
                ? DecorationImage(
                    image: NetworkImage(profileImageUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: profileImageUrl == null
              ? Icon(Icons.person, size: 20, color: Colors.grey.shade400)
              : null,
        ),
        SizedBox(width: Responsive.spacing(context, 5)),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 15),
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                SizedBox(height: Responsive.spacing(context, 4)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 14,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Icon(Icons.location_on_outlined, size: 12, color: _greyMeta),
                      ),
                    ),
                    SizedBox(width: Responsive.spacing(context, 3)),
                    Expanded(
                      child: Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 12),
                          color: _greyMeta,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );

    if (onTitleTap != null) {
      return InkWell(
        onTap: onTitleTap,
        child: content,
      );
    }
    return content;
  }
}
