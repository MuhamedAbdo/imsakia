package com.muhamed.imsakia

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * ═══════════════════════════════════════════════════════════════
 * BootReceiver — مستمع أحداث Boot وتحديث الحزمة
 * ═══════════════════════════════════════════════════════════════
 *
 * يُستدعى عند:
 *   1. BOOT_COMPLETED       → بعد إعادة تشغيل الجهاز
 *   2. MY_PACKAGE_REPLACED  → بعد تحديث التطبيق
 *
 * كلا الحدثين يُلغيان AlarmManager alarms تلقائياً،
 * لذا يجب إعادة جدولة كل المنبهات المستقبلية.
 *
 * Iron Muezzin: يُعيد تشغيل AlarmWatchdogService وWorkManager هنا أيضاً
 * لأن Foreground Services تُوقف عند إعادة تشغيل الجهاز.
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
                    // Layer 4: إعادة جدولة المنبهات
                    AlarmRescheduler.rescheduleAll(context, reason = action)

                    // Layer 2: إعادة تشغيل الحارس الدائم (يُوقف عند إعادة تشغيل الجهاز)
                    AlarmWatchdogService.start(context)

                    // Layer 3: إعادة تسجيل WorkManager (KEEP policy = آمن لاستدعائه مرات متعددة)
                    PeriodicRescueWorker.schedule(context)
                } finally {
                    pendingResult.finish()
                }
            }.start()
        }
    }
}
