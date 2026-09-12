package com.muhamed.imsakia

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.appwidget.AppWidgetManager
import android.content.ComponentName

/**
 * Handles TIME_SET and TIMEZONE_CHANGED broadcasts.
 *
 * When the user changes the device time or timezone, existing AlarmManager alarms remain
 * scheduled at the old (now incorrect) absolute timestamp. This receiver reschedules them.
 * It delegates to BootReceiver which already contains the rescheduling logic.
 *
 * Separated from BootReceiver because:
 *  - BOOT_COMPLETED can be caught with directBootAware, but time changes are not boot events.
 *  - The logic is identical but the trigger conditions differ.
 */
class TimeChangeReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return

        if (action == Intent.ACTION_TIME_CHANGED || action == Intent.ACTION_TIMEZONE_CHANGED) {
            android.util.Log.i("ZadTimeChange", "!!! Time/Timezone Changed — Rescheduling alarms ($action) !!!")

            // Delegate to BootReceiver logic via a synthetic BOOT_COMPLETED intent
            val bootIntent = Intent(context, BootReceiver::class.java).apply {
                this.action = Intent.ACTION_BOOT_COMPLETED
            }
            val pendingResult = goAsync()
            Thread {
                try {
                    // Inline the same rescheduling that BootReceiver would do
                    BootReceiver().onReceive(context, bootIntent)
                } finally {
                    pendingResult.finish()
                }
            }.start()

            // Also force-refresh both widgets immediately
            try {
                val appWidgetManager = AppWidgetManager.getInstance(context)

                val prayerIds = appWidgetManager.getAppWidgetIds(ComponentName(context, PrayerWidget::class.java))
                if (prayerIds.isNotEmpty()) {
                    val widgetIntent = Intent(context, PrayerWidget::class.java).apply {
                        this.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, prayerIds)
                    }
                    context.sendBroadcast(widgetIntent)
                }

                val nextIds = appWidgetManager.getAppWidgetIds(ComponentName(context, NextPrayerWidget::class.java))
                if (nextIds.isNotEmpty()) {
                    val nextIntent = Intent(context, NextPrayerWidget::class.java).apply {
                        this.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, nextIds)
                    }
                    context.sendBroadcast(nextIntent)
                }
            } catch (e: Exception) {
                android.util.Log.e("ZadTimeChange", "Failed to refresh widgets: ${e.message}")
            }
        }
    }
}
