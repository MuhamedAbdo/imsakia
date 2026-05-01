package com.muhamed.imsakia

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.Toast
import android.appwidget.AppWidgetManager
import android.content.ComponentName

class BootReceiver : BroadcastReceiver() {
    private val PREFS_NAME = "athan_schedules"

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action == Intent.ACTION_BOOT_COMPLETED || 
            action == Intent.ACTION_TIME_CHANGED || 
            action == Intent.ACTION_TIMEZONE_CHANGED) {
            
            // 1. Show Toast immediately to confirm wake up
            try {
                Toast.makeText(context, "زاد: تم تنشيط نظام الأذان", Toast.LENGTH_LONG).show()
            } catch (e: Exception) {}

            // 2. Use goAsync for background processing
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
                
                // 1. AthanReceiver Broadcast Intent
                val broadcastIntent = Intent(context, AthanReceiver::class.java).apply {
                    putExtra("prayer_name", prayerName)
                    putExtra("prayer_key", prayerKey)
                    putExtra("alarm_id", id)
                    putExtra("is_silent", isSilent)
                }
                
                val alarmPendingIntent = PendingIntent.getBroadcast(
                    context, 
                    id, 
                    broadcastIntent, 
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                // 2. Activity Intent for System Clock Icon
                val activityIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                }
                val uiPendingIntent = PendingIntent.getActivity(
                    context, 
                    id + 500, 
                    activityIntent, 
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                if (!isSilent) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        val clockInfo = AlarmManager.AlarmClockInfo(timeInMillis, uiPendingIntent)
                        alarmManager.setAlarmClock(clockInfo, alarmPendingIntent)
                    } else {
                        alarmManager.setExact(AlarmManager.RTC_WAKEUP, timeInMillis, alarmPendingIntent)
                    }
                } else {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeInMillis, alarmPendingIntent)
                    } else {
                        alarmManager.setExact(AlarmManager.RTC_WAKEUP, timeInMillis, alarmPendingIntent)
                    }
                }
            } else {
                // Cleanup past alarms
                android.util.Log.d("ZadBoot", "--- Cleaning up expired alarm ID=$id")
                prefs.edit().remove(idStr).remove("${id}_data").commit()
            }
        }

        // 3. Force widget update to clear 00:00
        try {
            val widgetIntent = Intent(context, PrayerWidget::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, PrayerWidget::class.java))
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(widgetIntent)
            android.util.Log.i("ZadBoot", "--- Widget Update Broadcast Sent ---")
        } catch (e: Exception) {
            android.util.Log.e("ZadBoot", "Failed to force widget update: ${e.message}")
        }

        android.util.Log.i("ZadBoot", "!!! Athan Rescheduling Completed !!!")
    }
}
