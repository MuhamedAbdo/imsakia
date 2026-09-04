package com.muhamed.imsakia

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat

class AthanReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ZadAthan"
        // الحد الأقصى لتأخر النظام المقبول: 15 دقيقة
        private const val MAX_ACCEPTABLE_DELAY_MS = 15 * 60 * 1000L
        // مفتاح SharedPreferences لتتبع آخر ID أُطلق من PreWarm لمنع التشغيل المزدوج
        private const val PREWARM_FIRED_PREF = "prewarm_last_fired_id"
    }

    override fun onReceive(context: Context, intent: Intent) {
        // ✅ DIAGNOSTIC: First line - always runs before any logic
        val alarmId = intent.getIntExtra("alarm_id", -1)
        android.util.Log.d(TAG, "Receiver Awake - ID: $alarmId")

        // ════════════════════════════════════════════════════════════════════
        // 🛡️ GUARD 1: إسقاط الأذان المتأخر (Drop Stale Alarms)
        // إذا أخّر MIUI المنبه لأكثر من 3 دقائق، نلغي الأذان ونجدول القادم.
        // ════════════════════════════════════════════════════════════════════
        val scheduledTime = intent.getLongExtra("scheduled_time", 0L)
        val firedFromPrewarm = intent.getBooleanExtra("fired_from_prewarm", false)

        if (scheduledTime > 0L) {
            val now = System.currentTimeMillis()
            val delayMs = now - scheduledTime

            if (delayMs > MAX_ACCEPTABLE_DELAY_MS) {
                android.util.Log.w(
                    TAG,
                    "!!! STALE ALARM DROPPED: $delayMs ms late (${delayMs / 1000}s) for alarm ID=$alarmId. " +
                    "MIUI likely throttled this alarm. Showing silent notification instead of skipping completely. !!!"
                )
                
                val rawPrayerName = intent.getStringExtra("prayer_name") ?: "الصلاة"
                val prayerName = rawPrayerName.replace("صلاة الشروق", "شروق الشمس")
                
                // إظهار إشعار صامت لإعلام المستخدم
                showSilentNotification(context, prayerName, alarmId)
                
                // تنظيف الـ prefs وجدولة الصلاة القادمة
                cleanupExpiredAlarm(context, alarmId)
                scheduleNextPrayerWidgetUpdate(context)
                return
            }

            android.util.Log.d(TAG, "--- Timing OK: delay=${delayMs}ms for $alarmId ---")
        }

        // ════════════════════════════════════════════════════════════════════
        // 🛡️ GUARD 2: منع التشغيل المزدوج (Anti Double-Firing)
        // إذا أطلق PreWarmReceiver هذا الـ Receiver بالفعل وجاء المنبه النظامي لاحقاً،
        // نتجاهل النسخة الثانية.
        // ════════════════════════════════════════════════════════════════════
        if (!firedFromPrewarm && alarmId >= 0) {
            val prefs = context.getSharedPreferences("athan_native_prefs", Context.MODE_PRIVATE)
            val lastPrewarmFiredId = prefs.getInt(PREWARM_FIRED_PREF, -1)
            if (lastPrewarmFiredId == alarmId) {
                android.util.Log.i(
                    TAG,
                    "--- Anti-Dup: Alarm ID=$alarmId was already fired by PreWarm. " +
                    "System alarm arrived late — IGNORING to prevent double athan. ---"
                )
                // تنظيف العلامة
                prefs.edit().remove(PREWARM_FIRED_PREF).apply()
                return
            }
        }

        // إذا جاء من PreWarm، سجّل المعرف لمنع النسخة النظامية من التشغيل مرة ثانية
        if (firedFromPrewarm && alarmId >= 0) {
            val prefs = context.getSharedPreferences("athan_native_prefs", Context.MODE_PRIVATE)
            prefs.edit().putInt(PREWARM_FIRED_PREF, alarmId).apply()
            android.util.Log.d(TAG, "--- Fired from PreWarm: Registered anti-dup marker for ID=$alarmId ---")
        }

        // ════════════════════════════════════════════════════════════════════
        // 0. إلغاء إشعار الأذان القديم (السابق)
        // ════════════════════════════════════════════════════════════════════
        try {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            notificationManager.cancel(1001)
        } catch (e: Exception) {}

        // ════════════════════════════════════════════════════════════════════
        // 1. استحواذ فوري على WakeLock — أول سطر في المنطق الأساسي
        // ════════════════════════════════════════════════════════════════════
        try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "Zad:SovereignWakeLock"
            )
            wakeLock.acquire(30000) // 30 ثانية لإتمام كل العمليات
            android.util.Log.d(TAG, "!!! HARDENED: WakeLock Acquired as First Line !!!")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "FAILED to acquire immediate WakeLock: ${e.message}")
        }

        val rawPrayerName = intent.getStringExtra("prayer_name") ?: "الصلاة"
        val prayerName = rawPrayerName.replace("صلاة الشروق", "شروق الشمس")
        val prayerKey = intent.getStringExtra("prayer_key") ?: "dhuhr"
        val isSilent = intent.getBooleanExtra("is_silent", false)

        // ════════════════════════════════════════════════════════════════════
        // 2. إزالة هذه الصلاة من athan_schedules فوراً بعد انطلاقها
        // بدون هذا، يقرأ الويدجت الـ timestamp المنتهي ويعرض عداداً سالباً.
        // ════════════════════════════════════════════════════════════════════
        if (alarmId >= 0) {
            cleanupExpiredAlarm(context, alarmId)
        }

        // ════════════════════════════════════════════════════════════════════
        // 3. تحديث فوري للويدجت + WorkManager
        // ════════════════════════════════════════════════════════════════════
        try {
            val widgetIntent = Intent(context, PrayerWidget::class.java).apply {
                action = "com.muhamed.imsakia.UPDATE_COUNTDOWN"
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, PrayerWidget::class.java))
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                putExtra("triggered_prayer_name", prayerName)
            }
            context.sendBroadcast(widgetIntent)
            android.util.Log.i(TAG, "--- Immediate Direct Widget Sync Broadcast Sent ($prayerName) ---")

            val workRequest = androidx.work.OneTimeWorkRequestBuilder<WidgetUpdateWorker>()
                .setExpedited(androidx.work.OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                .build()
            androidx.work.WorkManager.getInstance(context).enqueue(workRequest)
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to enqueue/broadcast widget update: ${e.message}")
        }

        if (isSilent) {
            showSilentNotification(context, prayerName, alarmId)
            return
        }

        android.util.Log.i(TAG, "!!! HARDENED: Athan Alert Triggered: $prayerName !!!")

        // --- Audible Branch: Full Protocol (Service + Activity) ---

        // 1. Start Service
        val serviceIntent = Intent(context, AthanService::class.java).apply {
            putExtra("prayer_name", prayerName)
            putExtra("prayer_key", prayerKey)
            putExtra("alarm_id", alarmId)
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (e: Exception) { e.printStackTrace() }

        // 2. Start Activity (MainActivity -> Flutter Overlay)
        try {
            val intentToMain = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                putExtra("trigger_athan_overlay", true)
                putExtra("prayer_name", prayerName)
                putExtra("prayer_key", prayerKey)
                putExtra("alarm_id", alarmId)
            }
            context.startActivity(intentToMain)
            android.util.Log.d(TAG, "--- MainActivity Started ---")
        } catch (e: Exception) { e.printStackTrace() }
    }

    private fun cleanupExpiredAlarm(context: Context, alarmId: Int) {
        try {
            val schedulePrefs = context.getSharedPreferences("athan_schedules", Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()
            
            // تنظيف الصلوات القديمة جداً (التي مر عليها أكثر من 12 ساعة) بدلاً من مسح الصلاة الحالية فوراً
            // هذا يسمح للويدجت بقراءة الصلاة الفائتة بشكل صحيح
            val editor = schedulePrefs.edit()
            for (entry in schedulePrefs.all) {
                if (entry.key.endsWith("_data")) continue
                val timestamp = entry.value as? Long ?: continue
                if (timestamp < now - (12 * 60 * 60 * 1000L)) {
                    editor.remove(entry.key).remove("${entry.key}_data")
                }
            }
            editor.apply()
            
            android.util.Log.d(TAG, "✅ Prefs cleaned (kept recent history) for alarm ID=$alarmId")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to clean prefs for alarm $alarmId: ${e.message}")
        }

        // تنظيف المنبه الاستباقي (PreWarm) المرتبط بنفس الصلاة
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            val preWarmIntent = Intent(context, PreWarmReceiver::class.java)
            val preWarmPI = android.app.PendingIntent.getBroadcast(
                context,
                alarmId + 10000, // نفس الـ requestCode المستخدم في الجدولة
                preWarmIntent,
                android.app.PendingIntent.FLAG_NO_CREATE or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            if (preWarmPI != null) {
                alarmManager.cancel(preWarmPI)
                android.util.Log.d(TAG, "✅ PreWarm alarm cancelled for ID=$alarmId")
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to cancel PreWarm for $alarmId: ${e.message}")
        }
    }

    /**
     * إطلاق تحديث فوري للويدجت ليجلب الصلاة القادمة من athan_schedules.
     */
    private fun scheduleNextPrayerWidgetUpdate(context: Context) {
        try {
            val widgetIntent = Intent(context, PrayerWidget::class.java).apply {
                action = "com.muhamed.imsakia.UPDATE_COUNTDOWN"
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, PrayerWidget::class.java))
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(widgetIntent)
            android.util.Log.i(TAG, "--- Stale: Next prayer widget update broadcast sent ---")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to broadcast next prayer widget update: ${e.message}")
        }
    }

    private fun showSilentNotification(context: Context, prayerName: String, alarmId: Int) {
        val channelId = "zad_silent_v3"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = android.app.NotificationManager.IMPORTANCE_HIGH
            val channel = android.app.NotificationChannel(channelId, "Athan Service (Silent)", importance).apply {
                setSound(null, null)
                setShowBadge(false)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 200, 100, 200)
            }
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            manager.createNotificationChannel(channel)
        }

        val titleText = if (prayerName.contains("شروق")) "شروق الشمس الآن" else "صلاة $prayerName الآن"
        val bodyText = if (prayerName.contains("شروق")) "حان الآن وقت الشروق" else ""

        val builder = NotificationCompat.Builder(context, channelId)
            .setContentTitle(titleText)
            .setContentText(bodyText)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_EVENT)
            .setAutoCancel(true)
            .setVibrate(longArrayOf(0, 200, 100, 200))

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        notificationManager.notify(1001, builder.build())
    }
}