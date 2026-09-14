package com.muhamed.imsakia

import android.app.AlarmManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder

/**
 * ═══════════════════════════════════════════════════════════
 * SwipeDismissGuardService — حارس الـ Swipe-to-Dismiss
 * ═══════════════════════════════════════════════════════════
 *
 * المشكلة التي تحلها هذه الخدمة:
 *
 * عند Swipe-to-Dismiss على شاومي (MIUI/HyperOS)، النظام يقتل العملية
 * بسرعة. رغم أن AlarmManager alarms تبقى موجودة نظرياً، إلا أن بعض
 * إصدارات MIUI تُلغي أو تُجمّد هذه المنبهات عند قتل العملية.
 *
 * الحل:
 *   1. `onTaskRemoved()` يُستدعى فوراً لحظة الـ Swipe، قبل قتل العملية.
 *      نستغل هذه اللحظة لإعادة جدولة كل المنبهات المستقبلية.
 *
 *   2. `START_STICKY` يطلب من النظام إعادة تشغيل الخدمة إذا قتلها.
 *      على شاومي مع تفعيل AutoStart، هذا يعمل بشكل موثوق.
 *
 *   3. لا Foreground Notification — الخدمة خفيفة في الخلفية.
 *      شاومي قد يوقفها بعد دقائق، لكن onTaskRemoved سيكون قد أدّى دوره.
 *
 * ملاحظة: هذه الخدمة لا تفعل شيئاً أثناء عملها سوى الاستماع لـ onTaskRemoved.
 * استهلاكها للموارد = صفر تقريباً.
 */
class SwipeDismissGuardService : Service() {

    private val TAG = "ZadGuard"

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        android.util.Log.d(TAG, "SwipeDismissGuardService started (watching for Swipe-to-Dismiss)")
        // START_STICKY → النظام يُعيد تشغيل الخدمة إذا قتلها (مع null intent)
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // ════════════════════════════════════════════════════════
        // 🚨 هذا يُستدعى فوراً لحظة Swipe-to-Dismiss
        // هذه هي اللحظة الذهبية — العملية لا تزال حية لثوانٍ
        // ════════════════════════════════════════════════════════
        android.util.Log.w(TAG, "!!! onTaskRemoved: Swipe-to-Dismiss detected — Rescheduling alarms NOW !!!")

        try {
            AlarmRescheduler.rescheduleAll(applicationContext, reason = "onTaskRemoved/Swipe")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "rescheduleAll failed in onTaskRemoved: ${e.message}")
        }

        // ════════════════════════════════════════════════════════
        // جدوَل إعادة تشغيل الخدمة بعد ثانية واحدة
        // هذا يضمن استمرار المراقبة حتى بعد قتل الخدمة
        // ════════════════════════════════════════════════════════
        scheduleServiceRestart()

        super.onTaskRemoved(rootIntent)
    }

    private fun scheduleServiceRestart() {
        try {
            val restartIntent = Intent(applicationContext, SwipeDismissGuardService::class.java)
            val pendingIntent = PendingIntent.getService(
                applicationContext,
                2001,
                restartIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            // إعادة التشغيل بعد ثانيتين
            alarmManager.set(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + 2_000L,
                pendingIntent
            )
            android.util.Log.d(TAG, "Service restart scheduled in 2s")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to schedule service restart: ${e.message}")
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        android.util.Log.d(TAG, "SwipeDismissGuardService destroyed")
        super.onDestroy()
    }
}
