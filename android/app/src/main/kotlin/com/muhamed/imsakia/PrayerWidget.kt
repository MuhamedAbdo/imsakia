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
        var nextDisplay = widgetData.getString("flutter.next_prayer_display", "--:--") ?: "--:--"
        var nextTimestamp = widgetData.getLong("flutter.next_prayer_timestamp", 0L)

        // Immediately show cached text to avoid "Updating..." hang
        views.setTextViewText(R.id.hijri_date, hijri)
        views.setTextViewText(R.id.past_prayer_display, pastDisplay)

        // 2. Smart Countdown Self-Healing
        val now = System.currentTimeMillis()
        if (nextTimestamp <= now) {
            // 🔥 البحث المحلي عن الصلاة التالية فوراً دون انتظار فلاتر
            val localNext = findNextPrayerLocally(context)
            if (localNext != null) {
                nextTimestamp = localNext["timestamp"] as Long
                nextDisplay = localNext["display"] as String
                // Sync back to prevent repeated searching
                syncToHomeWidget(context, localNext)
            }
        }
        
        views.setTextViewText(R.id.next_prayer_display, nextDisplay)

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
            // Fallback
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

    private fun findNextPrayerLocally(context: Context): Map<String, Any>? {
        val now = System.currentTimeMillis()
        val schedules = context.getSharedPreferences("athan_schedules", Context.MODE_PRIVATE)
        
        var earliestFutureTimestamp = Long.MAX_VALUE
        var foundData: String? = null
        
        for (entry in schedules.all) {
            val key = entry.key
            if (key.endsWith("_data")) continue
            val timestamp = entry.value as? Long ?: continue
            
            if (timestamp > now && timestamp < earliestFutureTimestamp) {
                earliestFutureTimestamp = timestamp
                foundData = schedules.getString("${key}_data", null)
            }
        }
        
        return if (foundData != null) {
            val parts = foundData.split("|")
            if (parts.size >= 2) {
                val name = parts[0]
                mapOf(
                    "timestamp" to earliestFutureTimestamp,
                    "name" to name,
                    "display" to "$name ${formatTime(earliestFutureTimestamp)}"
                )
            } else null
        } else null
    }

    private fun formatTime(millis: Long): String {
        val date = java.util.Date(millis)
        val sdf = java.text.SimpleDateFormat("h:mm a", java.util.Locale("ar"))
        return sdf.format(date)
    }

    private fun syncToHomeWidget(context: Context, data: Map<String, Any>) {
        val widgetData = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        widgetData.edit()
            .putLong("flutter.next_prayer_timestamp", data["timestamp"] as Long)
            .putString("flutter.next_prayer_name", data["name"] as String)
            .putString("flutter.next_prayer_display", data["display"] as String)
            .apply()
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

