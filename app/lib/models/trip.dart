import 'destination.dart';

/// Trip lifecycle status — mirrors `trips.status` in the Backend Schema.
enum TripStatus { active, alarmTriggered, completed, cancelled }

/// Travel mode. V1 ships `destination`; train/bus/metro land in V2.
enum TripMode { destination, train, bus, metro }

/// A single journey record. In Phase 1 this is populated from mock data;
/// Phase 3 wires it to the /trip endpoints.
class Trip {
  final String id;
  final TripMode mode;
  final Destination destination;
  final double alarmDistanceKm;
  final String soundId;
  final TripStatus status;
  final double? distanceTravelledKm;
  final DateTime createdAt;
  final DateTime? completedAt;
  final bool alarmTriggered;

  const Trip({
    required this.id,
    required this.mode,
    required this.destination,
    required this.alarmDistanceKm,
    required this.soundId,
    required this.status,
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
  }) {
    return Trip(
      id: id,
      mode: mode,
      destination: destination,
      alarmDistanceKm: alarmDistanceKm,
      soundId: soundId,
      status: status ?? this.status,
      createdAt: createdAt,
      distanceTravelledKm: distanceTravelledKm ?? this.distanceTravelledKm,
      completedAt: completedAt ?? this.completedAt,
      alarmTriggered: alarmTriggered ?? this.alarmTriggered,
    );
  }
}
