import 'package:flutter/material.dart';
import 'package:kins_app/core/responsive/responsive.dart';

/// Reusable group card with image, name, description, member avatars, and Join button.
/// Same design as group list in Chat screen.
/// Set [horizontalSlide] true when used in a horizontal list (reduces horizontal margin).
class GroupCard extends StatelessWidget {
  final String groupId;
  final String name;
  final String description;
  final int members;
  final String? imageUrl;
  final VoidCallback? onTap;
  final VoidCallback onJoin;
  /// When true, use minimal horizontal margin for horizontal scroll layout.
  final bool horizontalSlide;

  const GroupCard({
    super.key,
    this.groupId = '',
    required this.name,
    required this.description,
    required this.members,
    this.imageUrl,
    this.onTap,
    required this.onJoin,
    this.horizontalSlide = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      margin: horizontalSlide
          ? EdgeInsets.symmetric(vertical: Responsive.spacing(context, 5), horizontal: 6)
          : EdgeInsets.symmetric(
              horizontal: Responsive.screenPaddingH(context),
              vertical: Responsive.spacing(context, 5),
            ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Responsive.scale(context, 24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? Image.network(
                    imageUrl!,
                    height: Responsive.scale(context, 140),
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: Responsive.scale(context, 140),
                    width: double.infinity,
                    color: const Color(0xFF6B4C93).withOpacity(0.15),
                    child: Icon(
                      Icons.group,
                      color: const Color(0xFF6B4C93),
                      size: Responsive.scale(context, 48),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: 18,
              right: 18,
              bottom: 8,
              top: 5,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 12),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$members Members',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 12),
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 14),
                          height: 1.4,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    _MemberAvatars(memberCount: members),
                    _GroupJoinPlusButton(onTap: onJoin),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Responsive.scale(context, 24)),
        child: child,
      );
    }
    return child;
  }
}

class _MemberAvatars extends StatelessWidget {
  final int memberCount;

  const _MemberAvatars({required this.memberCount});

  static const double _avatarRadius = 14;
  static const double _overlap = 8;

  @override
  Widget build(BuildContext context) {
    final diameter = _avatarRadius * 2;
    final showOverflow = memberCount > 2;
    final avatarCount = showOverflow ? 2 : memberCount.clamp(1, 2);
    final circleCount = showOverflow ? 3 : avatarCount;
    final totalWidth = circleCount * (diameter - _overlap) + _overlap;

    return SizedBox(
      width: totalWidth,
      height: diameter,
      child: Stack(
        children: [
          ...List.generate(avatarCount, (i) {
            return Positioned(
              left: i * (diameter - _overlap),
              child: CircleAvatar(
                radius: _avatarRadius,
                backgroundColor: const Color(0xFF6B4C93).withOpacity(0.25),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 12),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B4C93),
                  ),
                ),
              ),
            );
          }),
          if (showOverflow)
            Positioned(
              left: 2 * (diameter - _overlap),
              child: CircleAvatar(
                radius: _avatarRadius,
                backgroundColor: Colors.white,
                child: Text(
                  '${(memberCount - 2).clamp(1, 999)}+',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 11),
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupJoinPlusButton extends StatelessWidget {
  final VoidCallback onTap;

  const _GroupJoinPlusButton({required this.onTap});

  static const double _size = 28;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _size,
        height: _size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade200,
        ),
        child: Icon(Icons.add, size: 20, color: Colors.grey.shade700),
      ),
    );
  }
}
