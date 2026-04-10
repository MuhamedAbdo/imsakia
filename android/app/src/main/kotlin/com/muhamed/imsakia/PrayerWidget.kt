package com.muhamed.imsakia

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PrayerWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val views = RemoteViews(context.packageName, R.layout.prayer_widget)
        
        // 1. البيانات الجمالية (اليسار)
        val hijri = widgetData.getString("flutter.hijri_date_full", "-- رمضان ١٤٤٧")
        views.setTextViewText(R.id.hijri_date, hijri)

        // 2. الصلوات (اليسار)
        val pastDisplay = widgetData.getString("flutter.last_prayer_display", "--:--")
        val nextDisplay = widgetData.getString("flutter.next_prayer_display", "--:--")
        views.setTextViewText(R.id.past_prayer_display, pastDisplay)
        views.setTextViewText(R.id.next_prayer_display, nextDisplay)

        // 3. العداد التنازلي المركزي (اليمين)
        val countdown = widgetData.getString("flutter.countdown_text", "00:00")
        views.setTextViewText(R.id.countdown_text, countdown)

        for (appWidgetId in appWidgetIds) {
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
