import 'package:flutter/material.dart';

/// Shared KINS logo used on splash, auth, and other screens.
/// [width] and [height] default to 150; e.g. use 200 for splash.
class KinsLogo extends StatelessWidget {
  const KinsLogo({
    super.key,
    this.width = 150,
    this.height = 150,
  });

  final double width;
  final double height;

  static const String _assetPath = 'assets/logo/Logo-KINS.png';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        _assetPath,
        width: width,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Text(
          'KINS',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
