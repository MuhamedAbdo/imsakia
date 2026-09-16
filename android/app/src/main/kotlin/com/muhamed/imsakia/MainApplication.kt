package com.muhamed.imsakia

import android.app.Application

/**
 * ═══════════════════════════════════════════════════════════════
 * MainApplication — نقطة الإدخال النيتف الحقيقية
 * ═══════════════════════════════════════════════════════════════
 *
 * لماذا هذا الملف ضروري؟
 *
 * Flutter افتراضياً يستخدم `${applicationName}` في AndroidManifest،
 * والذي يُحوَّل لـ `io.flutter.app.FlutterApplication` — وهي Application
 * بدون أي منطق.
 *
 * بإنشاء هذه الكلاس وتسجيلها في AndroidManifest كـ android:name=".MainApplication"،
 * نضمن أن `onCreate()` يُشغَّل في كل مرة تستيقظ فيها العملية، بما في ذلك:
 *   - عند إطلاق BroadcastReceiver (مثل BootReceiver أو AthanReceiver)
 *   - عند فتح التطبيق من الواجهة
 *   - عند إعادة تشغيل Service بعد الـ Swipe
 *
 * هذا يعني أن فحص المنبهات يحدث في كل مدخل للعملية — ليس فقط عند Boot.
 *
 * Iron Muezzin Layers initialized here:
 *   Layer 2: AlarmWatchdogService  — Persistent Foreground Service
 *   Layer 3: PeriodicRescueWorker  — WorkManager 15-min watchdog
 */
class MainApplication : Application() {

    override fun onCreate() {
        super.onCreate()

        android.util.Log.i("ZadApp", "MainApplication.onCreate() — Process awake, initializing Iron Muezzin…")

        // ── Layer 4 (Base): إعادة جدولة المنبهات المستقبلية ──────────────────
        // سريع جداً: قراءة SharedPreferences فقط (لا I/O ثقيل)
        try {
            AlarmRescheduler.rescheduleAll(this, reason = "MainApplication.onCreate")
        } catch (e: Exception) {
            android.util.Log.e("ZadApp", "rescheduleAll failed in onCreate: ${e.message}")
        }

        // ── Layer 2: تشغيل الحارس الدائم (Persistent Foreground Watchdog) ────
        // يعرض الصلاة القادمة في إشعار دائم ويمنع MIUI من تجميد العملية
        try {
            AlarmWatchdogService.start(this)
        } catch (e: Exception) {
            android.util.Log.e("ZadApp", "AlarmWatchdogService.start() failed: ${e.message}")
        }

        // ── Layer 3: تسجيل WorkManager كطبقة احتياطية ────────────────────────
        // يعمل كل 15 دقيقة لإصلاح أي منبه جمّده MIUI
        // KEEP policy: لا يُعيد الجدولة إذا كان العمل مسجلاً بالفعل
        try {
            PeriodicRescueWorker.schedule(this)
        } catch (e: Exception) {
            android.util.Log.e("ZadApp", "PeriodicRescueWorker.schedule() failed: ${e.message}")
        }
    }
}
