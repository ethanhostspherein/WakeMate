import 'destination.dart';

/// A trip that is currently being tracked. Persisted to local storage so the
/// OS can restart the process mid-trip and we resume correctly (P2-08).
class ActiveTrip {
  final String id;
  final Destination destination;
  final double alarmDistanceKm;
  final String soundId;
  final double volume;
  final bool maxVolumeOverride;
  final bool vibrate;
  final double? startLat;
  final double? startLng;
  final DateTime startedAt;
  final bool alarmFired;

  const ActiveTrip({
    required this.id,
    required this.destination,
    required this.alarmDistanceKm,
    required this.soundId,
    required this.volume,
    required this.maxVolumeOverride,
    required this.vibrate,
    required this.startedAt,
    this.startLat,
    this.startLng,
    this.alarmFired = false,
  });

  ActiveTrip copyWith({double? alarmDistanceKm, bool? alarmFired}) {
    return ActiveTrip(
      id: id,
      destination: destination,
      alarmDistanceKm: alarmDistanceKm ?? this.alarmDistanceKm,
      soundId: soundId,
      volume: volume,
      maxVolumeOverride: maxVolumeOverride,
      vibrate: vibrate,
      startedAt: startedAt,
      startLat: startLat,
      startLng: startLng,
      alarmFired: alarmFired ?? this.alarmFired,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'destination': destination.toJson(),
        'alarmDistanceKm': alarmDistanceKm,
        'soundId': soundId,
        'volume': volume,
        'maxVolumeOverride': maxVolumeOverride,
        'vibrate': vibrate,
        'startLat': startLat,
        'startLng': startLng,
        'startedAt': startedAt.toIso8601String(),
        'alarmFired': alarmFired,
      };

  factory ActiveTrip.fromJson(Map<String, dynamic> json) => ActiveTrip(
        id: json['id'] as String,
        destination:
            Destination.fromJson(json['destination'] as Map<String, dynamic>),
        alarmDistanceKm: (json['alarmDistanceKm'] as num).toDouble(),
        soundId: json['soundId'] as String,
        volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
        maxVolumeOverride: json['maxVolumeOverride'] as bool? ?? true,
        vibrate: json['vibrate'] as bool? ?? true,
        startLat: (json['startLat'] as num?)?.toDouble(),
        startLng: (json['startLng'] as num?)?.toDouble(),
        startedAt: DateTime.parse(json['startedAt'] as String),
        alarmFired: json['alarmFired'] as bool? ?? false,
      );
}

/// Live, in-memory tracking readout surfaced to the Tracking screen.
enum TrackingPhase { idle, tracking, alarm, completed }

class TrackingState {
  final TrackingPhase phase;
  final ActiveTrip? trip;
  final double? remainingKm;
  final double? speedKmh;
  final int? etaMinutes;
  final double? currentLat;
  final double? currentLng;
  final String? error;

  const TrackingState({
    this.phase = TrackingPhase.idle,
    this.trip,
    this.remainingKm,
    this.speedKmh,
    this.etaMinutes,
    this.currentLat,
    this.currentLng,
    this.error,
  });

  const TrackingState.idle() : this();

  bool get isActive =>
      phase == TrackingPhase.tracking || phase == TrackingPhase.alarm;

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
    );
  }
}
