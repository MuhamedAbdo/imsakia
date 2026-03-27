package com.muhamed.imsakia

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

class NativeAthanService : Service() {
    companion object {
        const val TAG = "NativeAthanService"
        const val CHANNEL_ID = "adhan_athan"
        const val NOTIFICATION_ID = 5001
        const val ACTION_STOP_ATHAN = "com.muhamed.imsakia.STOP_ATHAN"
        var isRunning = false
        private var wakeLock: PowerManager.WakeLock? = null
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP_ATHAN) {
            Log.d(TAG, "Stopping Athan via intent action")
            NativeAudioController.stop(this)
            releaseWakeLock()
            stopSelf()
            return START_NOT_STICKY
        }

        val prayerAr = intent?.getStringExtra("prayer_ar") ?: "الصلاة"
        val prayerEn = intent?.getStringExtra("prayer_en") ?: "Prayer"
        val assetPath = intent?.getStringExtra("asset_path") ?: "assets/audio/athan_egypt_ab.mp3"
        val prayerImage = intent?.getStringExtra("image") ?: ""

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "زاد - الأذان",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "الأذان (تنبيه وقت الصلاة)"
                setSound(null, null)
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
            this.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("open_athan_screen", true)
            putExtra("prayer_ar", prayerAr)
            putExtra("prayer_en", prayerEn)
            putExtra("image", prayerImage)
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this,
            NOTIFICATION_ID,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(this, NativeAthanService::class.java).apply {
            action = ACTION_STOP_ATHAN
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            NOTIFICATION_ID,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
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

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Apply foreground behavior for Android 12+
                notification = NotificationCompat.Builder(this, CHANNEL_ID)
                    .setSmallIcon(R.mipmap.ic_launcher)
                    .setContentTitle("حان وقت $prayerAr")
                    .setContentText("اضغط لإيقاف الأذان")
                    .setPriority(NotificationCompat.PRIORITY_MAX)
                    .setCategory(NotificationCompat.CATEGORY_ALARM)
                    .setFullScreenIntent(fullScreenPendingIntent, true)
                    .setOngoing(true)
                    .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
                    .addAction(0, "إيقاف الأذان", stopPendingIntent)
                    .build()
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Foreground start failed: ${e.message}")
            releaseWakeLock()
            stopSelf()
            return START_NOT_STICKY
        }

        // 1. Acquire WakeLock BEFORE playback
        acquireWakeLock()

        // 2. Start Audio Playback in Controller
        NativeAudioController.play(this, assetPath)

        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        Log.d(TAG, "Service being destroyed, cleaning up...")
        NativeAudioController.stop(this)
        releaseWakeLock()
        super.onDestroy()
    }

    private fun acquireWakeLock() {
        if (wakeLock == null) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "Imsakia::AthanServiceWakeLock"
            )
        }
        
        if (wakeLock?.isHeld == false) {
            Log.d(TAG, "Acquiring service-level WakeLock (4 min)")
            wakeLock?.acquire(4 * 60 * 1000L)
        }
    }

    private fun releaseWakeLock() {
        if (wakeLock?.isHeld == true) {
            Log.d(TAG, "Releasing service-level WakeLock")
            wakeLock?.release()
        }
        wakeLock = null
    }
}
