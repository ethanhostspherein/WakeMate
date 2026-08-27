import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Real interactive OpenStreetMap preview widget displaying exact real-world
/// coordinates (lat, lng), map tiles, pins, and route polylines.
class MapPreview extends StatelessWidget {
  final double lat;
  final double lng;
  final double? startLat;
  final double? startLng;
  final double? userLat;
  final double? userLng;
  final double height;
  final double zoom;
  final bool showRoute;
  final String? destinationLabel;
  final BorderRadius? borderRadius;
  final MapController? mapController;
  final void Function(LatLng point)? onTap;

  const MapPreview({
    super.key,
    this.lat = 26.9124, // Default Jaipur
    this.lng = 75.7873,
    this.startLat,
    this.startLng,
    this.userLat,
    this.userLng,
    this.height = 160,
    this.zoom = 13.0,
    this.showRoute = false,
    this.destinationLabel,
    this.borderRadius,
    this.mapController,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppSpacing.radiusMd);
    final destPoint = LatLng(lat, lng);
    final startPoint = (startLat != null && startLng != null) ? LatLng(startLat!, startLng!) : null;
    final userPoint = (userLat != null && userLng != null) ? LatLng(userLat!, userLng!) : null;
    final centerPoint = userPoint ?? destPoint;

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: centerPoint,
                initialZoom: zoom,
                onTap: onTap != null ? (_, point) => onTap!(point) : null,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.wakemate.wakemate',
                ),
                if (showRoute && (userPoint != null || startPoint != null))
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [userPoint ?? startPoint!, destPoint],
                        strokeWidth: 4.0,
                        color: AppColors.accent,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (userPoint != null)
                      Marker(
                        point: userPoint,
                        width: 36,
                        height: 36,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 6),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (startPoint != null && userPoint == null)
                      Marker(
                        point: startPoint,
                        width: 32,
                        height: 32,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4),
                            ],
                          ),
                          child: const Icon(Icons.my_location_rounded, size: 16, color: Colors.white),
                        ),
                      ),
                    Marker(
                      point: destPoint,
                      width: 44,
                      height: 44,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 4),
                              ],
                            ),
                            child: const Icon(Icons.place_rounded, size: 20, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (destinationLabel != null)
              Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.sm,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.place_rounded, size: 16, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text(
                        destinationLabel!,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
