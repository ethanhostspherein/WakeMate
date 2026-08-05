import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/active_trip.dart';
import '../../models/alarm_settings.dart';
import '../../models/pending_trip.dart';
import '../../routing/app_router.dart';
import '../../services/departure_scheduler.dart';
import '../../services/location_service.dart';
import '../../state/tracking_provider.dart';
import '../../state/trip_draft_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/map_preview.dart';
import '../../widgets/primary_button.dart';

/// Set Alarm — distance presets + custom slider, sound picker, volume with a
/// max-volume override toggle. UI/UX Brief §3.6, App Flow §2.
class SetAlarmScreen extends ConsumerStatefulWidget {
  const SetAlarmScreen({super.key});

  @override
  ConsumerState<SetAlarmScreen> createState() => _SetAlarmScreenState();
}

class _SetAlarmScreenState extends ConsumerState<SetAlarmScreen> {
  bool _customMode = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    final km = ref.read(tripDraftProvider).alarm.distanceKm;
    _customMode = !AlarmSettings.presets.contains(km);
  }

  Future<void> _startJourney() async {
    final draft = ref.read(tripDraftProvider);
    final destination = draft.destination;
    if (destination == null) return;

    setState(() => _starting = true);

    // Background tracking needs location permission + services on.
    final location = LocationService();
    final ready = await location.ensureReady();
    if (!ready) {
      if (!mounted) return;
      setState(() => _starting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Location permission is required to track your trip. Enable it in Settings.'),
      ));
      return;
    }

    final startPos = await location.currentPosition();
    final trip = ActiveTrip(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      destination: destination,
      alarmDistanceKm: draft.alarm.distanceKm,
      soundId: draft.alarm.soundId,
      volume: draft.alarm.volume,
      maxVolumeOverride: draft.alarm.maxVolumeOverride,
      vibrate: draft.alarm.vibrate,
      startLat: startPos?.latitude,
      startLng: startPos?.longitude,
      startedAt: DateTime.now(),
    );

    await ref.read(trackingProvider.notifier).start(trip);
    if (!mounted) return;
    setState(() => _starting = false);
    context.push(Routes.tracking);
  }

  Future<void> _armAtDeparture() async {
    final draft = ref.read(tripDraftProvider);
    final destination = draft.destination;
    final departureAt = draft.departureAt;
    if (destination == null || departureAt == null) return;

    final id = await DepartureScheduler.instance.schedule((id) => PendingTrip(
          id: id,
          destination: destination,
          alarmDistanceKm: draft.alarm.distanceKm,
          soundId: draft.alarm.soundId,
          volume: draft.alarm.volume,
          maxVolumeOverride: draft.alarm.maxVolumeOverride,
          vibrate: draft.alarm.vibrate,
          departureAt: departureAt,
        ));
    if (!mounted) return;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('That departure time has already passed.'),
      ));
      return;
    }
    ref.read(tripDraftProvider.notifier).reset();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.success,
      content: Text(
          "We'll remind you to arm WakeMate at ${_formatTime(departureAt)}."),
    ));
    context.go(Routes.home);
  }

  static String _formatTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ap = d.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(tripDraftProvider);
    final alarm = draft.alarm;
    final notifier = ref.read(tripDraftProvider.notifier);
    final destName = draft.destination?.placeName ?? 'your destination';
    final canArmLater = draft.departureAt != null &&
        draft.departureAt!.isAfter(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Set alarm')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding),
                children: [
                  MapPreview(
                    height: 130,
                    showRoute: true,
                    destinationLabel: draft.destination?.placeName,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Wake me within',
                      style: Theme.of(context).textTheme.titleLarge),
                  Text('of $destName',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.md),
                  _DistanceChips(
                    selected: alarm.distanceKm,
                    customMode: _customMode,
                    onPreset: (km) {
                      setState(() => _customMode = false);
                      notifier.setDistance(km);
                    },
                    onCustom: () {
                      setState(() => _customMode = true);
                      if (AlarmSettings.presets.contains(alarm.distanceKm)) {
                        notifier.setDistance(2);
                      }
                    },
                  ),
                  if (_customMode) _CustomSlider(
                    value: alarm.distanceKm,
                    onChanged: notifier.setDistance,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Alarm sound',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  _SoundPicker(
                    selectedId: alarm.soundId,
                    onSelect: notifier.setSound,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Volume',
                      style: Theme.of(context).textTheme.titleLarge),
                  _VolumeControl(
                    alarm: alarm,
                    onVolume: (v) =>
                        notifier.setAlarm(alarm.copyWith(volume: v)),
                    onOverride: (v) => notifier
                        .setAlarm(alarm.copyWith(maxVolumeOverride: v)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(
                    label: 'Start journey',
                    icon: Icons.navigation_rounded,
                    loading: _starting,
                    onPressed:
                        draft.destination == null ? null : _startJourney,
                  ),
                  if (canArmLater) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SecondaryButton(
                      label: 'Arm at departure • ${_formatTime(draft.departureAt!)}',
                      icon: Icons.alarm_add_rounded,
                      onPressed: _armAtDeparture,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistanceChips extends StatelessWidget {
  final double selected;
  final bool customMode;
  final ValueChanged<double> onPreset;
  final VoidCallback onCustom;

  const _DistanceChips({
    required this.selected,
    required this.customMode,
    required this.onPreset,
    required this.onCustom,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        ...AlarmSettings.presets.map((km) {
          final active = !customMode && selected == km;
          return _Chip(
            label: '${km.toStringAsFixed(0)} km',
            active: active,
            onTap: () => onPreset(km),
          );
        }),
        _Chip(
          label: 'Custom',
          active: customMode,
          onTap: onCustom,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: active ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(
              color: active ? AppColors.accent : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _CustomSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const _CustomSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final clamped =
        value.clamp(AlarmSettings.minCustomKm, AlarmSettings.maxCustomKm);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${AlarmSettings.minCustomKm} km',
                  style: Theme.of(context).textTheme.labelMedium),
              Text('${clamped.toStringAsFixed(1)} km',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppColors.accent)),
              Text('${AlarmSettings.maxCustomKm.toStringAsFixed(0)} km',
                  style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
          Slider(
            value: clamped.toDouble(),
            min: AlarmSettings.minCustomKm,
            max: AlarmSettings.maxCustomKm,
            divisions: 99,
            activeColor: AppColors.accent,
            label: '${clamped.toStringAsFixed(1)} km',
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SoundPicker extends StatelessWidget {
  final String selectedId;
  final ValueChanged<String> onSelect;
  const _SoundPicker({required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: AlarmSound.all.map((s) {
        final selected = s.id == selectedId;
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentSoft : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
                color: selected ? AppColors.accent : AppColors.border),
          ),
          child: ListTile(
            leading: Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.accent : AppColors.textSecondary,
            ),
            title: Text(s.label),
            trailing: IconButton(
              icon: const Icon(Icons.play_circle_outline_rounded,
                  color: AppColors.accent),
              tooltip: 'Preview',
              onPressed: () {
                // Sound preview playback is wired with the alarm engine in
                // Phase 2 (bundled sounds, offline). Feedback for now:
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Preview: ${s.label}'),
                    duration: const Duration(milliseconds: 900),
                  ),
                );
              },
            ),
            onTap: () => onSelect(s.id),
          ),
        );
      }).toList(),
    );
  }
}

class _VolumeControl extends StatelessWidget {
  final AlarmSettings alarm;
  final ValueChanged<double> onVolume;
  final ValueChanged<bool> onOverride;

  const _VolumeControl({
    required this.alarm,
    required this.onVolume,
    required this.onOverride,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.volume_down_rounded,
                color: AppColors.textSecondary),
            Expanded(
              child: Slider(
                value: alarm.volume,
                activeColor: AppColors.accent,
                onChanged: alarm.maxVolumeOverride ? null : onVolume,
              ),
            ),
            const Icon(Icons.volume_up_rounded,
                color: AppColors.textSecondary),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AppColors.accent,
          value: alarm.maxVolumeOverride,
          onChanged: onOverride,
          title: const Text('Max-volume override'),
          subtitle: const Text(
              'Ring at full volume even on silent, vibrate or Do Not Disturb.'),
        ),
      ],
    );
  }
}
