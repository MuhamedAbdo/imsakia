package com.muhamed.imsakia

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.appwidget.AppWidgetManager
import android.content.ComponentName

/**
 * ═══════════════════════════════════════════════════════════
 * AlarmRescheduler — المحرك المركزي لإعادة جدولة الأذان
 * ═══════════════════════════════════════════════════════════
 *
 * يُشغَّل من:
 *  1. MainApplication.onCreate()     → عند كل استيقاظ للعملية
 *  2. BootReceiver                   → بعد BOOT / MY_PACKAGE_REPLACED
 *  3. SwipeDismissGuardService       → فور onTaskRemoved()
 *  4. ExactAlarmPermissionReceiver   → عند تغيير الصلاحية (Android 12+)
 *  5. TimeChangeReceiver             → عند تغيير الوقت/المنطقة
 *
 * المبدأ: "أعد التسجيل دائماً" — إعادة تسجيل نفس المنبه عبر
 * FLAG_UPDATE_CURRENT آمنة تماماً ولا تُطلق المنبه مرتين.
 */
object AlarmRescheduler {

    private const val TAG = "ZadRescheduler"
    private const val PREFS_SCHEDULES = "athan_schedules"

    /**
     * نقطة الدخول الرئيسية.
     * يقرأ جميع المنبهات المستقبلية من SharedPreferences ويُعيد تسجيلها.
     * المنبهات المنتهية يُنظَّف منها الـ Prefs تلقائياً.
     *
     * @param context أي Context — لا يحتاج Activity
     * @param reason  نص يظهر في الـ Log لتتبع مَن استدعى الدالة
     */
    fun rescheduleAll(context: Context, reason: String = "unknown") {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val prefs = context.getSharedPreferences(PREFS_SCHEDULES, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()

        android.util.Log.i(TAG, "═══ rescheduleAll() TRIGGERED [$reason] ═══")

        val allEntries = prefs.all.toMap() // snapshot لمنع ConcurrentModification
        var rescheduled = 0
        var cleaned = 0
        val editor = prefs.edit()

        for ((idStr, timeObj) in allEntries) {
            // تجاهل مفاتيح الـ metadata (تنتهي بـ _data)
            if (idStr.endsWith("_data")) continue

            val id = idStr.toIntOrNull() ?: continue
            val timeInMillis = timeObj as? Long ?: continue

            if (timeInMillis > now) {
                // ─── منبه مستقبلي → أعد تسجيله (Overwrite آمن) ───
                val metadata = prefs.getString("${id}_data", "") ?: ""
                val parts = metadata.split("|")
                val prayerName = parts.getOrElse(0) { "الصلاة" }
                val prayerKey  = parts.getOrElse(1) { "dhuhr" }
                val isSilent   = parts.getOrElse(2) { "false" }.toBoolean()

                registerAlarm(context, alarmManager, id, timeInMillis, prayerName, prayerKey, isSilent)
                rescheduled++

                android.util.Log.d(
                    TAG,
                    "  ✅ Rescheduled ID=$id | $prayerName | in ${(timeInMillis - now) / 60_000} min"
                )
            } else {
                // ─── منبه منتهٍ → نظّف من الـ Prefs ───
                editor.remove(idStr).remove("${id}_data")
                cleaned++
                android.util.Log.d(TAG, "  🗑️  Cleaned expired ID=$id")
            }
        }

        editor.apply()

        // ─── إعادة جدولة المنبه الليلي للتحديث عند منتصف الليل ───
        MidnightReceiver.scheduleMidnightAlarm(context)

        // ─── تحديث فوري للويدجات ───
        refreshWidgets(context)

        android.util.Log.i(
            TAG,
            "═══ Done: rescheduled=$rescheduled, cleaned=$cleaned [$reason] ═══"
        )
    }

    // ─────────────────────────────────────────────────────────
    // الدوال الخاصة
    // ─────────────────────────────────────────────────────────

    private fun registerAlarm(
        context: Context,
        alarmManager: AlarmManager,
        id: Int,
        timeInMillis: Long,
        prayerName: String,
        prayerKey: String,
        isSilent: Boolean,
    ) {
        // Intent يُرسَل لـ AthanReceiver عند انطلاق المنبه
        val broadcastIntent = Intent(context, AthanReceiver::class.java).apply {
            action = "com.muhamed.imsakia.ATHAN_ALARM"
            putExtra("prayer_name", prayerName)
            putExtra("prayer_key", prayerKey)
            putExtra("alarm_id", id)
            putExtra("is_silent", isSilent)
            putExtra("scheduled_time", timeInMillis)
        }

        // FLAG_UPDATE_CURRENT → يستبدل المنبه القديم بنفس الـ requestCode بأمان
        val alarmPendingIntent = PendingIntent.getBroadcast(
            context,
            id,
            broadcastIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Intent لأيقونة الساعة في شريط الحالة
        val activityIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val uiPendingIntent = PendingIntent.getActivity(
            context,
            id + 500,
            activityIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // setAlarmClock هو الأقوى: يخترق Doze وقيود OEM
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val clockInfo = AlarmManager.AlarmClockInfo(timeInMillis, uiPendingIntent)
            alarmManager.setAlarmClock(clockInfo, alarmPendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, timeInMillis, alarmPendingIntent)
        }
    }

    private fun refreshWidgets(context: Context) {
        try {
            val appWidgetManager = AppWidgetManager.getInstance(context)

            val prayerIds = appWidgetManager.getAppWidgetIds(
                ComponentName(context, PrayerWidget::class.java)
            )
            if (prayerIds.isNotEmpty()) {
                val intent = Intent(context, PrayerWidget::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, prayerIds)
                }
                context.sendBroadcast(intent)
            }

            val nextIds = appWidgetManager.getAppWidgetIds(
                ComponentName(context, NextPrayerWidget::class.java)
            )
            if (nextIds.isNotEmpty()) {
                val intent = Intent(context, NextPrayerWidget::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, nextIds)
                }
                context.sendBroadcast(intent)
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "refreshWidgets failed: ${e.message}")
        }
    }
}
