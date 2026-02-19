import 'package:flutter/material.dart';

/// Positions the FAB a bit higher so it aligns better with the floating bottom nav.
/// Use for all main screens that show a FAB above the bottom navigation.
class KinsFabLocation extends FloatingActionButtonLocation {
  const KinsFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    const double endPadding = 16;
    const double bottomPadding = 110;
    final double x = geometry.scaffoldSize.width -
        geometry.floatingActionButtonSize.width -
        endPadding;
    final double y = geometry.contentBottom -
        geometry.floatingActionButtonSize.height -
        bottomPadding;
    return Offset(x, y);
  }
}
