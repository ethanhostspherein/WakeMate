import 'active_trip.dart';
import 'destination.dart';
import 'trip.dart';

/// A trip scheduled to be armed at its departure time. Persisted so tapping the
/// departure notification can rebuild the trip even after a process restart.
class PendingTrip {
  final int id; // also the scheduled notification id
  final Destination destination;
  final double alarmDistanceKm;
  final TripMode mode;
  final String? pnr;
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
  final DateTime departureAt;

  const PendingTrip({
    required this.id,
    required this.destination,
    required this.alarmDistanceKm,
    this.mode = TripMode.bus,
    this.pnr,
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
    required this.departureAt,
  });

  /// Materialise into an ActiveTrip when the user arms it.
  ActiveTrip toActiveTrip() => ActiveTrip(
        id: id.toString(),
        mode: mode,
        pnr: pnr,
        destination: destination,
        alarmDistanceKm: alarmDistanceKm,
        triggerType: triggerType,
        triggerMinutes: triggerMinutes,
        soundId: soundId,
        volume: volume,
        maxVolumeOverride: maxVolumeOverride,
        vibrate: vibrate,
        notifyFamily: notifyFamily,
        familyContactName: familyContactName,
        familyContactPhone: familyContactPhone,
        familyChannel: familyChannel,
        startedAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'destination': destination.toJson(),
        'alarmDistanceKm': alarmDistanceKm,
        'mode': mode.name,
        'pnr': pnr,
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
        'departureAt': departureAt.toIso8601String(),
      };

  factory PendingTrip.fromJson(Map<String, dynamic> json) => PendingTrip(
        id: json['id'] as int,
        destination:
            Destination.fromJson(json['destination'] as Map<String, dynamic>),
        alarmDistanceKm: (json['alarmDistanceKm'] as num).toDouble(),
        mode: TripMode.values.firstWhere(
          (e) => e.name == json['mode'],
          orElse: () => TripMode.bus,
        ),
        pnr: json['pnr'] as String?,
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
        departureAt: DateTime.parse(json['departureAt'] as String),
      );
}
