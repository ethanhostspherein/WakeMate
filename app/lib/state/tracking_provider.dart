import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../core/geo_math.dart';
import '../models/active_trip.dart';
import '../services/alarm_service.dart';
import '../services/location_service.dart';
import '../services/trip_persistence.dart';

/// Central tracking controller. Owns the location subscription, computes live
/// distance/ETA/speed, switches polling tiers, and fires/handles the alarm.
/// Implementation Plan P2-02/03/04/08.
class TrackingController extends Notifier<TrackingState> {
  final _location = LocationService();
  final _persistence = TripPersistence();
  final _alarm = AlarmService.instance;

  StreamSubscription<Position>? _sub;
  bool _fineTier = false;

  @override
  TrackingState build() {
    ref.onDispose(() => _sub?.cancel());
    return const TrackingState.idle();
  }

  /// Begin tracking a freshly-started trip.
  Future<void> start(ActiveTrip trip) async {
    await _alarm.init();
    await _persistence.save(trip);
    state = TrackingState(phase: TrackingPhase.tracking, trip: trip);
    _fineTier = false;

    // Seed an immediate reading so the UI isn't blank while the stream warms up.
    final now = await _location.currentPosition();
    if (now != null) _onPosition(now);

    _subscribe(fine: false);
  }

  /// On app launch: resume an interrupted trip if one was persisted (P2-08).
  Future<void> restoreIfAny() async {
    if (state.isActive) return;
    final trip = await _persistence.load();
    if (trip == null) return;
    await _alarm.init();
    state = TrackingState(phase: TrackingPhase.tracking, trip: trip);
    _fineTier = false;

    final now = await _location.currentPosition();
    if (now != null) {
      // If we already passed the threshold while the process was dead, fire
      // the alarm retroactively (App Flow §7, TRD §4.2).
      final remaining = GeoMath.distanceKm(now.latitude, now.longitude,
          trip.destination.lat, trip.destination.lng);
      if (remaining <= trip.alarmDistanceKm) {
        await _triggerAlarm();
        return;
      }
      _onPosition(now);
    }
    _subscribe(fine: _shouldBeFine());
  }

  void _subscribe({required bool fine}) {
    _sub?.cancel();
    _fineTier = fine;
    _sub = _location.positionStream(fine: fine).listen(
      _onPosition,
      onError: (e) => state = state.copyWith(error: e.toString()),
    );
  }

  bool _shouldBeFine() {
    final trip = state.trip;
    final remaining = state.remainingKm;
    if (trip == null || remaining == null) return false;
    return remaining <= trip.alarmDistanceKm * 2; // inside outer radius
  }

  Future<void> _onPosition(Position p) async {
    final trip = state.trip;
    if (trip == null) return;

    final remainingKm = GeoMath.distanceKm(
        p.latitude, p.longitude, trip.destination.lat, trip.destination.lng);
    final speedKmh = GeoMath.msToKmh(p.speed.clamp(0, 120).toDouble());
    final eta = GeoMath.etaMinutes(remainingKm, speedKmh);

    state = state.copyWith(
      remainingKm: remainingKm,
      speedKmh: speedKmh,
      etaMinutes: eta,
      clearEta: eta == null,
      currentLat: p.latitude,
      currentLng: p.longitude,
    );

    // Tighten polling once inside the outer radius (2× alarm distance).
    if (!_fineTier && remainingKm <= trip.alarmDistanceKm * 2) {
      _subscribe(fine: true);
    }

    if (!trip.alarmFired && remainingKm <= trip.alarmDistanceKm) {
      await _triggerAlarm();
    }
  }

  Future<void> _triggerAlarm() async {
    final trip = state.trip;
    if (trip == null || trip.alarmFired) return;

    final fired = trip.copyWith(alarmFired: true);
    await _persistence.save(fired);
    state = state.copyWith(phase: TrackingPhase.alarm, trip: fired);

    // Stop consuming location updates while the alarm rings.
    await _sub?.cancel();
    _sub = null;

    await _alarm.fire(
      soundId: trip.soundId,
      volume: trip.volume,
      maxVolumeOverride: trip.maxVolumeOverride,
      vibrate: trip.vibrate,
      destinationName: trip.destination.placeName,
    );
  }

  /// Snooze: silence the alarm and re-arm at a shorter distance (TRD §5).
  Future<void> snooze() async {
    final trip = state.trip;
    if (trip == null) return;
    await _alarm.stop();

    final shorter = trip.alarmDistanceKm > 1 ? 1.0 : trip.alarmDistanceKm / 2;
    final rearmed =
        trip.copyWith(alarmDistanceKm: shorter, alarmFired: false);
    await _persistence.save(rearmed);
    state = state.copyWith(phase: TrackingPhase.tracking, trip: rearmed);
    _subscribe(fine: true);
  }

  /// Dismiss: end the trip successfully.
  Future<void> dismiss() async {
    await _alarm.stop();
    await _sub?.cancel();
    _sub = null;
    await _persistence.clear();
    state = TrackingState(phase: TrackingPhase.completed, trip: state.trip);
  }

  /// Stop/cancel the trip before arrival.
  Future<void> stop() async {
    await _alarm.stop();
    await _sub?.cancel();
    _sub = null;
    await _persistence.clear();
    state = const TrackingState.idle();
  }

  /// Debug helper (Phase 1/2): force the alarm without waiting to arrive.
  Future<void> debugTriggerAlarm() => _triggerAlarm();
}

final trackingProvider =
    NotifierProvider<TrackingController, TrackingState>(TrackingController.new);
