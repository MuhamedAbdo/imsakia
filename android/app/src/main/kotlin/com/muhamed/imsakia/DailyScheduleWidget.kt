package com.muhamed.imsakia

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.graphics.Color

/**
 * DailyScheduleWidget — A widget that shows all 6 prayer times for the day.
 * Highlights the next prayer.
 */
class DailyScheduleWidget : AppWidgetProvider() {

    companion object {
        fun updateAll(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, DailyScheduleWidget::class.java))
            if (ids.isNotEmpty()) {
                val provider = DailyScheduleWidget()
                provider.onUpdate(context, appWidgetManager, ids)
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

        val nextName = prefs.getString("flutter.next_prayer_name", null)
        
        val fajrTime = prefs.getString("flutter.fajr_time", "--")
        val sunriseTime = prefs.getString("flutter.sunrise_time", "--")
        val dhuhrTime = prefs.getString("flutter.dhuhr_time", "--")
        val asrTime = prefs.getString("flutter.asr_time", "--")
        val maghribTime = prefs.getString("flutter.maghrib_time", "--")
        val ishaTime = prefs.getString("flutter.isha_time", "--")

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.daily_schedule_widget)

            // Set prayer times
            views.setTextViewText(R.id.prayer1_time, fajrTime)
            views.setTextViewText(R.id.prayer2_time, sunriseTime)
            views.setTextViewText(R.id.prayer3_time, dhuhrTime)
            views.setTextViewText(R.id.prayer4_time, asrTime)
            views.setTextViewText(R.id.prayer5_time, maghribTime)
            views.setTextViewText(R.id.prayer6_time, ishaTime)

            // Reset backgrounds for all
            val defaultColor = Color.parseColor("#FFFFFF")
            val defaultBg = R.drawable.widget_bg_small
            val activeColor = Color.parseColor("#D4AF37")
            
            // Note: Since we are using a solid background drawable, we will just change the text color to highlight
            // instead of complex background switching, keeping it clean as requested.
            views.setTextColor(R.id.prayer1_name, defaultColor)
            views.setTextColor(R.id.prayer1_time, defaultColor)
            views.setTextColor(R.id.prayer2_name, defaultColor)
            views.setTextColor(R.id.prayer2_time, defaultColor)
            views.setTextColor(R.id.prayer3_name, defaultColor)
            views.setTextColor(R.id.prayer3_time, defaultColor)
            views.setTextColor(R.id.prayer4_name, defaultColor)
            views.setTextColor(R.id.prayer4_time, defaultColor)
            views.setTextColor(R.id.prayer5_name, defaultColor)
            views.setTextColor(R.id.prayer5_time, defaultColor)
            views.setTextColor(R.id.prayer6_name, defaultColor)
            views.setTextColor(R.id.prayer6_time, defaultColor)

            // Highlight next prayer
            when (nextName) {
                "الفجر" -> {
                    views.setTextColor(R.id.prayer1_name, activeColor)
                    views.setTextColor(R.id.prayer1_time, activeColor)
                }
                "الشروق" -> {
                    views.setTextColor(R.id.prayer2_name, activeColor)
                    views.setTextColor(R.id.prayer2_time, activeColor)
                }
                "الظهر" -> {
                    views.setTextColor(R.id.prayer3_name, activeColor)
                    views.setTextColor(R.id.prayer3_time, activeColor)
                }
                "العصر" -> {
                    views.setTextColor(R.id.prayer4_name, activeColor)
                    views.setTextColor(R.id.prayer4_time, activeColor)
                }
                "المغرب" -> {
                    views.setTextColor(R.id.prayer5_name, activeColor)
                    views.setTextColor(R.id.prayer5_time, activeColor)
                }
                "العشاء" -> {
                    views.setTextColor(R.id.prayer6_name, activeColor)
                    views.setTextColor(R.id.prayer6_time, activeColor)
                }
            }

            // Tap to open app
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                2001, // Unique request code
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.daily_schedule_widget_layout, pendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
