package com.muhamed.imsakia

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * ═══════════════════════════════════════════════════════════
 * ExactAlarmPermissionReceiver — مستمع تغيير صلاحية المنبهات
 * ═══════════════════════════════════════════════════════════
 *
 * يُستدعى على Android 12+ عند:
 *   - منح المستخدم صلاحية SCHEDULE_EXACT_ALARM  → ترقية المنبهات لـ exact
 *   - سحب المستخدم الصلاحية                   → تخفيض لـ inexact (setAlarmClock يبقى يعمل)
 *
 * هذا يضمن أن المنبهات دائماً بأعلى دقة ممكنة حسب الصلاحية الحالية.
 * مستوحى من آلية al-azan-compose's ExactAlarmPermissionReceiver.
 */
class ExactAlarmPermissionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return

        if (action == "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED") {
            android.util.Log.i(
                "ZadExactAlarm",
                "Exact alarm permission changed — rescheduling all alarms"
            )
            val pendingResult = goAsync()
            Thread {
                try {
                    AlarmRescheduler.rescheduleAll(context, reason = "ExactAlarmPermissionChanged")
                } finally {
                    pendingResult.finish()
                }
            }.start()
        }
    }
}
