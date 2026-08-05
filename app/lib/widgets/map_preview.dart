import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Lightweight stylised map placeholder used across Phase 1 in place of the
/// live Google Maps SDK (which needs an API key + native config — wired in a
/// later task). Draws a calm grid, a route line, and pins so screens read
/// correctly without network map tiles.
class MapPreview extends StatelessWidget {
  final double height;
  final bool showRoute;
  final String? destinationLabel;
  final BorderRadius? borderRadius;

  const MapPreview({
    super.key,
    this.height = 160,
    this.showRoute = false,
    this.destinationLabel,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius =
        borderRadius ?? BorderRadius.circular(AppSpacing.radiusMd);
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _MapPainter(showRoute: showRoute),
          child: Stack(
            children: [
              if (destinationLabel != null)
                Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.place_rounded,
                            size: 14, color: AppColors.accent),
                        const SizedBox(width: 4),
                        Text(destinationLabel!,
                            style:
                                Theme.of(context).textTheme.labelMedium),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final bool showRoute;
  _MapPainter({required this.showRoute});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFE9EEF3);
    canvas.drawRect(Offset.zero & size, bg);

    // Faint grid — reads as a map without needing tiles.
    final grid = Paint()
      ..color = const Color(0xFFD3DBE3)
      ..strokeWidth = 1;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // A couple of "roads" for texture.
    final road = Paint()
      ..color = const Color(0xFFF7F8FA)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, size.height * 0.7),
        Offset(size.width, size.height * 0.35), road);
    canvas.drawLine(Offset(size.width * 0.3, 0),
        Offset(size.width * 0.55, size.height), road);

    if (showRoute) {
      final start = Offset(size.width * 0.2, size.height * 0.8);
      final end = Offset(size.width * 0.78, size.height * 0.25);
      final route = Paint()
        ..color = AppColors.accent
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(
            size.width * 0.5, size.height * 0.9, end.dx, end.dy);
      canvas.drawPath(path, route);

      _drawPin(canvas, start, AppColors.primary);
      _drawPin(canvas, end, AppColors.accent);
    } else {
      _drawPin(canvas, Offset(size.width / 2, size.height / 2),
          AppColors.accent);
    }
  }

  void _drawPin(Canvas canvas, Offset center, Color color) {
    final halo = Paint()..color = color.withValues(alpha: 0.18);
    canvas.drawCircle(center, 14, halo);
    final dot = Paint()..color = color;
    canvas.drawCircle(center, 6, dot);
    final ring = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, 6, ring);
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) =>
      oldDelegate.showRoute != showRoute;
}

/// Convenience: a haversine distance in km between two lat/lng points.
/// Used by the tracking calc later; handy now for realistic mock distances.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _rad(double deg) => deg * (math.pi / 180);
