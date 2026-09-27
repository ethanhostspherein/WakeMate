import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/destination.dart';
import '../models/favorite.dart';
import '../models/trip.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_auth_service.dart';

/// Persistence service for User Created Recent Trips and Favorites.
class UserTripsService {
  UserTripsService._();
  static final UserTripsService instance = UserTripsService._();

  static const _recentKey = 'user_recent_trips_v1';
  static const _favoritesKey = 'user_favorites_v1';

  final _recentTripsController = StreamController<List<Trip>>.broadcast();

  /// Real-time stream of recent trips.
  Stream<List<Trip>> get recentTripsStream => _recentTripsController.stream;

  /// Load user-created recent trips.
  Future<List<Trip>> getRecentTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentKey);
    List<Trip> trips = [];

    if (raw != null) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        trips = list.map((item) => _tripFromJson(item as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    // Try syncing from Supabase database if configured
    try {
      final client = SupabaseAuthService.instance.client;
      final userId = SupabaseAuthService.instance.currentUser?.id;
      if (client != null && userId != null) {
        final data = await client
            .from('trips')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(20);

        final List<Trip> dbTrips = data.map((item) => _tripFromDbJson(item)).toList();
        final dbIds = dbTrips.map((t) => t.id).toSet();

        // Merge any local trips not yet in DB (e.g. created while offline/guest)
        for (final localTrip in trips) {
          if (!dbIds.contains(localTrip.id)) {
            dbTrips.add(localTrip);
            unawaited(_syncSingleTripToDb(client, userId, localTrip));
          }
        }

        if (dbTrips.isNotEmpty) {
          dbTrips.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          trips = dbTrips.take(20).toList();
          await _saveToPrefs(trips);
        }
      }
    } catch (e) {
      debugPrint('UserTripsService.getRecentTrips: Supabase sync failed: $e');
    }

    _recentTripsController.add(trips);
    return trips;
  }

  Future<void> _syncSingleTripToDb(SupabaseClient client, String userId, Trip trip) async {
    try {
      await client.from('trips').upsert({
        'id': trip.id,
        'user_id': userId,
        'destination_name': trip.destination.placeName,
        'destination_lat': trip.destination.lat,
        'destination_lng': trip.destination.lng,
        'alarm_distance_km': trip.alarmDistanceKm,
        'sound_id': trip.soundId,
        'mode': trip.mode.name,
        'pnr': trip.pnr,
        'trigger_type': trip.triggerType.name,
        'trigger_minutes': trip.triggerMinutes,
        'status': trip.status.name,
        'notify_family': trip.notifyFamily,
        'family_contact_name': trip.familyContactName,
        'family_contact_phone': trip.familyContactPhone,
        'family_channel': trip.familyChannel,
        'distance_travelled_km': trip.distanceTravelledKm,
        'completed_at': trip.completedAt?.toIso8601String(),
        'created_at': trip.createdAt.toIso8601String(),
      });
    } catch (e) {
      debugPrint('UserTripsService._syncSingleTripToDb failed: $e');
    }
  }

  /// Add a newly started trip to recent trips.
  Future<void> addTrip(Trip trip) async {
    final current = await getRecentTrips();
    current.removeWhere((t) => t.id == trip.id || t.destination.placeName == trip.destination.placeName);
    current.insert(0, trip);

    if (current.length > 20) {
      current.removeRange(20, current.length);
    }

    await _saveToPrefs(current);
    _recentTripsController.add(current);

    // Sync to Supabase table asynchronously if available
    try {
      final client = SupabaseAuthService.instance.client;
      final userId = SupabaseAuthService.instance.currentUser?.id;
      if (client != null && userId != null) {
        await client.from('trips').upsert({
          'id': trip.id,
          'user_id': userId,
          'destination_name': trip.destination.placeName,
          'destination_lat': trip.destination.lat,
          'destination_lng': trip.destination.lng,
          'alarm_distance_km': trip.alarmDistanceKm,
          'sound_id': trip.soundId,
          'mode': trip.mode.name,
          'pnr': trip.pnr,
          'trigger_type': trip.triggerType.name,
          'trigger_minutes': trip.triggerMinutes,
          'status': trip.status.name,
          'notify_family': trip.notifyFamily,
          'family_contact_name': trip.familyContactName,
          'family_contact_phone': trip.familyContactPhone,
          'family_channel': trip.familyChannel,
          'created_at': trip.createdAt.toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('UserTripsService.addTrip: Supabase sync failed: $e');
    }
  }

  /// Update trip status in real-time (e.g. active -> completed / cancelled).
  Future<void> updateTripStatus(
    String tripId,
    TripStatus status, {
    double? distanceTravelledKm,
    DateTime? completedAt,
  }) async {
    final current = await getRecentTrips();
    final index = current.indexWhere((t) => t.id == tripId);
    if (index != -1) {
      final old = current[index];
      current[index] = old.copyWith(
        status: status,
        distanceTravelledKm: distanceTravelledKm ?? old.distanceTravelledKm,
        completedAt: completedAt ?? DateTime.now(),
      );
      await _saveToPrefs(current);
      _recentTripsController.add(current);

      try {
        final client = SupabaseAuthService.instance.client;
        if (client != null) {
          await client.from('trips').update({
            'status': status.name,
            'distance_travelled_km': distanceTravelledKm,
            'completed_at': (completedAt ?? DateTime.now()).toIso8601String(),
          }).eq('id', tripId);
        }
      } catch (e) {
        debugPrint('UserTripsService.updateTripStatus: Supabase sync failed: $e');
      }
    }
  }

  /// Delete a recent trip by ID.
  Future<void> deleteTrip(String tripId) async {
    final current = await getRecentTrips();
    current.removeWhere((t) => t.id == tripId);

    await _saveToPrefs(current);
    _recentTripsController.add(current);

    try {
      final client = SupabaseAuthService.instance.client;
      if (client != null) {
        await client.from('trips').delete().eq('id', tripId);
      }
    } catch (e) {
      debugPrint('UserTripsService.deleteTrip: Supabase sync failed: $e');
    }
  }

  /// Update alarm distance for a recent trip.
  Future<void> updateTripDistance(String tripId, double newDistanceKm) async {
    final current = await getRecentTrips();
    final index = current.indexWhere((t) => t.id == tripId);
    if (index != -1) {
      final old = current[index];
      current[index] = old.copyWith(alarmDistanceKm: newDistanceKm);
      await _saveToPrefs(current);
      _recentTripsController.add(current);
    }
  }

  Future<void> _saveToPrefs(List<Trip> trips) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = trips.map((t) => _tripToJson(t)).toList();
    await prefs.setString(_recentKey, jsonEncode(jsonList));
  }

  /// Load user favorites.
  Future<List<Favorite>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_favoritesKey);
    if (raw == null) return [];

    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((item) => Favorite.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Check if place is favorited.
  Future<bool> isFavorite(String placeName) async {
    final favs = await getFavorites();
    return favs.any((f) => f.placeName.toLowerCase() == placeName.toLowerCase());
  }

  /// Add a new favorite.
  Future<void> addFavorite(Favorite favorite) async {
    final current = await getFavorites();
    current.removeWhere((f) => f.placeName == favorite.placeName);
    current.insert(0, favorite);

    final prefs = await SharedPreferences.getInstance();
    final jsonList = current.map((f) => f.toJson()).toList();
    await prefs.setString(_favoritesKey, jsonEncode(jsonList));
  }

  /// Remove a favorite by place name.
  Future<void> removeFavorite(String placeName) async {
    final current = await getFavorites();
    current.removeWhere((f) => f.placeName.toLowerCase() == placeName.toLowerCase());

    final prefs = await SharedPreferences.getInstance();
    final jsonList = current.map((f) => f.toJson()).toList();
    await prefs.setString(_favoritesKey, jsonEncode(jsonList));
  }

  /// Toggle favorite status for a destination. Returns true if now favorited, false if removed.
  Future<bool> toggleFavorite(Destination destination, {double? defaultAlarmDistanceKm}) async {
    final isFav = await isFavorite(destination.placeName);
    if (isFav) {
      await removeFavorite(destination.placeName);
      return false;
    } else {
      await addFavorite(Favorite(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        placeName: destination.placeName,
        lat: destination.lat,
        lng: destination.lng,
        defaultAlarmDistanceKm: defaultAlarmDistanceKm,
      ));
      return true;
    }
  }

  Map<String, dynamic> _tripToJson(Trip t) {
    return {
      'id': t.id,
      'mode': t.mode.name,
      'pnr': t.pnr,
      'destinationName': t.destination.placeName,
      'destinationLat': t.destination.lat,
      'destinationLng': t.destination.lng,
      'alarmDistanceKm': t.alarmDistanceKm,
      'triggerType': t.triggerType.name,
      'triggerMinutes': t.triggerMinutes,
      'soundId': t.soundId,
      'status': t.status.name,
      'notifyFamily': t.notifyFamily,
      'familyContactName': t.familyContactName,
      'familyContactPhone': t.familyContactPhone,
      'familyChannel': t.familyChannel,
      'distanceTravelledKm': t.distanceTravelledKm,
      'createdAt': t.createdAt.toIso8601String(),
      'completedAt': t.completedAt?.toIso8601String(),
    };
  }

  Trip _tripFromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String? ?? '',
      mode: TripMode.values.firstWhere(
        (e) => e.name == json['mode'],
        orElse: () => TripMode.bus,
      ),
      pnr: json['pnr'] as String?,
      destination: Destination(
        placeName: json['destinationName'] as String? ?? 'Unknown Destination',
        lat: (json['destinationLat'] as num?)?.toDouble() ?? 0.0,
        lng: (json['destinationLng'] as num?)?.toDouble() ?? 0.0,
      ),
      alarmDistanceKm: (json['alarmDistanceKm'] as num?)?.toDouble() ?? 3.0,
      triggerType: AlarmTriggerType.values.firstWhere(
        (e) => e.name == json['triggerType'],
        orElse: () => AlarmTriggerType.distance,
      ),
      triggerMinutes: json['triggerMinutes'] as int?,
      soundId: json['soundId'] as String? ?? 'alarm_classic',
      status: TripStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TripStatus.active,
      ),
      notifyFamily: json['notifyFamily'] as bool? ?? false,
      familyContactName: json['familyContactName'] as String?,
      familyContactPhone: json['familyContactPhone'] as String?,
      familyChannel: json['familyChannel'] as String?,
      distanceTravelledKm: (json['distanceTravelledKm'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
    );
  }

  Trip _tripFromDbJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String? ?? '',
      mode: TripMode.values.firstWhere(
        (e) => e.name == json['mode'],
        orElse: () => TripMode.bus,
      ),
      pnr: json['pnr'] as String?,
      destination: Destination(
        placeName: json['destination_name'] as String? ?? 'Unknown Destination',
        lat: (json['destination_lat'] as num?)?.toDouble() ?? 0.0,
        lng: (json['destination_lng'] as num?)?.toDouble() ?? 0.0,
      ),
      alarmDistanceKm: (json['alarm_distance_km'] as num?)?.toDouble() ?? 3.0,
      triggerType: AlarmTriggerType.values.firstWhere(
        (e) => e.name == json['trigger_type'],
        orElse: () => AlarmTriggerType.distance,
      ),
      triggerMinutes: json['trigger_minutes'] as int?,
      soundId: json['sound_id'] as String? ?? 'alarm_classic',
      status: TripStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TripStatus.active,
      ),
      notifyFamily: json['notify_family'] as bool? ?? false,
      familyContactName: json['family_contact_name'] as String?,
      familyContactPhone: json['family_contact_phone'] as String?,
      familyChannel: json['family_channel'] as String?,
      distanceTravelledKm: (json['distance_travelled_km'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      completedAt: DateTime.tryParse(json['completed_at'] as String? ?? ''),
    );
  }
}

