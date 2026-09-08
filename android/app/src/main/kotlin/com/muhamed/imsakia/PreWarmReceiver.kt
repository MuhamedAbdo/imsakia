package com.muhamed.imsakia

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import androidx.core.content.ContextCompat

class PreWarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ZadPreWarm"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val scheduledTime = intent.getLongExtra("scheduled_time", 0L)
        val prayerName = intent.getStringExtra("prayer_name") ?: "الصلاة"
        val alarmId = intent.getIntExtra("alarm_id", -1)

        android.util.Log.i(TAG, "!!! PreWarmReceiver Awake — $prayerName (ID: $alarmId, scheduledAt: $scheduledTime) !!!")

        if (scheduledTime <= 0L) {
            android.util.Log.e(TAG, "Invalid scheduledTime — aborting PreWarm")
            return
        }

        // 1. Acquire WakeLock for 4 minutes (enough to cover the 1-min gap until the real Athan alarm)
        // ✅ FIX: Previous value was 5000ms (5s) — MIUI was putting CPU back to sleep before the alarm fired,
        // causing 15+ minute delays. Now we hold the lock for the full pre-warm window.
        try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "Zad:PreWarmWakeLock"
            )
            wakeLock.acquire(240_000L) // 4 minutes — covers the 1-min PreWarm gap + buffer
            android.util.Log.i(TAG, "--- PreWarm: WakeLock acquired for 4 minutes ---")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to acquire PreWarm WakeLock: ${e.message}")
        }

        // 2. تحديث الويدجت مبكراً
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
    }
}
