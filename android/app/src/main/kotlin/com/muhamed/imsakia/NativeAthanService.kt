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
import com.muhamed.imsakia.R

class NativeAthanService : Service() {
    companion object {
        const val TAG = "NativeAthanService"
        const val CHANNEL_ID = "adhan_athan"
        const val NOTIFICATION_ID = 5001
        const val ACTION_STOP_ATHAN = "com.muhamed.imsakia.STOP_ATHAN"
        var isRunning = false
        private var wakeLock: PowerManager.WakeLock? = null
    }

    private val volumeHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private var currentVolume = 0.0f
    private val FADE_DURATION_MS = 4000L // 4 seconds
    private val FADE_INTERVAL_MS = 100L
    private val VOLUME_INCREMENT = 1.0f / (FADE_DURATION_MS / FADE_INTERVAL_MS)

    override fun onCreate() {
        super.onCreate()
        isRunning = true
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP_ATHAN) {
            Log.d(TAG, "Stopping Athan via intent action")
            stopAthan()
            return START_NOT_STICKY
        }

        val prayerAr = intent?.getStringExtra("prayer_ar") ?: "الصلاة"
        val prayerEn = intent?.getStringExtra("prayer_en") ?: "Prayer"
        val prayerImage = intent?.getStringExtra("image") ?: ""

        setupForeground(prayerAr, prayerEn, prayerImage)
        acquireWakeLock()

        // 2. Determine and Start Audio Playback (Strictly Raw Resources)
        try {
            // Start at volume 0.0 for fade-in
            NativeAudioController.setVolume(0.0f)

            if (prayerEn.equals("Fajr", ignoreCase = true) || prayerAr.contains("الفجر")) {
                Log.i(TAG, "Starting Fajr Athan from Raw Resource")
                NativeAudioController.playRaw(this, R.raw.fajr_default)
            } else {
                Log.i(TAG, "Starting Regular Athan from Raw Resource")
                NativeAudioController.playRaw(this, R.raw.athan_default)
            }
            
            startFadeIn()
        } catch (e: Exception) {
            Log.e(TAG, "Raw resource playback failed: ${e.message}")
            // Do NOT fall back to assets as per strict requirement
        }

        return START_STICKY
    }

    private fun setupForeground(prayerAr: String, prayerEn: String, prayerImage: String) {
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

        // زر الإيقاف: يُرسل Broadcast إلى AthanReceiver (لا يمكن استخدام getService في Android 12+)
        val stopIntent = Intent(this, AthanReceiver::class.java).apply {
            action = ACTION_STOP_ATHAN
        }
        val stopPendingIntent = PendingIntent.getBroadcast(
            this,
            NOTIFICATION_ID + 1, // request code مختلف عن الـ fullScreenPendingIntent لتجنب التعارض
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("حان وقت $prayerAr")
            .setContentText("اضغط لإيقاف الأذان")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setOngoing(true)
            .addAction(0, "إيقاف الأذان", stopPendingIntent)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            notificationBuilder.setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
        }

        val notification = notificationBuilder.build()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Foreground start failed: ${e.message}")
            stopSelf()
        }
    }

    private fun startFadeIn() {
        Log.i(TAG, "[SERVICE] Fade-in started")
        currentVolume = 0.0f
        volumeHandler.post(object : Runnable {
            override fun run() {
                if (currentVolume < 1.0f) {
                    currentVolume += VOLUME_INCREMENT
                    if (currentVolume > 1.0f) currentVolume = 1.0f
                    NativeAudioController.setVolume(currentVolume)
                    volumeHandler.postDelayed(this, FADE_INTERVAL_MS)
                } else {
                    Log.i(TAG, "[SERVICE] Fade-in completed")
                }
            }
        })
    }

    private fun stopAthan() {
        volumeHandler.removeCallbacksAndMessages(null)
        NativeAudioController.stop(this)
        releaseWakeLock()
        stopSelf()
    }

    override fun onDestroy() {
        isRunning = false
        Log.d(TAG, "Service being destroyed, cleaning up...")
        // Memory Safety: Clear handler callbacks
        volumeHandler.removeCallbacksAndMessages(null)
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
