package com.muhamed.imsakia

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PrayerWidget : HomeWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action
        
        // Handling TIME_TICK (every minute) or custom update actions
        if (action == Intent.ACTION_TIME_TICK || 
            action == "com.muhamed.imsakia.UPDATE_COUNTDOWN" || 
            action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, PrayerWidget::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            
            // Get SharedPreferences (same as what HomeWidgetProvider uses internally)
            val widgetData = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            
            onUpdate(context, appWidgetManager, appWidgetIds, widgetData)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val views = RemoteViews(context.packageName, R.layout.prayer_widget)
        
        // 1. Offline First: Read cached data immediately
        val hijri = widgetData.getString("flutter.hijri_date_full", "-- رمضان ١٤٤٧")
        val pastDisplay = widgetData.getString("flutter.last_prayer_display", "--:--")
        val nextDisplay = widgetData.getString("flutter.next_prayer_display", "--:--")
        val nextTimestamp = widgetData.getLong("flutter.next_prayer_timestamp", 0L)

        // Immediately show cached text to avoid "Updating..." hang
        views.setTextViewText(R.id.hijri_date, hijri)
        views.setTextViewText(R.id.past_prayer_display, pastDisplay)
        views.setTextViewText(R.id.next_prayer_display, nextDisplay)

        // 2. Smart Countdown (Chronometer/Manual)
        val now = System.currentTimeMillis()
        if (nextTimestamp > now) {
            val remainingMs = nextTimestamp - now
            val baseTime = android.os.SystemClock.elapsedRealtime() + remainingMs
            
            // Update Chronometer
            views.setChronometer(R.id.countdown_text, baseTime, null, true)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                views.setChronometerCountDown(R.id.countdown_text, true)
            }
            
            // 3. Schedule Reliable NEXT Alarm (StabilityChain)
            scheduleExactAlarm(context, nextTimestamp, appWidgetIds)
        } else {
            // Fallback: If no future timestamp, show loading or zero
            views.setChronometer(R.id.countdown_text, android.os.SystemClock.elapsedRealtime(), null, false)
            views.setTextViewText(R.id.countdown_text, "جاري التحديث...")
        }

        // 4. Interaction: Click to open app
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

        // Apply update to all active widgets
        for (appWidgetId in appWidgetIds) {
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun scheduleExactAlarm(context: Context, triggerTime: Long, appWidgetIds: IntArray) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        val alarmIntent = Intent(context, PrayerWidget::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            1001,
            alarmIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    android.app.AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    android.app.AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
            }
        } catch (e: Exception) {
            // Fallback for security exceptions on some OEMs
            alarmManager.set(android.app.AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
        }
    }
}

