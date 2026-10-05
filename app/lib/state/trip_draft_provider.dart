import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/alarm_settings.dart';
import '../models/destination.dart';
import '../models/trip.dart';
import '../models/trip_source.dart';

/// The trip the user is currently setting up, before it becomes an active Trip.
/// Flows across Destination Search → Set Alarm → Start Journey.
class TripDraft {
  final Destination? destination;
  final AlarmSettings alarm;
  final TripMode mode;
  final String? pnrNumber;

  /// Family notification options
  final bool notifyFamily;
  final String? familyContactName;
  final String? familyContactPhone;
  final String familyChannel; // 'whatsapp' | 'sms'
  final bool saveContactForFuture;

  /// Scheduled departure (from a shared ticket) — enables "Arm at departure".
  final DateTime? departureAt;
  final TripSource source;

  const TripDraft({
    this.destination,
    required this.alarm,
    this.mode = TripMode.bus,
    this.pnrNumber,
    this.notifyFamily = false,
    this.familyContactName,
    this.familyContactPhone,
    this.familyChannel = 'whatsapp',
    this.saveContactForFuture = true,
    this.departureAt,
    this.source = TripSource.manual,
  });

  TripDraft copyWith({
    Destination? destination,
    AlarmSettings? alarm,
    TripMode? mode,
    String? pnrNumber,
    bool? notifyFamily,
    String? familyContactName,
    String? familyContactPhone,
    String? familyChannel,
    bool? saveContactForFuture,
    DateTime? departureAt,
    TripSource? source,
  }) {
    return TripDraft(
      destination: destination ?? this.destination,
      alarm: alarm ?? this.alarm,
      mode: mode ?? this.mode,
      pnrNumber: pnrNumber ?? this.pnrNumber,
      notifyFamily: notifyFamily ?? this.notifyFamily,
      familyContactName: familyContactName ?? this.familyContactName,
      familyContactPhone: familyContactPhone ?? this.familyContactPhone,
      familyChannel: familyChannel ?? this.familyChannel,
      saveContactForFuture: saveContactForFuture ?? this.saveContactForFuture,
      departureAt: departureAt ?? this.departureAt,
      source: source ?? this.source,
    );
  }
}

class TripDraftController extends Notifier<TripDraft> {
  @override
  TripDraft build() => TripDraft(alarm: AlarmSettings.defaults);

  void setDestination(Destination destination) {
    state = state.copyWith(destination: destination);
  }

  void setMode(TripMode mode) {
    state = state.copyWith(mode: mode);
  }

  void setPnr(String pnr) {
    state = state.copyWith(pnrNumber: pnr);
  }

  void setNotifyFamily(bool notify) {
    state = state.copyWith(notifyFamily: notify);
  }

  void setFamilyContactInfo({String? name, String? phone}) {
    state = state.copyWith(
      familyContactName: name ?? state.familyContactName,
      familyContactPhone: phone ?? state.familyContactPhone,
    );
  }

  void setFamilyChannel(String channel) {
    state = state.copyWith(familyChannel: channel);
  }

  void setSaveContactForFuture(bool save) {
    state = state.copyWith(saveContactForFuture: save);
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

  void setTriggerType(AlarmTriggerType type) {
    state = state.copyWith(alarm: state.alarm.copyWith(triggerType: type));
  }

  void setTriggerMinutes(int mins) {
    state = state.copyWith(alarm: state.alarm.copyWith(triggerMinutes: mins));
  }

  void setSound(String soundId) {
    state = state.copyWith(alarm: state.alarm.copyWith(soundId: soundId));
  }

  void reset() {
    state = TripDraft(alarm: AlarmSettings.defaults);
  }
}

final tripDraftProvider =
    NotifierProvider<TripDraftController, TripDraft>(TripDraftController.new);

