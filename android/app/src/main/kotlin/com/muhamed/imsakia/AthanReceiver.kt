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
    override fun onReceive(context: Context, intent: Intent) {
        // ✅ DIAGNOSTIC: First line - always runs before any logic
        val alarmId = intent.getIntExtra("alarm_id", -1)
        android.util.Log.d("ZadAthan", "Receiver Awake - ID: $alarmId")

        // 0. ✅ FIX: Cancel ONLY our previous athan notification (ID 1001).
        // Using cancelAll() was catastrophic — it killed system notifications and
        // could force-stop any active ForegroundService, leading to random failures.
        try {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            notificationManager.cancel(1001)
        } catch (e: Exception) {}

        // 1. Acquire WakeLock IMMEDIATELY (Partial Wake) - MUST BE FIRST LINE
        try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "Zad:SovereignWakeLock"
            )
            wakeLock.acquire(30000) // 30 seconds to allow everything to load
            android.util.Log.d("ZadAthan", "!!! HARDENED: WakeLock Acquired as First Line !!!")
        } catch (e: Exception) { 
            android.util.Log.e("ZadAthan", "FAILED to acquire immediate WakeLock: ${e.message}")
        }

        val rawPrayerName = intent.getStringExtra("prayer_name") ?: "الصلاة"
        val prayerName = rawPrayerName.replace("صلاة الشروق", "شروق الشمس")
        val prayerKey = intent.getStringExtra("prayer_key") ?: "dhuhr"
        val isSilent = intent.getBooleanExtra("is_silent", false)

        // ✅ FIX: Remove this prayer from athan_schedules IMMEDIATELY after it fires.
        // Without this, the Widget reads the expired timestamp and displays a negative
        // countdown until the (now-removed) Dart isolate wakes up and corrects it.
        if (alarmId >= 0) {
            try {
                val schedulePrefs = context.getSharedPreferences("athan_schedules", Context.MODE_PRIVATE)
                schedulePrefs.edit()
                    .remove(alarmId.toString())
                    .remove("${alarmId}_data")
                    .apply()
                android.util.Log.d("ZadAthan", "✅ Prefs cleaned for alarm ID=$alarmId")
            } catch (e: Exception) {
                android.util.Log.e("ZadAthan", "Failed to clean prefs for alarm $alarmId: ${e.message}")
            }
        }

        // 2. Expedited & Direct Immediate Widget Update
        try {
            val widgetIntent = Intent(context, PrayerWidget::class.java).apply {
                action = "com.muhamed.imsakia.UPDATE_COUNTDOWN"
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, PrayerWidget::class.java))
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                putExtra("triggered_prayer_name", prayerName)
            }
            context.sendBroadcast(widgetIntent)
            android.util.Log.i("ZadAthan", "--- Immediate Direct Widget Sync Broadcast Sent ($prayerName) ---")

            val workRequest = androidx.work.OneTimeWorkRequestBuilder<WidgetUpdateWorker>()
                .setExpedited(androidx.work.OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                .build()
            androidx.work.WorkManager.getInstance(context).enqueue(workRequest)
        } catch (e: Exception) {
            android.util.Log.e("ZadAthan", "Failed to enqueue/broadcast widget update: ${e.message}")
        }


        if (isSilent) {
            showSilentNotification(context, prayerName, alarmId)
            return
        }

        android.util.Log.i("ZadAthan", "!!! HARDENED: Athan Alert Triggered: $prayerName !!!")

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
            android.util.Log.d("ZadAthan", "--- MainActivity Started ---")
        } catch (e: Exception) { e.printStackTrace() }
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