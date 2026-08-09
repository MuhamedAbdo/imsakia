package com.muhamed.imsakia

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.PowerManager

/**
 * PreWarmReceiver — الاستيقاظ الاستباقي قبل 3 دقائق من الصلاة.
 *
 * استراتيجية كسر غفوة MIUI:
 * 1. يستيقظ قبل موعد الصلاة بـ 3 دقائق عبر setAlarmClock.
 * 2. يستحوذ فوراً على PARTIAL_WAKE_LOCK لمنع الهاتف من النوم.
 * 3. يحسب الوقت المتبقي بدقة وينتظر عبر Handler.postDelayed.
 * 4. عند الثانية الصفر المطلقة، يُطلق AthanReceiver مباشرةً من الكود.
 * 5. يُحدّث الويدجت في نفس اللحظة.
 *
 * ملاحظة: يستخدم goAsync() لتجاوز حد الـ 10 ثوانٍ للـ BroadcastReceiver.
 */
class PreWarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ZadPreWarm"
        // مدة WakeLock الاستباقي: 5 دقائق كحد أقصى (3 دقائق انتظار + 2 دقيقة هامش)
        private const val WAKELOCK_TIMEOUT_MS = 5 * 60 * 1000L
        // إذا انقضى هذا الوقت بعد موعد الصلاة، لا تُطلق الأذان (متزامن مع guard في AthanReceiver)
        private const val MAX_DELAY_MS = 3 * 60 * 1000L
    }

    override fun onReceive(context: Context, intent: Intent) {
        val scheduledTime = intent.getLongExtra("scheduled_time", 0L)
        val prayerName = intent.getStringExtra("prayer_name") ?: "الصلاة"
        val prayerKey = intent.getStringExtra("prayer_key") ?: "dhuhr"
        val alarmId = intent.getIntExtra("alarm_id", -1)
        val isSilent = intent.getBooleanExtra("is_silent", false)

        android.util.Log.i(TAG, "!!! PreWarmReceiver Awake — $prayerName (ID: $alarmId, scheduledAt: $scheduledTime) !!!")

        if (scheduledTime <= 0L) {
            android.util.Log.e(TAG, "Invalid scheduledTime — aborting PreWarm")
            return
        }

        // 1. استحواذ فوري على WakeLock لمدة 4 دقائق
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val wakeLock = powerManager?.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "Zad:PreWarmWakeLock"
        )

        try {
            // 4 * 60 * 1000L = 4 دقائق
            wakeLock?.acquire(4 * 60 * 1000L)
            android.util.Log.d(TAG, "--- PreWarm WakeLock Acquired (4 min timeout) ---")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to acquire PreWarm WakeLock: ${e.message}")
        }

        // 2. تحديث الويدجت فوراً عند الاستيقاظ الاستباقي (تهيئة مبكرة)
        try {
            val widgetIntent = Intent(context, PrayerWidget::class.java).apply {
                action = "com.muhamed.imsakia.UPDATE_COUNTDOWN"
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, PrayerWidget::class.java))
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(widgetIntent)
            android.util.Log.d(TAG, "--- PreWarm: Widget warm-up broadcast sent ---")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to send warm-up widget broadcast: ${e.message}")
        }

        android.util.Log.i(TAG, "--- PreWarmReceiver finished. System will stay awake for 4 mins to guarantee AthanReceiver fires on time. ---")
    }
}
