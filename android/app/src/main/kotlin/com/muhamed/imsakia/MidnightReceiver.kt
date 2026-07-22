package com.muhamed.imsakia

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager

class MidnightReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        android.util.Log.i("ZadMidnight", "!!! MidnightReceiver Triggered at 00:01 !!!")

        // 1. Acquire WakeLock to ensure Doze Mode breakthrough during rollover
        try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "Zad:MidnightWakeLock"
            )
            wakeLock.acquire(15000) // 15 seconds max
            android.util.Log.d("ZadMidnight", "--- WakeLock Acquired ---")
        } catch (e: Exception) {
            android.util.Log.e("ZadMidnight", "Failed to acquire WakeLock: ${e.message}")
        }

        // 2. Perform Hijri & Day Name Rollover directly inside SharedPreferences
        try {
            val widgetData = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val currentHijri = widgetData.getString("flutter.hijri_date_full", "") ?: ""
            
            if (currentHijri.isNotEmpty()) {
                val updatedHijri = adjustHijriDateManually(currentHijri)
                widgetData.edit().putString("flutter.hijri_date_full", updatedHijri).apply()
                android.util.Log.i("ZadMidnight", "Rolled over Hijri date: $currentHijri -> $updatedHijri")
            }
        } catch (e: Exception) {
            android.util.Log.e("ZadMidnight", "Failed to update Hijri date in prefs: ${e.message}")
        }

        // 3. Broadcast immediate update to PrayerWidget
        try {
            val widgetIntent = Intent(context, PrayerWidget::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, PrayerWidget::class.java))
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(widgetIntent)
            android.util.Log.d("ZadMidnight", "--- Widget Update Broadcast Sent ---")
        } catch (e: Exception) {
            android.util.Log.e("ZadMidnight", "Failed to send widget update broadcast: ${e.message}")
        }

        // 4. Reschedule for next midnight (00:01)
        scheduleMidnightAlarm(context)
    }

    private fun adjustHijriDateManually(fullDate: String): String {
        val daysOfWeek = listOf("الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت", "الإثنين")
        val nextDays = listOf("الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت", "الأحد", "الثلاثاء")
        var updatedDate = fullDate

        // 1. تحديث اسم اليوم (مثلاً: الأربعاء -> الخميس)
        for (i in daysOfWeek.indices) {
            if (fullDate.contains(daysOfWeek[i])) {
                updatedDate = updatedDate.replace(daysOfWeek[i], nextDays[i])
                break
            }
        }

        // 2. زيادة رقم اليوم (مثلاً: ٢٧ -> ٢٨)
        val arabicDigits = "٠١٢٣٤٥٦٧٨٩"
        val regex = Regex("[0-9٠-٩]+")
        val match = regex.find(updatedDate) ?: return updatedDate
        
        val originalNumStr = match.value
        val isArabic = originalNumStr.any { it in arabicDigits }
        
        val standardNumStr = if (isArabic) {
            originalNumStr.map { char ->
                val idx = arabicDigits.indexOf(char)
                if (idx != -1) '0' + idx else char
            }.joinToString("")
        } else {
            originalNumStr
        }
        
        val incrementedInt = standardNumStr.toIntOrNull()?.plus(1) ?: return updatedDate
        var incrementedStr = incrementedInt.toString()
        
        if (isArabic) {
            incrementedStr = incrementedStr.map { char ->
                if (char in '0'..'9') arabicDigits[char - '0'] else char
            }.joinToString("")
        }
        
        return updatedDate.replaceFirst(originalNumStr, incrementedStr)
    }

    companion object {
        fun scheduleMidnightAlarm(context: Context) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val intent = Intent(context, MidnightReceiver::class.java).apply {
                    action = "com.muhamed.imsakia.MIDNIGHT_ROLLOVER"
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    1002,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                val calendar = java.util.Calendar.getInstance().apply {
                    set(java.util.Calendar.HOUR_OF_DAY, 0)
                    set(java.util.Calendar.MINUTE, 1)
                    set(java.util.Calendar.SECOND, 0)
                    set(java.util.Calendar.MILLISECOND, 0)
                }
                if (calendar.timeInMillis <= System.currentTimeMillis()) {
                    calendar.add(java.util.Calendar.DAY_OF_YEAR, 1)
                }
                val finalTriggerTime = calendar.timeInMillis

                val activityIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                }
                val uiPendingIntent = PendingIntent.getActivity(
                    context,
                    1502,
                    activityIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    val clockInfo = AlarmManager.AlarmClockInfo(finalTriggerTime, uiPendingIntent)
                    alarmManager.setAlarmClock(clockInfo, pendingIntent)
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, finalTriggerTime, pendingIntent)
                }
                android.util.Log.i("ZadMidnight", "!!! Midnight Rollover Alarm Scheduled for ${java.util.Date(finalTriggerTime)} !!!")
            } catch (e: Exception) {
                android.util.Log.e("ZadMidnight", "Failed to schedule midnight alarm: ${e.message}")
            }
        }
    }
}
