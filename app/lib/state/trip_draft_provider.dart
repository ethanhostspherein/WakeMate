import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/alarm_settings.dart';
import '../models/destination.dart';
import '../models/trip_source.dart';

/// The trip the user is currently setting up, before it becomes an active Trip.
/// Flows across Destination Search → Set Alarm → Start Journey.
class TripDraft {
  final Destination? destination;
  final AlarmSettings alarm;

  /// Scheduled departure (from a shared ticket) — enables "Arm at departure".
  final DateTime? departureAt;
  final TripSource source;

  const TripDraft({
    this.destination,
    this.alarm = AlarmSettings.defaults,
    this.departureAt,
    this.source = TripSource.manual,
  });

  TripDraft copyWith({
    Destination? destination,
    AlarmSettings? alarm,
    DateTime? departureAt,
    TripSource? source,
  }) {
    return TripDraft(
      destination: destination ?? this.destination,
      alarm: alarm ?? this.alarm,
      departureAt: departureAt ?? this.departureAt,
      source: source ?? this.source,
    );
  }
}

class TripDraftController extends Notifier<TripDraft> {
  @override
  TripDraft build() => const TripDraft();

  void setDestination(Destination destination) {
    state = state.copyWith(destination: destination);
  }

  /// Seed the draft from a shared/parsed ticket, carrying the departure time so
  /// Set Alarm can offer "Arm at departure".
  void setFromShared({
    required Destination destination,
    DateTime? departureAt,
  }) {
    state = state.copyWith(
      destination: destination,
      departureAt: departureAt,
      source: TripSource.shared,
    );
  }

  void setAlarm(AlarmSettings alarm) {
    state = state.copyWith(alarm: alarm);
  }

  void setDistance(double km) {
    state = state.copyWith(alarm: state.alarm.copyWith(distanceKm: km));
  }

  void setSound(String soundId) {
    state = state.copyWith(alarm: state.alarm.copyWith(soundId: soundId));
  }

  void reset() {
    state = const TripDraft();
  }
}

final tripDraftProvider =
    NotifierProvider<TripDraftController, TripDraft>(TripDraftController.new);
