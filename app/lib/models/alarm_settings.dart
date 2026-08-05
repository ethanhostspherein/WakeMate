/// User's choices on the Set Alarm screen (distance, sound, volume).
class AlarmSettings {
  final double distanceKm;
  final String soundId;
  final double volume; // 0.0 – 1.0
  final bool maxVolumeOverride;
  final bool vibrate;

  const AlarmSettings({
    required this.distanceKm,
    required this.soundId,
    this.volume = 1.0,
    this.maxVolumeOverride = true,
    this.vibrate = true,
  });

  /// Preset distances shown as chips on the Set Alarm screen (km).
  static const List<double> presets = [1, 3, 5, 10];

  /// Custom slider bounds (UI/UX Brief §3.6).
  static const double minCustomKm = 0.5;
  static const double maxCustomKm = 50;

  static const AlarmSettings defaults = AlarmSettings(
    distanceKm: 3,
    soundId: 'classic_bell',
  );

  AlarmSettings copyWith({
    double? distanceKm,
    String? soundId,
    double? volume,
    bool? maxVolumeOverride,
    bool? vibrate,
  }) {
    return AlarmSettings(
      distanceKm: distanceKm ?? this.distanceKm,
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
  ];

  static String labelFor(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => all.first).label;
}
