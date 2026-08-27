import 'package:flutter/material.dart';

/// The app's bell+pin mark (assets/images/logo.png). [onDark] is kept for
/// call-site compatibility but unused — the artwork already ships its own
/// navy background, so it reads the same on any surface.
class WakeMateLogo extends StatelessWidget {
  final double size;
  final bool onDark;

  const WakeMateLogo({super.key, this.size = 72, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.26),
      child: Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
