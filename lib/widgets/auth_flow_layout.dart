import 'package:flutter/material.dart';
import 'package:kins_app/core/responsive/responsive.dart';
import 'package:kins_app/widgets/kins_logo.dart';

/// Layout wrapper for auth/profile flow screens: SafeArea, logo at top, then
/// [children] (e.g. [Expanded(child: SingleChildScrollView(...))]).
/// Logo and layout adapt to screen size.
class AuthFlowLayout extends StatelessWidget {
  const AuthFlowLayout({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final logoSize = Responsive.isSmallHeight(context) ? 100.0 : 150.0;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          KinsLogo(width: logoSize, height: logoSize),
          ...children,
        ],
      ),
    );
  }
}
