package com.wakemate.wakemate

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import org.json.JSONObject

/**
 * Native receiver triggered by Google Play Services Geofence hardware transitions.
 * Fires even when the Flutter VM and application process are dead.
 */
class GeofenceBroadcastReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val geofencingEvent = GeofencingEvent.fromIntent(intent) ?: return
        if (geofencingEvent.hasError()) {
            Log.e("GeofenceReceiver", "Geofence error code: ${geofencingEvent.errorCode}")
            return
        }

        val transition = geofencingEvent.geofenceTransition
        if (transition == Geofence.GEOFENCE_TRANSITION_ENTER || transition == Geofence.GEOFENCE_TRANSITION_DWELL) {
            Log.d("GeofenceReceiver", "Hardware geofence ENTER transition detected! Waking native alarm screen...")

            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = prefs.getString("flutter.active_trip_v1", null)
            var destName = "Your Destination"
            var tripId = ""
            var alarmFired = false

            if (raw != null) {
                try {
                    val json = JSONObject(raw)
                    alarmFired = json.optBoolean("alarmFired", false)
                    tripId = json.optString("id", "")
                    val dest = json.getJSONObject("destination")
                    destName = dest.optString("placeName", dest.optString("formattedAddress", "Your Destination"))
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }

            if (!alarmFired) {
                val alarmIntent = Intent(context, AlarmActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    putExtra("destinationName", destName)
                    putExtra("tripId", tripId)
                }
                context.startActivity(alarmIntent)
            }
        }
    }
}
