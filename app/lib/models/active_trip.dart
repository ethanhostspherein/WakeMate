import 'destination.dart';
import 'trip.dart';

/// A trip that is currently being tracked. Persisted to local storage so the
/// OS can restart the process mid-trip and we resume correctly (P2-08).
class ActiveTrip {
  final String id;
  final TripMode mode;
  final String? pnr;
  final Destination destination;
  final double alarmDistanceKm;
  final AlarmTriggerType triggerType;
  final int? triggerMinutes;
  final String soundId;
  final double volume;
  final bool maxVolumeOverride;
  final bool vibrate;
  final bool notifyFamily;
  final String? familyContactName;
  final String? familyContactPhone;
  final String? familyChannel;
  final double? startLat;
  final double? startLng;
  final DateTime startedAt;
  final bool alarmFired;

  const ActiveTrip({
    required this.id,
    this.mode = TripMode.bus,
    this.pnr,
    required this.destination,
    required this.alarmDistanceKm,
    this.triggerType = AlarmTriggerType.distance,
    this.triggerMinutes,
    required this.soundId,
    required this.volume,
    required this.maxVolumeOverride,
    required this.vibrate,
    this.notifyFamily = false,
    this.familyContactName,
    this.familyContactPhone,
    this.familyChannel,
    required this.startedAt,
    this.startLat,
    this.startLng,
    this.alarmFired = false,
  });

  ActiveTrip copyWith({
    double? alarmDistanceKm,
    bool? alarmFired,
    AlarmTriggerType? triggerType,
    int? triggerMinutes,
    bool? notifyFamily,
    String? familyContactName,
    String? familyContactPhone,
    String? familyChannel,
  }) {
    return ActiveTrip(
      id: id,
      mode: mode,
      pnr: pnr,
      destination: destination,
      alarmDistanceKm: alarmDistanceKm ?? this.alarmDistanceKm,
      triggerType: triggerType ?? this.triggerType,
      triggerMinutes: triggerMinutes ?? this.triggerMinutes,
      soundId: soundId,
      volume: volume,
      maxVolumeOverride: maxVolumeOverride,
      vibrate: vibrate,
      notifyFamily: notifyFamily ?? this.notifyFamily,
      familyContactName: familyContactName ?? this.familyContactName,
      familyContactPhone: familyContactPhone ?? this.familyContactPhone,
      familyChannel: familyChannel ?? this.familyChannel,
      startedAt: startedAt,
      startLat: startLat,
      startLng: startLng,
      alarmFired: alarmFired ?? this.alarmFired,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'mode': mode.name,
        'pnr': pnr,
        'destination': destination.toJson(),
        'alarmDistanceKm': alarmDistanceKm,
        'triggerType': triggerType.name,
        'triggerMinutes': triggerMinutes,
        'soundId': soundId,
        'volume': volume,
        'maxVolumeOverride': maxVolumeOverride,
        'vibrate': vibrate,
        'notifyFamily': notifyFamily,
        'familyContactName': familyContactName,
        'familyContactPhone': familyContactPhone,
        'familyChannel': familyChannel,
        'startLat': startLat,
        'startLng': startLng,
        'startedAt': startedAt.toIso8601String(),
        'alarmFired': alarmFired,
      };

  factory ActiveTrip.fromJson(Map<String, dynamic> json) => ActiveTrip(
        id: json['id'] as String,
        mode: TripMode.values.firstWhere(
          (e) => e.name == json['mode'],
          orElse: () => TripMode.bus,
        ),
        pnr: json['pnr'] as String?,
        destination:
            Destination.fromJson(json['destination'] as Map<String, dynamic>),
        alarmDistanceKm: (json['alarmDistanceKm'] as num).toDouble(),
        triggerType: AlarmTriggerType.values.firstWhere(
          (e) => e.name == json['triggerType'],
          orElse: () => AlarmTriggerType.distance,
        ),
        triggerMinutes: json['triggerMinutes'] as int?,
        soundId: json['soundId'] as String,
        volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
        maxVolumeOverride: json['maxVolumeOverride'] as bool? ?? true,
        vibrate: json['vibrate'] as bool? ?? true,
        notifyFamily: json['notifyFamily'] as bool? ?? false,
        familyContactName: json['familyContactName'] as String?,
        familyContactPhone: json['familyContactPhone'] as String?,
        familyChannel: json['familyChannel'] as String?,
        startLat: (json['startLat'] as num?)?.toDouble(),
        startLng: (json['startLng'] as num?)?.toDouble(),
        startedAt: DateTime.parse(json['startedAt'] as String),
        alarmFired: json['alarmFired'] as bool? ?? false,
      );
}

/// Live, in-memory tracking readout surfaced to the Tracking screen.
enum TrackingPhase { idle, tracking, alarm, completed }

/// Overall confidence that the alarm will fire reliably. Computed from GPS fix
/// quality and battery-optimization exemption (the two most common causes of
/// a missed alarm) — Reliability Engine.
enum ReliabilityLevel { green, yellow, red }

class TrackingState {
  final TrackingPhase phase;
  final ActiveTrip? trip;
  final double? remainingKm;
  final double? speedKmh;
  final int? etaMinutes;
  final double? currentLat;
  final double? currentLng;
  final String? error;
  final double? gpsAccuracyM;
  final bool? batteryExempt;
  final bool? notificationGranted;
  final bool? selfTestPassed;
  final double? closestRemainingKm;
  final bool missedStop;

  const TrackingState({
    this.phase = TrackingPhase.idle,
    this.trip,
    this.remainingKm,
    this.speedKmh,
    this.etaMinutes,
    this.currentLat,
    this.currentLng,
    this.error,
    this.gpsAccuracyM,
    this.batteryExempt,
    this.notificationGranted,
    this.selfTestPassed,
    this.closestRemainingKm,
    this.missedStop = false,
  });

  const TrackingState.idle() : this();

  bool get isActive =>
      phase == TrackingPhase.tracking || phase == TrackingPhase.alarm;

  /// green: good GPS fix, battery-exempt, notification permission granted,
  /// self-test passed (or not due yet). yellow: fix/self-test still
  /// settling. red: any hard failure — no notification permission (alarm
  /// can't show full-screen), not battery-exempt (top kill risk), self-test
  /// failed, or a poor GPS fix.
  ReliabilityLevel get reliabilityLevel {
    if (notificationGranted == false) return ReliabilityLevel.red;
    if (batteryExempt == false) return ReliabilityLevel.red;
    if (selfTestPassed == false) return ReliabilityLevel.red;
    if (gpsAccuracyM == null) return ReliabilityLevel.yellow;
    if (gpsAccuracyM! <= 50) return ReliabilityLevel.green;
    if (gpsAccuracyM! <= 150) return ReliabilityLevel.yellow;
    return ReliabilityLevel.red;
  }

  TrackingState copyWith({
    TrackingPhase? phase,
    ActiveTrip? trip,
    double? remainingKm,
    double? speedKmh,
    int? etaMinutes,
    double? currentLat,
    double? currentLng,
    String? error,
    bool clearEta = false,
    double? gpsAccuracyM,
    bool? batteryExempt,
    bool? notificationGranted,
    bool? selfTestPassed,
    double? closestRemainingKm,
    bool? missedStop,
  }) {
    return TrackingState(
      phase: phase ?? this.phase,
      trip: trip ?? this.trip,
      remainingKm: remainingKm ?? this.remainingKm,
      speedKmh: speedKmh ?? this.speedKmh,
      etaMinutes: clearEta ? null : (etaMinutes ?? this.etaMinutes),
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      error: error,
      gpsAccuracyM: gpsAccuracyM ?? this.gpsAccuracyM,
      batteryExempt: batteryExempt ?? this.batteryExempt,
      notificationGranted: notificationGranted ?? this.notificationGranted,
      selfTestPassed: selfTestPassed ?? this.selfTestPassed,
      closestRemainingKm: closestRemainingKm ?? this.closestRemainingKm,
      missedStop: missedStop ?? this.missedStop,
    );
  }
}
