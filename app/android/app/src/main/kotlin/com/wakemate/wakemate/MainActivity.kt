package com.wakemate.wakemate

import android.content.Context
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
                    else -> result.notImplemented()
                }
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
