package com.muhamed.imsakia

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * ═══════════════════════════════════════════════════════════
 * BootReceiver — مستمع أحداث Boot وتحديث الحزمة
 * ═══════════════════════════════════════════════════════════
 *
 * يُستدعى عند:
 *   1. BOOT_COMPLETED       → بعد إعادة تشغيل الجهاز
 *   2. MY_PACKAGE_REPLACED  → بعد تحديث التطبيق
 *
 * كلا الحدثين يُلغيان AlarmManager alarms تلقائياً،
 * لذا يجب إعادة جدولة كل المنبهات المستقبلية.
 *
 * المنطق مُفوَّض بالكامل لـ AlarmRescheduler لتجنب التكرار.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return

        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            android.util.Log.i("ZadBoot", "!!! BootReceiver triggered: $action !!!")

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
