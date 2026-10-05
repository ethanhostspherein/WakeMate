package com.wakemate.wakemate

import android.app.Activity
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONObject

/**
 * Pure Kotlin Full-Screen Alarm Activity.
 * Rings full-volume audio over the lock screen immediately even when Flutter VM is dead.
 */
class AlarmActivity : Activity() {

    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var destinationName: String = "Your Station"
    private var tripId: String = ""
    private var previousVolume: Int = -1

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        wakeScreen()

        destinationName = intent.getStringExtra("destinationName") ?: loadDestinationFromPrefs() ?: "Your Station"
        tripId = intent.getStringExtra("tripId") ?: loadTripIdFromPrefs() ?: ""

        val root = createUI()
        setContentView(root)

        startAlarmSoundAndVibration()
    }

    private fun wakeScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
        )
    }

    private fun createUI(): View {
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#0B0F19")) // Dark background
            setPadding(48, 96, 48, 96)
        }

        // Warning Badge
        val badge = TextView(this).apply {
            text = "🔔 ARRIVAL ALARM"
            setTextColor(Color.parseColor("#FF5252"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(32, 16, 32, 16)
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#2A1215"))
                setCornerRadius(24f)
                setStroke(2, Color.parseColor("#FF5252"))
            }
        }
        val badgeParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            bottomMargin = 48
        }
        container.addView(badge, badgeParams)

        // Wake Up Title
        val titleView = TextView(this).apply {
            text = "Wake up!"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 36f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }
        container.addView(titleView)

        // Subtitle
        val subTitleView = TextView(this).apply {
            text = "Approaching your destination"
            setTextColor(Color.parseColor("#94A3B8"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            gravity = Gravity.CENTER
        }
        val subTitleParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            topMargin = 12
            bottomMargin = 64
        }
        container.addView(subTitleView, subTitleParams)

        // Destination Card
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(48, 48, 48, 48)
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#1E293B"))
                setCornerRadius(32f)
            }
        }
        val destLabel = TextView(this).apply {
            text = "DESTINATION"
            setTextColor(Color.parseColor("#38BDF8"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            typeface = Typeface.DEFAULT_BOLD
        }
        val destName = TextView(this).apply {
            text = destinationName
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 24f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }
        card.addView(destLabel)
        card.addView(destName)

        val cardParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            bottomMargin = 96
        }
        container.addView(card, cardParams)

        // Dismiss Button
        val dismissBtn = Button(this).apply {
            text = "DISMISS ALARM"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            typeface = Typeface.DEFAULT_BOLD
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#22C55E")) // Emerald green
                setCornerRadius(32f)
            }
            setOnClickListener { handleDismiss() }
        }
        val dismissParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            140
        ).apply {
            bottomMargin = 32
        }
        container.addView(dismissBtn, dismissParams)

        // Snooze Button
        val snoozeBtn = Button(this).apply {
            text = "SNOOZE (Shorter Distance)"
            setTextColor(Color.parseColor("#E2E8F0"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#334155"))
                setCornerRadius(32f)
            }
            setOnClickListener { handleSnooze() }
        }
        val snoozeParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            120
        )
        container.addView(snoozeBtn, snoozeParams)

        return container
    }

    private fun startAlarmSoundAndVibration() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        previousVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
        val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
        audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxVolume, 0)

        try {
            val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

            mediaPlayer = MediaPlayer().apply {
                setDataSource(applicationContext, alarmUri)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                isLooping = true
                prepare()
                start()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // Vibration
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vibrator = vm.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }

            val pattern = longArrayOf(0, 600, 300, 600, 300, 600)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun stopAlarmSoundAndVibration() {
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
            mediaPlayer = null
        } catch (_: Exception) {}

        try {
            vibrator?.cancel()
            vibrator = null
        } catch (_: Exception) {}

        if (previousVolume != -1) {
            try {
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                audioManager.setStreamVolume(AudioManager.STREAM_ALARM, previousVolume, 0)
            } catch (_: Exception) {}
        }
    }

    private fun handleDismiss() {
        stopAlarmSoundAndVibration()
        markAlarmFiredInPrefs(true)
        GeofenceManager.removeGeofence(this)
        finish()
    }

    private fun handleSnooze() {
        stopAlarmSoundAndVibration()

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString("flutter.active_trip_v1", null)
        if (raw != null) {
            try {
                val json = JSONObject(raw)
                val currentDist = json.optDouble("alarmDistanceKm", 1.0)
                val newDist = (currentDist * 0.5).coerceIn(0.2, 1.0)
                json.put("alarmDistanceKm", newDist)
                json.put("alarmFired", false)
                prefs.edit().putString("flutter.active_trip_v1", json.toString()).apply()

                val dest = json.getJSONObject("destination")
                val lat = dest.getDouble("latitude")
                val lng = dest.getDouble("longitude")
                val id = json.getString("id")

                GeofenceManager.registerGeofence(this, id, lat, lng, newDist)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        finish()
    }

    private fun loadDestinationFromPrefs(): String? {
        return try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = prefs.getString("flutter.active_trip_v1", null) ?: return null
            val json = JSONObject(raw)
            val dest = json.getJSONObject("destination")
            dest.optString("placeName", dest.optString("formattedAddress", "Your Station"))
        } catch (e: Exception) {
            null
        }
    }

    private fun loadTripIdFromPrefs(): String? {
        return try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = prefs.getString("flutter.active_trip_v1", null) ?: return null
            val json = JSONObject(raw)
            json.optString("id", null)
        } catch (e: Exception) {
            null
        }
    }

    private fun markAlarmFiredInPrefs(fired: Boolean) {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = prefs.getString("flutter.active_trip_v1", null) ?: return
            val json = JSONObject(raw)
            json.put("alarmFired", fired)
            prefs.edit().putString("flutter.active_trip_v1", json.toString()).apply()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        stopAlarmSoundAndVibration()
        super.onDestroy()
    }
}
