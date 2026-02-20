import 'package:flutter/material.dart';
import 'package:kins_app/widgets/main_bottom_nav.dart';

/// Wraps screen content so the bottom nav floats on top (overlay).
/// Use this instead of [Scaffold.bottomNavigationBar] so the nav does not push content up.
/// Adds safe-area bottom spacing so the nav does not clash with system gestures.
/// [bottomWidget] optional (e.g. Pigeon logo + dots on home).
class FloatingNavOverlay extends StatelessWidget {
  const FloatingNavOverlay({
    super.key,
    required this.child,
    required this.currentIndex,
    this.bottomWidget,
  });

  final Widget child;
  final int currentIndex;
  /// Optional widget below the nav bar (e.g. brand logo + carousel dots).
  final Widget? bottomWidget;

  static const double _bottomPadding = 16;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            left: false,
            right: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: _bottomPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MainBottomNav(currentIndex: currentIndex),
                  if (bottomWidget != null) ...[
                    const SizedBox(height: 8),
                    bottomWidget!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
