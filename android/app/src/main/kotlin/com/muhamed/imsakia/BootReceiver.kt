package com.muhamed.imsakia

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.appwidget.AppWidgetManager
import android.content.ComponentName

class BootReceiver : BroadcastReceiver() {
    private val PREFS_NAME = "athan_schedules"

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED) {

            // ACTION_BOOT_COMPLETED and ACTION_MY_PACKAGE_REPLACED both clear AlarmManager alarms,
            // so we must reschedule everything.
            val pendingResult = goAsync()
            Thread {
                try {
                    rescheduleAlarms(context)
                } finally {
                    pendingResult.finish()
                }
            }.start()
        }
    }

    private fun rescheduleAlarms(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val allSchedules = prefs.all
        val currentTime = System.currentTimeMillis()

        android.util.Log.i("ZadBoot", "!!! Starting Athan Rescheduling (Total items: ${allSchedules.size}) !!!")

        for ((idStr, timeObj) in allSchedules) {
            // Ignore metadata keys (suffixed with _data)
            if (idStr.endsWith("_data")) continue

            val id = idStr.toIntOrNull() ?: continue
            val timeInMillis = timeObj as? Long ?: continue

            // Read metadata
            val metadata = prefs.getString("${id}_data", "") ?: ""
            val parts = metadata.split("|")

            val prayerName = if (parts.size >= 1) parts[0] else "الصلاة"
            val prayerKey = if (parts.size >= 2) parts[1] else "dhuhr"
            val isSilent = if (parts.size >= 3) parts[2].toBoolean() else false

            if (timeInMillis > currentTime) {
                android.util.Log.d("ZadBoot", ">>> Rescheduling ID=$id: $prayerName at $timeInMillis (Silent=$isSilent)")

                // AthanReceiver Broadcast Intent
                // carries scheduled_time for the stale guard in AthanReceiver
                val broadcastIntent = Intent(context, AthanReceiver::class.java).apply {
                    action = "com.muhamed.imsakia.ATHAN_ALARM"
                    putExtra("prayer_name", prayerName)
                    putExtra("prayer_key", prayerKey)
                    putExtra("alarm_id", id)
                    putExtra("is_silent", isSilent)
                    putExtra("scheduled_time", timeInMillis)
                }

                val alarmPendingIntent = PendingIntent.getBroadcast(
                    context,
                    id,
                    broadcastIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                // Activity Intent for System Clock Icon
                val activityIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                }
                val uiPendingIntent = PendingIntent.getActivity(
                    context,
                    id + 500,
                    activityIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                // setAlarmClock is the strongest guarantee that penetrates Doze + OEM restrictions
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    val clockInfo = AlarmManager.AlarmClockInfo(timeInMillis, uiPendingIntent)
                    alarmManager.setAlarmClock(clockInfo, alarmPendingIntent)
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, timeInMillis, alarmPendingIntent)
                }

                android.util.Log.d("ZadBoot", ">>> Rescheduled athan alarm ID=$id for $prayerName")

            } else {
                // Cleanup past alarms
                android.util.Log.d("ZadBoot", "--- Cleaning up expired alarm ID=$id")
                prefs.edit().remove(idStr).remove("${id}_data").commit()
            }
        }

        // Schedule Midnight Rollover Alarm
        MidnightReceiver.scheduleMidnightAlarm(context)

        // Force widget updates to reflect new schedule
        try {
            val widgetIntent = Intent(context, PrayerWidget::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, PrayerWidget::class.java))
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(widgetIntent)
            android.util.Log.i("ZadBoot", "--- PrayerWidget Update Broadcast Sent ---")
        } catch (e: Exception) {
            android.util.Log.e("ZadBoot", "Failed to force PrayerWidget update: ${e.message}")
        }

        try {
            val nextWidgetIntent = Intent(context, NextPrayerWidget::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, NextPrayerWidget::class.java))
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(nextWidgetIntent)
            android.util.Log.i("ZadBoot", "--- NextPrayerWidget Update Broadcast Sent ---")
        } catch (e: Exception) {
            android.util.Log.e("ZadBoot", "Failed to force NextPrayerWidget update: ${e.message}")
        }

        android.util.Log.i("ZadBoot", "!!! Athan Rescheduling Completed !!!")
    }
}
