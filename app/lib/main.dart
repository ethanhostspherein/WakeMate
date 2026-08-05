import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routing/app_router.dart';
import 'services/alarm_service.dart';
import 'services/departure_scheduler.dart';
import 'services/location_service.dart';
import 'services/share_intake_handler.dart';
import 'state/tracking_provider.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Prepare the alarm channel + notifications up front so a full-screen intent
  // can surface instantly when the trigger fires.
  await AlarmService.instance.init();
  await DepartureScheduler.instance.initTimezone();

  // Explicit container so notification-tap handlers (which run outside the
  // widget tree) can reach providers like the tracker.
  final container = ProviderContainer();

  // Tapping the full-screen alarm notification routes to the Alarm screen.
  AlarmService.onAlarmTap = () => appRouter.go(Routes.alarm);
  // Tapping a departure prompt arms that trip in one tap.
  AlarmService.onDepartureTap = (id) => _armPendingTrip(container, id);

  // Listen for tickets shared into the app while it's running.
  ShareIntakeHandler.instance.listen();

  runApp(UncontrolledProviderScope(
    container: container,
    child: const WakeMateApp(),
  ));
}

/// Arm a trip that was scheduled to start at its departure time.
Future<void> _armPendingTrip(ProviderContainer container, int id) async {
  final pending = await DepartureScheduler.instance.take(id);
  if (pending == null) return;
  final ready = await LocationService().ensureReady();
  if (!ready) {
    appRouter.go(Routes.home);
    return;
  }
  await container.read(trackingProvider.notifier).start(pending.toActiveTrip());
  appRouter.go(Routes.tracking);
}

class WakeMateApp extends StatelessWidget {
  const WakeMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'WakeMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
