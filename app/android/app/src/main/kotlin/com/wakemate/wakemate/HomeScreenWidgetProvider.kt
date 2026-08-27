package com.wakemate.wakemate

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/// Home-screen widget — shows the most recent trip pushed from Dart
/// (HomeWidgetService) and opens the app on tap. Tracking Task #10.
class HomeScreenWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.home_screen_widget).apply {
                setTextViewText(
                    R.id.widget_status,
                    widgetData.getString("status", "WakeMate"),
                )
                setTextViewText(
                    R.id.widget_dest,
                    widgetData.getString("destName", "No trip yet"),
                )
                setTextViewText(
                    R.id.widget_detail,
                    widgetData.getString("detail", "Start a trip in the app"),
                )
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
