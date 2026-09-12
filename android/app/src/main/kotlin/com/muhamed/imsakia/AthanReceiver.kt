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
        // الحد الأقصى لتأخر النظام المقبول: 30 دقيقة
        private const val MAX_ACCEPTABLE_DELAY_MS = 30 * 60 * 1000L
    }

    override fun onReceive(context: Context, intent: Intent) {
        val now = System.currentTimeMillis()
        val scheduledTime = intent.getLongExtra("scheduled_time", 0L)
        val delayMs = now - scheduledTime
        val rawPrayerName = intent.getStringExtra("prayer_name") ?: "الصلاة"
        val prayerName = rawPrayerName.replace("صلاة الشروق", "شروق الشمس")
        val alarmId = intent.getIntExtra("alarm_id", -1)
        android.util.Log.e("AZAN_TRACE", "RECEIVER FIRED\nprayerName=$prayerName\nid=$alarmId\nscheduledTime=$scheduledTime\nnow=$now\ndelayMs=$delayMs")
        android.util.Log.d(TAG, "Receiver Awake - ID: $alarmId")

        // ════════════════════════════════════════════════════════════════════
        // 🛡️ GUARD: إسقاط الأذان المتأخر (Drop Stale Alarms)
        // إذا أخّر النظام المنبه لأكثر من 30 دقيقة، نلغي الأذان ونعرض إشعاراً صامتاً.
        // ════════════════════════════════════════════════════════════════════
        if (scheduledTime > 0L && delayMs > MAX_ACCEPTABLE_DELAY_MS) {
            android.util.Log.w(
                TAG,
                "!!! STALE ALARM DROPPED: $delayMs ms late (${delayMs / 1000}s) for alarm ID=$alarmId. " +
                "Showing silent notification instead."
            )
            showSilentNotification(context, prayerName, alarmId)
            return
        }

        if (scheduledTime > 0L) {
            android.util.Log.d(TAG, "--- Timing OK: delay=${delayMs}ms for $alarmId ---")
        }

        val prayerKey = intent.getStringExtra("prayer_key") ?: "dhuhr"
        val isSilent = intent.getBooleanExtra("is_silent", false)

        // ════════════════════════════════════════════════════════════════════
        // 1. إزالة هذه الصلاة من athan_schedules فوراً بعد انطلاقها
        // بدون هذا، يقرأ الويدجت الـ timestamp المنتهي ويعرض عداداً سالباً.
        // ════════════════════════════════════════════════════════════════════
        if (alarmId >= 0) {
            cleanupExpiredAlarm(context, alarmId)
        }

        // ════════════════════════════════════════════════════════════════════
        // 2. إلغاء إشعار الأذان القديم (السابق)
        // ════════════════════════════════════════════════════════════════════
        try {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            notificationManager.cancel(1001)
        } catch (e: Exception) {}

        // ════════════════════════════════════════════════════════════════════
        // 3. تحديث فوري للويدجت
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

        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to broadcast widget update: ${e.message}")
        }

        // تحديث NextPrayerWidget أيضاً
        try {
            val nextWidgetIntent = Intent(context, NextPrayerWidget::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, NextPrayerWidget::class.java))
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(nextWidgetIntent)
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to broadcast NextPrayerWidget update: ${e.message}")
        }

        if (isSilent) {
            showSilentNotification(context, prayerName, alarmId)
            return
        }

        android.util.Log.i(TAG, "!!! Athan Alert Triggered: $prayerName !!!")

        // --- Audible Branch: Start AthanService ---
        val serviceIntent = Intent(context, AthanService::class.java).apply {
            putExtra("prayer_name", prayerName)
            putExtra("prayer_key", prayerKey)
            putExtra("alarm_id", alarmId)
        }

        try {
            android.util.Log.e("AZAN_TRACE", "SERVICE REQUESTED")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (e: Exception) { e.printStackTrace() }
    }

    private fun cleanupExpiredAlarm(context: Context, alarmId: Int) {
        try {
            val schedulePrefs = context.getSharedPreferences("athan_schedules", Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()

            // Keep only alarms from the last 30 minutes
            val editor = schedulePrefs.edit()
            for (entry in schedulePrefs.all) {
                if (entry.key.endsWith("_data")) continue
                val timestamp = entry.value as? Long ?: continue
                if (timestamp < now - (30 * 60 * 1000L)) {
                    editor.remove(entry.key).remove("${entry.key}_data")
                }
            }
            editor.apply()

            android.util.Log.d(TAG, "✅ Prefs cleaned (kept recent history) for alarm ID=$alarmId")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to clean prefs for alarm $alarmId: ${e.message}")
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

        val isShorooq = prayerName.contains("شروق") || prayerName == "الشروق"
        val titleText = if (isShorooq) "شروق الشمس الآن" else "صلاة $prayerName الآن"
        val bodyText = if (isShorooq) "حان الآن وقت الشروق" else ""

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