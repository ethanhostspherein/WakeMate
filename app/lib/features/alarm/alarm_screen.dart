import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    // Ends the trip → Journey Complete → History (App Flow §2).
    final destName =
        ref.read(trackingProvider).trip?.destination.placeName ?? 'your stop';
    await ref.read(trackingProvider.notifier).dismiss();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Arrived at $destName. Trip saved.'),
        backgroundColor: AppColors.success,
      ),
    );
    context.go(Routes.home);
  }

  Future<void> _snooze() async {
    // Re-arm at a shorter distance (App Flow §2, TRD §5).
    await ref.read(trackingProvider.notifier).snooze();
    if (!mounted) return;
    final km = ref.read(trackingProvider).trip?.alarmDistanceKm ?? 1;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Snoozed — re-alerting at ${km.toStringAsFixed(km < 1 ? 1 : 0)} km.')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final destName =
        ref.watch(trackingProvider).trip?.destination.placeName ?? 'your stop';

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
                  const Spacer(),
                  _AlarmButton(
                    label: 'Dismiss',
                    icon: Icons.check_rounded,
                    filled: true,
                    onTap: _dismiss,
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
