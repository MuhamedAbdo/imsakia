package com.muhamed.imsakia

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * ═══════════════════════════════════════════════════════════════
 * PeriodicRescueWorker — Layer 3: الطبقة الاحتياطية (WorkManager)
 * ═══════════════════════════════════════════════════════════════
 *
 * يعمل كل 15 دقيقة (الحد الأدنى لـ WorkManager) في الخلفية.
 *
 * لماذا WorkManager وليس AlarmManager مباشرة؟
 *  - WorkManager يُجدوَل عبر JobScheduler/AlarmManager بصلاحيات النظام
 *  - MIUI يمنح JobScheduler أولوية أعلى من التطبيقات العادية
 *  - يضمن الاستمرارية حتى بعد إعادة التشغيل
 *  - لا يستهلك بطارية إضافية (يُدمج مع نوافذ الصيانة الطبيعية)
 *
 * ما يفعله:
 *  1. يُعيد جدولة كل المنبهات المستقبلية (via AlarmRescheduler)
 *  2. يُعيد تشغيل AlarmWatchdogService إذا لم يكن يعمل
 *  3. يُحدّث HomeWidgetPreferences بالصلاة القادمة
 *
 * ملاحظة مهمة: WorkManager مُصمَّم للمهام القابلة للتأجيل.
 * لا نستخدمه لإطلاق الصوت مباشرة — بل لـ "إصلاح" ما كسره MIUI.
 */
class PeriodicRescueWorker(
    context: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(context, workerParams) {

    companion object {
        private const val TAG = "ZadRescueWorker"
        private const val WORK_NAME = "zad_periodic_rescue"

        /**
         * تسجيل العمل الدوري في WorkManager.
         * يُستدعى من MainApplication.onCreate() مرة واحدة.
         * KEEP_EXISTING يمنع إعادة الجدولة في كل تشغيل للتطبيق.
         */
        fun schedule(context: Context) {
            try {
                val request = PeriodicWorkRequestBuilder<PeriodicRescueWorker>(
                    15, TimeUnit.MINUTES   // الحد الأدنى المسموح به في WorkManager
                ).build()

                WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                    WORK_NAME,
                    ExistingPeriodicWorkPolicy.KEEP,  // لا تُعيد الجدولة إذا كان موجوداً بالفعل
                    request
                )
                android.util.Log.i(TAG, "PeriodicRescueWorker scheduled (every 15 min)")
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Failed to schedule PeriodicRescueWorker: ${e.message}")
            }
        }

        /**
         * إلغاء العمل الدوري (للاستخدام المستقبلي).
         */
        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        }
    }

    override suspend fun doWork(): Result {
        android.util.Log.i(TAG, "=== PeriodicRescueWorker TRIGGERED ===")

        return try {
            // 1. إعادة جدولة كل المنبهات المستقبلية
            AlarmRescheduler.rescheduleAll(applicationContext, reason = "PeriodicRescueWorker")

            // 2. إعادة تشغيل AlarmWatchdogService إذا لم يكن يعمل
            AlarmWatchdogService.start(applicationContext)

            android.util.Log.i(TAG, "=== PeriodicRescueWorker SUCCESS ===")
            Result.success()
        } catch (e: Exception) {
            android.util.Log.e(TAG, "PeriodicRescueWorker FAILED: ${e.message}")
            // retry بعد محاولة فاشلة
            Result.retry()
        }
    }
}
