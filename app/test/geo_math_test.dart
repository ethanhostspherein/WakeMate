import 'package:flutter_test/flutter_test.dart';
import 'package:wakemate/core/geo_math.dart';

void main() {
  group('GeoMath', () {
    test('distanceKm calculates correct distance between known coordinates', () {
      // Jaipur Junction (26.9196, 75.7878) to New Delhi Station (28.6430, 77.2194) ~240 km
      final dist = GeoMath.distanceKm(26.9196, 75.7878, 28.6430, 77.2194);
      expect(dist, greaterThan(235.0));
      expect(dist, lessThan(250.0));
    });

    test('distanceKm between identical points is 0', () {
      final dist = GeoMath.distanceKm(26.9196, 75.7878, 26.9196, 75.7878);
      expect(dist, equals(0.0));
    });

    test('msToKmh converts m/s to km/h correctly', () {
      expect(GeoMath.msToKmh(10), closeTo(36.0, 0.001));
      expect(GeoMath.msToKmh(0), equals(0.0));
    });

    test('etaMinutes returns correct rounded minutes at reasonable speeds', () {
      // 30 km at 60 km/h = 30 minutes
      expect(GeoMath.etaMinutes(30.0, 60.0), equals(30));

      // 10 km at 120 km/h = 5 minutes
      expect(GeoMath.etaMinutes(10.0, 120.0), equals(5));
    });

    test('etaMinutes returns null when stationary or speed is too low (< 3 km/h)', () {
      expect(GeoMath.etaMinutes(10.0, 2.0), isNull);
      expect(GeoMath.etaMinutes(10.0, 0.0), isNull);
    });
  });
}
