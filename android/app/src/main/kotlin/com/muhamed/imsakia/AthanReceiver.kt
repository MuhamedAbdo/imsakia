package com.muhamed.imsakia

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * AthanReceiver
 *
 * يستقبل Actions مرتبطة بالأذان:
 *
 * 1. ATHAN_ACTION  — الـ Action الأصلي لإطلاق الأذان (محجوز للمستقبل).
 * 2. STOP_ATHAN   — يُطلَق من زر "إيقاف الأذان" في الإشعار، وينفّذ:
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

        when (action) {
            NativeAthanService.ACTION_STOP_ATHAN -> handleStopAthan(context)
            "com.muhamed.imsakia.ATHAN_ACTION"  -> {
                // محجوز — الجدولة تتم الآن عبر الـ Flutter Background Service
                Log.i(TAG, "[ATHAN_RECEIVER] ATHAN_ACTION received (scheduled via Flutter).")
            }
            else -> Log.w(TAG, "[ATHAN_RECEIVER] Unknown action: $action")
        }
    }

    // ─────────────────────────────────────────────────────────────────────────

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
