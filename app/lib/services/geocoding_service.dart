import 'dart:convert';

import 'package:http/http.dart' as http;

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
  Future<List<Destination>> search(String query, {int limit = 6}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final uri = Uri.parse(_base).replace(queryParameters: {
      'q': q,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '$limit',
      'countrycodes': 'in',
    });
    try {
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as List<dynamic>;
      return data
          .map((e) => _toDestination(e as Map<String, dynamic>))
          .whereType<Destination>()
          .toList();
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
