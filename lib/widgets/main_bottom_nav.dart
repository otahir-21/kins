import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:kins_app/core/responsive/responsive.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/constants/app_constants.dart';

/// Floating bottom nav: order Feed, Chat, Home, Brand, Marketplace.
/// Use inside [FloatingNavOverlay] so it overlays content. Icon-only, asset icons.
/// Selected: purple circle + white icon. Unselected: white/translucent circle + dark icon.
class MainBottomNav extends StatelessWidget {
  const MainBottomNav({
    super.key,
    required this.currentIndex,
  });

  /// 0=Feed, 1=Chat, 2=Home, 3=Brand, 4=Marketplace
  final int currentIndex;

  static const int feedIndex = 0;
  static const int chatIndex = 1;
  static const int homeIndex = 2;
  static const int brandIndex = 3;
  static const int marketplaceIndex = 4;

  static const Color _primaryPurple = Color(0xFF6A1A5D);
  static const double _horizontalMargin = 20;
  static const double _verticalPadding = 11; // 12 * 0.9 (10% smaller)
  static const double _iconSize = 20; // 34 * 0.6 (40% smaller)
  static const double _circleSizeInactive = 43; // 48 * 0.9
  static const double _circleSizeActive = 47; // 52 * 0.9

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Responsive.spacing(context, _horizontalMargin),
        0,
        Responsive.spacing(context, _horizontalMargin),
        0,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: Responsive.spacing(context, _verticalPadding),
              horizontal: Responsive.spacing(context, 8),
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.45),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(context, feedIndex, 'assets/icons/nav_discovery.png', AppConstants.routeDiscover, Icons.explore, iconSize: _iconSize),
                _buildNavItem(context, chatIndex, 'assets/icons/nav_bubble_chat.png', AppConstants.routeChat, Icons.chat_bubble_outline, iconSize: _iconSize),
                _buildNavItem(context, homeIndex, 'assets/icons/nav_home.png', AppConstants.routeHome, Icons.home, iconSize: _iconSize),
                _buildNavItem(context, brandIndex, 'assets/icons/nav_insurance.png', AppConstants.routeMembership, Icons.shield_outlined, iconSize: _iconSize),
                _buildNavItem(context, marketplaceIndex, 'assets/icons/nav_bag.png', AppConstants.routeMarketplace, Icons.shopping_bag_outlined, iconSize: _iconSize),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, String assetPath, String route, IconData fallbackIcon, {double iconSize = _iconSize}) {
    final isActive = currentIndex == index;
    final size = isActive ? _circleSizeActive : _circleSizeInactive;

    return GestureDetector(
      onTap: () {
        if (currentIndex == index) return;
        context.go(route);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isActive ? _primaryPurple : Colors.white.withOpacity(0.95),
          shape: BoxShape.circle,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: _primaryPurple.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              isActive ? Colors.white : Colors.black87,
              BlendMode.srcIn,
            ),
            child: Image.asset(
              assetPath,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
              errorBuilder: (_, error, __) {
                debugPrint('Bottom nav icon failed to load: $assetPath - $error');
                return Icon(fallbackIcon, size: iconSize, color: isActive ? Colors.white : Colors.black87);
              },
            ),
          ),
        ),
      ),
    );
  }
}
