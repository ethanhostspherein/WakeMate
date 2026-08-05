import 'active_trip.dart';
import 'destination.dart';

/// A trip scheduled to be armed at its departure time. Persisted so tapping the
/// departure notification can rebuild the trip even after a process restart.
class PendingTrip {
  final int id; // also the scheduled notification id
  final Destination destination;
  final double alarmDistanceKm;
  final String soundId;
  final double volume;
  final bool maxVolumeOverride;
  final bool vibrate;
  final DateTime departureAt;

  const PendingTrip({
    required this.id,
    required this.destination,
    required this.alarmDistanceKm,
    required this.soundId,
    required this.volume,
    required this.maxVolumeOverride,
    required this.vibrate,
    required this.departureAt,
  });

  /// Materialise into an ActiveTrip when the user arms it.
  ActiveTrip toActiveTrip() => ActiveTrip(
        id: id.toString(),
        destination: destination,
        alarmDistanceKm: alarmDistanceKm,
        soundId: soundId,
        volume: volume,
        maxVolumeOverride: maxVolumeOverride,
        vibrate: vibrate,
        startedAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'destination': destination.toJson(),
        'alarmDistanceKm': alarmDistanceKm,
        'soundId': soundId,
        'volume': volume,
        'maxVolumeOverride': maxVolumeOverride,
        'vibrate': vibrate,
        'departureAt': departureAt.toIso8601String(),
      };

  factory PendingTrip.fromJson(Map<String, dynamic> json) => PendingTrip(
        id: json['id'] as int,
        destination:
            Destination.fromJson(json['destination'] as Map<String, dynamic>),
        alarmDistanceKm: (json['alarmDistanceKm'] as num).toDouble(),
        soundId: json['soundId'] as String,
        volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
        maxVolumeOverride: json['maxVolumeOverride'] as bool? ?? true,
        vibrate: json['vibrate'] as bool? ?? true,
        departureAt: DateTime.parse(json['departureAt'] as String),
      );
}
