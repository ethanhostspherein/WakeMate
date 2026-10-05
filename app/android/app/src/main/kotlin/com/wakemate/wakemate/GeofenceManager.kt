package com.wakemate.wakemate

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices

/**
 * Manages native hardware geofences and AlarmManager watchdog timers.
 * Ensures location tracking and arrival alarms survive process kills & reboots.
 */
object GeofenceManager {
    private const val TAG = "WakeMateGeofence"
    const val GEOFENCE_REQ_CODE = 8801
    const val WATCHDOG_REQ_CODE = 8802

    fun registerGeofence(
        context: Context,
        tripId: String,
        lat: Double,
        lng: Double,
        radiusKm: Double
    ) {
        val radiusMeters = (radiusKm * 1000.0).coerceAtLeast(200.0).toFloat()
        val geofencingClient: GeofencingClient = LocationServices.getGeofencingClient(context)

        val geofence = Geofence.Builder()
            .setRequestId(tripId)
            .setCircularRegion(lat, lng, radiusMeters)
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_DWELL)
            .setLoiteringDelay(15000)
            .build()

        val request = GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofence(geofence)
            .build()

        val intent = Intent(context, GeofenceBroadcastReceiver::class.java).apply {
            action = "com.wakemate.ACTION_GEOFENCE_EVENT"
            putExtra("tripId", tripId)
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            GEOFENCE_REQ_CODE,
            intent,
            flags
        )

        try {
            geofencingClient.removeGeofences(pendingIntent).addOnCompleteListener {
                try {
                    geofencingClient.addGeofences(request, pendingIntent)
                        .addOnSuccessListener {
                            Log.d(TAG, "Successfully registered native geofence for trip $tripId at radius ${radiusMeters}m")
                        }
                        .addOnFailureListener { e ->
                            Log.e(TAG, "Failed to register native geofence", e)
                        }
                } catch (e: SecurityException) {
                    Log.e(TAG, "Missing location permission for geofence registration", e)
                }
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "Missing location permission for geofence removal", e)
        }

        scheduleWatchdog(context)
    }

    fun removeGeofence(context: Context) {
        val geofencingClient: GeofencingClient = LocationServices.getGeofencingClient(context)
        val intent = Intent(context, GeofenceBroadcastReceiver::class.java).apply {
            action = "com.wakemate.ACTION_GEOFENCE_EVENT"
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            GEOFENCE_REQ_CODE,
            intent,
            flags
        )

        try {
            geofencingClient.removeGeofences(pendingIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Error removing native geofence", e)
        }

        cancelWatchdog(context)
    }

    fun scheduleWatchdog(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, WatchdogReceiver::class.java).apply {
            action = "com.wakemate.ACTION_WATCHDOG_TICK"
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            WATCHDOG_REQ_CODE,
            intent,
            flags
        )

        val intervalMs = 15 * 60 * 1000L // 15 minutes
        val triggerAtMs = SystemClock.elapsedRealtime() + intervalMs

        try {
            alarmManager.setInexactRepeating(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                triggerAtMs,
                intervalMs,
                pendingIntent
            )
            Log.d(TAG, "Scheduled AlarmManager watchdog ticker every 15 mins")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule watchdog timer", e)
        }
    }

    fun cancelWatchdog(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, WatchdogReceiver::class.java).apply {
            action = "com.wakemate.ACTION_WATCHDOG_TICK"
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            WATCHDOG_REQ_CODE,
            intent,
            flags
        )
        alarmManager.cancel(pendingIntent)
    }
}
