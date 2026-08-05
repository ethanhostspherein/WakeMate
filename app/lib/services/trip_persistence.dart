import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/active_trip.dart';

/// Persists the single active trip so tracking survives a process restart by
/// the OS (App Flow §7, Implementation Plan P2-08).
class TripPersistence {
  static const _key = 'active_trip_v1';

  Future<void> save(ActiveTrip trip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(trip.toJson()));
  }

  Future<ActiveTrip?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return ActiveTrip.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
