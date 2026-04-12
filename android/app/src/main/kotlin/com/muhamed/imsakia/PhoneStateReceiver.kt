package com.muhamed.imsakia

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager
import android.appwidget.AppWidgetManager
import android.content.ComponentName

class PhoneStateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == TelephonyManager.ACTION_PHONE_STATE_CHANGED) {
            val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
            if (state == TelephonyManager.EXTRA_STATE_IDLE) {
                // Refresh Widget after call ends
                val widgetIntent = Intent(context, PrayerWidget::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                }
                val ids = AppWidgetManager.getInstance(context)
                    .getAppWidgetIds(ComponentName(context, PrayerWidget::class.java))
                widgetIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                context.sendBroadcast(widgetIntent)
            }
        }
    }
}
