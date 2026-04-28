package com.muhamed.imsakia

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.util.Log

class PhoneStateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == TelephonyManager.ACTION_PHONE_STATE_CHANGED) {
            try {
                val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
                
                // Stop Athan immediately if ringing or offhook
                if (state == TelephonyManager.EXTRA_STATE_RINGING || state == TelephonyManager.EXTRA_STATE_OFFHOOK) {
                    Log.d("ImsakiaNative", "!!! PhoneStateReceiver: Call state is $state, stopping Athan !!!")
                    val stopIntent = Intent(context, AthanService::class.java).apply {
                        action = "com.muhamed.imsakia.STOP_ATHAN"
                    }
                    context.startService(stopIntent)
                }
                
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
            } catch (e: SecurityException) {
                // Graceful degradation: If READ_PHONE_STATE permission is missing on Android 12+
                Log.w("ImsakiaNative", "PhoneStateReceiver: Missing READ_PHONE_STATE permission, cannot read call state.")
            } catch (e: Exception) {
                Log.e("ImsakiaNative", "PhoneStateReceiver: Error processing phone state", e)
            }
        }
    }
}
