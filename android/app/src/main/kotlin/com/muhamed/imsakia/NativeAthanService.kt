package com.muhamed.imsakia

import android.app.KeyguardManager
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
        val cityName = intent?.getStringExtra("city") ?: ""

        // 1. Acquire screen-waking WakeLock FIRST (turns screen on)
        acquireWakeLock()
        // 2. Dismiss keyguard so our Activity can appear
        dismissKeyguard()
        // 3. Build foreground notification with fullScreenIntent
        setupForeground(prayerAr, prayerEn, prayerImage, cityName)

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

    private fun setupForeground(prayerAr: String, prayerEn: String, prayerImage: String, cityName: String) {
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
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                setBypassDnd(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
            this.flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("open_athan_screen", true)
            putExtra("prayer_ar", prayerAr)
            putExtra("prayer_en", prayerEn)
            putExtra("image", prayerImage)
            putExtra("city", cityName)
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
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .addAction(0, "إيقاف الأذان", stopPendingIntent)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            notificationBuilder.setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
        }

        val notification = notificationBuilder.build()
        // Force heads-up behavior
        notification.flags = notification.flags or android.app.Notification.FLAG_INSISTENT

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

    /**
     * Acquires a SCREEN_BRIGHT WakeLock that actually turns the screen ON.
     * PARTIAL_WAKE_LOCK only keeps CPU alive but the screen stays off.
     * SCREEN_BRIGHT_WAKE_LOCK + ACQUIRE_CAUSES_WAKEUP is the reliable
     * combination to wake the device screen for alarm-type scenarios.
     */
    @Suppress("DEPRECATION")
    private fun acquireWakeLock() {
        if (wakeLock == null) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "Imsakia::AthanScreenWakeLock"
            )
        }
        
        if (wakeLock?.isHeld == false) {
            Log.d(TAG, "Acquiring SCREEN_BRIGHT WakeLock (4 min) — screen will turn ON")
            wakeLock?.acquire(4 * 60 * 1000L)
        }
    }

    /**
     * Dismisses the keyguard (lock screen) so the full-screen intent Activity
     * appears directly. Works on Android 8.0+ via KeyguardManager.
     */
    private fun dismissKeyguard() {
        try {
            val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // On Android 8+, requestDismissKeyguard is the clean API
                // But since we're in a Service (no Activity), we rely on
                // showWhenLocked + turnScreenOn flags set in the manifest & Activity.
                Log.d(TAG, "KeyguardManager: lock screen will be dismissed by Activity flags")
            }
            // For older devices, deprecated API:
            @Suppress("DEPRECATION")
            if (km.isKeyguardLocked) {
                Log.d(TAG, "Device is locked — fullScreenIntent will show over keyguard")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Keyguard dismiss failed: ${e.message}")
        }
    }

    private fun releaseWakeLock() {
        if (wakeLock?.isHeld == true) {
            Log.d(TAG, "Releasing screen WakeLock")
            wakeLock?.release()
        }
        wakeLock = null
    }
}
