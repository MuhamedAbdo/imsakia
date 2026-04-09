package com.muhamed.imsakia

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import java.util.Calendar
import java.util.concurrent.TimeUnit

class PrayerWidget : AppWidgetProvider() {

    companion object {
        private const val ACTION_UPDATE_COUNTDOWN = "com.muhamed.imsakia.UPDATE_COUNTDOWN"
        
        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.prayer_widget)
            
            // نحاول جلب البيانات من ملفات التفضيلات المحتملة (الأولوية لـ HomeWidget)
            val homeWidgetPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val defaultPrefs = android.preference.PreferenceManager.getDefaultSharedPreferences(context)

            // دالة مساعدة للجلب من المصادر المتاحة بالترتيب
            fun getValue(key: String, default: String): String {
                return homeWidgetPrefs.getString(key, null) 
                    ?: flutterPrefs.getString(key, null) 
                    ?: defaultPrefs.getString(key, null) 
                    ?: default
            }

            // 1. جلب البيانات الأساسية فقط (الخطة C - تبسيط مطلق)
            val nextPrayerName = getValue("flutter.next_prayer_name", "الصلاة")
            val countdownText = getValue("flutter.countdown_text", "--:--")

            Log.d("ZadWidget", "Plan C Update: Next=$nextPrayerName, Time=$countdownText")

            try {
                // 2. تحديث النصوص في الهيكل المجرد (3 عناصر فقط)
                views.setTextViewText(R.id.prayer_name, nextPrayerName)
                views.setTextViewText(R.id.countdown_short, countdownText)

                // 3. الضغط لفتح التطبيق
                val intent = Intent(context, MainActivity::class.java)
                val pendingIntent = PendingIntent.getActivity(
                    context, 0, intent, 
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

            } catch (e: Exception) {
                Log.e("ZadWidget", "Critical error in Plan C update", e)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
        scheduleNextUpdate(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_UPDATE_COUNTDOWN || intent.action == Intent.ACTION_TIME_TICK) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, PrayerWidget::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            for (appWidgetId in appWidgetIds) {
                updateAppWidget(context, appWidgetManager, appWidgetId)
            }
            if (intent.action == ACTION_UPDATE_COUNTDOWN) {
                scheduleNextUpdate(context)
            }
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        scheduleNextUpdate(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        cancelUpdate(context)
    }

    private fun scheduleNextUpdate(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, PrayerWidget::class.java).apply {
            action = ACTION_UPDATE_COUNTDOWN
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, 0, intent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val calendar = Calendar.getInstance()
        calendar.add(Calendar.MINUTE, 1)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (alarmManager.canScheduleExactAlarms()) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, calendar.timeInMillis, pendingIntent)
            } else {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, calendar.timeInMillis, pendingIntent)
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, calendar.timeInMillis, pendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, calendar.timeInMillis, pendingIntent)
        }
    }

    private fun cancelUpdate(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, PrayerWidget::class.java).apply {
            action = ACTION_UPDATE_COUNTDOWN
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, 0, intent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
    }
}
