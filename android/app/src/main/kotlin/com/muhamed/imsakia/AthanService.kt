package com.muhamed.imsakia

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat

class AthanService : Service() {
    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val SERVICE_NOTIFICATION_ID = 7777
    private val ATHAN_SERVICE_CHANNEL = "athan_service_channel"
    private var retryCount = 0
    private val MAX_RETRY = 3

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        System.err.println("!!! ATHAN SERVICE: onStartCommand CALLED !!!")
        
        try {
            // 🔥 منع تداخل الأصوات: أوقف أي ميديا بلاير قديم
            mediaPlayer?.let {
                if (it.isPlaying) it.stop()
                it.release()
                mediaPlayer = null
                System.err.println("!!! ATHAN SERVICE: Old MediaPlayer stopped and released !!!")
            }

            // 1. Start Foreground immediately to prevent OS kill
            startForegroundServiceNotification()
            
            // 2. Acquire WakeLock
            acquireWakeLock()
            
            // 3. Play Audio in Background Thread
            Thread {
                playAthanAudioWithRetry()
            }.start()
            
        } catch (e: Exception) {
            System.err.println("!!! ATHAN SERVICE: CRITICAL ERROR: ${e.message} !!!")
        }
        
        return START_NOT_STICKY // ✅ لا تقم بإعادة تشغيل الخدمة تلقائياً بعد انتهائها
    }

    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "Imsakia:AthanServiceWakeLock"
            ).apply {
                setReferenceCounted(false)
                acquire(120000) // 2 minutes max
            }
        } catch (e: Exception) { e.printStackTrace() }
    }

    private fun startForegroundServiceNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                ATHAN_SERVICE_CHANNEL, "Athan Service", NotificationManager.IMPORTANCE_HIGH
            ).apply {
                setSound(null, null)
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }

        val mainIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(this, 0, mainIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val notification = NotificationCompat.Builder(this, ATHAN_SERVICE_CHANNEL)
            .setContentTitle("🕌 حان وقت الأذان")
            .setContentText("جاري تشغيل أذان الصلاة...")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setOngoing(true)
            .setSound(null)
            .setContentIntent(pendingIntent)
            .setFullScreenIntent(pendingIntent, true) // Force Wake Screen
            .setOnlyAlertOnce(true) // ✅ منع تكرار الهزاز عند التداخل
            .build()

        startForeground(SERVICE_NOTIFICATION_ID, notification)
        System.err.println("!!! ATHAN SERVICE: Foreground Started !!!")
    }

    private fun playAthanAudioWithRetry() {
        while (retryCount < MAX_RETRY) {
            try {
                System.err.println("!!! ATHAN SERVICE: Playing Audio (Attempt ${retryCount + 1}) !!!")
                playAthanAudio()
                return // Success
            } catch (e: Exception) {
                retryCount++
                Thread.sleep(1000) // Wait before retry
            }
        }
    }

    private fun playAthanAudio() {
        val soundUri = android.net.Uri.parse("android.resource://${packageName}/raw/athan_makkah")
        
        mediaPlayer = MediaPlayer().apply {
            setDataSource(applicationContext, soundUri)
            
            // ✅ CRITICAL: Use RINGTONE usage for MIUI compatibility
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE) 
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            
            isLooping = false // ✅ تشغيل الأذان مرة واحدة فقط (بدون تكرار)
            setVolume(1.0f, 1.0f)
            
            setOnPreparedListener { mp ->
                System.err.println("!!! ATHAN SERVICE: Prepared, Starting... !!!")
                mp.start()
            }
            
            setOnErrorListener { mp, what, extra ->
                System.err.println("!!! ATHAN SERVICE: Error - what=$what, extra=$extra !!!")
                true
            }
            
            prepareAsync() // ✅ Non-blocking
        }
    }

    override fun onDestroy() {
        mediaPlayer?.stop()
        mediaPlayer?.release()
        wakeLock?.release()
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}