import 'package:flutter/material.dart';
import 'package:kins_app/widgets/kins_logo.dart';

/// Layout wrapper for auth/profile flow screens: SafeArea, logo at top, then
/// [children] (e.g. [Expanded(child: SingleChildScrollView(...))]).
/// Does not change layout or positioning.
class AuthFlowLayout extends StatelessWidget {
  const AuthFlowLayout({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const KinsLogo(),
          ...children,
        ],
      ),
    );
  }
}
