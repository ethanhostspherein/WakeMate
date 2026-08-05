import 'package:permission_handler/permission_handler.dart';

/// Detects whether the app is exempt from battery optimization and offers a
/// path to fix it. Aggressive OEM battery-saving is the top reliability risk
/// (TRD §4.1, Implementation Plan P2-07).
class BatteryOptimization {
  BatteryOptimization._();

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
}
