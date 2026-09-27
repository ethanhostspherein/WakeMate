import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/active_trip.dart';
import '../../models/alarm_settings.dart';
import '../../models/family_contact.dart';
import '../../models/pending_trip.dart';
import '../../models/trip.dart';
import '../../routing/app_router.dart';
import '../../services/departure_scheduler.dart';
import '../../services/family_contacts_service.dart';
import '../../services/location_service.dart';
import '../../services/user_trips_service.dart';
import '../../services/weather_service.dart';
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
  late final TextEditingController _destNameController;
  late final TextEditingController _pnrController;
  late final TextEditingController _familyNameController;
  late final TextEditingController _familyPhoneController;
  List<FamilyContact> _savedContacts = [];

  AudioPlayer? _audioPlayer;
  String? _playingSoundId;
  bool _isPlayingPreview = false;
  WeatherInfo? _weather;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    final draft = ref.read(tripDraftProvider);
    final km = draft.alarm.distanceKm;
    _customMode = !AlarmSettings.presets.contains(km);
    _destNameController = TextEditingController(text: draft.destination?.placeName ?? '');
    _pnrController = TextEditingController(text: draft.pnrNumber ?? '');
    _familyNameController = TextEditingController(text: draft.familyContactName ?? '');
    _familyPhoneController = TextEditingController(text: draft.familyContactPhone ?? '');
    _loadFamilyContacts();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    final dest = ref.read(tripDraftProvider).destination;
    if (dest == null) return;
    final w = await WeatherService().current(dest.lat, dest.lng);
    if (mounted) setState(() => _weather = w);
  }

  Future<void> _loadFamilyContacts() async {
    final contacts = await FamilyContactsService.instance.getContacts();
    if (mounted) {
      setState(() {
        _savedContacts = contacts;
      });
    }
  }

  @override
  void dispose() {
    _destNameController.dispose();
    _pnrController.dispose();
    _familyNameController.dispose();
    _familyPhoneController.dispose();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _togglePreview(String soundId) async {
    if (_playingSoundId == soundId && _isPlayingPreview) {
      await _audioPlayer?.stop();
      if (mounted) {
        setState(() {
          _isPlayingPreview = false;
        });
      }
      return;
    }

    try {
      await _audioPlayer?.stop();
      final volume = ref.read(tripDraftProvider).alarm.volume;
      await _audioPlayer?.setVolume(volume);
      await _audioPlayer?.play(AssetSource('sounds/$soundId.wav'));
      if (mounted) {
        setState(() {
          _playingSoundId = soundId;
          _isPlayingPreview = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isPlayingPreview = false;
        });
      }
    }
  }

  void _onVolumeChanged(double v) {
    final alarm = ref.read(tripDraftProvider).alarm;
    ref.read(tripDraftProvider.notifier).setAlarm(alarm.copyWith(volume: v));
    if (_isPlayingPreview) {
      _audioPlayer?.setVolume(v);
    }
  }

  Future<void> _startJourney() async {
    await _audioPlayer?.stop();
    final draft = ref.read(tripDraftProvider);
    final customDestName = _destNameController.text.trim();
    final destination = (customDestName.isNotEmpty && draft.destination != null)
        ? draft.destination!.copyWith(placeName: customDestName)
        : draft.destination;
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

    // Determine target distance in KM
    double targetKm = draft.alarm.distanceKm;
    if (draft.alarm.triggerType == AlarmTriggerType.time) {
      // Approximate 40 km/h average travel speed for time-based distance equivalent
      targetKm = (draft.alarm.triggerMinutes / 60.0) * 40.0;
      if (targetKm < 0.5) targetKm = 0.5;
    }

    // Save family contact for future use if enabled
    if (draft.notifyFamily && draft.saveContactForFuture && _familyPhoneController.text.trim().isNotEmpty) {
      final contactName = _familyNameController.text.trim().isNotEmpty ? _familyNameController.text.trim() : 'Family Member';
      await FamilyContactsService.instance.addContact(FamilyContact(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: contactName,
        phone: _familyPhoneController.text.trim(),
        channel: draft.familyChannel,
      ));
    }

    final startPos = await location.currentPosition();
    final trip = ActiveTrip(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      mode: draft.mode,
      pnr: draft.pnrNumber,
      destination: destination,
      alarmDistanceKm: targetKm,
      triggerType: draft.alarm.triggerType,
      triggerMinutes: draft.alarm.triggerMinutes,
      soundId: draft.alarm.soundId,
      volume: draft.alarm.volume,
      maxVolumeOverride: draft.alarm.maxVolumeOverride,
      vibrate: draft.alarm.vibrate,
      notifyFamily: draft.notifyFamily,
      familyContactName: _familyNameController.text.trim().isNotEmpty ? _familyNameController.text.trim() : draft.familyContactName,
      familyContactPhone: _familyPhoneController.text.trim().isNotEmpty ? _familyPhoneController.text.trim() : draft.familyContactPhone,
      familyChannel: draft.familyChannel,
      startLat: startPos?.latitude,
      startLng: startPos?.longitude,
      startedAt: DateTime.now(),
    );

    // Persist trip to User Recent Trips history
    await UserTripsService.instance.addTrip(Trip(
      id: trip.id,
      mode: draft.mode,
      pnr: draft.pnrNumber,
      destination: trip.destination,
      alarmDistanceKm: trip.alarmDistanceKm,
      triggerType: draft.alarm.triggerType,
      triggerMinutes: draft.alarm.triggerMinutes,
      soundId: trip.soundId,
      status: TripStatus.active,
      notifyFamily: trip.notifyFamily,
      familyContactName: trip.familyContactName,
      familyContactPhone: trip.familyContactPhone,
      familyChannel: trip.familyChannel,
      createdAt: trip.startedAt,
    ));

    await ref.read(trackingProvider.notifier).start(trip);
    if (!mounted) return;
    setState(() => _starting = false);
    context.push(Routes.tracking);
  }

  Future<void> _armAtDeparture() async {
    await _audioPlayer?.stop();
    final draft = ref.read(tripDraftProvider);
    final customDestName = _destNameController.text.trim();
    final destination = (customDestName.isNotEmpty && draft.destination != null)
        ? draft.destination!.copyWith(placeName: customDestName)
        : draft.destination;
    final departureAt = draft.departureAt;
    if (destination == null || departureAt == null) return;

    final id = await DepartureScheduler.instance.schedule((id) => PendingTrip(
          id: id,
          destination: destination,
          alarmDistanceKm: draft.alarm.distanceKm,
          mode: draft.mode,
          pnr: draft.pnrNumber,
          triggerType: draft.alarm.triggerType,
          triggerMinutes: draft.alarm.triggerMinutes,
          soundId: draft.alarm.soundId,
          volume: draft.alarm.volume,
          maxVolumeOverride: draft.alarm.maxVolumeOverride,
          vibrate: draft.alarm.vibrate,
          notifyFamily: draft.notifyFamily,
          familyContactName: _familyNameController.text.trim().isNotEmpty
              ? _familyNameController.text.trim()
              : draft.familyContactName,
          familyContactPhone: _familyPhoneController.text.trim().isNotEmpty
              ? _familyPhoneController.text.trim()
              : draft.familyContactPhone,
          familyChannel: draft.familyChannel,
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
                    lat: draft.destination?.lat ?? 26.9124,
                    lng: draft.destination?.lng ?? 75.7873,
                    showRoute: true,
                    destinationLabel: draft.destination?.placeName,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _destNameController,
                    onChanged: (val) {
                      final dest = ref.read(tripDraftProvider).destination;
                      if (dest != null && val.trim().isNotEmpty) {
                        ref.read(tripDraftProvider.notifier).setDestination(dest.copyWith(placeName: val.trim()));
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Destination Name (Optional)',
                      hintText: 'e.g. Home, Grandma\'s House, Office',
                      prefixIcon: const Icon(Icons.edit_location_alt_rounded, color: AppColors.accent),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Travel Mode Selection Tabs (Bus vs Train)
                  Text('Select Mode',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  _ModeTabs(
                    selectedMode: draft.mode,
                    onSelectMode: (mode) {
                      notifier.setMode(mode);
                    },
                  ),
                  if (draft.mode == TripMode.train) ...[
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _pnrController,
                      keyboardType: TextInputType.number,
                      onChanged: (val) => notifier.setPnr(val),
                      decoration: InputDecoration(
                        labelText: 'Enter 10-Digit PNR Number',
                        hintText: 'e.g. 2415896321',
                        prefixIcon: const Icon(Icons.train_rounded, color: AppColors.accent),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                        filled: true,
                        fillColor: AppColors.surface,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Text('Wake me within',
                      style: Theme.of(context).textTheme.titleLarge),
                  Text('of $destName',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.sm),
                  // Trigger Type Switch (Distance vs Time)
                  _TriggerTypeToggle(
                    triggerType: alarm.triggerType,
                    onChanged: (type) {
                      notifier.setTriggerType(type);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (alarm.triggerType == AlarmTriggerType.distance) ...[
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
                    if (_customMode)
                      _CustomSlider(
                        value: alarm.distanceKm,
                        onChanged: notifier.setDistance,
                      ),
                  ] else ...[
                    _TimeChips(
                      selectedMinutes: alarm.triggerMinutes,
                      customMode: _customMode,
                      onPreset: (mins) {
                        setState(() => _customMode = false);
                        notifier.setTriggerMinutes(mins);
                      },
                      onCustom: () {
                        setState(() => _customMode = true);
                        if (AlarmSettings.timePresets.contains(alarm.triggerMinutes)) {
                          notifier.setTriggerMinutes(15);
                        }
                      },
                    ),
                    if (_customMode)
                      _CustomTimeSlider(
                        valueMinutes: alarm.triggerMinutes,
                        onChanged: notifier.setTriggerMinutes,
                      ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Text('Alarm sound',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  _SoundPicker(
                    selectedId: alarm.soundId,
                    playingId: _playingSoundId,
                    isPlaying: _isPlayingPreview,
                    onSelect: notifier.setSound,
                    onTogglePreview: _togglePreview,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Volume',
                      style: Theme.of(context).textTheme.titleLarge),
                  _VolumeControl(
                    alarm: alarm,
                    onVolume: _onVolumeChanged,
                    onOverride: (v) => notifier
                        .setAlarm(alarm.copyWith(maxVolumeOverride: v)),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Family Notification',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  _FamilyNotificationSection(
                    draft: draft,
                    notifier: notifier,
                    savedContacts: _savedContacts,
                    nameController: _familyNameController,
                    phoneController: _familyPhoneController,
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
                  if (draft.destination != null)
                    _SleepModeCard(
                      destName: destName,
                      wakeSummary: alarm.triggerType == AlarmTriggerType.distance
                          ? '${alarm.distanceKm.toStringAsFixed(alarm.distanceKm < 1 ? 1 : 0)} km before arrival'
                          : '${alarm.triggerMinutes} min before arrival',
                      weather: _weather,
                    ),
                  PrimaryButton(
                    label: 'Start Sleep',
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

/// Sleep Mode preflight card — destination + wake trigger at a glance plus a
/// static "protection ready" badge, right above the Start Sleep button.
class _SleepModeCard extends StatelessWidget {
  final String destName;
  final String wakeSummary;
  final WeatherInfo? weather;

  const _SleepModeCard(
      {required this.destName, required this.wakeSummary, this.weather});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.accentSoft.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bedtime_rounded, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text('Sleep Mode',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: const Text('PROTECTION READY',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Destination: $destName',
              style: Theme.of(context).textTheme.bodyMedium),
          Text('Wake me: $wakeSummary',
              style: Theme.of(context).textTheme.bodyMedium),
          if (weather != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(_weatherIcon(weather!.condition),
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                    '${weather!.condition}, ${weather!.tempC.round()}°C at arrival',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static IconData _weatherIcon(String condition) {
    switch (condition) {
      case 'Clear':
        return Icons.wb_sunny_rounded;
      case 'Rainy':
      case 'Showers':
        return Icons.umbrella_rounded;
      case 'Snowy':
        return Icons.ac_unit_rounded;
      case 'Thunderstorms':
        return Icons.thunderstorm_rounded;
      case 'Foggy':
        return Icons.foggy;
      default:
        return Icons.cloud_rounded;
    }
  }
}

class _ModeTabs extends StatelessWidget {
  final TripMode selectedMode;
  final ValueChanged<TripMode> onSelectMode;

  const _ModeTabs({
    required this.selectedMode,
    required this.onSelectMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onSelectMode(TripMode.bus),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selectedMode == TripMode.bus ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.directions_bus_rounded,
                      size: 20,
                      color: selectedMode == TripMode.bus ? Colors.white : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Bus',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: selectedMode == TripMode.bus ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onSelectMode(TripMode.train),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selectedMode == TripMode.train ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.train_rounded,
                      size: 20,
                      color: selectedMode == TripMode.train ? Colors.white : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Train',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: selectedMode == TripMode.train ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TriggerTypeToggle extends StatelessWidget {
  final AlarmTriggerType triggerType;
  final ValueChanged<AlarmTriggerType> onChanged;

  const _TriggerTypeToggle({
    required this.triggerType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.accentSoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(AlarmTriggerType.distance),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: triggerType == AlarmTriggerType.distance ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  boxShadow: triggerType == AlarmTriggerType.distance
                      ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                      : [],
                ),
                child: Center(
                  child: Text(
                    'Distance (km)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: triggerType == AlarmTriggerType.distance ? AppColors.accent : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(AlarmTriggerType.time),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: triggerType == AlarmTriggerType.time ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  boxShadow: triggerType == AlarmTriggerType.time
                      ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                      : [],
                ),
                child: Center(
                  child: Text(
                    'Time (minutes)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: triggerType == AlarmTriggerType.time ? AppColors.accent : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeChips extends StatelessWidget {
  final int selectedMinutes;
  final bool customMode;
  final ValueChanged<int> onPreset;
  final VoidCallback onCustom;

  const _TimeChips({
    required this.selectedMinutes,
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
        ...AlarmSettings.timePresets.map((mins) {
          final active = !customMode && selectedMinutes == mins;
          return _Chip(
            label: '$mins min',
            active: active,
            onTap: () => onPreset(mins),
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

class _CustomTimeSlider extends StatelessWidget {
  final int valueMinutes;
  final ValueChanged<int> onChanged;

  const _CustomTimeSlider({required this.valueMinutes, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final clamped = valueMinutes.clamp(5, 60);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('5 min', style: Theme.of(context).textTheme.labelMedium),
              Text('$clamped min',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppColors.accent)),
              Text('60 min', style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
          Slider(
            value: clamped.toDouble(),
            min: 5,
            max: 60,
            divisions: 55,
            activeColor: AppColors.accent,
            label: '$clamped min',
            onChanged: (val) => onChanged(val.round()),
          ),
        ],
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
  final String? playingId;
  final bool isPlaying;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onTogglePreview;

  const _SoundPicker({
    required this.selectedId,
    required this.playingId,
    required this.isPlaying,
    required this.onSelect,
    required this.onTogglePreview,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: AlarmSound.all.map((s) {
        final selected = s.id == selectedId;
        final playingThis = isPlaying && playingId == s.id;
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
              icon: Icon(
                playingThis
                    ? Icons.stop_circle_rounded
                    : Icons.play_circle_outline_rounded,
                color: playingThis ? Colors.redAccent : AppColors.accent,
                size: 28,
              ),
              tooltip: playingThis ? 'Stop preview' : 'Play preview',
              onPressed: () => onTogglePreview(s.id),
            ),
            onTap: () {
              onSelect(s.id);
              onTogglePreview(s.id);
            },
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

class _FamilyNotificationSection extends StatelessWidget {
  final TripDraft draft;
  final TripDraftController notifier;
  final List<FamilyContact> savedContacts;
  final TextEditingController nameController;
  final TextEditingController phoneController;

  const _FamilyNotificationSection({
    required this.draft,
    required this.notifier,
    required this.savedContacts,
    required this.nameController,
    required this.phoneController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: draft.notifyFamily ? AppColors.accent : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
            activeThumbColor: AppColors.accent,
            value: draft.notifyFamily,
            onChanged: (val) => notifier.setNotifyFamily(val),
            title: const Row(
              children: [
                Icon(Icons.family_restroom_rounded, color: AppColors.accent, size: 20),
                SizedBox(width: 8),
                Text('Notify Family Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            subtitle: const Text('Send automatic arrival alert to family when trip ends'),
          ),
          if (draft.notifyFamily) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (savedContacts.isNotEmpty) ...[
                    Text('Quick Select Saved Contact', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ...savedContacts.map((contact) {
                            final selected = draft.familyContactPhone == contact.phone;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                selectedColor: AppColors.accentSoft,
                                avatar: Icon(Icons.person_rounded, size: 16, color: selected ? AppColors.accent : AppColors.textSecondary),
                                label: Text('${contact.name} (${contact.phone})'),
                                selected: selected,
                                onSelected: (sel) {
                                  if (sel) {
                                    notifier.setFamilyContactInfo(name: contact.name, phone: contact.phone);
                                    nameController.text = contact.name;
                                    phoneController.text = contact.phone;
                                  }
                                },
                              ),
                            );
                          }),
                          ChoiceChip(
                            selectedColor: AppColors.accentSoft,
                            avatar: const Icon(Icons.person_add_rounded, size: 16, color: AppColors.accent),
                            label: const Text('+ Add New'),
                            selected: savedContacts.every((c) => c.phone != draft.familyContactPhone),
                            onSelected: (sel) {
                              if (sel) {
                                notifier.setFamilyContactInfo(name: '', phone: '');
                                nameController.clear();
                                phoneController.clear();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameController,
                          onChanged: (val) => notifier.setFamilyContactInfo(name: val),
                          decoration: InputDecoration(
                            labelText: 'Contact Name',
                            hintText: 'e.g. Mom, Dad',
                            prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.accent, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          onChanged: (val) => notifier.setFamilyContactInfo(phone: val),
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            hintText: '+91 9876543210',
                            prefixIcon: const Icon(Icons.phone_rounded, color: AppColors.accent, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.accent,
                    value: draft.saveContactForFuture,
                    onChanged: (val) => notifier.setSaveContactForFuture(val ?? true),
                    title: const Text('Save contact for future trips', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 8),
                  Text('Notification Channel', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ChoiceChip(
                        selectedColor: AppColors.accentSoft,
                        label: const Row(
                          children: [
                            Icon(Icons.chat_rounded, color: Colors.green, size: 16),
                            SizedBox(width: 6),
                            Text('WhatsApp'),
                          ],
                        ),
                        selected: draft.familyChannel == 'whatsapp',
                        onSelected: (sel) => notifier.setFamilyChannel('whatsapp'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        selectedColor: AppColors.accentSoft,
                        label: const Row(
                          children: [
                            Icon(Icons.sms_rounded, color: AppColors.accent, size: 16),
                            SizedBox(width: 6),
                            Text('SMS'),
                          ],
                        ),
                        selected: draft.familyChannel == 'sms',
                        onSelected: (sel) => notifier.setFamilyChannel('sms'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
