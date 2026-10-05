import 'package:shared_preferences/shared_preferences.dart';

import 'trip.dart';

/// User's choices on the Set Alarm screen (distance/time trigger, sound, volume).
class AlarmSettings {
  final double distanceKm;
  final AlarmTriggerType triggerType;
  final int triggerMinutes;
  final String soundId;
  final double volume; // 0.0 – 1.0
  final bool maxVolumeOverride;
  final bool vibrate;

  const AlarmSettings({
    required this.distanceKm,
    this.triggerType = AlarmTriggerType.distance,
    this.triggerMinutes = 10,
    required this.soundId,
    this.volume = 1.0,
    this.maxVolumeOverride = true,
    this.vibrate = true,
  });

  /// Preset distances shown as chips on the Set Alarm screen (km).
  static const List<double> presets = [1, 3, 5, 10];

  /// Preset minutes shown as chips on the Set Alarm screen.
  static const List<int> timePresets = [10, 20, 30, 45];

  /// Custom slider bounds (UI/UX Brief §3.6).
  static const double minCustomKm = 0.5;
  static const double maxCustomKm = 50;

  // Settings-screen choices, pre-warmed by [loadPersistedDefaults] in main()
  // so [defaults] can stay a synchronous getter (TripDraftController.build()
  // must return synchronously — no awaiting SharedPreferences there).
  static bool _defaultVibrate = true;
  static String _defaultSoundId = 'classic_bell';

  /// Display-only unit preference (Settings screen). Distances are always
  /// stored/computed in km internally — this only affects [formatDistance].
  static bool useMetric = true;

  static AlarmSettings get defaults => AlarmSettings(
        distanceKm: 3,
        triggerType: AlarmTriggerType.distance,
        triggerMinutes: 10,
        soundId: _defaultSoundId,
        vibrate: _defaultVibrate,
      );

  /// Load the user's Settings-screen defaults (same SharedPreferences keys
  /// `settings_screen.dart` writes) before the provider tree builds.
  static Future<void> loadPersistedDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultVibrate = prefs.getBool('pref_vibrate') ?? _defaultVibrate;
    _defaultSoundId = prefs.getString('pref_sound') ?? _defaultSoundId;
    useMetric = prefs.getBool('pref_metric') ?? useMetric;
  }

  /// Format a km distance per the user's unit preference, e.g. "3 km" or
  /// "1.9 mi".
  static String formatDistance(double km) {
    if (useMetric) return '${km.toStringAsFixed(km < 1 ? 1 : 0)} km';
    final mi = km * 0.621371;
    return '${mi.toStringAsFixed(mi < 1 ? 1 : 0)} mi';
  }

  AlarmSettings copyWith({
    double? distanceKm,
    AlarmTriggerType? triggerType,
    int? triggerMinutes,
    String? soundId,
    double? volume,
    bool? maxVolumeOverride,
    bool? vibrate,
  }) {
    return AlarmSettings(
      distanceKm: distanceKm ?? this.distanceKm,
      triggerType: triggerType ?? this.triggerType,
      triggerMinutes: triggerMinutes ?? this.triggerMinutes,
      soundId: soundId ?? this.soundId,
      volume: volume ?? this.volume,
      maxVolumeOverride: maxVolumeOverride ?? this.maxVolumeOverride,
      vibrate: vibrate ?? this.vibrate,
    );
  }
}

/// A selectable alarm sound. Bundled sounds work offline (TRD §5).
class AlarmSound {
  final String id;
  final String label;

  const AlarmSound(this.id, this.label);

  static const List<AlarmSound> all = [
    AlarmSound('classic_bell', 'Classic Bell'),
    AlarmSound('gentle_chime', 'Gentle Chime'),
    AlarmSound('loud_siren', 'Loud Siren'),
    AlarmSound('train_horn', 'Train Horn'),
    AlarmSound('rooster', 'Rooster'),
    AlarmSound('alarm_beep', 'Alarm Beep'),
    AlarmSound('warning_buzzer', 'Warning Buzzer'),
    AlarmSound('morning_alarm', 'Morning Alarm'),
    AlarmSound('emergency_alert', 'Emergency Alert'),
    AlarmSound('classic_short_alarm', 'Quick Alarm'),
  ];

  static String labelFor(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => all.first).label;
}
