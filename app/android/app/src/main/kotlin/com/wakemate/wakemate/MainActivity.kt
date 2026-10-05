package com.wakemate.wakemate

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.bluetooth.BluetoothHeadset
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the `wakemate/alarm` platform channel and headphone disconnect safety guard.
 *
 * The alarm must override silent / vibrate / Do-Not-Disturb, which on Android
 * means raising STREAM_ALARM to its maximum before playback (TRD §5). We also
 * flag the window to show over the lock screen and turn the screen on so the
 * full-screen alarm is visible when the device wakes.
 *
 * Safety Guard: Dynamically catches ACTION_AUDIO_BECOMING_NOISY and headset
 * unplugs, automatically routing full alarm playback directly through hardware
 * speakers so riders never miss alarms when earphones fall out mid-trip.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "wakemate/alarm"
    private var methodChannel: MethodChannel? = null
    private var noisyReceiverRegistered = false

    private val noisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = intent?.action
            if (AudioManager.ACTION_AUDIO_BECOMING_NOISY == action ||
                Intent.ACTION_HEADSET_PLUG == action ||
                BluetoothHeadset.ACTION_CONNECTION_STATE_CHANGED == action) {
                
                // Dart decides whether to force volume and routing, and only
                // while the alarm is actually ringing (AlarmService).

                // Dispatch event notification to Dart layer
                runOnUiThread {
                    methodChannel?.invokeMethod(
                        "onAudioBecomingNoisy",
                        mapOf(
                            "headphonesConnected" to isHeadphonesConnected(),
                            "action" to (action ?: "BECOMING_NOISY")
                        )
                    )
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        showWhenLocked()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel?.setMethodCallHandler { call, result ->
            val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            when (call.method) {
                "forceMaxAlarmVolume" -> {
                    val previous = audio.getStreamVolume(AudioManager.STREAM_ALARM)
                    val max = audio.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                    audio.setStreamVolume(AudioManager.STREAM_ALARM, max, 0)
                    routeToSpeaker(true)
                    showWhenLocked()
                    result.success(previous)
                }
                "restoreAlarmVolume" -> {
                    val volume = call.argument<Int>("volume")
                    if (volume != null) {
                        audio.setStreamVolume(AudioManager.STREAM_ALARM, volume, 0)
                    }
                    routeToSpeaker(false)
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
                "isHeadphonesConnected" -> {
                    result.success(isHeadphonesConnected())
                }
                "routeToSpeaker" -> {
                    val enable = call.argument<Boolean>("enable") ?: true
                    routeToSpeaker(enable)
                    result.success(true)
                }
                "enableHeadphoneGuard" -> {
                    registerNoisyReceiver()
                    result.success(true)
                }
                "disableHeadphoneGuard" -> {
                    unregisterNoisyReceiver()
                    result.success(true)
                }
                "getAudioRouteStatus" -> {
                    result.success(
                        mapOf(
                            "headphonesConnected" to isHeadphonesConnected(),
                            "speakerphoneOn" to audio.isSpeakerphoneOn,
                            "guardActive" to noisyReceiverRegistered
                        )
                    )
                }
                "syncActiveTripGeofence" -> {
                    val tripId = call.argument<String>("tripId") ?: ""
                    val lat = call.argument<Double>("lat") ?: 0.0
                    val lng = call.argument<Double>("lng") ?: 0.0
                    val radiusKm = call.argument<Double>("radiusKm") ?: 1.0
                    if (tripId.isNotEmpty() && lat != 0.0 && lng != 0.0) {
                        GeofenceManager.registerGeofence(this, tripId, lat, lng, radiusKm)
                    }
                    result.success(true)
                }
                "cancelActiveTripGeofence" -> {
                    GeofenceManager.removeGeofence(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        registerNoisyReceiver()
    }

    private fun isHeadphonesConnected(): Boolean {
        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val devices = audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            devices.any { device ->
                device.type == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
                device.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES ||
                device.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                device.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                device.type == AudioDeviceInfo.TYPE_USB_HEADSET
            }
        } else {
            @Suppress("DEPRECATION")
            audio.isWiredHeadsetOn || audio.isBluetoothA2dpOn
        }
    }

    private fun routeToSpeaker(enable: Boolean) {
        try {
            val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            @Suppress("DEPRECATION")
            audio.isSpeakerphoneOn = enable
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (enable) {
                    val devices = audio.availableCommunicationDevices
                    val speakerDevice = devices.firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
                    if (speakerDevice != null) {
                        audio.setCommunicationDevice(speakerDevice)
                    }
                } else {
                    audio.clearCommunicationDevice()
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun registerNoisyReceiver() {
        if (!noisyReceiverRegistered) {
            try {
                val filter = IntentFilter().apply {
                    addAction(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
                    addAction(Intent.ACTION_HEADSET_PLUG)
                    addAction(BluetoothHeadset.ACTION_CONNECTION_STATE_CHANGED)
                }
                registerReceiver(noisyReceiver, filter)
                noisyReceiverRegistered = true
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun unregisterNoisyReceiver() {
        if (noisyReceiverRegistered) {
            try {
                unregisterReceiver(noisyReceiver)
                noisyReceiverRegistered = false
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    override fun onDestroy() {
        unregisterNoisyReceiver()
        super.onDestroy()
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

