import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/active_trip.dart';
import '../../models/destination.dart';
import '../../routing/app_router.dart';
import '../../state/tracking_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Alarm Screen — full-screen takeover with the amber→red urgency gradient
/// (used ONLY here, per UI/UX Brief §2.1), a strong pulsing ring, and two
/// large ≥64dp buttons. The native full-screen-intent + max-volume playback
/// is wired in Phase 2 (P2-05); this is the visual + interaction layer.
class AlarmScreen extends ConsumerStatefulWidget {
  const AlarmScreen({super.key});

  @override
  ConsumerState<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends ConsumerState<AlarmScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  // Dismiss requires a 2s hold, not a tap — guards against a half-asleep
  // reflex tap silencing the alarm before the rider actually wakes up.
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) _dismiss();
    });

  @override
  void dispose() {
    _pulse.dispose();
    _hold.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    final wasSimulated = ref.read(trackingProvider).simulated;
    // Ends the trip → Journey Complete → History (App Flow §2).
    final trip = ref.read(trackingProvider).trip;
    final destName = trip?.destination.placeName ?? 'your stop';
    await ref.read(trackingProvider.notifier).dismiss();

    if (wasSimulated) {
      // Just testing the alarm — trip is still live, go back to it.
      if (mounted) context.pop();
      return;
    }

    if (trip != null && trip.notifyFamily) {
      await _notifyFamily(trip);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Arrived at $destName. Trip saved.'),
        backgroundColor: AppColors.success,
      ),
    );
    if (trip != null) await _showQuickActions(trip.destination);
    if (!mounted) return;
    context.go(Routes.home);
  }

  /// Post-arrival quick actions — offered right after dismiss, while the
  /// user still has the app open.
  Future<void> _showQuickActions(Destination destination) {
    final destName = destination.placeName;
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("You've arrived", style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text('Need a ride from $destName?',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.local_taxi_rounded),
                    label: const Text('Uber'),
                    onPressed: () => _bookCab('Uber', destination),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.local_taxi_rounded),
                    label: const Text('Ola'),
                    onPressed: () => _bookCab('Ola', destination),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Not now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bookCab(String provider, Destination destination) async {
    // Uber sets pickup to my_location (Station B) and leaves dropoff empty
    // so user can type their final destination (Home/Hotel/etc.).
    final Uri primary = provider == 'Uber'
        ? Uri.parse('https://m.uber.com/ul/?action=setPickup&pickup=my_location')
        : Uri.parse('olacabs://app/launch?lat=${destination.lat}&lng=${destination.lng}');
    final fallbackPackage = provider == 'Uber' ? 'com.ubercab' : 'com.olacabs.customer';

    var launched = await launchUrl(primary, mode: LaunchMode.externalApplication);
    if (!launched && provider == 'Ola') {
      launched = await launchUrl(
        Uri.parse('https://book.olacabs.com/?lat=${destination.lat}&lng=${destination.lng}'),
        mode: LaunchMode.externalApplication,
      );
    }
    if (!launched) {
      launched = await launchUrl(
          Uri.parse('https://play.google.com/store/apps/details?id=$fallbackPackage'),
          mode: LaunchMode.externalApplication);
    }
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $provider.')),
      );
    }
  }

  Future<void> _snooze() async {
    final wasSimulated = ref.read(trackingProvider).simulated;
    // Re-arm at a shorter distance (App Flow §2, TRD §5).
    await ref.read(trackingProvider.notifier).snooze();
    if (!mounted) return;
    if (!wasSimulated) {
      final km = ref.read(trackingProvider).trip?.alarmDistanceKm ?? 1;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Snoozed — re-alerting at ${km.toStringAsFixed(km < 1 ? 1 : 0)} km.')),
      );
    }
    context.pop();
  }

  Future<void> _notifyFamily(ActiveTrip trip) async {
    final phone = trip.familyContactPhone?.trim();
    if (phone == null || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No family contact saved for this trip.')),
      );
      return;
    }

    final destName = trip.destination.placeName;
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final message =
        'WakeMate alert: I may have missed my stop near $destName. Please check on me.';

    // wa.me / sms: deep links only pre-fill the message — the platform
    // requires a final manual tap inside WhatsApp/Messages to actually send.
    final uri = trip.familyChannel == 'sms'
        ? (Platform.isIOS
            ? Uri.parse('sms:$digits&body=${Uri.encodeComponent(message)}')
            : Uri(scheme: 'sms', path: digits, queryParameters: {'body': message}))
        : Uri.parse(
            'https://wa.me/${digits.replaceAll('+', '')}?text=${Uri.encodeComponent(message)}');

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open messaging app.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(trackingProvider);
    final destName = trackingState.trip?.destination.placeName ?? 'your stop';
    final missedStop = trackingState.missedStop;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          decoration:
              const BoxDecoration(gradient: AppColors.alarmGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  const Spacer(),
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.92, end: 1.08)
                        .animate(CurvedAnimation(
                            parent: _pulse, curve: Curves.easeInOut)),
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.18),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 3),
                      ),
                      child: const Icon(Icons.notifications_active_rounded,
                          size: 84, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text('Wake up',
                      style: AppTypography.alarmHeadline(),
                      textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Station near — $destName',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (missedStop) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning_rounded, color: Colors.white),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You may have passed your stop',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: () {
                                final trip = ref.read(trackingProvider).trip;
                                if (trip != null) _notifyFamily(trip);
                              },
                              icon: const Icon(Icons.message_rounded, color: Colors.white),
                              label: const Text('Notify family',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  const Spacer(),
                  _HoldButton(
                    label: 'Hold to dismiss',
                    icon: Icons.check_rounded,
                    progress: _hold,
                    onHoldStart: () => _hold.forward(),
                    onHoldEnd: () => _hold.reverse(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _AlarmButton(
                    label: 'Snooze — alert at 1 km',
                    icon: Icons.snooze_rounded,
                    filled: false,
                    onTap: _snooze,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HoldButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Animation<double> progress;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  const _HoldButton({
    required this.label,
    required this.icon,
    required this.progress,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onHoldStart(),
      onTapUp: (_) => onHoldEnd(),
      onTapCancel: onHoldEnd,
      child: SizedBox(
        width: double.infinity,
        height: AppSpacing.alarmTouchTarget + 8,
        child: AnimatedBuilder(
          animation: progress,
          builder: (context, _) {
            final filled = progress.value > 0.5;
            return ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress.value,
                    child: Container(color: Colors.white),
                  ),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon,
                            size: 26,
                            color: filled ? AppColors.alarmEnd : Colors.white),
                        const SizedBox(width: 10),
                        Text(
                          progress.value > 0.02 ? 'Keep holding…' : label,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: filled ? AppColors.alarmEnd : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AlarmButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  const _AlarmButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // ≥64dp touch height (UI/UX Brief §3.8, §5).
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.alarmTouchTarget + 8,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon,
            size: 26, color: filled ? AppColors.alarmEnd : Colors.white),
        label: Text(label,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: filled ? AppColors.alarmEnd : Colors.white,
            )),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              filled ? Colors.white : Colors.white.withValues(alpha: 0.12),
          elevation: 0,
          side: filled
              ? null
              : const BorderSide(color: Colors.white, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
        ),
      ),
    );
  }
}
