import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// The alarm engine. Overrides silent / vibrate / Do-Not-Disturb by playing on
/// the Android ALARM audio stream at forced-max volume, backed by a full-screen
/// intent notification that wakes the screen even when locked (TRD §5).
class AlarmService {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  static const _channel = MethodChannel('wakemate/alarm');
  final _player = AudioPlayer();
  final _notifications = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _ringing = false;
  int? _savedAlarmVolume;

  /// Tapping the full-screen alarm notification (wired in main() → Alarm screen).
  static void Function()? onAlarmTap;

  /// Tapping a scheduled departure prompt (payload `arm:<id>`) → arm that trip.
  static void Function(int pendingId)? onDepartureTap;

  /// Exposed so the departure scheduler can post/zoned-schedule via the same
  /// plugin instance (a second instance would clobber the response handler).
  FlutterLocalNotificationsPlugin get notifications => _notifications;

  Future<void> init() async {
    if (_initialized) return;
    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(
      settings: const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: _onResponse,
    );

    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // High-importance channel required for full-screen intent to surface.
    const alarmChannel = AndroidNotificationChannel(
      'wakemate_alarm',
      'Arrival alarm',
      description: 'Full-screen wake-up alarm when you near your stop.',
      importance: Importance.max,
      playSound: false, // audio handled by the player on STREAM_ALARM
      enableVibration: false,
    );
    // Standard channel for the "arm at departure" reminder.
    const departureChannel = AndroidNotificationChannel(
      'wakemate_departure',
      'Departure reminders',
      description: "Prompts you to arm WakeMate when your trip departs.",
      importance: Importance.high,
    );
    await android?.createNotificationChannel(alarmChannel);
    await android?.createNotificationChannel(departureChannel);

    _initialized = true;
  }

  /// Dispatch a notification tap by payload: alarm vs. departure prompt.
  static void _onResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.startsWith('arm:')) {
      final id = int.tryParse(payload.substring(4));
      if (id != null) onDepartureTap?.call(id);
      return;
    }
    onAlarmTap?.call();
  }

  /// Fire the alarm: max volume, loop the sound, vibrate, wake the screen and
  /// post a full-screen-intent notification.
  Future<void> fire({
    required String soundId,
    required double volume,
    required bool maxVolumeOverride,
    required bool vibrate,
    required String destinationName,
  }) async {
    if (_ringing) return;
    _ringing = true;
    await init();

    await WakelockPlus.enable();

    if (maxVolumeOverride) {
      _savedAlarmVolume = await _forceMaxAlarmVolume();
    }

    // Loop the bundled sound on the ALARM stream (works offline).
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      );
      await _player.setVolume(maxVolumeOverride ? 1.0 : volume);
      await _player.play(AssetSource('sounds/$soundId.wav'));
    } catch (_) {
      // Playback failure must not swallow the alarm — the notification and
      // vibration still fire below.
    }

    if (vibrate) {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(
            pattern: [0, 600, 300, 600, 300, 600], repeat: 1);
      }
    }

    await _showFullScreenNotification(destinationName);
  }

  Future<void> _showFullScreenNotification(String destinationName) async {
    final details = AndroidNotificationDetails(
      'wakemate_alarm',
      'Arrival alarm',
      channelDescription: 'Full-screen wake-up alarm.',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      visibility: NotificationVisibility.public,
    );
    await _notifications.show(
      id: 42,
      title: 'Wake up — station near',
      body: 'You are approaching $destinationName.',
      notificationDetails: NotificationDetails(android: details),
    );
  }

  /// Stop everything and restore the user's previous alarm volume.
  Future<void> stop() async {
    if (!_ringing) return;
    _ringing = false;
    try {
      await _player.stop();
    } catch (_) {}
    try {
      Vibration.cancel();
    } catch (_) {}
    await _notifications.cancel(id: 42);
    await WakelockPlus.disable();
    if (_savedAlarmVolume != null) {
      await _restoreAlarmVolume(_savedAlarmVolume!);
      _savedAlarmVolume = null;
    }
  }

  bool get isRinging => _ringing;

  Future<int?> _forceMaxAlarmVolume() async {
    try {
      return await _channel.invokeMethod<int>('forceMaxAlarmVolume');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> _restoreAlarmVolume(int previous) async {
    try {
      await _channel.invokeMethod('restoreAlarmVolume', {'volume': previous});
    } catch (_) {}
  }
}
