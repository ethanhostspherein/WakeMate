package com.wakemate.wakemate

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the `wakemate/alarm` platform channel.
 *
 * The alarm must override silent / vibrate / Do-Not-Disturb, which on Android
 * means raising STREAM_ALARM to its maximum before playback (TRD §5). We also
 * flag the window to show over the lock screen and turn the screen on so the
 * full-screen alarm is visible when the device wakes.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "wakemate/alarm"

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        showWhenLocked()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                val audio =
                    getSystemService(Context.AUDIO_SERVICE) as AudioManager
                when (call.method) {
                    "forceMaxAlarmVolume" -> {
                        val previous = audio.getStreamVolume(AudioManager.STREAM_ALARM)
                        val max = audio.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                        audio.setStreamVolume(AudioManager.STREAM_ALARM, max, 0)
                        showWhenLocked()
                        result.success(previous)
                    }
                    "restoreAlarmVolume" -> {
                        val volume = call.argument<Int>("volume")
                        if (volume != null) {
                            audio.setStreamVolume(
                                AudioManager.STREAM_ALARM, volume, 0
                            )
                        }
                        result.success(null)
                    }
                    "turnScreenOn" -> {
                        showWhenLocked()
                        result.success(null)
                    }
                    "getManufacturer" -> {
                        result.success(Build.MANUFACTURER)
                    }
                    "openOemSettings" -> {
                        result.success(openOemAutostartSettings())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Best-effort deep link into the OEM's own autostart/background-kill
    // manager (MIUI Autostart, Oppo/Vivo startup manager, Huawei protected
    // apps) — these sit on top of standard Android battery optimization and
    // aren't reachable through any public permission API. Component names
    // are undocumented and vary by firmware/region, so failure is expected
    // on some devices; the Dart caller falls back to the app's own Settings
    // page when this returns false.
    private fun openOemAutostartSettings(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val intent = when {
            manufacturer.contains("samsung") -> {
                val samsungIntents = listOf(
                    Intent().setComponent(ComponentName("com.samsung.android.looper", "com.samsung.android.looper.MainActivity")),
                    Intent().setComponent(ComponentName("com.samsung.android.sm", "com.samsung.android.sm.ui.battery.BatteryActivity")),
                    Intent().setComponent(ComponentName("com.samsung.android.sm_cn", "com.samsung.android.sm.ui.ram.AutoRunActivity")),
                    Intent("android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS")
                )
                for (si in samsungIntents) {
                    try {
                        si.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(si)
                        return true
                    } catch (_: Exception) {}
                }
                null
            }
            manufacturer.contains("xiaomi") -> Intent().setComponent(ComponentName(
                "com.miui.securitycenter",
                "com.miui.permcenter.autostart.AutoStartManagementActivity"))
            manufacturer.contains("oppo") -> Intent().setComponent(ComponentName(
                "com.coloros.safecenter",
                "com.coloros.safecenter.permission.startup.StartupAppListActivity"))
            manufacturer.contains("vivo") -> Intent().setComponent(ComponentName(
                "com.vivo.permissionmanager",
                "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"))
            manufacturer.contains("huawei") || manufacturer.contains("honor") -> Intent().setComponent(ComponentName(
                "com.huawei.systemmanager",
                "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"))
            else -> null
        } ?: return false

        return try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun showWhenLocked() {
        runOnUiThread {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
            } else {
                @Suppress("DEPRECATION")
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                )
            }
        }
    }
}
