package com.muhamed.imsakia

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * ═══════════════════════════════════════════════════════════════
 * AlarmWatchdogService — Layer 2: الحارس الدائم (Iron Muezzin)
 * ═══════════════════════════════════════════════════════════════
 *
 * المشكلة التي تحلها هذه الخدمة:
 *
 *  MIUI/HyperOS عند Swipe-to-Dismiss يُجمّد العملية ويُطبّق
 *  "app freeze". هذا يجعل startForegroundService() يُلقي
 *  ForegroundServiceStartNotAllowedException عند محاولة إطلاق
 *  الأذان من AthanReceiver لاحقاً.
 *
 * الحل:
 *  خدمة Foreground دائمة بإشعار خفي (IMPORTANCE_LOW) لا يُصدر
 *  صوتاً ولا يومض، يعرض اسم وموعد الصلاة القادمة.
 *  MIUI لا يُجمّد العمليات التي لديها Foreground Service نشط.
 *
 * المزايا للمستخدم:
 *  - الإشعار الدائم يعرض الصلاة القادمة (كالويدجت)
 *  - نقر الإشعار يفتح التطبيق
 *  - لا صوت ولا اهتزاز ولا نقطة
 *
 * الميزات التقنية:
 *  1. onTaskRemoved() → إعادة جدولة كل المنبهات فوراً
 *  2. فحص دوري كل 15 دقيقة لسلامة المنبهات
 *  3. تحديث الإشعار عند كل أذان (بالصلاة الجديدة القادمة)
 *  4. START_STICKY + foreground → MIUI لا يستطيع تجميدها
 *  5. self-restart via AlarmManager إذا قُتلت قسراً
 */
class AlarmWatchdogService : Service() {

    companion object {
        private const val TAG = "ZadWatchdog"
        const val NOTIFICATION_ID = 9001
        private const val CHANNEL_ID = "zad_watchdog_v1"

        // كل 15 دقيقة نتحقق من سلامة المنبهات
        private const val CHECK_INTERVAL_MS = 15 * 60 * 1000L

        // request code ثابت لإعادة التشغيل
        private const val RESTART_REQUEST_CODE = 3001

        /**
         * تشغيل الخدمة أو إعادة تشغيلها بأمان.
         * يُستدعى من MainApplication.onCreate() وبعد كل boot.
         */
        fun start(context: Context) {
            val intent = Intent(context, AlarmWatchdogService::class.java)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                android.util.Log.i(TAG, "AlarmWatchdogService.start() called")
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Failed to start AlarmWatchdogService: ${e.message}")
            }
        }

        /**
         * إيقاف الخدمة (إذا أراد المستخدم في المستقبل إيقاف الإشعار الدائم).
         */
        fun stop(context: Context) {
            context.stopService(Intent(context, AlarmWatchdogService::class.java))
        }
    }

    private var serviceJob: Job? = null
    private var serviceScope: CoroutineScope? = null
    private var engineLoopCount = 0

    // ─────────────────────────────────────────────────────────────
    // دورة حياة الخدمة
    // ─────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        android.util.Log.i(TAG, "AlarmWatchdogService created — going foreground")
        createNotificationChannel()
        // استدعاء فوري جداً لـ startForeground دون أي قراءة من الشيرد بريفرنسز لتجنب كراش ForegroundServiceDidNotStartInTimeException
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) { // API 34
                startForeground(
                    NOTIFICATION_ID, 
                    buildNotification(fastMode = true), 
                    android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                )
            } else {
                startForeground(NOTIFICATION_ID, buildNotification(fastMode = true))
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "startForeground failed: ${e.message}")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        android.util.Log.d(TAG, "onStartCommand — watchdog active")

        // تحديث الإشعار بأحدث بيانات الصلاة القادمة
        updateNotification()

        // بدء محرك الأذان الذاتي
        startAthanEngine()

        // START_STICKY: النظام يُعيد تشغيل الخدمة إذا قتلها بـ null intent
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // ════════════════════════════════════════════════════════
        // 🚨 اللحظة الذهبية: Swipe-to-Dismiss تم الكشف عنه!
        //    العملية لا تزال حية لثوانٍ — نستغلها فوراً
        // ════════════════════════════════════════════════════════
        android.util.Log.w(TAG, "!!! WATCHDOG: onTaskRemoved — Swipe detected, rescheduling ALL alarms !!!")

        try {
            AlarmRescheduler.rescheduleAll(applicationContext, reason = "WatchdogService.onTaskRemoved")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "rescheduleAll failed in onTaskRemoved: ${e.message}")
        }

        // جدولة إعادة تشغيل الخدمة بعد 3 ثوانٍ (طبقة أمان إضافية)
        scheduleServiceRestart()

        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        android.util.Log.w(TAG, "AlarmWatchdogService destroyed — scheduling restart")
        serviceJob?.cancel()
        scheduleServiceRestart()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ─────────────────────────────────────────────────────────────
    // إدارة الإشعار
    // ─────────────────────────────────────────────────────────────

    /**
     * يقرأ بيانات الصلاة القادمة ويُحدّث الإشعار الدائم.
     * يُستدعى من AthanReceiver بعد كل أذان لتحديث الصلاة التالية.
     */
    fun updateNotification() {
        try {
            val notification = buildNotification()
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIFICATION_ID, notification)
        } catch (e: Exception) {
            android.util.Log.e(TAG, "updateNotification failed: ${e.message}")
        }
    }

    private fun buildNotification(fastMode: Boolean = false): Notification {
        val prayerName: String
        val prayerTime: String

        if (fastMode) {
            prayerName = ""
            prayerTime = ""
        } else {
            val result = readNextPrayer()
            prayerName = result.first
            prayerTime = result.second
        }

        // Intent لفتح التطبيق عند نقر الإشعار
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val contentTitle: String
        val contentText: String

        if (prayerName.isNotEmpty() && prayerTime.isNotEmpty()) {
            contentTitle = "الصلاة القادمة: $prayerName"
            contentText = prayerTime
        } else {
            contentTitle = "زاد — مواقيت الصلاة"
            contentText = if (fastMode) "جاري التهيئة..." else "اضغط للدخول للتطبيق"
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(contentTitle)
            .setContentText(contentText)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)          // لا يمكن للمستخدم رفعه بالسحب
            .setShowWhen(false)        // لا يعرض وقت الإنشاء
            .setSilent(true)           // لا صوت ولا اهتزاز
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
    }

    /**
     * يقرأ اسم ووقت الصلاة القادمة من:
     *   1. HomeWidgetPreferences (مكتوب من AthanReceiver و Flutter)
     *   2. athan_schedules (fallback مباشر)
     */
    private fun readNextPrayer(): Pair<String, String> {
        return try {
            val now = System.currentTimeMillis()

            // محاولة أولى: HomeWidgetPreferences (أسرع)
            val widgetPrefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val name = widgetPrefs.getString("flutter.next_prayer_name", "") ?: ""
            val ts = widgetPrefs.getLong("flutter.next_prayer_timestamp", 0L)

            if (name.isNotEmpty() && ts > now) {
                val sdf = SimpleDateFormat("h:mm a", Locale("ar"))
                return Pair(name, sdf.format(Date(ts)))
            }

            // محاولة ثانية: athan_schedules مباشرة
            val schedules = getSharedPreferences("athan_schedules", Context.MODE_PRIVATE)
            var nextTs = Long.MAX_VALUE
            var nextName = ""

            for ((key, value) in schedules.all) {
                if (key.endsWith("_data")) continue
                val id = key.toIntOrNull() ?: continue
                val timestamp = (value as? Number)?.toLong() ?: continue
                if (timestamp > now && timestamp < nextTs) {
                    nextTs = timestamp
                    val data = schedules.getString("${id}_data", "") ?: ""
                    nextName = data.split("|").getOrElse(0) { "" }
                }
            }

            if (nextName.isNotEmpty() && nextTs != Long.MAX_VALUE) {
                val sdf = SimpleDateFormat("h:mm a", Locale("ar"))
                Pair(nextName, sdf.format(Date(nextTs)))
            } else {
                Pair("", "")
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "readNextPrayer failed: ${e.message}")
            Pair("", "")
        }
    }

    // ─────────────────────────────────────────────────────────────
    // الفحص الدوري وإعادة التشغيل
    // ─────────────────────────────────────────────────────────────

    /**
     * محرك الأذان الذاتي: يعمل في الخلفية كل 30 ثانية بدون تجميد واجهة المستخدم (Non-blocking).
     */
    private fun startAthanEngine() {
        if (serviceJob?.isActive == true) return
        
        serviceJob = Job()
        serviceScope = CoroutineScope(Dispatchers.Default + serviceJob!!)
        
        serviceScope?.launch {
            android.util.Log.i(TAG, "🚀 Athan Engine (Coroutine Loop) started!")
            while (isActive) {
                try {
                    checkAndFireAthan()
                } catch (e: Exception) {
                    android.util.Log.e(TAG, "Error in Athan Engine loop: ${e.message}")
                }
                delay(30_000) // فحص كل 30 ثانية
            }
        }
    }

    /**
     * يفحص إذا حان وقت الصلاة، ويطلق AthanReceiver مباشرة
     */
    private fun checkAndFireAthan() {
        val schedules = getSharedPreferences("athan_schedules", Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()

        for ((key, value) in schedules.all) {
            if (key.endsWith("_data")) continue
            val id = key.toIntOrNull() ?: continue
            val timestamp = (value as? Number)?.toLong() ?: continue

            // 1. إذا كان موعد الصلاة قد حان
            if (timestamp in 1..now) {
                val data = schedules.getString("${id}_data", "") ?: ""
                val parts = data.split("|")
                val prayerName = parts.getOrElse(0) { "الصلاة" }
                val prayerKey  = parts.getOrElse(1) { "dhuhr" }
                val isSilent   = parts.getOrElse(2) { "false" }.toBoolean()

                android.util.Log.w(TAG, "⏰ Athan Engine: Triggering $prayerName (ID=$id)! delay=${now - timestamp}ms")
                
                // بدء AthanService مباشرة كـ Foreground Service
                val serviceIntent = Intent(applicationContext, AthanService::class.java).apply {
                    action = "com.muhamed.imsakia.ATHAN_ALARM"
                    putExtra("prayer_name", prayerName)
                    putExtra("prayer_key", prayerKey)
                    putExtra("alarm_id", id)
                    putExtra("is_silent", isSilent)
                    putExtra("scheduled_time", timestamp)
                }

                val occurrenceKey = "${prayerKey}_${timestamp}"
                
                android.util.Log.e("WATCHDOG_DIRECT",
                    "WATCHDOG_DIRECT_START_BEFORE" +
                    " | occurrenceKey=$occurrenceKey" +
                    " | prayerKey=$prayerKey" +
                    " | scheduledTime=$timestamp" +
                    " | currentTime=$now" +
                    " | delay=${now - timestamp}ms" +
                    " | alarmId=$id"
                )
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    applicationContext.startForegroundService(serviceIntent)
                } else {
                    applicationContext.startService(serviceIntent)
                }
                
                android.util.Log.e("WATCHDOG_DIRECT",
                    "WATCHDOG_DIRECT_START_AFTER" +
                    " | occurrenceKey=$occurrenceKey" +
                    " | prayerKey=$prayerKey" +
                    " | scheduledTime=$timestamp" +
                    " | currentTime=${System.currentTimeMillis()}" +
                    " | delay=${now - timestamp}ms" +
                    " | alarmId=$id"
                )
            }
        }
        
        // 2. الفحص الدوري كخط دفاع إضافي (كل 30 لفة = 15 دقيقة)
        engineLoopCount++
        if (engineLoopCount >= 30) {
            engineLoopCount = 0
            try {
                AlarmRescheduler.rescheduleAll(applicationContext, reason = "WatchdogService.EngineCheck")
                updateNotification()
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Integrity check failed: ${e.message}")
            }
        }
    }

    /**
     * يُجدوِل إعادة تشغيل الخدمة بعد 3 ثوانٍ عبر AlarmManager.
     * طبقة أمان ضد القتل القسري من MIUI.
     * يستخدم alarmManager.set() (لا setAlarmClock) لعدم استهلاك الحصة.
     */
    private fun scheduleServiceRestart() {
        try {
            val restartIntent = Intent(applicationContext, AlarmWatchdogService::class.java)
            val pi = PendingIntent.getService(
                applicationContext,
                RESTART_REQUEST_CODE,
                restartIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.set(AlarmManager.RTC_WAKEUP, System.currentTimeMillis() + 3_000L, pi)
            android.util.Log.d(TAG, "Watchdog restart scheduled in 3s")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "scheduleServiceRestart failed: ${e.message}")
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "زاد — الصلاة القادمة",         // اسم قناة الإشعارات (يظهر في الإعدادات)
                NotificationManager.IMPORTANCE_LOW  // لا صوت، لا اهتزاز، لا نقطة تنبيه
            ).apply {
                description = "يعرض اسم وموعد الصلاة القادمة"
                setShowBadge(false)
                setSound(null, null)
                enableVibration(false)
                enableLights(false)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }
}
