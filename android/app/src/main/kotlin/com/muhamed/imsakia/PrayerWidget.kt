package com.muhamed.imsakia

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
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

        // 3. العداد التنازلي الذكي (Chronometer) - اليمين
        val nextTimestamp = widgetData.getLong("flutter.next_prayer_timestamp", 0L)
        if (nextTimestamp > 0L) {
            val now = System.currentTimeMillis()
            val remainingMs = nextTimestamp - now
            
            if (remainingMs > 0) {
                val baseTime = android.os.SystemClock.elapsedRealtime() + remainingMs
                
                views.setChronometer(R.id.countdown_text, baseTime, null, true)
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                    views.setChronometerCountDown(R.id.countdown_text, true)
                }
            } else {
                val fallback = widgetData.getString("flutter.countdown_text", "00:00")
                views.setChronometer(R.id.countdown_text, android.os.SystemClock.elapsedRealtime(), null, false)
                views.setTextViewText(R.id.countdown_text, fallback)
            }
        } else {
            val fallback = widgetData.getString("flutter.countdown_text", "00:00")
            views.setChronometer(R.id.countdown_text, android.os.SystemClock.elapsedRealtime(), null, false)
            views.setTextViewText(R.id.countdown_text, fallback)
        }

        // 4. ربط الضغط على الويدجت بفتح التطبيق
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

        // 5. جدولة تنبيه (Alarm) وقت الصلاة لضمان تحديث الطقم وقت الـ Zero
        if (nextTimestamp > System.currentTimeMillis()) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            val alarmIntent = Intent(context, PrayerWidget::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
            }
            // نستخدم كود ثابت لنتمكن من تحديث/إلغاء التنبيه السابق
            val alarmPendingIntent = PendingIntent.getBroadcast(
                context,
                1001,
                alarmIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    android.app.AlarmManager.RTC_WAKEUP,
                    nextTimestamp,
                    alarmPendingIntent
                )
            } else {
                alarmManager.setExact(
                    android.app.AlarmManager.RTC_WAKEUP,
                    nextTimestamp,
                    alarmPendingIntent
                )
            }
        }

        for (appWidgetId in appWidgetIds) {
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
