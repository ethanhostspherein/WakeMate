import 'package:home_widget/home_widget.dart';

/// Home-screen widget — shows the active or most recent trip and opens the
/// app on tap. Best-effort like the other services here: widget errors
/// never crash the app, just leave the widget stale.
/// ponytail: tap only opens the app (Home), doesn't auto-restart the trip —
/// that needs re-deriving a full TripDraft (destination/mode/alarm), a
/// bigger feature than the widget itself. Add if users want a true
/// one-tap-repeat.
class HomeWidgetService {
  HomeWidgetService._();
  static final HomeWidgetService instance = HomeWidgetService._();

  static const _providerName = 'HomeScreenWidgetProvider';

  Future<void> showActiveTrip(String destName, double alarmKm) => _push(
        status: 'Tracking',
        destName: destName,
        detail:
            'Alarm at ${alarmKm.toStringAsFixed(alarmKm < 1 ? 1 : 0)} km',
      );

  Future<void> showLastTrip(String destName) => _push(
        status: 'Last trip',
        destName: destName,
        detail: 'Tap to open WakeMate',
      );

  Future<void> clear() => _push(
        status: 'WakeMate',
        destName: 'No trip yet',
        detail: 'Start a trip in the app',
      );

  Future<void> _push({
    required String status,
    required String destName,
    required String detail,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('status', status);
      await HomeWidget.saveWidgetData<String>('destName', destName);
      await HomeWidget.saveWidgetData<String>('detail', detail);
      await HomeWidget.updateWidget(
        name: _providerName,
        androidName: _providerName,
      );
    } catch (_) {}
  }
}
