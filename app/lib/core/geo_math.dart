import 'dart:math' as math;

/// On-device geo calculations. Deliberately dependency-free and offline — the
/// alarm math must never require a routing API mid-trip (TRD §6, PRD NFR).
class GeoMath {
  GeoMath._();

  static const double earthRadiusKm = 6371.0;

  /// Great-circle (haversine) distance in kilometres.
  static double distanceKm(
      double lat1, double lng1, double lat2, double lng2) {
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// ETA in minutes from a straight-line remaining distance and current speed.
  /// Returns null when speed is too low to be meaningful (avoids "∞ min").
  static int? etaMinutes(double remainingKm, double speedKmh) {
    if (speedKmh < 3) return null; // stationary / GPS noise
    final hours = remainingKm / speedKmh;
    return (hours * 60).round();
  }

  static double msToKmh(double metersPerSecond) => metersPerSecond * 3.6;

  static double _rad(double deg) => deg * (math.pi / 180);
}
