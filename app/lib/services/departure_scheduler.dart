import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/pending_trip.dart';
import 'alarm_service.dart';
import 'pending_trip_store.dart';

/// Schedules an "Arm WakeMate?" prompt at a trip's departure time. Tapping the
/// prompt arms tracking in one tap — we never silently start GPS. Trip-intake
/// piece #3 (works off shared tickets today; PNR feeds it later).
class DepartureScheduler {
  DepartureScheduler._();
  static final DepartureScheduler instance = DepartureScheduler._();

  final _store = PendingTripStore();
  bool _tzReady = false;

  Future<void> initTimezone() async {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Fall back to UTC if the platform can't report a zone.
    }
    _tzReady = true;
  }

  bool canSchedule(DateTime? departureAt) =>
      departureAt != null && departureAt.isAfter(DateTime.now());

  /// Schedule the prompt and persist the trip. Returns the pending id, or null
  /// if the departure is not in the future.
  Future<int?> schedule(PendingTrip Function(int id) build) async {
    await initTimezone();
    await AlarmService.instance.init();

    // Notification id derived from the minute of departure (stable, unique-ish).
    final probe = build(0);
    if (!canSchedule(probe.departureAt)) return null;
    final id = probe.departureAt.millisecondsSinceEpoch ~/ 60000 % 2147483647;
    final trip = build(id);

    await _store.add(trip);

    final when = tz.TZDateTime.from(trip.departureAt, tz.local);
    await AlarmService.instance.notifications.zonedSchedule(
      id: id,
      title: 'Time to arm WakeMate',
      body:
          'Your trip to ${trip.destination.placeName} is departing — tap to start tracking.',
      scheduledDate: when,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'wakemate_departure',
          'Departure reminders',
          channelDescription: 'Prompts you to arm WakeMate when your trip departs.',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
      ),
      payload: 'arm:$id',
      // Inexact avoids the SCHEDULE_EXACT_ALARM permission; a few minutes'
      // slack at departure is fine.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    return id;
  }

  /// Look up a scheduled trip (e.g. when its notification is tapped).
  Future<PendingTrip?> take(int id) => _store.take(id);

  Future<void> cancel(int id) async {
    await AlarmService.instance.notifications.cancel(id: id);
    await _store.remove(id);
  }
}
