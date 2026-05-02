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
    private val SERVICE_NOTIFICATION_ID = 7777
    private val ATHAN_SERVICE_CHANNEL = "athan_audible_channel"
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
        
        currentPrayerName = prayerName
        currentAlarmId = alarmId

        android.util.Log.d("ImsakiaNative", "!!! SERVICE: Started for $prayerName (ID: $alarmId) !!!")
        android.util.Log.d("ImsakiaNative", "!!! SERVICE: isSilentInIntent = $isSilentInIntent, isAthanEnabled (prefs) = $isAthanEnabled !!!")
        
        // 🔥 BYPASS: If intent is NOT silent, we play it even if global toggle is off (for tests)
        val shouldPlayAudio = !isSilentInIntent && (isAthanEnabled || prayerName.contains("اختبار"))
        
        // Removed early stop block for silent intent to allow polite silent notification
        
        if (intent?.action == ACTION_STOP_ATHAN) {
            // Stop media player immediately before broadcasting to avoid lingering ring
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
            
            if (isAthanEnabled) {
                sendBroadcast(Intent("com.muhamed.imsakia.ATHAN_COMPLETED"))
            } else {
            }
            
            stopForeground(true)
            stopSelf()
            return START_NOT_STICKY
        }
        
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
            
            // 3. Play Audio (Only if enabled or test)
            if (shouldPlayAudio) {
                android.util.Log.d("ImsakiaNative", "!!! SERVICE: Triggering audio playback !!!")
                Thread {
                    playAthanAudioWithRetry(prayerKey)
                }.start()
            } else {
                android.util.Log.w("ImsakiaNative", "!!! SERVICE: Audio is DISABLED, service will linger for 5m !!!")
                Handler(Looper.getMainLooper()).postDelayed({
                    stopSelf()
                }, 300000) // 5 minutes
            }
            
        } catch (e: Exception) {
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
        val channelId = if (isAthanEnabled) ATHAN_SERVICE_CHANNEL else "silent_athan_channel"
        
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

        val isShorooq = prayerName == "الشروق"
        val titleText = if (isShorooq) "شروق الشمس الآن" else "صلاة $prayerName الآن"
        val bodyText = if (isShorooq) "حان الآن وقت الشروق" else (if (isAthanEnabled && isOngoing) "اضغط للإيقاف" else "حان الآن موعد صلاة $prayerName")
        
        val notificationBuilder = NotificationCompat.Builder(this, channelId)
            .setContentTitle(titleText)
            .setContentText(bodyText)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(if (isAthanEnabled) NotificationCompat.PRIORITY_MAX else NotificationCompat.PRIORITY_DEFAULT)
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
        // ملاحظة: بلجن shared_preferences في فلاتر يضيف بادئة "flutter." لكل المفاتيح
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val assetPath = prefs.getString("flutter.athan_path_$prayerKey", null) 
                        ?: if(prayerKey == "fajr") "assets/audio/fajr_makkah.mp3" else "assets/audio/athan_makkah.mp3"


        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        // Audio Focus
        val result = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest = android.media.AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(audioAttributes)
                .setOnAudioFocusChangeListener(audioFocusChangeListener)
                .build()
            audioManager.requestAudioFocus(focusRequest!!)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(audioFocusChangeListener, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN)
        }

        mediaPlayer = MediaPlayer().apply {
            try {
                android.util.Log.d("ImsakiaNative", "!!! HARDENED: Attempting to play asset: $assetPath !!!")
                val assetDescriptor = assets.openFd("flutter_assets/$assetPath")
                setDataSource(assetDescriptor.fileDescriptor, assetDescriptor.startOffset, assetDescriptor.length)
            } catch (e: Exception) {
                android.util.Log.e("ImsakiaNative", "!!! HARDENED ERROR: Failed to load asset $assetPath: ${e.message} !!!")
                android.util.Log.d("ImsakiaNative", "!!! HARDENED: Falling back to SYSTEM ALARM SOUND (TYPE_ALARM) !!!")
                val alert = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                setDataSource(applicationContext, alert)
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

                // استعادة التركيز الصوتي فوراً
                try {
                    val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
                    } else {
                        @Suppress("DEPRECATION")
                        audioManager.abandonAudioFocus(audioFocusChangeListener)
                    }
                } catch (e: Exception) {}
                
                sendBroadcast(Intent("com.muhamed.imsakia.ATHAN_COMPLETED"))
                stopForeground(true)
                stopSelf()
            }

            setOnErrorListener { _, what, extra ->
                true
            }
            
            prepareAsync() 
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
        stopForeground(true)
        sendBroadcast(Intent("com.muhamed.imsakia.ATHAN_COMPLETED"))
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}