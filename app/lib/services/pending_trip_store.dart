import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/pending_trip.dart';

/// Persists trips scheduled to arm at departure. Keyed by notification id so a
/// tapped departure notification can rebuild the trip after a restart.
class PendingTripStore {
  static const _key = 'pending_trips_v1';

  Future<List<PendingTrip>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    final trips = <PendingTrip>[];
    for (final s in raw) {
      try {
        trips.add(PendingTrip.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {/* skip corrupt entries */}
    }
    return trips;
  }

  Future<void> add(PendingTrip trip) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? <String>[];
    list.add(jsonEncode(trip.toJson()));
    await prefs.setStringList(_key, list);
  }

  Future<PendingTrip?> take(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? <String>[];
    PendingTrip? found;
    final remaining = <String>[];
    for (final s in list) {
      try {
        final t = PendingTrip.fromJson(jsonDecode(s) as Map<String, dynamic>);
        if (t.id == id) {
          found = t;
        } else {
          remaining.add(s);
        }
      } catch (_) {/* drop corrupt */}
    }
    await prefs.setStringList(_key, remaining);
    return found;
  }

  Future<void> remove(int id) async => take(id);
}
