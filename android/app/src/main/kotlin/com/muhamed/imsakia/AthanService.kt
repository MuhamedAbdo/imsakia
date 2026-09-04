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
import android.media.RingtoneManager

class AthanService : Service() {
    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var focusRequest: android.media.AudioFocusRequest? = null

    private val audioFocusChangeListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            AudioManager.AUDIOFOCUS_LOSS,
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT,
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                android.util.Log.d("ImsakiaNative", "!!! SERVICE: Audio Focus Lost ($focusChange), stopping Athan !!!")
                val stopIntent = Intent(this, AthanService::class.java).apply {
                    action = ACTION_STOP_ATHAN
                }
                startService(stopIntent)
            }
        }
    }
    private val SERVICE_NOTIFICATION_ID = 1001
    private val ATHAN_SERVICE_CHANNEL = "zad_athan_v3"
    private val ACTION_STOP_ATHAN = "com.muhamed.imsakia.STOP_ATHAN"
    private var retryCount = 0
    private val MAX_RETRY = 3
    private var currentPrayerName = "الصلاة"
    private var currentAlarmId = 0

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isAthanEnabled = prefs.getBoolean("flutter.athan_enabled", true)
        val isSilentInIntent = intent?.getBooleanExtra("is_silent", false) ?: false
        
        val rawPrayerName = intent?.getStringExtra("prayer_name") ?: "الصلاة"
        val prayerName = rawPrayerName.replace("صلاة الشروق", "شروق الشمس")
        val prayerKey = intent?.getStringExtra("prayer_key") ?: "dhuhr"
        val alarmId = intent?.getIntExtra("alarm_id", 0) ?: 0
        
        val isPrewarm = intent?.getBooleanExtra("is_prewarm", false) ?: false
        val scheduledTime = intent?.getLongExtra("scheduled_time", 0L) ?: 0L

        currentPrayerName = prayerName
        currentAlarmId = alarmId

        android.util.Log.d("ImsakiaNative", "!!! SERVICE: Started for $prayerName (ID: $alarmId), isPrewarm=$isPrewarm !!!")
        
        if (intent?.action == ACTION_STOP_ATHAN) {
            mediaPlayer?.let {
                if (it.isPlaying) it.stop()
                it.release()
                mediaPlayer = null
            }
            
            try {
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
                } else {
                    @Suppress("DEPRECATION")
                    audioManager.abandonAudioFocus(audioFocusChangeListener)
                }
            } catch (e: Exception) {}
            
            if (isAthanEnabled && !isPrewarm) {
                sendBroadcast(Intent("com.muhamed.imsakia.ATHAN_COMPLETED"))
            }
            
            stopForeground(STOP_FOREGROUND_DETACH)
            stopSelf()
            return START_NOT_STICKY
        }
        
        try {
            // 🔥 منع تداخل الأصوات
            mediaPlayer?.let {
                if (it.isPlaying) it.stop()
                it.release()
                mediaPlayer = null
            }

            // 1. إظهار إشعار Foreground (يعتمد على ما إذا كان PreWarm أو الأذان الفعلي)
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancelAll()
            
            if (isPrewarm) {
                startPreWarmNotification(prayerName, alarmId)
                acquireWakeLock()
                
                val now = System.currentTimeMillis()
                var delay = scheduledTime - now
                if (delay < 0) delay = 0
                
                android.util.Log.i("ImsakiaNative", "--- PreWarm Active: Waiting $delay ms before triggering Athan ---")
                
                Handler(Looper.getMainLooper()).postDelayed({
                    android.util.Log.i("ImsakiaNative", "--- PreWarm Timer Finished: Launching AthanReceiver ---")
                    val athanIntent = Intent(this, AthanReceiver::class.java).apply {
                        putExtra("alarm_id", alarmId)
                        putExtra("scheduled_time", scheduledTime)
                        putExtra("prayer_name", rawPrayerName)
                        putExtra("prayer_key", prayerKey)
                        putExtra("is_silent", isSilentInIntent)
                        putExtra("fired_from_prewarm", true)
                    }
                    sendBroadcast(athanIntent)
                }, delay)
                
                return START_NOT_STICKY
            }

            // ─── مسار الأذان الفعلي ─────────────────────────────────────────
            
            startForegroundServiceNotification(prayerName, alarmId, isAthanEnabled, isOngoing = isAthanEnabled)
            acquireWakeLock()
            
            val shouldPlayAudio = !isSilentInIntent && (isAthanEnabled || prayerName.contains("اختبار"))
            
            if (shouldPlayAudio) {
                android.util.Log.d("ImsakiaNative", "!!! SERVICE: Triggering audio playback !!!")
                Thread {
                    playAthanAudioWithRetry(prayerKey)
                }.start()
            } else {
                android.util.Log.w("ImsakiaNative", "!!! SERVICE: Audio is DISABLED, service will linger for 5s !!!")
                Handler(Looper.getMainLooper()).postDelayed({
                    stopSelf()
                }, 5000)
            }
            
        } catch (e: Exception) {
            e.printStackTrace()
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
    
    private fun startPreWarmNotification(prayerName: String, alarmId: Int) {
        val channelId = "zad_prewarm_v3"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId, "Athan Standby", NotificationManager.IMPORTANCE_LOW
            ).apply {
                setSound(null, null)
                setShowBadge(false)
                enableVibration(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }

        val isShorooq = prayerName.contains("شروق") || prayerName == "الشروق"
        val titleText = if (isShorooq) "اقترب وقت الشروق..." else "اقترب موعد صلاة $prayerName..."
        val bodyText = "يرجى الاستعداد..."
        
        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle(titleText)
            .setContentText(bodyText)
            .setSmallIcon(R.mipmap.ic_launcher) // أو رمز مناسب للصلاة
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOngoing(true)
            .build()

        startForeground(SERVICE_NOTIFICATION_ID, notification)
    }

    private fun startForegroundServiceNotification(prayerName: String, alarmId: Int, isAthanEnabled: Boolean, isOngoing: Boolean) {
        val channelId = if (isAthanEnabled) ATHAN_SERVICE_CHANNEL else "zad_silent_v3"
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (isAthanEnabled) {
                val channel = NotificationChannel(
                    channelId, "Athan Service", NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    setSound(null, null)
                    setShowBadge(false)
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 500, 200, 500)
                }
                getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
            } else {
                val channel = NotificationChannel(
                    channelId, "Silent Athan", NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    setSound(null, null)
                    setShowBadge(false)
                    enableVibration(false)
                }
                getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
            }
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
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION
            putExtra("emergency_athan_mode", true)
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

        val isShorooq = prayerName.contains("شروق") || prayerName == "الشروق"
        val titleText = if (isShorooq) "شروق الشمس الآن" else "صلاة $prayerName الآن"
        val bodyText = if (isShorooq) "حان الآن وقت الشروق" else (if (isAthanEnabled && isOngoing) "اضغط للإيقاف" else "حان الآن موعد صلاة $prayerName")
        
        val notificationBuilder = NotificationCompat.Builder(this, channelId)
            .setContentTitle(titleText)
            .setContentText(bodyText)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(if (isAthanEnabled) NotificationCompat.CATEGORY_ALARM else NotificationCompat.CATEGORY_REMINDER)
            .setOngoing(isOngoing)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            
        if (isAthanEnabled) {
            notificationBuilder.setContentIntent(stopPendingIntent) // Tap to stop
            notificationBuilder.setVibrate(longArrayOf(0, 500, 200, 500))
            notificationBuilder.setFullScreenIntent(fullScreenPendingIntent, true)
        }

        val notification = notificationBuilder.build()
        startForeground(SERVICE_NOTIFICATION_ID, notification)

        if (isAthanEnabled) {
            // 🔥 محاولة فتح الأكتيفيتي قسرياً فقط في حالة تفعيل الأذان
            try {
                startActivity(mainIntent)
            } catch (e: Exception) {
            }
        }
    }

    private fun playAthanAudioWithRetry(prayerKey: String) {
        while (retryCount < MAX_RETRY) {
            try {
                playAthanAudio(prayerKey)
                return // Success
            } catch (e: Exception) {
                retryCount++
                Thread.sleep(1000)
            }
        }
    }

    private fun playAthanAudio(prayerKey: String) {
        // 1. القراءة من SharedPreferences الخاصة بـ Flutter
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val assetPath = prefs.getString("flutter.athan_path_$prayerKey", null) 
                        ?: if(prayerKey == "fajr") "assets/audio/fajr_makkah.mp3" else "assets/audio/athan_makkah.mp3"

        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        // Audio Focus
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest = android.media.AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(audioAttributes)
                .setOnAudioFocusChangeListener(audioFocusChangeListener)
                .build()
            audioManager.requestAudioFocus(focusRequest!!)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(audioFocusChangeListener, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN)
        }

        mediaPlayer = MediaPlayer()
        var success = false

        fun applySettings(mp: MediaPlayer) {
            mp.setAudioAttributes(audioAttributes)
            mp.isLooping = false
            mp.setVolume(1.0f, 1.0f)
        }

        // Try 1: Absolute Path (Downloaded File)
        if (assetPath != null && assetPath.startsWith("/")) {
            try {
                android.util.Log.d("ImsakiaNative", "!!! HARDENED: Attempting to play absolute path: $assetPath !!!")
                java.io.FileInputStream(java.io.File(assetPath)).use { fis ->
                    mediaPlayer?.setDataSource(fis.fd)
                    applySettings(mediaPlayer!!)
                    mediaPlayer?.prepare() // Synchronous prepare inside try-catch
                }
                success = true
            } catch (e: Exception) {
                android.util.Log.e("ImsakiaNative", "!!! HARDENED ERROR: Absolute path failed: ${e.message}, falling back to Asset !!!")
                mediaPlayer?.reset()
            }
        }

        // Try 2: Asset Fallback
        if (!success) {
            try {
                val targetAsset = if (assetPath != null && !assetPath.startsWith("/")) {
                    assetPath
                } else {
                    if (prayerKey == "fajr") "assets/audio/fajr_makkah.mp3" else "assets/audio/athan_makkah.mp3"
                }
                android.util.Log.d("ImsakiaNative", "!!! HARDENED: Attempting to play asset: $targetAsset !!!")
                val assetDescriptor = assets.openFd("flutter_assets/$targetAsset")
                mediaPlayer?.setDataSource(assetDescriptor.fileDescriptor, assetDescriptor.startOffset, assetDescriptor.length)
                applySettings(mediaPlayer!!)
                mediaPlayer?.prepare() // Synchronous prepare
                success = true
            } catch (e: Exception) {
                android.util.Log.e("ImsakiaNative", "!!! HARDENED ERROR: Asset failed: ${e.message}, falling back to default alarm !!!")
                mediaPlayer?.reset()
            }
        }

        // Try 3: System Default Alarm Fallback
        if (!success) {
            try {
                android.util.Log.d("ImsakiaNative", "!!! HARDENED: Attempting to play SYSTEM ALARM SOUND !!!")
                val alert = android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_ALARM)
                mediaPlayer?.setDataSource(applicationContext, alert)
                applySettings(mediaPlayer!!)
                mediaPlayer?.prepare() // Synchronous prepare
                success = true
            } catch (e: Exception) {
                android.util.Log.e("ImsakiaNative", "!!! HARDENED ERROR: Default alarm failed: ${e.message} !!!")
                mediaPlayer?.reset()
            }
        }

        if (success) {
            mediaPlayer?.setOnCompletionListener {
                val nativePrefs = getSharedPreferences("athan_native_prefs", Context.MODE_PRIVATE)
                nativePrefs.edit().putBoolean("should_exit_to_background", true).apply()

                try {
                    val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        focusRequest?.let { am.abandonAudioFocusRequest(it) }
                    } else {
                        @Suppress("DEPRECATION")
                        am.abandonAudioFocus(audioFocusChangeListener)
                    }
                } catch (e: Exception) {}
                
                sendBroadcast(Intent("com.muhamed.imsakia.ATHAN_COMPLETED"))
                stopForeground(STOP_FOREGROUND_DETACH)
                stopSelf()
            }

            mediaPlayer?.setOnErrorListener { _, _, _ -> 
                true // Handled, prevent crash
            }
            
            mediaPlayer?.start()
        } else {
            // All attempts failed, notify UI to refresh anyway
            android.util.Log.e("ImsakiaNative", "!!! CRITICAL: All audio playback methods failed. Broadcasting completion to prevent stuck UI !!!")
            sendBroadcast(Intent("com.muhamed.imsakia.ATHAN_COMPLETED"))
            stopForeground(STOP_FOREGROUND_DETACH)
            stopSelf()
        }
    }

    override fun onDestroy() {
        mediaPlayer?.let {
            if (it.isPlaying) it.stop()
            it.release()
        }
        mediaPlayer = null
        
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
            } else {
                @Suppress("DEPRECATION")
                audioManager.abandonAudioFocus(audioFocusChangeListener)
            }
        } catch (e: Exception) {
            android.util.Log.e("ImsakiaNative", "Error abandoning audio focus: ${e.message}")
        }
        
        wakeLock?.release()
        stopForeground(STOP_FOREGROUND_DETACH)
        sendBroadcast(Intent("com.muhamed.imsakia.ATHAN_COMPLETED"))
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}