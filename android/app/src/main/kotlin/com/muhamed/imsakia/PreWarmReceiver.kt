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

        // 1. استحواذ فوري على WakeLock قبل أي شيء آخر
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val wakeLock = powerManager?.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "Zad:PreWarmWakeLock"
        )

        try {
            wakeLock?.acquire(WAKELOCK_TIMEOUT_MS)
            android.util.Log.d(TAG, "--- PreWarm WakeLock Acquired (5 min max) ---")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to acquire PreWarm WakeLock: ${e.message}")
        }

        // 2. استخدام goAsync() لتجاوز حد الـ 10 ثوانٍ
        val pendingResult = goAsync()

        val now = System.currentTimeMillis()
        val delayUntilPrayer = scheduledTime - now

        android.util.Log.d(TAG, "--- Time until prayer: ${delayUntilPrayer}ms (${delayUntilPrayer / 1000}s) ---")

        // 3. التحقق: هل فات موعد الصلاة بأكثر من الحد المسموح؟
        if (delayUntilPrayer < -MAX_DELAY_MS) {
            android.util.Log.w(TAG, "!!! PreWarm: Prayer time is too stale (${-delayUntilPrayer}ms late) — Aborting !!!")
            try { wakeLock?.release() } catch (e: Exception) {}
            pendingResult.finish()
            return
        }

        // 4. تحديث الويدجت فوراً عند الاستيقاظ الاستباقي (تهيئة مبكرة)
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

        // 5. الانتظار الدقيق حتى الثانية الصفر المطلقة
        val waitMs = if (delayUntilPrayer > 0L) delayUntilPrayer else 0L

        android.util.Log.i(TAG, "--- PreWarm: Waiting ${waitMs}ms until exact prayer zero-second ---")

        Handler(Looper.getMainLooper()).postDelayed({
            try {
                val fireTime = System.currentTimeMillis()
                val actualDelay = fireTime - scheduledTime
                android.util.Log.i(TAG, "!!! PreWarm FIRING AthanReceiver — actual delay: ${actualDelay}ms !!!")

                // 6. إطلاق AthanReceiver مباشرةً من الكود (لا عبر النظام)
                val athanIntent = Intent(context, AthanReceiver::class.java).apply {
                    putExtra("prayer_name", prayerName)
                    putExtra("prayer_key", prayerKey)
                    putExtra("alarm_id", alarmId)
                    putExtra("is_silent", isSilent)
                    putExtra("scheduled_time", scheduledTime)
                    putExtra("fired_from_prewarm", true) // علامة لمنع الـ double-firing
                }
                context.sendBroadcast(athanIntent)
                android.util.Log.i(TAG, "--- PreWarm: AthanReceiver broadcast delivered ---")

            } catch (e: Exception) {
                android.util.Log.e(TAG, "PreWarm fire error: ${e.message}")
            } finally {
                // 7. تحرير WakeLock — سيتم الاستحواذ عليه من جديد داخل AthanReceiver
                try { wakeLock?.release() } catch (e: Exception) {}
                pendingResult.finish()
                android.util.Log.d(TAG, "--- PreWarm: WakeLock released, pendingResult finished ---")
            }
        }, waitMs)
    }
}
