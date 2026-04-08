package com.muhamed.imsakia

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
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
    private val ACTION_STOP_ATHAN = "com.muhamed.imsakia.STOP_ATHAN"
    private var retryCount = 0
    private val MAX_RETRY = 3
    private var currentPrayerName = "الصلاة"
    private var currentAlarmId = 0

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        System.err.println("!!! ATHAN SERVICE: onStartCommand CALLED !!! action=${intent?.action}")
        
        // 🔥 Hard Guard: منع تشغيل الخدمة في الوضع الصامت تماماً
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isAthanEnabled = prefs.getBoolean("flutter.athan_enabled", true)
        val isSilentInIntent = intent?.getBooleanExtra("is_silent", false) ?: false
        
        if (isSilentInIntent || !isAthanEnabled) {
            System.err.println("!!! ATHAN SERVICE: Hard Guard - Silent mode detected (Intent=$isSilentInIntent, Prefs=$isAthanEnabled). Stopping immediately. !!!")
            stopSelf()
            return START_NOT_STICKY
        }
        
        if (intent?.action == ACTION_STOP_ATHAN) {
            System.err.println("!!! ATHAN SERVICE: Stop action received. Checking if broadcast needed.")
            
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isEnabled = prefs.getBoolean("flutter.athan_enabled", true)
            
            if (isEnabled) {
                System.err.println("!!! ATHAN SERVICE: Athan was enabled, sending ATHAN_COMPLETED broadcast.")
                sendBroadcast(Intent("com.muhamed.imsakia.ATHAN_COMPLETED"))
            } else {
                System.err.println("!!! ATHAN SERVICE: Athan was silent, skipping broadcast.")
            }
            
            stopSelf()
            return START_NOT_STICKY
        }

        val prayerName = intent?.getStringExtra("prayer_name") ?: "الصلاة"
        val prayerKey = intent?.getStringExtra("prayer_key") ?: "dhuhr"
        val alarmId = intent?.getIntExtra("alarm_id", 0) ?: 0
        
        currentPrayerName = prayerName
        currentAlarmId = alarmId

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isAthanEnabled = prefs.getBoolean("flutter.athan_enabled", true)
        
        try {
            // 🔥 منع تداخل الأصوات: أوقف أي ميديا بلاير قديم
            mediaPlayer?.let {
                if (it.isPlaying) it.stop()
                it.release()
                mediaPlayer = null
            }

            // 1. Start Foreground immediately (Always show notification)
            startForegroundServiceNotification(prayerName, alarmId, isAthanEnabled, isOngoing = isAthanEnabled)
            
            // 2. Acquire WakeLock
            acquireWakeLock()
            
            // 3. Play Audio (Only if enabled)
            if (isAthanEnabled) {
                Thread {
                    playAthanAudioWithRetry(prayerKey)
                }.start()
            } else {
                System.err.println("!!! ATHAN SERVICE: Silent mode. Keeping notification alive for 5 minutes.")
                Handler(Looper.getMainLooper()).postDelayed({
                    System.err.println("!!! ATHAN SERVICE: Silent 5-min timeout reached. Stopping service.")
                    stopSelf()
                }, 300000) // 5 minutes
            }
            
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

    private fun startForegroundServiceNotification(prayerName: String, alarmId: Int, isAthanEnabled: Boolean, isOngoing: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                ATHAN_SERVICE_CHANNEL, "Athan Service", NotificationManager.IMPORTANCE_HIGH
            ).apply {
                setSound(null, null)
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }

        // Action for Notification Content Click: Stop Athan
        val stopIntent = Intent(this, AthanService::class.java).apply {
            action = ACTION_STOP_ATHAN
        }
        val stopPendingIntent = PendingIntent.getService(
            this, alarmId + 1000, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val mainIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            putExtra("trigger_athan_overlay", true)
            putExtra("prayer_name", prayerName)
            putExtra("alarm_id", alarmId)
        }
        
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this, 
            alarmId, 
            mainIntent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val body = if (isAthanEnabled && isOngoing) "اضغط للإيقاف" else ""
        
        val notificationBuilder = NotificationCompat.Builder(this, ATHAN_SERVICE_CHANNEL)
            .setContentTitle("صلاة $prayerName الآن")
            .setContentText(body)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(if (isAthanEnabled) NotificationCompat.PRIORITY_MAX else NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(if (isAthanEnabled) NotificationCompat.CATEGORY_ALARM else NotificationCompat.CATEGORY_REMINDER)
            .setOngoing(isOngoing)
            .setAutoCancel(true)
            .setTimeoutAfter(300000) // 5 minutes
            .setOnlyAlertOnce(true)
            .setContentIntent(stopPendingIntent) // Tap to stop
            
        if (isAthanEnabled) {
            notificationBuilder.setFullScreenIntent(fullScreenPendingIntent, true)
        }

        val notification = notificationBuilder.build()
        startForeground(SERVICE_NOTIFICATION_ID, notification)
        System.err.println("!!! ATHAN SERVICE: Foreground Started for $prayerName (Ongoing=$isOngoing) !!!")

        if (isAthanEnabled) {
            // 🔥 محاولة فتح الأكتيفيتي قسرياً فقط في حالة تفعيل الأذان
            try {
                startActivity(mainIntent)
                System.err.println("!!! ATHAN SERVICE: Aggressive startActivity executed (Athan Enabled) !!!")
            } catch (e: Exception) {
                System.err.println("!!! ATHAN SERVICE ERROR: Aggressive startActivity FAILED: ${e.message} !!!")
            }
        }
    }

    private fun playAthanAudioWithRetry(prayerKey: String) {
        while (retryCount < MAX_RETRY) {
            try {
                System.err.println("!!! ATHAN SERVICE: Playing Audio for $prayerKey (Attempt ${retryCount + 1}) !!!")
                playAthanAudio(prayerKey)
                return // Success
            } catch (e: Exception) {
                System.err.println("!!! ATHAN SERVICE: Playback Failed for $prayerKey: ${e.message} !!!")
                retryCount++
                Thread.sleep(1000)
            }
        }
    }

    private fun playAthanAudio(prayerKey: String) {
        // 1. القراءة من SharedPreferences الخاصة بـ Flutter
        // ملاحظة: بلجن shared_preferences في فلاتر يضيف بادئة "flutter." لكل المفاتيح
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val assetPath = prefs.getString("flutter.athan_path_$prayerKey", null) 
                        ?: if(prayerKey == "fajr") "assets/audio/fajr_makkah.mp3" else "assets/audio/athan_makkah.mp3"

        System.err.println("!!! ATHAN SERVICE: Selected Asset Path: $assetPath !!!")

        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        // Audio Focus
        val result = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val focusRequest = android.media.AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(audioAttributes)
                .build()
            audioManager.requestAudioFocus(focusRequest)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(null, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
        }

        mediaPlayer = MediaPlayer().apply {
            // ✅ تشغيل الملف من مجلد flutter_assets داخل الـ APK
            try {
                val assetDescriptor = assets.openFd("flutter_assets/$assetPath")
                setDataSource(assetDescriptor.fileDescriptor, assetDescriptor.startOffset, assetDescriptor.length)
            } catch (e: Exception) {
                System.err.println("!!! ATHAN SERVICE: Failed to load $assetPath, falling back to raw/athan_makkah !!!")
                val soundUri = android.net.Uri.parse("android.resource://${packageName}/raw/athan_makkah")
                setDataSource(applicationContext, soundUri)
            }

            setAudioAttributes(audioAttributes)
            isLooping = false 
            setVolume(1.0f, 1.0f)
            
            setOnPreparedListener { mp ->
                mp.start()
            }
            
            setOnCompletionListener {
                val nativePrefs = getSharedPreferences("athan_native_prefs", Context.MODE_PRIVATE)
                nativePrefs.edit().putBoolean("should_exit_to_background", true).commit()

                // التحول لوضع "قابل للمسح" بعد انتهاء الصوت
                System.err.println("!!! ATHAN SERVICE: Audio completed. Making notification cancellable.")
                startForegroundServiceNotification(currentPrayerName, currentAlarmId, isAthanEnabled = true, isOngoing = false)
                
                sendBroadcast(Intent("com.muhamed.imsakia.ATHAN_COMPLETED"))
            }

            setOnErrorListener { _, what, extra ->
                System.err.println("!!! ATHAN SERVICE: MediaPlayer Error what=$what extra=$extra !!!")
                true
            }
            
            prepareAsync() 
        }
    }

    override fun onDestroy() {
        mediaPlayer?.stop()
        mediaPlayer?.release()
        wakeLock?.release()
        stopForeground(STOP_FOREGROUND_REMOVE)
        sendBroadcast(Intent("com.muhamed.imsakia.ATHAN_COMPLETED"))
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}