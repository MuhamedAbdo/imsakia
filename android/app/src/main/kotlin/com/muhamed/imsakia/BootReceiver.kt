package com.muhamed.imsakia

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * BootReceiver
 *
 * يستمع لأحداث الإقلاع وتغيير الوقت ليُعيد تشغيل الخدمات الحيوية:
 * - BOOT_COMPLETED / LOCKED_BOOT_COMPLETED: إقلاع عادي أو سريع
 * - MY_PACKAGE_REPLACED: بعد تحديث التطبيق
 * - TIME_SET / TIMEZONE_CHANGED: إعادة جدولة الأذان عند تغيير الوقت
 * - QUICKBOOT_POWERON: أجهزة HTC
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        Log.i(TAG, "[BOOT] Action received: $action")

        when (action) {
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.LOCKED_BOOT_COMPLETED",
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
            "android.intent.action.TIME_SET",
            "android.intent.action.TIMEZONE_CHANGED" -> {
                restartServices(context, action)
            }
            else -> {
                Log.d(TAG, "[BOOT] Unhandled action: $action")
            }
        }
    }

    private fun restartServices(context: Context, reason: String) {
        Log.i(TAG, "[BOOT] Restarting Zad services. Reason: $reason")

        // 1. تشغيل ZadWatchdogService — الطبقة الأولى للمراقبة
        try {
            val watchdogIntent = Intent(context, ZadWatchdogService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(watchdogIntent)
            } else {
                context.startService(watchdogIntent)
            }
            Log.i(TAG, "[BOOT] ZadWatchdogService started.")
        } catch (e: Exception) {
            Log.e(TAG, "[BOOT] Failed to start ZadWatchdogService: ${e.message}")
        }

        // 2. تشغيل FlutterBackgroundService — الطبقة الثانية (Dart Isolate)
        // (flutter_background_service معرّف بـ autoStart: true لكن نُشغّله صراحة كـ fallback)
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
            Log.i(TAG, "[BOOT] FlutterBackgroundService started.")
        } catch (e: Exception) {
            Log.e(TAG, "[BOOT] Failed to start FlutterBackgroundService: ${e.message}")
        }
    }
}
