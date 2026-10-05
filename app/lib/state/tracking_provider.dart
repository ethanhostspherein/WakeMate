import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/geo_math.dart';
import '../models/active_trip.dart';
import '../models/trip.dart';
import '../services/alarm_service.dart';
import '../services/battery_optimization.dart';
import '../services/family_notify_service.dart';
import '../services/home_widget_service.dart';
import '../services/location_service.dart';
import '../services/trip_persistence.dart';
import '../services/trip_share_service.dart';
import '../services/user_trips_service.dart';

/// Central tracking controller. Owns the location subscription, computes live
/// distance/ETA/speed, switches polling tiers, and fires/handles the alarm.
/// Implementation Plan P2-02/03/04/08.
class TrackingController extends Notifier<TrackingState> {
  final _location = LocationService();
  final _persistence = TripPersistence();
  final _alarm = AlarmService.instance;
  final _share = TripShareService.instance;
  final _familyNotify = FamilyNotifyService.instance;

  StreamSubscription<Position>? _sub;
  bool _fineTier = false;
  String? _shareToken;
  DateTime? _lastShareUpdate;
  Timer? _selfTestTimer;

  String? get shareToken => _shareToken;

  /// Start (or return the existing) live ETA share link for the current
  /// trip. Position updates push to it from [_onPosition], throttled.
  Future<String?> startShare() async {
    if (_shareToken != null) return _shareToken;
    final trip = state.trip;
    if (trip == null) return null;
    _shareToken = await _share.createShare(
      tripId: trip.id,
      destLat: trip.destination.lat,
      destLng: trip.destination.lng,
      destName: trip.destination.placeName,
    );
    return _shareToken;
  }

  Future<void> stopShare() async {
    final token = _shareToken;
    if (token == null) return;
    _shareToken = null;
    await _share.revoke(token);
  }

  @override
  TrackingState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _selfTestTimer?.cancel();
    });
    return const TrackingState.idle();
  }

  /// Begin tracking a freshly-started trip.
  Future<void> start(ActiveTrip trip) async {
    await _alarm.init();
    await _persistence.save(trip);
    state = TrackingState(phase: TrackingPhase.tracking, trip: trip);
    _fineTier = false;
    _shareToken = null;
    _lastShareUpdate = null;

    // Seed an immediate reading so the UI isn't blank while the stream warms up.
    final now = await _location.currentPosition();
    if (now != null) _onPosition(now);

    _subscribe(fine: false);
    unawaited(refreshBatteryStatus());
    unawaited(refreshNotificationStatus());
    _scheduleSelfTest();
    unawaited(HomeWidgetService.instance
        .showActiveTrip(trip.destination.placeName, trip.alarmDistanceKm));
  }

  /// Check the notification-permission grant (Reliability Engine signal) —
  /// without it, the alarm can't show its full-screen intent.
  Future<void> refreshNotificationStatus() async {
    final status = await Permission.notification.status;
    state = state.copyWith(
        notificationGranted: status.isGranted || status.isLimited);
  }

  /// ~2min after start, run a collision-safe self-test (vibration-only,
  /// guarded by [AlarmService.isRinging]) so a dead vibrator/permission
  /// setup surfaces before the real alarm is needed.
  void _scheduleSelfTest() {
    _selfTestTimer?.cancel();
    _selfTestTimer = Timer(const Duration(minutes: 2), () async {
      if (state.phase != TrackingPhase.tracking || _alarm.isRinging) return;
      final passed = await _alarm.selfTest();
      state = state.copyWith(selfTestPassed: passed);
    });
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
    unawaited(refreshBatteryStatus());
    unawaited(refreshNotificationStatus());
    _scheduleSelfTest();
  }

  /// Re-check battery-optimization exemption (Reliability Engine signal).
  /// Called once on start/restore, and again after the user backs out of the
  /// OS settings screen from the reliability chip's "fix" tap.
  Future<void> refreshBatteryStatus() async {
    final exempt = await BatteryOptimization.isExempt();
    state = state.copyWith(batteryExempt: exempt);
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
    final closest = state.closestRemainingKm == null
        ? remainingKm
        : (remainingKm < state.closestRemainingKm! ? remainingKm : state.closestRemainingKm!);

    // Missed-stop: alarm already fired (phase == alarm means still
    // unacknowledged) and the vehicle has since moved noticeably further from
    // the destination than its closest approach — likely rode past the stop.
    final missedStop = state.missedStop ||
        (state.phase == TrackingPhase.alarm && remainingKm - closest >= 1.5);

    // Escalate once, right on the false→true transition.
    if (missedStop && !state.missedStop) {
      unawaited(_alarm.escalate());
      if (trip.notifyFamily) {
        unawaited(_familyNotify.notifyMissedStop(trip));
      }
    }

    state = state.copyWith(
      remainingKm: remainingKm,
      speedKmh: speedKmh,
      etaMinutes: eta,
      clearEta: eta == null,
      currentLat: p.latitude,
      currentLng: p.longitude,
      gpsAccuracyM: p.accuracy,
      closestRemainingKm: closest,
      missedStop: missedStop,
    );

    // Tighten polling once inside the outer radius (2× alarm distance).
    if (!_fineTier && remainingKm <= trip.alarmDistanceKm * 2) {
      _subscribe(fine: true);
    }

    // Push to the live share link, if active — throttled to ~15s so an
    // active share doesn't multiply write volume by the fine-tier GPS rate.
    final shareToken = _shareToken;
    if (shareToken != null &&
        (_lastShareUpdate == null ||
            DateTime.now().difference(_lastShareUpdate!) >
                const Duration(seconds: 15))) {
      _lastShareUpdate = DateTime.now();
      unawaited(_share.updatePosition(shareToken, p.latitude, p.longitude, eta));
    }

    bool shouldFire = false;
    if (trip.triggerType == AlarmTriggerType.time && trip.triggerMinutes != null) {
      if (eta != null && eta <= trip.triggerMinutes!) {
        shouldFire = true;
      } else if (remainingKm <= trip.alarmDistanceKm) {
        shouldFire = true;
      }
    } else {
      if (remainingKm <= trip.alarmDistanceKm) {
        shouldFire = true;
      }
    }

    if (!trip.alarmFired && shouldFire) {
      await _triggerAlarm();
    }
  }

  Future<void> _triggerAlarm({bool simulated = false}) async {
    final trip = state.trip;
    if (trip == null || (!simulated && trip.alarmFired)) return;

    // A simulated/test alarm must not mark the real trip as fired — that
    // would (a) permanently block the real distance-based alarm from ever
    // firing again, and (b) get recorded as a real arrival on dismiss.
    if (simulated) {
      state = state.copyWith(phase: TrackingPhase.alarm, simulated: true);
    } else {
      final fired = trip.copyWith(alarmFired: true);
      await _persistence.save(fired);
      state = state.copyWith(
        phase: TrackingPhase.alarm,
        trip: fired,
        closestRemainingKm: state.remainingKm,
      );
    }

    // Keep a coarse subscription alive (instead of cancelling outright) so
    // missed-stop detection can see the vehicle continuing past the
    // destination while the alarm is still ringing unacknowledged.
    _subscribe(fine: false);

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

    if (state.simulated) {
      state = state.copyWith(phase: TrackingPhase.tracking, simulated: false);
      _subscribe(fine: _shouldBeFine());
      return;
    }

    final shorter = trip.alarmDistanceKm > 1 ? 1.0 : trip.alarmDistanceKm / 2;
    final rearmed =
        trip.copyWith(alarmDistanceKm: shorter, alarmFired: false);
    await _persistence.save(rearmed);
    state = state.copyWith(
      phase: TrackingPhase.tracking,
      trip: rearmed,
      missedStop: false,
      closestRemainingKm: state.remainingKm,
    );
    _subscribe(fine: true);
  }

  /// Dismiss: end the trip successfully.
  Future<void> dismiss() async {
    if (state.simulated) {
      // Just a sound/vibration/lock-screen test — resume the real trip
      // instead of ending it; nothing was actually completed.
      await _alarm.stop();
      state = state.copyWith(phase: TrackingPhase.tracking, simulated: false);
      _subscribe(fine: _shouldBeFine());
      return;
    }

    final trip = state.trip;
    _selfTestTimer?.cancel();
    await _alarm.stop();
    await _sub?.cancel();
    _sub = null;
    await stopShare();
    await _persistence.clear();
    if (trip != null) {
      // ponytail: straight-line start→destination distance, not actual GPS
      // path length (no route history is recorded). Good enough for the
      // travel-stats card; upgrade to accumulated path length if needed.
      final distanceTravelledKm = trip.startLat != null && trip.startLng != null
          ? GeoMath.distanceKm(trip.startLat!, trip.startLng!,
              trip.destination.lat, trip.destination.lng)
          : null;
      await UserTripsService.instance.updateTripStatus(
        trip.id,
        TripStatus.completed,
        completedAt: DateTime.now(),
        distanceTravelledKm: distanceTravelledKm,
      );
      unawaited(HomeWidgetService.instance
          .showLastTrip(trip.destination.placeName));
    }
    state = TrackingState(phase: TrackingPhase.completed, trip: state.trip);
  }

  /// Stop/cancel the trip before arrival.
  Future<void> stop() async {
    final trip = state.trip;
    _selfTestTimer?.cancel();
    await _alarm.stop();
    await _sub?.cancel();
    _sub = null;
    await stopShare();
    await _persistence.clear();
    if (trip != null) {
      await UserTripsService.instance.updateTripStatus(
        trip.id,
        TripStatus.cancelled,
      );
      unawaited(HomeWidgetService.instance.clear());
    }
    state = const TrackingState.idle();
  }

  /// Debug helper (Phase 1/2): force the alarm without waiting to arrive,
  /// without touching the real trip's fired/completed state.
  Future<void> debugTriggerAlarm() => _triggerAlarm(simulated: true);
}

final trackingProvider =
    NotifierProvider<TrackingController, TrackingState>(TrackingController.new);
