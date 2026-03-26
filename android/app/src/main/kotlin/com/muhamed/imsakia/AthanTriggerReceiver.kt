package com.muhamed.imsakia

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

class AthanTriggerReceiver : BroadcastReceiver() {
    companion object {
        const val TAG = "AthanTriggerReceiver"
        const val CHANNEL_ID = "adhan_athan"
        const val NOTIFICATION_ID = 5001
        const val ACTION_STOP_ATHAN = "com.muhamed.imsakia.STOP_ATHAN"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "⏰ Exact Athan OS-Level Alarm Triggered!")

        // 1. Acquire WakeLock (Keep device awake for max 4 minutes while Athan plays)
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "Imsakia::AthanWakeLock"
        )
        wakeLock.acquire(4 * 60 * 1000L)

        // 2. Extract Data
        val prayerAr = intent.getStringExtra("prayer_ar") ?: "الصلاة"
        val prayerEn = intent.getStringExtra("prayer_en") ?: "Prayer"
        val assetPath = intent.getStringExtra("asset_path") ?: "assets/audio/athan_egypt_ab.mp3"
        val prayerImage = intent.getStringExtra("prayer_image") ?: ""

        // 3. Play Audio Natively Immediately (No Flutter engine needed!)
        NativeAudioController.play(context, assetPath, wakeLock)

        // 3.5 Set SharedPreferences flag for Dart (athan_is_playing = true)
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean("flutter.athan_is_playing", true)
                .putString("flutter.athan_prayer_ar", prayerAr)
                .putString("flutter.athan_prayer_en", prayerEn)
                .putString("flutter.athan_prayer_image", prayerImage)
                .apply()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update SharedPreferences: ${e.message}")
        }

        // 4. Init Notification Manager & Channel
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "زاد - الأذان",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "الأذان (تنبيه وقت الصلاة)"
                setSound(null, null) // Audio is manually played via NativeAudioController
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        // 5. Intents Setup
        // FullScreen Intent -> opens MainActivity
        val fullScreenIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("show_athan", true)
            putExtra("prayer_ar", prayerAr)
            putExtra("prayer_en", prayerEn)
            putExtra("prayer_image", prayerImage)
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            context,
            NOTIFICATION_ID,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Stop Action Intent -> triggers AthanReceiver
        val stopIntent = Intent(context, AthanReceiver::class.java).apply {
            action = ACTION_STOP_ATHAN
        }
        val stopPendingIntent = PendingIntent.getBroadcast(
            context,
            NOTIFICATION_ID,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 6. Post Notification
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher) // Adjust if you have a specific white 24x24 icon like R.drawable.ic_notification
            .setContentTitle("حان وقت $prayerAr")
            .setContentText("اضغط لإيقاف الأذان")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setOngoing(true)
            .addAction(
                NotificationCompat.Action(
                    0,
                    "إيقاف الأذان",
                    stopPendingIntent
                )
            )
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
        Log.d(TAG, "Notification and full-screen intent dispatched.")
    }
}
