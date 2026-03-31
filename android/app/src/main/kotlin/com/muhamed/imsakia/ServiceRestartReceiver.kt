package com.muhamed.imsakia

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * ServiceRestartReceiver
 *
 * يُستدعى من onTaskRemoved() داخل ZadWatchdogService بعد تأخير 1.5 ثانية
 * عبر AlarmManager (setExactAndAllowWhileIdle) ليضمن النجاة من Doze Mode.
 *
 * مهمته: إعادة تشغيل ZadWatchdogService + إطلاق FlutterBackgroundService.
 */
class ServiceRestartReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ServiceRestartReceiver"
        const val ACTION_RESTART = "com.muhamed.imsakia.RESTART_SERVICE"

        /**
         * جدوِل إعادة تشغيل الخدمات بعد تأخير معطى (افتراضي 1500ms).
         * يستخدم setExactAndAllowWhileIdle لضمان التشغيل حتى في Doze Mode.
         */
        fun schedule(context: Context, delayMs: Long = 1500L) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

                // Android 12+: تحقق من إذن الـ Exact Alarm قبل الجدولة
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    if (!alarmManager.canScheduleExactAlarms()) {
                        Log.w(TAG, "[WATCHDOG] Exact alarm permission not granted — falling back to inexact restart.")
                        scheduleInexact(context, delayMs)
                        return
                    }
                }

                val intent = Intent(context, ServiceRestartReceiver::class.java).apply {
                    action = ACTION_RESTART
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    9999,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                val triggerAt = System.currentTimeMillis() + delayMs

                // setExactAndAllowWhileIdle: يعمل حتى في Doze بعد Clear All
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAt,
                    pendingIntent
                )

                Log.i(TAG, "[WATCHDOG] Restart scheduled in ${delayMs}ms via setExactAndAllowWhileIdle.")
            } catch (e: Exception) {
                Log.e(TAG, "[WATCHDOG] Failed to schedule restart: ${e.message}")
            }
        }

        /** Fallback لأجهزة Android 11 وما دون أو عند عدم وجود الإذن */
        private fun scheduleInexact(context: Context, delayMs: Long) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val intent = Intent(context, ServiceRestartReceiver::class.java).apply {
                    action = ACTION_RESTART
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    9999,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        System.currentTimeMillis() + delayMs,
                        pendingIntent
                    )
                } else {
                    alarmManager.set(
                        AlarmManager.RTC_WAKEUP,
                        System.currentTimeMillis() + delayMs,
                        pendingIntent
                    )
                }
                Log.i(TAG, "[WATCHDOG] Inexact restart scheduled in ${delayMs}ms.")
            } catch (e: Exception) {
                Log.e(TAG, "[WATCHDOG] Inexact schedule failed: ${e.message}")
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.i(TAG, "[WATCHDOG] Restart signal received — action: ${intent.action}")

        // 1. إعادة تشغيل ZadWatchdogService (Foreground Service بـ START_STICKY)
        try {
            val watchdogIntent = Intent(context, ZadWatchdogService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(watchdogIntent)
            } else {
                context.startService(watchdogIntent)
            }
            Log.i(TAG, "[WATCHDOG] ZadWatchdogService restart issued.")
        } catch (e: Exception) {
            Log.e(TAG, "[WATCHDOG] Failed to restart ZadWatchdogService: ${e.message}")
        }

        // 2. إطلاق FlutterBackgroundService عبر الـ Intent المباشر للخدمة
        // (flutter_background_service يُسجّل خدمته تحت: id.flutter.flutter_background_service.BackgroundService)
        try {
            val fgServiceIntent = Intent().apply {
                setClassName(
                    context.packageName,
                    "id.flutter.flutter_background_service.BackgroundService"
                )
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(fgServiceIntent)
            } else {
                context.startService(fgServiceIntent)
            }
            Log.i(TAG, "[WATCHDOG] FlutterBackgroundService restart issued.")
        } catch (e: Exception) {
            Log.e(TAG, "[WATCHDOG] Failed to restart FlutterBackgroundService: ${e.message}")
        }
    }
}
