import 'package:go_router/go_router.dart';

import '../features/alarm/alarm_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/legal/legal_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/permissions/permission_screen.dart';
import '../features/search/destination_search_screen.dart';
import '../features/set_alarm/set_alarm_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/share_intake/shared_trip_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/tracking/tracking_screen.dart';
import '../services/ticket_parser.dart';

/// Named routes for the whole app. Keeping the strings in one place avoids
/// typos across `context.go(...)` calls.
class Routes {
  Routes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const permissions = '/permissions';
  static const home = '/home';
  static const search = '/search';
  static const setAlarm = '/set-alarm';
  static const tracking = '/tracking';
  static const alarm = '/alarm';
  static const history = '/history';
  static const settings = '/settings';
  static const sharedTrip = '/shared-trip';
  static const privacyPolicy = '/privacy-policy';
  static const termsOfService = '/terms-of-service';
}

final appRouter = GoRouter(
  initialLocation: Routes.splash,
  routes: [
    GoRoute(
      path: Routes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: Routes.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: Routes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: Routes.permissions,
      builder: (context, state) => const PermissionScreen(),
    ),
    GoRoute(
      path: Routes.home,
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: Routes.search,
      builder: (context, state) => const DestinationSearchScreen(),
    ),
    GoRoute(
      path: Routes.setAlarm,
      builder: (context, state) => const SetAlarmScreen(),
    ),
    GoRoute(
      path: Routes.tracking,
      builder: (context, state) => const TrackingScreen(),
    ),
    GoRoute(
      path: Routes.alarm,
      builder: (context, state) => const AlarmScreen(),
    ),
    GoRoute(
      path: Routes.history,
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: Routes.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: Routes.sharedTrip,
      builder: (context, state) =>
          SharedTripScreen(ticket: state.extra as ParsedTicket),
    ),
    GoRoute(
      path: Routes.privacyPolicy,
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
    GoRoute(
      path: Routes.termsOfService,
      builder: (context, state) => const TermsOfServiceScreen(),
    ),
  ],
);
