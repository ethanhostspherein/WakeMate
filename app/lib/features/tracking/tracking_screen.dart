import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/active_trip.dart';
import '../../models/alarm_settings.dart';
import '../../routing/app_router.dart';
import '../../services/alarm_service.dart';
import '../../services/battery_optimization.dart';
import '../../services/trip_share_service.dart';
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
          Positioned.fill(
            child: MapPreview(
              height: double.infinity,
              lat: trip?.destination.lat ?? 26.9124,
              lng: trip?.destination.lng ?? 75.7873,
              startLat: state.currentLat ?? trip?.startLat,
              startLng: state.currentLng ?? trip?.startLng,
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
                        onTap: () => context.go(Routes.home),
                      ),
                      const Spacer(),
                      _CircleButton(
                        icon: Icons.share_rounded,
                        onTap: () => _showShareSheet(context, ref),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      const _TrackingChip(),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: _ReliabilityChip(),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: _HeadphoneGuardChip(),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: _GuardianStatusLine(),
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

  /// Live ETA share link — generate (or reuse) a token and show the link
  /// with a copy button. Family opens it in a plain browser, no app needed.
  Future<void> _showShareSheet(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(trackingProvider.notifier);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: FutureBuilder<String?>(
          future: notifier.startShare(),
          builder: (context, snapshot) {
            if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final token = snapshot.data;
            if (token == null) {
              return const SizedBox(
                height: 100,
                child: Center(
                  child: Text('Sign in to share your live location.'),
                ),
              );
            }
            final link = TripShareService.linkFor(token);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Share live location',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                const Text('Anyone with this link can watch your ETA, no app needed.'),
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Text(link, style: Theme.of(context).textTheme.bodySmall),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy link'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: link));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copied')),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
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

/// Reliability Engine indicator. Hidden when green (good GPS fix +
/// battery-exempt) to keep the UI quiet; surfaces as a tap-to-fix pill for
/// battery optimization (the top kill risk), or an informational pill while
/// GPS is still settling / degraded.
class _ReliabilityChip extends ConsumerWidget {
  const _ReliabilityChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trackingProvider);
    final level = state.reliabilityLevel;
    if (level == ReliabilityLevel.green) return const SizedBox.shrink();

    final noNotifPermission = state.notificationGranted == false;
    final canFixBattery = state.batteryExempt == false;
    final selfTestFailed = state.selfTestPassed == false;
    final color = level == ReliabilityLevel.red ? AppColors.danger : AppColors.warning;
    final icon = noNotifPermission
        ? Icons.notifications_off_rounded
        : canFixBattery
            ? Icons.battery_alert_rounded
            : selfTestFailed
                ? Icons.warning_rounded
                : Icons.gps_not_fixed_rounded;
    final label = noNotifPermission
        ? 'Enable notifications'
        : canFixBattery
            ? 'Fix battery setting'
            : selfTestFailed
                ? 'Alarm test failed — check volume/vibration'
                : (level == ReliabilityLevel.yellow ? 'Confirming GPS…' : 'Weak GPS signal');

    return GestureDetector(
      onTap: canFixBattery ? () => _fixBattery(ref) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _fixBattery(WidgetRef ref) async {
    await BatteryOptimization.requestExemption();
    // Also surface the OEM's own autostart/background-kill manager (Samsung,
    // Xiaomi, Oppo, Vivo, Huawei) — a second layer standard Android battery
    // optimization doesn't cover, with no runtime permission of its own.
    await BatteryOptimization.openOemSettings();
    await ref.read(trackingProvider.notifier).refreshBatteryStatus();
  }
}

/// Journey Guardian — single plain-language line summarizing everything the
/// rider needs to know right now, derived from Reliability Engine + missed-
/// stop state (steps 1–2). No new state of its own.
class _GuardianStatusLine extends ConsumerWidget {
  const _GuardianStatusLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trackingProvider);
    final trip = state.trip;

    String text;
    if (state.missedStop) {
      text = "May have missed your stop — check the alarm screen";
    } else if (state.batteryExempt == false) {
      text = 'Backup protection active — battery setting may limit alerts';
    } else if (state.reliabilityLevel == ReliabilityLevel.red) {
      text = 'Weak signal — using your last known position';
    } else if (state.reliabilityLevel == ReliabilityLevel.yellow) {
      text = 'Confirming your position…';
    } else if (trip != null &&
        state.remainingKm != null &&
        state.remainingKm! <= trip.alarmDistanceKm * 2) {
      text = 'Approaching — watching closely';
    } else {
      text = 'Tracking normally, all clear';
    }

    return Text(
      text,
      textAlign: TextAlign.right,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
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
        remainingKm != null ? AlarmSettings.formatDistance(remainingKm!) : '—';
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
                Text('Alarm at ${AlarmSettings.formatDistance(alarmKm)}',
                    style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(remaining,
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

/// Headphone Disconnect Safety Guard status pill shown on tracking screen.
class _HeadphoneGuardChip extends StatefulWidget {
  const _HeadphoneGuardChip();

  @override
  State<_HeadphoneGuardChip> createState() => _HeadphoneGuardChipState();
}

class _HeadphoneGuardChipState extends State<_HeadphoneGuardChip> {
  bool _headphonesConnected = false;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _sub = AlarmService.instance.onHeadphonesDisconnected.listen((connected) {
      if (mounted) setState(() => _headphonesConnected = connected);
    });
  }

  Future<void> _checkStatus() async {
    final connected = await AlarmService.instance.isHeadphonesConnected();
    if (mounted) setState(() => _headphonesConnected = connected);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _headphonesConnected
                ? Icons.headset_rounded
                : Icons.volume_up_rounded,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            _headphonesConnected
                ? 'Earphones connected · Speaker fallback active'
                : 'Hardware Speaker Guard active',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

