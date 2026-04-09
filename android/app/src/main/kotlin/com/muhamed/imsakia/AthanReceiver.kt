package com.muhamed.imsakia

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat

class AthanReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val prayerName = intent.getStringExtra("prayer_name") ?: "الصلاة"
        val prayerKey = intent.getStringExtra("prayer_key") ?: "dhuhr"
        val alarmId = intent.getIntExtra("alarm_id", 0)
        val isSilent = intent.getBooleanExtra("is_silent", false)
        

        if (isSilent) {
            showSilentNotification(context, prayerName, alarmId)
            return
        }

        // --- Audible Branch: Full Protocol (Service + Activity + WakeLock) ---
        
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
            }
            context.startActivity(intentToMain)
            
            // 3. Acquire WakeLock
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val wakeLock = powerManager.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
                "Imsakia:WakeLock"
            )
            wakeLock.acquire(15000) // 15 seconds
        } catch (e: Exception) { e.printStackTrace() }
    }

    private fun showSilentNotification(context: Context, prayerName: String, alarmId: Int) {
        val channelId = "athan_silent_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = android.app.NotificationManager.IMPORTANCE_DEFAULT
            val channel = android.app.NotificationChannel(channelId, "Athan Service (Silent)", importance).apply {
                setSound(null, null)
                setShowBadge(false)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 200, 100, 200)
            }
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            manager.createNotificationChannel(channel)
        }

        val builder = NotificationCompat.Builder(context, channelId)
            .setContentTitle("صلاة $prayerName الآن")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_EVENT)
            .setAutoCancel(true)
            .setTimeoutAfter(300000) // 5 minutes
            .setVibrate(longArrayOf(0, 200, 100, 200))

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        notificationManager.notify(9999 + alarmId, builder.build())
    }
}