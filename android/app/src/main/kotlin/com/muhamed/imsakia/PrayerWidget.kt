package com.muhamed.imsakia

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.appwidget.AppWidgetProvider

class PrayerWidget : AppWidgetProvider() {

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
            
            
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val widgetData = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val views = RemoteViews(context.packageName, R.layout.prayer_widget)
        
        // 1. Offline First: Read cached data immediately
        val hijri = widgetData.getString("flutter.hijri_date_full", "-- رمضان ١٤٤٧")
        val pastDisplay = widgetData.getString("flutter.last_prayer_display", "--:--")
        var nextDisplay = widgetData.getString("flutter.next_prayer_display", "--:--") ?: "--:--"
        var nextTimestamp = widgetData.getLong("flutter.next_prayer_timestamp", 0L)

        // Immediately show cached text to avoid "Updating..." hang
        views.setTextViewText(R.id.hijri_date, hijri)
        views.setTextViewText(R.id.past_prayer_display, pastDisplay)

        // 2. Midnight Guard & Hijri Adjustment
        val calendar = java.util.Calendar.getInstance()
        val hour = calendar.get(java.util.Calendar.HOUR_OF_DAY)
        
        var displayHijri = hijri
        // وإذا كانت الساعة الحالية تجاوزت 00:00 (منتصف الليل) ولم يتم تحديث التاريخ الهجري بعد
        if (hour in 0..4) { // Window: Midnight until Fajr (approx)
            displayHijri = adjustHijriDateManually(hijri ?: "")
        }
        views.setTextViewText(R.id.hijri_date, displayHijri)

        // 3. Smart Countdown Self-Healing
        val now = System.currentTimeMillis()
        if (nextTimestamp <= now) {
            val refreshed = forceRefreshFromLocalDatabase(context, views, widgetData)
            if (refreshed != null) {
                nextTimestamp = refreshed["timestamp"] as Long
                nextDisplay = refreshed["display"] as String
            }
        } else {
            // إذا كانت الصلاة القادمة صحيحة، نتأكد برضه من الربط الصارم للسابقة
            val nextName = widgetData.getString("flutter.next_prayer_name", "") ?: ""
            if (nextName.isNotEmpty()) {
                val manualPastName = getManualPastPrayer(nextName)
                val localPast = findLastPrayerByName(context, manualPastName)
                if (localPast != null) {
                    views.setTextViewText(R.id.past_prayer_display, localPast["display"] as String)
                }
            }
        }
        
        views.setTextViewText(R.id.next_prayer_display, nextDisplay)

        if (nextTimestamp > now) {
            val remainingMs = nextTimestamp - now
            val baseTime = android.os.SystemClock.elapsedRealtime() + remainingMs

            // Update Chronometer (countdown mode)
            views.setChronometer(R.id.countdown_text, baseTime, null, true)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                views.setChronometerCountDown(R.id.countdown_text, true)
            }

            // ✅ Schedule Reliable NEXT Alarm (StabilityChain) — carries scheduledTime for stale guard
            scheduleExactAlarm(context, nextTimestamp, appWidgetIds)
        } else {
            // ════════════════════════════════════════════════════════════════
            // ⛔ ZERO-TOLERANCE UI: منع مطلق لأي عد سالب في الويدجت.
            // بمجرد أن يصل الوقت المتبقي إلى 0 أو أقل:
            //   1. أوقف الـ Chronometer فوراً.
            //   2. اعرض نصاً ثابتاً — يُمنع منعاً باتاً تمرير قيمة سالبة.
            //   حتى لو تأخر MIUI في إطلاق الـ Receiver بساعة كاملة.
            // ════════════════════════════════════════════════════════════════
            views.setChronometer(
                R.id.countdown_text,
                android.os.SystemClock.elapsedRealtime(), // base = now → لن يتحرك
                null,
                false // stopped = لا يعد
            )
            views.setTextViewText(R.id.countdown_text, "حان الصلاة")
            android.util.Log.d("ZadWidget", "⛔ ZERO-TOLERANCE: Chronometer stopped, showing 'حان الصلاة'")
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

    private fun forceRefreshFromLocalDatabase(context: Context, views: RemoteViews, widgetData: SharedPreferences): Map<String, Any>? {
        // البحث المحلي عن الصلاة التالية فوراً (Local Database / SharedPreferences)
        val localNext = findNextPrayerLocally(context)
        if (localNext != null) {
            val nextName = localNext["name"] as String
            
            // 🔥 تطبيق الربط الصارم للمسميات يدوياً
            val manualPastName = getManualPastPrayer(nextName)
            val localPast = findLastPrayerByName(context, manualPastName)
            
            if (localPast != null) {
                val pastDisplayLocal = localPast["display"] as String
                views.setTextViewText(R.id.past_prayer_display, pastDisplayLocal)
                widgetData.edit().putString("flutter.last_prayer_display", pastDisplayLocal).apply()
            }

            // Sync back to prevent repeated searching
            syncToHomeWidget(context, localNext)
            return localNext
        }
        return null
    }

    private fun findNextPrayerLocally(context: Context): Map<String, Any>? {
        val now = System.currentTimeMillis()
        val schedules = context.getSharedPreferences("athan_schedules", Context.MODE_PRIVATE)
        
        var earliestFutureTimestamp = Long.MAX_VALUE
        var foundData: String? = null

        // ✅ FIX: Collect expired entries to delete them — prevents negative widget countdown
        val expiredKeys = mutableListOf<String>()

        for (entry in schedules.all) {
            val key = entry.key
            if (key.endsWith("_data")) continue
            val timestamp = (entry.value as? Number)?.toLong() ?: continue

            if (timestamp > now && timestamp < earliestFutureTimestamp) {
                earliestFutureTimestamp = timestamp
                foundData = schedules.getString("${key}_data", null)
            } else if (timestamp <= now) {
                expiredKeys.add(key)
            }
        }

        // Delete all expired alarms in one batch
        if (expiredKeys.isNotEmpty()) {
            val editor = schedules.edit()
            for (key in expiredKeys) {
                editor.remove(key).remove("${key}_data")
            }
            editor.apply()
            android.util.Log.d("ZadWidget", "✅ Cleaned ${expiredKeys.size} expired alarm(s) from prefs")
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

    private fun findLastPrayerByName(context: Context, name: String): Map<String, Any>? {
        val schedules = context.getSharedPreferences("athan_schedules", Context.MODE_PRIVATE)
        
        var targetTimestamp = 0L
        
        for (entry in schedules.all) {
            val key = entry.key
            if (!key.endsWith("_data")) continue
            val data = entry.value as? String ?: continue
            if (data.startsWith(name)) {
                val baseKey = key.removeSuffix("_data")
                val timestamp = schedules.getLong(baseKey, 0L)
                // نأخذ أقرب توقيت مر بالفعل لهذه الصلاة
                if (timestamp <= System.currentTimeMillis() && timestamp > targetTimestamp) {
                    targetTimestamp = timestamp
                }
            }
        }
        
        return if (targetTimestamp > 0L) {
            mapOf(
                "timestamp" to targetTimestamp,
                "name" to name,
                "display" to "$name ${formatTime(targetTimestamp)}"
            )
        } else null
    }

    private fun getManualPastPrayer(nextName: String): String {
        return when (nextName) {
            "الفجر" -> "العشاء"
            "الشروق" -> "الفجر"
            "الظهر" -> "الشروق"
            "العصر" -> "الظهر"
            "المغرب" -> "العصر"
            "العشاء" -> "المغرب"
            else -> "المغرب"
        }
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
        // ✅ يحمل scheduled_time ليستخدمه AthanReceiver في Stale Guard
        val alarmIntent = Intent(context, PrayerWidget::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
            putExtra("scheduled_time", triggerTime)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            1001,
            alarmIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            // setAlarmClock هو الوحيد المضمون اختراق Doze/MIUI
            val activityIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
            val uiPendingIntent = PendingIntent.getActivity(
                context,
                2001,
                activityIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                val clockInfo = android.app.AlarmManager.AlarmClockInfo(triggerTime, uiPendingIntent)
                alarmManager.setAlarmClock(clockInfo, pendingIntent)
            } else if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
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

