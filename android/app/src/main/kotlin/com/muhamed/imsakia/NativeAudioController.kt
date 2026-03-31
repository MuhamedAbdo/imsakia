package com.muhamed.imsakia

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.PowerManager
import android.util.Log

object NativeAudioController {
    private const val TAG = "NativeAudioController"
    private var mediaPlayer: MediaPlayer? = null
    private var audioManager: AudioManager? = null
    private var focusRequest: AudioFocusRequest? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var applicationContext: Context? = null

    private val audioFocusChangeListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            AudioManager.AUDIOFOCUS_LOSS -> stop(applicationContext)
        }
    }

    fun play(context: Context, assetPath: String, lock: PowerManager.WakeLock? = null) {
        stop(context)
        applicationContext = context.applicationContext
        wakeLock = lock

        setupMediaPlayer(context) { mp ->
            val flutterAssetPath = "flutter_assets/$assetPath"
            Log.d(TAG, "Attempting to play asset: $flutterAssetPath")
            val afd = context.assets.openFd(flutterAssetPath)
            mp.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            afd.close()
        }
    }

    fun playRaw(context: Context, resId: Int, lock: PowerManager.WakeLock? = null) {
        stop(context)
        applicationContext = context.applicationContext
        wakeLock = lock

        setupMediaPlayer(context) { mp ->
            Log.d(TAG, "Attempting to play raw resource ID: $resId")
            val afd = context.resources.openRawResourceFd(resId)
            mp.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            afd.close()
        }
    }

    private fun setupMediaPlayer(context: Context, dataSourceSetter: (MediaPlayer) -> Unit) {
        try {
            // CENTRALIZED START STATE
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean("flutter.athan_is_playing", true)
                .putLong("flutter.athan_start_time", System.currentTimeMillis())
                .apply()

            audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager?
            mediaPlayer = MediaPlayer()

            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()

            mediaPlayer?.setAudioAttributes(audioAttributes)

            // Read latest volume from SharedPreferences
            var userVolume = 1.0f
            try {
                val volumeVal = prefs.all["flutter.athan_volume"]
                if (volumeVal is Double) userVolume = volumeVal.toFloat()
                else if (volumeVal is Float) userVolume = volumeVal
                else if (volumeVal is String) userVolume = volumeVal.toFloatOrNull() ?: 1.0f
            } catch (e: Exception) {
                Log.e(TAG, "Volume parse error: \${e.message}")
            }
            mediaPlayer?.setVolume(userVolume, userVolume)

            // Request Audio Focus
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                    .setAudioAttributes(audioAttributes)
                    .setAcceptsDelayedFocusGain(true)
                    .setOnAudioFocusChangeListener(audioFocusChangeListener)
                    .build()
                audioManager?.requestAudioFocus(focusRequest!!)
            } else {
                @Suppress("DEPRECATION")
                audioManager?.requestAudioFocus(audioFocusChangeListener, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
            }

            dataSourceSetter(mediaPlayer!!)

            mediaPlayer?.isLooping = false
            mediaPlayer?.setOnCompletionListener {
                Log.d(TAG, "Playback completed naturally")
                stop(context)
            }

            mediaPlayer?.setOnPreparedListener { mp ->
                mp.start()
                Log.d(TAG, "Athan Playback Started")
            }
            mediaPlayer?.prepareAsync()

        } catch (e: Exception) {
            Log.e(TAG, "Failed setupMediaPlayer: \${e.message}")
            e.printStackTrace()
            stop(context)
        }
    }

    fun isReallyPlaying(context: Context?): Boolean {
        if (context == null) return false
        val isServiceRunning = NativeAthanService.isRunning
        val isMediaPlayerPlaying = try { mediaPlayer?.isPlaying == true } catch (e: Exception) { false }
        
        var isNotificationShowing = false
        try {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val activeNotifications = notificationManager?.activeNotifications
                isNotificationShowing = activeNotifications?.any { it.id == 5001 } == true
            } else {
                // Fallback for older APIs where we can't easily check active notifications
                isNotificationShowing = isServiceRunning 
            }
        } catch (e: Exception) {
            Log.d(TAG, "Notification check failed: ${e.message}")
        }

        return isServiceRunning && isMediaPlayerPlaying && isNotificationShowing
    }

    fun setVolume(volume: Float) {
        try {
            val mp = mediaPlayer
            if (mp != null && mp.isPlaying) {
                mp.setVolume(volume, volume)
            }
        } catch (e: Exception) {
            Log.d(TAG, "Failed to set volume: ${e.message}")
        }
    }

    fun stop(context: Context?) {
        try {
            Log.d(TAG, "NativeAudioController.stop - NUCLEAR CLEANUP")
            
            // 1. MediaPlayer
            try {
                mediaPlayer?.setOnCompletionListener(null)
                if (mediaPlayer?.isPlaying == true) {
                    mediaPlayer?.stop()
                }
                mediaPlayer?.release()
            } catch (e: Exception) { Log.d(TAG, "MP Stop fail: ${e.message}") }
            mediaPlayer = null
            
            // 2. Audio Focus
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    focusRequest?.let { audioManager?.abandonAudioFocusRequest(it) }
                } else {
                    @Suppress("DEPRECATION")
                    audioManager?.abandonAudioFocus(audioFocusChangeListener)
                }
            } catch (e: Exception) { Log.d(TAG, "Focus Stop fail: ${e.message}") }
            
            // 3. WakeLock
            try {
                if (wakeLock?.isHeld == true) {
                    wakeLock?.release()
                }
            } catch (e: Exception) { Log.d(TAG, "WL Release fail: ${e.message}") }
            wakeLock = null

            // 4. Service
            try {
                context?.stopService(Intent(context, NativeAthanService::class.java))
            } catch (e: Exception) { Log.d(TAG, "Service Stop fail: ${e.message}") }

            // 5. Notification
            try {
                val notificationManager = context?.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                notificationManager?.cancel(5001) // ATHAN_NOTIFICATION_ID
            } catch (e: Exception) { Log.d(TAG, "Notif Cancel fail: ${e.message}") }

            // 6. SharedPreferences (HARD RESET)
            try {
                val prefs = context?.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                prefs?.edit()
                    ?.putBoolean("flutter.athan_is_playing", false)
                    ?.putBoolean("athan_is_playing", false) // Legacy cleanup
                    ?.remove("flutter.athan_start_time")
                    ?.putLong("flutter.athan_last_stop_time", System.currentTimeMillis())
                    ?.apply()
                Log.d(TAG, "Flags cleared successfully")
            } catch (e: Exception) { Log.d(TAG, "Prefs Reset fail: ${e.message}") }

        } catch (e: Exception) {
            Log.d(TAG, "Global Stop error: ${e.message}")
        }
    }
}
