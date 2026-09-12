package com.muhamed.imsakia

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.widget.RemoteViews

/**
 * NextPrayerWidget — compact 1×1 home screen widget.
 *
 * Shows the name of the upcoming prayer and a live countdown chronometer.
 * Data is read from SharedPreferences that Flutter (via home_widget plugin)
 * writes whenever prayer times are recalculated.
 *
 * Design based on Al-Azan's NextPrayerWidget / renderNextPrayer:
 *  - countdownBaseMillis = prayerTimeMs (always a future timestamp when set correctly)
 *  - Widget is self-scheduling: it sets an exact alarm at `nextTimestamp + 1s`
 *    so it rebuilds the moment the prayer transitions, preventing negative countdown.
 */
class NextPrayerWidget : AppWidgetProvider() {

    companion object {
        /** Request code for the self-scheduling redraw alarm. Distinct from PrayerWidget (1001). */
        private const val REDRAW_REQUEST_CODE = 1002
        /** Action for the self-scheduled redraw. */
        const val ACTION_REDRAW = "com.muhamed.imsakia.NEXT_PRAYER_WIDGET_REDRAW"

        fun updateAll(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, NextPrayerWidget::class.java))
            if (ids.isNotEmpty()) {
                val provider = NextPrayerWidget()
                provider.onUpdate(context, appWidgetManager, ids)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        if (intent.action == ACTION_REDRAW) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, NextPrayerWidget::class.java))
            if (ids.isNotEmpty()) {
                onUpdate(context, appWidgetManager, ids)
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

        val nextName = prefs.getString("flutter.next_prayer_name", null)
        val nextTimestamp = prefs.getLong("flutter.next_prayer_timestamp", 0L)
        val now = System.currentTimeMillis()

        for (widgetId in appWidgetIds) {
            val views = buildViews(context, nextName, nextTimestamp, now)
            appWidgetManager.updateAppWidget(widgetId, views)
        }

        // Self-schedule: redraw precisely when the next prayer transitions
        if (nextTimestamp > now) {
            scheduleRedraw(context, nextTimestamp + 1_000L)
        }
    }

    private fun buildViews(
        context: Context,
        nextName: String?,
        nextTimestamp: Long,
        now: Long,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.next_prayer_widget)

        // Prayer name
        val displayName = nextName ?: "--"
        views.setTextViewText(R.id.next_prayer_name, displayName)

        if (nextTimestamp > now) {
            // Safe countdown: countdownBase is a future value, so the chronometer counts down positively
            val countdownBase = SystemClock.elapsedRealtime() + (nextTimestamp - now)
            views.setChronometer(R.id.next_prayer_countdown, countdownBase, "%s", true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                views.setChronometerCountDown(R.id.next_prayer_countdown, true)
            }
        } else {
            // Timestamp is in the past or zero — stop the chronometer to prevent negative display
            views.setChronometer(R.id.next_prayer_countdown, SystemClock.elapsedRealtime(), "%s", false)
            views.setTextViewText(R.id.next_prayer_countdown, "--:--")
            android.util.Log.d("ZadNextWidget", "No future prayer — chronometer stopped")
        }

        // Tap to open app
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            REDRAW_REQUEST_CODE + 100,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.next_prayer_widget_layout, pendingIntent)

        return views
    }

    /**
     * Schedules a one-shot exact alarm at [triggerAtMs] to redraw the widget.
     * Uses setAlarmClock to guarantee delivery through Doze and OEM restrictions.
     */
    private fun scheduleRedraw(context: Context, triggerAtMs: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager

        val intent = Intent(context, NextPrayerWidget::class.java).apply {
            action = ACTION_REDRAW
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            REDRAW_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val uiIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val uiPendingIntent = PendingIntent.getActivity(
            context,
            REDRAW_REQUEST_CODE + 200,
            uiIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val clockInfo = android.app.AlarmManager.AlarmClockInfo(triggerAtMs, uiPendingIntent)
            alarmManager.setAlarmClock(clockInfo, pendingIntent)
        } else {
            alarmManager.setExact(android.app.AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
        }

        android.util.Log.d("ZadNextWidget", "Redraw alarm scheduled at $triggerAtMs")
    }

    override fun onDisabled(context: Context) {
        // Cancel the redraw alarm when the last widget instance is removed
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            val intent = Intent(context, NextPrayerWidget::class.java).apply {
                action = ACTION_REDRAW
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                REDRAW_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            )
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
            }
        } catch (e: Exception) {
            android.util.Log.e("ZadNextWidget", "Failed to cancel redraw alarm: ${e.message}")
        }
    }
}
