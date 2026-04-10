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
        
        // 1. التاريخ الهجري (اليمين)
        val hijri = widgetData.getString("flutter.hijri_date_full", "-- رمضان ١٤٤٧")
        views.setTextViewText(R.id.hijri_date, hijri)

        // 2. اسم الصلاة القادمة (اليسار)
        val nextPrayer = widgetData.getString("flutter.next_prayer_name", "الصلاة")
        views.setTextViewText(R.id.prayer_name, nextPrayer)

        // 3. العداد التنازلي (اليسار)
        val countdown = widgetData.getString("flutter.countdown_text", "00:00")
        views.setTextViewText(R.id.countdown_text, countdown)

        for (appWidgetId in appWidgetIds) {
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
