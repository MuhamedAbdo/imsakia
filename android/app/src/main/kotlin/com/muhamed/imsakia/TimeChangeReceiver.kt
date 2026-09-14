package com.muhamed.imsakia

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * ═══════════════════════════════════════════════════════════
 * TimeChangeReceiver — مستمع تغيير الوقت والمنطقة الزمنية
 * ═══════════════════════════════════════════════════════════
 *
 * يُستدعى عند:
 *   - TIME_SET      → عند تغيير الوقت يدوياً
 *   - TIMEZONE_CHANGED → عند تغيير المنطقة الزمنية
 *
 * كلا الحدثين يُبطلان الـ timestamps المخزَّنة (كانت بالتوقيت القديم)،
 * لذا يجب إعادة جدولة المنبهات.
 *
 * المنطق مُفوَّض لـ AlarmRescheduler المركزي.
 * ملاحظة: تحديث الويدجات مُضمَّن داخل AlarmRescheduler.refreshWidgets().
 */
class TimeChangeReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return

        if (action == Intent.ACTION_TIME_CHANGED || action == Intent.ACTION_TIMEZONE_CHANGED) {
            android.util.Log.i("ZadTimeChange", "!!! Time/Timezone Changed [$action] — Rescheduling alarms !!!")

            val pendingResult = goAsync()
            Thread {
                try {
                    AlarmRescheduler.rescheduleAll(context, reason = action)
                } finally {
                    pendingResult.finish()
                }
            }.start()
        }
    }
}
