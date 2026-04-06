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
        
        val prayerName = intent?.getStringExtra("prayer_name") ?: "الصلاة"
        val alarmId = intent?.getIntExtra("alarm_id", 0) ?: 0
        
        try {
            // 🔥 منع تداخل الأصوات: أوقف أي ميديا بلاير قديم
            mediaPlayer?.let {
                if (it.isPlaying) it.stop()
                it.release()
                mediaPlayer = null
                System.err.println("!!! ATHAN SERVICE: Old MediaPlayer stopped and released !!!")
            }

            // 1. Start Foreground immediately to prevent OS kill
            startForegroundServiceNotification(prayerName, alarmId)
            
            // 2. Acquire WakeLock
            acquireWakeLock()
            
            // 3. Play Audio in Background Thread
            Thread {
                playAthanAudioWithRetry()
            }.start()
            
        } catch (e: Exception) {
            System.err.println("!!! ATHAN SERVICE: CRITICAL ERROR: ${e.message} !!!")
        }
        
        return START_NOT_STICKY 
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

    private fun startForegroundServiceNotification(prayerName: String, alarmId: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                ATHAN_SERVICE_CHANNEL, "Athan Service", NotificationManager.IMPORTANCE_HIGH
            ).apply {
                setSound(null, null)
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }

        // 🔥 تعديل الـ Intent ليحمل بيانات التفعيل لشاشة الأذان
        val mainIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            putExtra("trigger_athan_overlay", true)
            putExtra("prayer_name", prayerName)
            putExtra("alarm_id", alarmId)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this, 
            alarmId, 
            mainIntent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, ATHAN_SERVICE_CHANNEL)
            .setContentTitle("🕌 حان وقت $prayerName")
            .setContentText("اضغط لفتح الشاشة أو انتظر التفعيل التلقائي...")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM) // ✅ مهم جداً لظهورها فوق القفل
            .setOngoing(true)
            .setStyle(NotificationCompat.BigTextStyle().bigText("athan_overlay|$prayerName|$alarmId"))
            .setContentIntent(pendingIntent)
            .setFullScreenIntent(pendingIntent, true) // ✅ التفعيل التلقائي للشاشة
            .setOnlyAlertOnce(true)
            .build()

        startForeground(SERVICE_NOTIFICATION_ID, notification)
        System.err.println("!!! ATHAN SERVICE: Foreground Started for $prayerName !!!")
        
        // 🔥 محاولة فتح الأكتيفيتي قسرياً لضمان تخطي قيود شاومي
        try {
            startActivity(mainIntent)
            System.err.println("!!! ATHAN SERVICE: Aggressive startActivity executed !!!")
        } catch (e: Exception) {
            System.err.println("!!! ATHAN SERVICE ERROR: Aggressive startActivity FAILED: ${e.message} !!!")
        }
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