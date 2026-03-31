package com.muhamed.imsakia

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * AthanReceiver
 *
 * يستقبل Actions مرتبطة بالأذان:
 *
 * 1. ATHAN_ACTION_*  — يُطلق الأذان عبر NativeAthanService (من AlarmManager).
 * 2. STOP_ATHAN      — يُطلَق من زر "إيقاف الأذان" في الإشعار أو من Flutter، وينفّذ:
 *    أ. إيقاف صوت الأذان عبر NativeAudioController.
 *    ب. إيقاف NativeAthanService.
 *    ج. إلغاء إشعار الأذان بالـ ID الصحيح.
 *
 * هذا الحل يعمل حتى لو كان التطبيق في الخلفية أو مغلقاً (Task Removed).
 */
class AthanReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AthanReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        Log.i(TAG, "[ATHAN_RECEIVER] Action: $action")

        when {
            action == NativeAthanService.ACTION_STOP_ATHAN -> handleStopAthan(context)

            action.startsWith("ATHAN_ACTION_") -> {
                // AlarmManager fired — start NativeAthanService to play Athan
                handleStartAthan(context, intent)
            }

            action == "com.muhamed.imsakia.ATHAN_ACTION" -> {
                // Legacy action — also start Athan
                handleStartAthan(context, intent)
            }

            else -> Log.w(TAG, "[ATHAN_RECEIVER] Unknown action: $action")
        }
    }

    // ─────────────────────────────────────────────────────────────────────────

    /**
     * يُطلق NativeAthanService لتشغيل الأذان مع الإشعار و fullScreenIntent.
     * يمرّر جميع بيانات الصلاة (الاسم، الصورة، المدينة) عبر extras.
     */
    private fun handleStartAthan(context: Context, intent: Intent) {
        val prayerEn = intent.getStringExtra("prayer_en") ?: "Prayer"
        val prayerAr = intent.getStringExtra("prayer_ar") ?: "الصلاة"
        val prayerImage = intent.getStringExtra("image") ?: ""
        val cityName = intent.getStringExtra("city") ?: ""

        Log.i(TAG, "[ATHAN_RECEIVER] Starting NativeAthanService for $prayerAr ($prayerEn)")

        try {
            val serviceIntent = Intent(context, NativeAthanService::class.java).apply {
                putExtra("prayer_en", prayerEn)
                putExtra("prayer_ar", prayerAr)
                putExtra("image", prayerImage)
                putExtra("city", cityName)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.i(TAG, "[ATHAN_RECEIVER] ✓ NativeAthanService started.")
        } catch (e: Exception) {
            Log.e(TAG, "[ATHAN_RECEIVER] Failed to start NativeAthanService: ${e.message}")
        }
    }

    /**
     * ينفّذ إيقاف الأذان الكامل في 3 خطوات متتالية:
     * 1. إيقاف الصوت الفوري عبر NativeAudioController
     * 2. إيقاف NativeAthanService (يُطلق onDestroy ويُسقط الـ WakeLock)
     * 3. إلغاء إشعار الأذان يدوياً باستخدام نفس الـ ID المستخدم في startForeground
     */
    private fun handleStopAthan(context: Context) {
        Log.i(TAG, "[STOP_ATHAN] Executing full stop sequence...")

        // 1. إيقاف الصوت فورياً
        try {
            NativeAudioController.stop(context)
            Log.i(TAG, "[STOP_ATHAN] ✓ NativeAudioController.stop() called.")
        } catch (e: Exception) {
            Log.e(TAG, "[STOP_ATHAN] Audio stop failed: ${e.message}")
        }

        // 2. إيقاف NativeAthanService (يُعيد isRunning=false ويُحرر WakeLock)
        try {
            val serviceIntent = Intent(context, NativeAthanService::class.java)
            context.stopService(serviceIntent)
            Log.i(TAG, "[STOP_ATHAN] ✓ NativeAthanService.stopService() called.")
        } catch (e: Exception) {
            Log.e(TAG, "[STOP_ATHAN] Service stop failed: ${e.message}")
        }

        // 3. إلغاء الإشعار يدوياً — NativeAthanService.NOTIFICATION_ID = 5001
        // (ضروري لأن stopService لا يُلغي الإشعار تلقائياً دائماً على بعض الأجهزة)
        try {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(NativeAthanService.NOTIFICATION_ID)
            Log.i(TAG, "[STOP_ATHAN] ✓ Notification ${NativeAthanService.NOTIFICATION_ID} cancelled.")
        } catch (e: Exception) {
            Log.e(TAG, "[STOP_ATHAN] Notification cancel failed: ${e.message}")
        }

        Log.i(TAG, "[STOP_ATHAN] Full stop sequence complete.")
    }
}
