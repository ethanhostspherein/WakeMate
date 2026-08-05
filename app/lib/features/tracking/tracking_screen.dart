import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/active_trip.dart';
import '../../routing/app_router.dart';
import '../../services/battery_optimization.dart';
import '../../state/tracking_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/map_preview.dart';
import '../../widgets/primary_button.dart';

/// Tracking Screen — live map + bottom sheet with remaining distance, ETA and
/// speed, a 'Tracking active' chip, and a Stop button. Fed by [trackingProvider]
/// (real background location). UI/UX Brief §3.7, Implementation Plan P2-04.
class TrackingScreen extends ConsumerWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // When the alarm fires, take over with the full-screen Alarm screen.
    ref.listen(trackingProvider, (prev, next) {
      if (next.phase == TrackingPhase.alarm &&
          prev?.phase != TrackingPhase.alarm) {
        context.push(Routes.alarm);
      }
    });

    final state = ref.watch(trackingProvider);
    final trip = state.trip;
    final destName = trip?.destination.placeName ?? 'Destination';

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: MapPreview(
              height: double.infinity,
              showRoute: true,
              borderRadius: BorderRadius.zero,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      _CircleButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => context.pop(),
                      ),
                      const Spacer(),
                      const _TrackingChip(),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: _BatteryWarningChip(),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _StatsSheet(
              destName: destName,
              alarmKm: trip?.alarmDistanceKm ?? 0,
              remainingKm: state.remainingKm,
              etaMin: state.etaMinutes,
              speedKmh: state.speedKmh,
              onStop: () => _confirmStop(context, ref),
              onSimulateAlarm: () =>
                  ref.read(trackingProvider.notifier).debugTriggerAlarm(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmStop(BuildContext context, WidgetRef ref) async {
    final stop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop tracking?'),
        content: const Text(
            'Your trip will end and the alarm will be cancelled.'),
        actions: [
          TextButton(
              onPressed: () => context.pop(false),
              child: const Text('Keep tracking')),
          TextButton(
            onPressed: () => context.pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (stop == true && context.mounted) {
      await ref.read(trackingProvider.notifier).stop();
      if (context.mounted) context.go(Routes.home);
    }
  }
}

class _TrackingChip extends StatelessWidget {
  const _TrackingChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.success,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _PulsingDot(),
          SizedBox(width: 6),
          Text('Tracking active',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

/// Shown only when the app is NOT exempt from battery optimization — the
/// single biggest cause of tracking being killed mid-trip. UI/UX Brief §3.7.
class _BatteryWarningChip extends StatefulWidget {
  const _BatteryWarningChip();

  @override
  State<_BatteryWarningChip> createState() => _BatteryWarningChipState();
}

class _BatteryWarningChipState extends State<_BatteryWarningChip> {
  bool _exempt = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final exempt = await BatteryOptimization.isExempt();
    if (mounted) setState(() => _exempt = exempt);
  }

  Future<void> _fix() async {
    await BatteryOptimization.requestExemption();
    _check();
  }

  @override
  Widget build(BuildContext context) {
    if (_exempt) return const SizedBox.shrink();
    return GestureDetector(
      onTap: _fix,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.warning,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.battery_alert_rounded, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text('Fix battery setting',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1).animate(_c),
      child: Container(
        width: 8,
        height: 8,
        decoration:
            const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      ),
    );
  }
}

class _StatsSheet extends StatelessWidget {
  final String destName;
  final double alarmKm;
  final double? remainingKm;
  final int? etaMin;
  final double? speedKmh;
  final VoidCallback onStop;
  final VoidCallback onSimulateAlarm;

  const _StatsSheet({
    required this.destName,
    required this.alarmKm,
    required this.remainingKm,
    required this.etaMin,
    required this.speedKmh,
    required this.onStop,
    required this.onSimulateAlarm,
  });

  @override
  Widget build(BuildContext context) {
    final remaining =
        remainingKm != null ? remainingKm!.toStringAsFixed(remainingKm! < 10 ? 1 : 0) : '—';
    final eta = etaMin != null ? '$etaMin min' : '—';
    final speed = speedKmh != null ? '${speedKmh!.round()} km/h' : '—';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md,
          AppSpacing.lg, AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(Icons.place_rounded, color: AppColors.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(destName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                Text('Alarm at ${alarmKm.toStringAsFixed(alarmKm < 1 ? 1 : 0)} km',
                    style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$remaining km',
                    style: AppTypography.statNumeral(fontSize: 52)),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('remaining',
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _MiniStat(
                    icon: Icons.schedule_rounded, value: eta, label: 'ETA'),
                const SizedBox(width: AppSpacing.lg),
                _MiniStat(
                    icon: Icons.speed_rounded, value: speed, label: 'Speed'),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // Test affordance — force the alarm without waiting to arrive.
            // Useful on the emulator; remove before store release.
            PrimaryButton(
              label: 'Simulate arrival (test alarm)',
              icon: Icons.notifications_active_rounded,
              onPressed: onSimulateAlarm,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: 'Stop trip',
              icon: Icons.stop_circle_outlined,
              onPressed: onStop,
              color: AppColors.danger,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _MiniStat(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: AppColors.primary),
        ),
      ),
    );
  }
}
