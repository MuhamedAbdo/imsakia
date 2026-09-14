package com.muhamed.imsakia

import android.app.Application

/**
 * ═══════════════════════════════════════════════════════════
 * MainApplication — نقطة الإدخال النيتف الحقيقية
 * ═══════════════════════════════════════════════════════════
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
 */
class MainApplication : Application() {

    override fun onCreate() {
        super.onCreate()

        android.util.Log.i("ZadApp", "MainApplication.onCreate() — Process awake, checking alarms…")

        // فحص وإعادة جدولة أي منبه مستقبلي مفقود
        // هذا يعمل بشكل متزامن لكنه سريع جداً (قراءة SharedPreferences فقط)
        try {
            AlarmRescheduler.rescheduleAll(this, reason = "MainApplication.onCreate")
        } catch (e: Exception) {
            // لا نوقف تشغيل التطبيق بسبب خطأ في الجدولة
            android.util.Log.e("ZadApp", "rescheduleAll failed in onCreate: ${e.message}")
        }
    }
}
