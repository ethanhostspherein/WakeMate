package com.wakemate.wakemate

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONObject

/**
 * Boot Receiver listening for device boot completion and package updates.
 * Restores active trip geofencing and watchdog alarms automatically after a phone restart.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (Intent.ACTION_BOOT_COMPLETED == action || Intent.ACTION_MY_PACKAGE_REPLACED == action) {
            Log.d("BootReceiver", "Boot completed / package replaced. Checking for persisted active trips...")

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

                GeofenceManager.registerGeofence(context, tripId, lat, lng, alarmDistanceKm)
                Log.d("BootReceiver", "Successfully restored native geofence on device reboot for trip $tripId")
            } catch (e: Exception) {
                Log.e("BootReceiver", "Error restoring trip on reboot", e)
            }
        }
    }
}
