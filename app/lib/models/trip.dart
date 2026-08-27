import 'destination.dart';

/// Alarm trigger mechanism: distance-based or time-before-arrival.
enum AlarmTriggerType { distance, time }

/// Trip lifecycle status — mirrors `trips.status` in the Backend Schema.
enum TripStatus { active, alarmTriggered, completed, cancelled }

/// Travel mode.
enum TripMode { destination, bus, train, metro }

/// A single journey record.
class Trip {
  final String id;
  final TripMode mode;
  final String? pnr;
  final Destination destination;
  final double alarmDistanceKm;
  final AlarmTriggerType triggerType;
  final int? triggerMinutes;
  final String soundId;
  final TripStatus status;
  final bool notifyFamily;
  final String? familyContactName;
  final String? familyContactPhone;
  final String? familyChannel;
  final double? distanceTravelledKm;
  final DateTime createdAt;
  final DateTime? completedAt;
  final bool alarmTriggered;

  const Trip({
    required this.id,
    required this.mode,
    this.pnr,
    required this.destination,
    required this.alarmDistanceKm,
    this.triggerType = AlarmTriggerType.distance,
    this.triggerMinutes,
    required this.soundId,
    required this.status,
    this.notifyFamily = false,
    this.familyContactName,
    this.familyContactPhone,
    this.familyChannel,
    required this.createdAt,
    this.distanceTravelledKm,
    this.completedAt,
    this.alarmTriggered = false,
  });

  bool get reachedSuccessfully => status == TripStatus.completed;

  Trip copyWith({
    TripStatus? status,
    double? distanceTravelledKm,
    DateTime? completedAt,
    bool? alarmTriggered,
    double? alarmDistanceKm,
    AlarmTriggerType? triggerType,
    int? triggerMinutes,
    String? pnr,
    TripMode? mode,
    bool? notifyFamily,
    String? familyContactName,
    String? familyContactPhone,
    String? familyChannel,
  }) {
    return Trip(
      id: id,
      mode: mode ?? this.mode,
      pnr: pnr ?? this.pnr,
      destination: destination,
      alarmDistanceKm: alarmDistanceKm ?? this.alarmDistanceKm,
      triggerType: triggerType ?? this.triggerType,
      triggerMinutes: triggerMinutes ?? this.triggerMinutes,
      soundId: soundId,
      status: status ?? this.status,
      notifyFamily: notifyFamily ?? this.notifyFamily,
      familyContactName: familyContactName ?? this.familyContactName,
      familyContactPhone: familyContactPhone ?? this.familyContactPhone,
      familyChannel: familyChannel ?? this.familyChannel,
      createdAt: createdAt,
      distanceTravelledKm: distanceTravelledKm ?? this.distanceTravelledKm,
      completedAt: completedAt ?? this.completedAt,
      alarmTriggered: alarmTriggered ?? this.alarmTriggered,
    );
  }
}

