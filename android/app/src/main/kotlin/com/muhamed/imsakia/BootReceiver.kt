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
                    // ── Fix 5: علم إعادة جدولة المناسبات ─────────────────────────────────
                    // يكتب BootReceiver هذا العلم في FlutterSharedPreferences قبل أي شيء،
                    // حتى تقرأه IslamicOccasionNotificationService عند أول فتح للتطبيق
                    // وتتجاوز الحارس اليومي لإعادة الجدولة.
                    // المفتاح مكتوب كـ "flutter.<key>" لأن plugin Flutter يُضيف هذا البادئة.
                    try {
                        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                            .edit()
                            .putBoolean("flutter.needs_occasion_reschedule", true)
                            .apply()
                        android.util.Log.d("ZadBoot", "needs_occasion_reschedule flag written to FlutterSharedPreferences")
                    } catch (e: Exception) {
                        android.util.Log.e("ZadBoot", "Failed to write occasion reschedule flag: ${e.message}")
                    }

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
