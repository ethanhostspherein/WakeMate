package com.wakemate.wakemate

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONObject

/**
 * Native AlarmManager Watchdog Receiver.
 * Ticks periodically to ensure native geofences remain registered and valid.
 */
class WatchdogReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        Log.d("WatchdogReceiver", "Watchdog ticker received")

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString("flutter.active_trip_v1", null) ?: return

        try {
            val json = JSONObject(raw)
            val alarmFired = json.optBoolean("alarmFired", false)
            if (alarmFired) return

            val tripId = json.getString("id")
            val alarmDistanceKm = json.optDouble("alarmDistanceKm", 1.0)
            val dest = json.getJSONObject("destination")
            val lat = dest.getDouble("latitude")
            val lng = dest.getDouble("longitude")

            // Re-enforce native hardware geofence
            GeofenceManager.registerGeofence(context, tripId, lat, lng, alarmDistanceKm)
            Log.d("WatchdogReceiver", "Watchdog verified and re-armed geofence for active trip $tripId")
        } catch (e: Exception) {
            Log.e("WatchdogReceiver", "Error inspecting trip in watchdog", e)
        }
    }
}
