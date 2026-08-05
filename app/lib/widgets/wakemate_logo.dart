import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Custom transit-themed mark (bell + location pin) rather than a generic
/// stock map pin — UI/UX Brief §2.3. Drawn in code so it scales crisply and
/// ships without an asset dependency.
class WakeMateLogo extends StatelessWidget {
  final double size;
  final bool onDark;

  const WakeMateLogo({super.key, this.size = 72, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LogoPainter(onDark: onDark),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final bool onDark;
  _LogoPainter({required this.onDark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h * 0.44);

    // Rounded teal container.
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.08, w * 0.84, h * 0.84),
      Radius.circular(w * 0.26),
    );
    final bg = Paint()..color = AppColors.accent;
    if (onDark) {
      canvas.drawRRect(bgRect, bg);
    }

    final bellColor = onDark ? Colors.white : AppColors.accent;
    final bell = Paint()
      ..color = bellColor
      ..style = PaintingStyle.fill;

    // Bell body — a dome sitting on a flat base.
    final bellPath = Path();
    final bellTop = center.dy - h * 0.16;
    final bellW = w * 0.34;
    bellPath.moveTo(center.dx - bellW, center.dy + h * 0.10);
    bellPath.quadraticBezierTo(
      center.dx - bellW,
      bellTop,
      center.dx,
      bellTop,
    );
    bellPath.quadraticBezierTo(
      center.dx + bellW,
      bellTop,
      center.dx + bellW,
      center.dy + h * 0.10,
    );
    bellPath.close();
    canvas.drawPath(bellPath, bell);

    // Bell base bar.
    final baseBar = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(center.dx, center.dy + h * 0.13),
          width: bellW * 2.4,
          height: h * 0.055),
      Radius.circular(h * 0.03),
    );
    canvas.drawRRect(baseBar, bell);

    // Clapper — a location-pin dot, tying "wake" to "place".
    final pinColor = onDark ? AppColors.primary : Colors.white;
    final clapper = Paint()..color = pinColor;
    canvas.drawCircle(
        Offset(center.dx, center.dy + h * 0.205), h * 0.045, clapper);

    // Top knob.
    canvas.drawCircle(Offset(center.dx, bellTop - h * 0.02), h * 0.03, bell);
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) =>
      oldDelegate.onDark != onDark;
}
