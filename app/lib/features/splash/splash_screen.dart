import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/active_trip.dart';
import '../../routing/app_router.dart';
import '../../services/share_intake_handler.dart';
import '../../state/tracking_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/wakemate_logo.dart';

/// Splash — logo with a subtle scale-in, ~1.5s, then routes to Onboarding
/// (first launch), a resumed trip, or Home. UI/UX Brief §3.1.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Hold the splash ~1.5s total (UI/UX Brief §3.1).
    final prefs = await SharedPreferences.getInstance();
    // Resume any trip the OS interrupted mid-journey (P2-08).
    await ref.read(trackingProvider.notifier).restoreIfAny();
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final tracking = ref.read(trackingProvider);
    if (tracking.phase == TrackingPhase.alarm) {
      context.go(Routes.alarm);
      return;
    }
    if (tracking.isActive) {
      context.go(Routes.tracking);
      return;
    }

    // If the app was launched by sharing a ticket, jump to the Confirm screen
    // (with Home beneath so back returns somewhere sensible).
    final sharedTicket = await ShareIntakeHandler.instance.takeInitial();
    if (!mounted) return;
    final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;
    if (sharedTicket != null && seenOnboarding) {
      context.go(Routes.home);
      appRouter.push(Routes.sharedTrip, extra: sharedTicket);
      return;
    }

    context.go(seenOnboarding ? Routes.home : Routes.onboarding);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                WakeMateLogo(size: 96, onDark: true),
                SizedBox(height: 20),
                Text(
                  'WakeMate',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Never miss your stop',
                  style: TextStyle(
                    color: Color(0xFFB9C2D6),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
