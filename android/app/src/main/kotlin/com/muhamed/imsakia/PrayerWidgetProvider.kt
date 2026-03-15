package com.muhamed.imsakia

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import com.muhamed.imsakia.R
import es.antonborri.home_widget.HomeWidgetProvider

import android.app.PendingIntent
import android.content.Intent

class PrayerWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_layout)

        // Null Safety is handled by a fallback empty string or default dashes
        val widgetHours   = widgetData.getString("widget_hours",   "00") ?: "00"
        val widgetMinutes = widgetData.getString("widget_minutes", "00") ?: "00"
        val nextPrayer    = widgetData.getString("next_prayer",    "")  ?: ""
        val missedPrayer  = widgetData.getString("missed_prayer",  "")  ?: ""

        views.setTextViewText(R.id.tv_hours,       widgetHours)
        views.setTextViewText(R.id.tv_minutes,     widgetMinutes)
        views.setTextViewText(R.id.tv_next_prayer, nextPrayer)
        views.setTextViewText(R.id.tv_missed_prayer, missedPrayer)

        // Click to open App
        val intent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

        for (appWidgetId in appWidgetIds) {
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
