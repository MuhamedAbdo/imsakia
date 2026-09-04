package com.muhamed.imsakia

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

class PreWarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ZadPreWarm"
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

        // 1. تحديث الويدجت مبكراً
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

        // 2. إطلاق AthanService كخدمة Foreground Service في وضع PreWarm
        try {
            val serviceIntent = Intent(context, AthanService::class.java).apply {
                putExtra("prayer_name", prayerName)
                putExtra("prayer_key", prayerKey)
                putExtra("alarm_id", alarmId)
                putExtra("is_silent", isSilent)
                putExtra("scheduled_time", scheduledTime)
                putExtra("is_prewarm", true)
            }
            ContextCompat.startForegroundService(context, serviceIntent)
            android.util.Log.i(TAG, "--- PreWarm: Launched AthanService as Foreground Service ---")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to launch AthanService in PreWarm: ${e.message}")
        }
    }
}
