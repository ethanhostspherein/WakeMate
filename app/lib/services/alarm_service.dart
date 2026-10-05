import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// The alarm engine. Overrides silent / vibrate / Do-Not-Disturb by playing on
/// the Android ALARM audio stream at forced-max volume, backed by a full-screen
/// intent notification that wakes the screen even when locked (TRD §5).
///
/// Headphones / Earphone Disconnect Safety Guard: Ensures that when the alarm
/// fires or when earphones fall out / disconnect mid-trip (ACTION_AUDIO_BECOMING_NOISY),
/// playback is immediately routed directly through hardware speakers on STREAM_ALARM.
class AlarmService {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  static const _channel = MethodChannel('wakemate/alarm');
  final _player = AudioPlayer();
  final _notifications = FlutterLocalNotificationsPlugin();
  final _audioGuardController = StreamController<bool>.broadcast();

  bool _initialized = false;
  bool _ringing = false;
  int? _savedAlarmVolume;

  /// Stream emitting earphone connection status updates when ACTION_AUDIO_BECOMING_NOISY fires.
  Stream<bool> get onHeadphonesDisconnected => _audioGuardController.stream;

  /// Tapping the full-screen alarm notification (wired in main() → Alarm screen).
  static void Function()? onAlarmTap;

  /// Tapping a scheduled departure prompt (payload `arm:<id>`) → arm that trip.
  static void Function(int pendingId)? onDepartureTap;

  /// Exposed so the departure scheduler can post/zoned-schedule via the same
  /// plugin instance (a second instance would clobber the response handler).
  FlutterLocalNotificationsPlugin get notifications => _notifications;

  Future<void> init() async {
    if (_initialized) return;
    _channel.setMethodCallHandler(_handleNativeMethodCall);

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

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'onAudioBecomingNoisy') {
      final Map<dynamic, dynamic>? args =
          call.arguments as Map<dynamic, dynamic>?;
      final bool headphonesConnected =
          args?['headphonesConnected'] as bool? ?? false;

      // Earphones unplugged / audio route changed!
      // Immediately enforce hardware speaker output and max volume.
      await routeToSpeaker(true);
      if (_ringing) {
        await _forceMaxAlarmVolume();
      }
      _audioGuardController.add(headphonesConnected);
    }
  }

  /// Checks if wired/Bluetooth earphones are currently connected.
  Future<bool> isHeadphonesConnected() async {
    try {
      final connected =
          await _channel.invokeMethod<bool>('isHeadphonesConnected');
      return connected ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Forces audio output through device hardware speaker.
  Future<void> routeToSpeaker(bool enable) async {
    try {
      await _channel.invokeMethod('routeToSpeaker', {'enable': enable});
    } catch (_) {}
  }

  /// Returns raw audio routing status map from native plugin.
  Future<Map<String, dynamic>> getAudioRouteStatus() async {
    try {
      final map =
          await _channel.invokeMapMethod<String, dynamic>('getAudioRouteStatus');
      return map ?? {};
    } catch (_) {
      return {};
    }
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
  /// post a full-screen-intent notification, with hardware speaker fallback forced.
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
    await _turnScreenOn();

    if (maxVolumeOverride) {
      _savedAlarmVolume = await _forceMaxAlarmVolume();
    }
    // Force audio route directly to hardware speaker (Safety Guard).
    await routeToSpeaker(true);

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

  /// Self-test probe (Reliability Engine): confirms the device can vibrate
  /// AND that the audio pipeline accepts a source, without ever touching the
  /// shared [_player]/ALARM stream so it can't collide with [fire]'s
  /// volume/ringing state. Guarded by [isRinging] at the call site.
  Future<bool> selfTest() async {
    bool vibrationOk = false;
    try {
      vibrationOk = await Vibration.hasVibrator();
    } catch (_) {}

    // ponytail: confirms the playback pipeline initializes and accepts a
    // source at zero volume — not that sound is actually audible through the
    // speaker. Upgrade to a hardware/output-device check if false negatives
    // (silent-but-reported-ok) become a real complaint.
    bool audioOk = false;
    final probe = AudioPlayer();
    try {
      await probe.setVolume(0);
      await probe.play(AssetSource('sounds/classic_bell.wav'));
      audioOk = true;
    } catch (_) {
    } finally {
      try {
        await probe.stop();
      } catch (_) {}
      await probe.dispose();
    }

    return vibrationOk && audioOk;
  }

  /// Missed-stop escalation: a sharper vibration burst layered onto an
  /// already-ringing alarm. No-ops if the alarm isn't currently ringing.
  Future<void> escalate() async {
    if (!_ringing) return;
    try {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(
            pattern: [0, 1000, 200, 1000, 200, 1000, 200, 1000], repeat: 1);
      }
    } catch (_) {}
  }

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

  Future<void> _turnScreenOn() async {
    try {
      await _channel.invokeMethod('turnScreenOn');
    } catch (_) {}
  }
}

