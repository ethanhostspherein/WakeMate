import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/geo_math.dart';
import '../models/destination.dart';

/// Keyless place search via OpenStreetMap's Nominatim API — the cost-control
/// fallback called out in the TRD (§2, §10) for when the Google Places key is
/// not configured. Used to resolve a shared ticket's destination name into
/// coordinates, and reusable for the destination search screen.
class GeocodingService {
  static const _base = 'https://nominatim.openstreetmap.org/search';

  // Nominatim requires an identifying User-Agent (usage policy).
  static const _headers = {
    'User-Agent': 'WakeMate/0.1 (travel alarm app)',
    'Accept': 'application/json',
  };

  /// Search places by free-text query. India-biased to match the target users.
  /// If userLat and userLng are provided, results are sorted by nearest proximity.
  Future<List<Destination>> search(
    String query, {
    int limit = 10,
    double? userLat,
    double? userLng,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final params = <String, String>{
      'q': q,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '$limit',
      'countrycodes': 'in',
    };

    if (userLat != null && userLng != null) {
      // Add viewbox surrounding user location for Nominatim search biasing
      final delta = 1.0;
      params['viewbox'] =
          '${userLng - delta},${userLat + delta},${userLng + delta},${userLat - delta}';
    }

    final uri = Uri.parse(_base).replace(queryParameters: params);
    try {
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as List<dynamic>;
      var results = data
          .map((e) => _toDestination(e as Map<String, dynamic>))
          .whereType<Destination>()
          .toList();

      if (userLat != null && userLng != null) {
        results = results.map((d) {
          final dist = GeoMath.distanceKm(userLat, userLng, d.lat, d.lng);
          return d.copyWith(distanceFromUserKm: dist);
        }).toList();

        // Sort nearest to user location first
        results.sort((a, b) => (a.distanceFromUserKm ?? double.infinity)
            .compareTo(b.distanceFromUserKm ?? double.infinity));
      }

      return results;
    } catch (_) {
      return [];
    }
  }

  /// Convenience: the single best match for a name (used for shared tickets).
  Future<Destination?> resolve(String name) async {
    final results = await search(name, limit: 1);
    return results.isEmpty ? null : results.first;
  }

  Destination? _toDestination(Map<String, dynamic> json) {
    final lat = double.tryParse(json['lat']?.toString() ?? '');
    final lng = double.tryParse(json['lon']?.toString() ?? '');
    if (lat == null || lng == null) return null;
    final displayName = json['display_name']?.toString() ?? '';
    final name = json['name']?.toString();
    final shortName = (name != null && name.isNotEmpty)
        ? name
        : displayName.split(',').first.trim();
    return Destination(
      placeName: shortName,
      lat: lat,
      lng: lng,
      address: displayName,
    );
  }
}
