import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Detects whether the app is exempt from battery optimization and offers a
/// path to fix it. Aggressive OEM battery-saving is the top reliability risk
/// (TRD §4.1, Implementation Plan P2-07).
///
/// Standard Android's "ignore battery optimizations" permission is not
/// enough on several OEMs (Samsung, Xiaomi, Oppo, Vivo, Huawei), which run a
/// second, non-standard autostart/background-kill manager with no runtime
/// permission API — see [instructionsFor] / [openOemSettings].
class BatteryOptimization {
  BatteryOptimization._();

  static const _channel = MethodChannel('wakemate/alarm');

  /// True when tracking is safe from Doze/standby kills.
  static Future<bool> isExempt() async {
    final status = await Permission.ignoreBatteryOptimizations.status;
    return status.isGranted;
  }

  /// Prompt the OS "ignore battery optimizations" dialog / settings.
  static Future<bool> requestExemption() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  /// Deep link to the app's system settings for manual OEM configuration
  /// (MIUI Autostart, Oppo Startup Manager, etc. live here per device).
  static Future<void> openSettings() => openAppSettings();

  /// Device manufacturer (e.g. "samsung", "xiaomi"), lowercased. Empty string
  /// if it can't be read (non-Android, or the channel is unavailable).
  static Future<String> manufacturer() async {
    try {
      final name = await _channel.invokeMethod<String>('getManufacturer');
      return (name ?? '').toLowerCase();
    } catch (_) {
      return '';
    }
  }

  /// Plain-language instructions for the OEM-specific background-kill layer,
  /// or null if this manufacturer needs no special-casing beyond the
  /// standard Android battery-optimization exemption above.
  static String? instructionsFor(String manufacturer) {
    if (manufacturer.contains('samsung')) {
      return 'Battery and device care → Background usage limits → '
          'Never sleeping apps → add WakeMate.';
    }
    if (manufacturer.contains('xiaomi') ||
        manufacturer.contains('redmi') ||
        manufacturer.contains('poco')) {
      return 'Security app → Autostart → enable WakeMate.';
    }
    if (manufacturer.contains('oppo') || manufacturer.contains('realme')) {
      return 'Settings → Battery → Startup Manager → allow WakeMate to '
          'start automatically.';
    }
    if (manufacturer.contains('vivo')) {
      return 'i Manager → App autostart / Background power → allow '
          'WakeMate.';
    }
    if (manufacturer.contains('huawei') || manufacturer.contains('honor')) {
      return 'Phone Manager → Protected apps → enable WakeMate.';
    }
    if (manufacturer.contains('oneplus')) {
      return 'Settings → Battery → Battery optimization → set WakeMate to '
          '"Don\'t optimize".';
    }
    return null;
  }

  /// Best-effort deep link into the OEM's autostart/background screen.
  /// Component names are undocumented and vary by firmware/region, so this
  /// silently falls back to the app's own Settings page when the OEM screen
  /// can't be reached (unsupported manufacturer, or intent failure).
  static Future<void> openOemSettings() async {
    try {
      final opened = await _channel.invokeMethod<bool>('openOemSettings');
      if (opened == true) return;
    } catch (_) {}
    await openSettings();
  }
}
