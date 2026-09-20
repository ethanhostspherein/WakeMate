import 'package:geolocator/geolocator.dart';

/// Wraps geolocator with WakeMate's adaptive-interval strategy and the Android
/// foreground-service notification that keeps tracking alive against Doze/OEM
/// kills (TRD §4.1, Implementation Plan P2-01/P2-02).
class LocationService {
  /// Coarse tier — used when far from the destination to save battery
  /// (60–90s / large distance filter). TRD §4.1 adaptive intervals.
  static const _coarseDistanceFilterM = 250;

  /// Fine tier — used once inside the outer radius (2× alarm distance).
  static const _fineDistanceFilterM = 15;

  /// Whether location services + permission are ready for background updates.
  Future<bool> ensureReady() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    // Attempt requesting background location ("Allow all the time") on Android
    // if only whileInUse was granted, so background updates don't get throttled.
    if (perm == LocationPermission.whileInUse) {
      try {
        perm = await Geolocator.requestPermission();
      } catch (_) {}
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  /// A best-effort current position that never hangs: it bounds the fresh-fix
  /// wait and falls back to the last known location so "Start journey" can't
  /// get stuck on a device that's slow to acquire GPS.
  Future<Position?> currentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  /// A position stream configured for the given tier. Re-subscribe with
  /// [fine] = true after crossing the outer radius to tighten the cadence.
  Stream<Position> positionStream({required bool fine}) {
    final settings = AndroidSettings(
      accuracy: fine ? LocationAccuracy.bestForNavigation : LocationAccuracy.high,
      distanceFilter: fine ? _fineDistanceFilterM : _coarseDistanceFilterM,
      // Persistent foreground service — the single most reliable way to keep
      // location updates flowing when the screen is locked / app backgrounded.
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'WakeMate is tracking your trip',
        notificationText: 'Tap to see remaining distance and ETA.',
        notificationChannelName: 'Trip tracking',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
    return Geolocator.getPositionStream(locationSettings: settings);
  }
}
