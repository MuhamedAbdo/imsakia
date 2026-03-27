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
        stop(context) // Guard against multiple simultaneous athans
        applicationContext = context.applicationContext
        wakeLock = lock

        try {
            audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager?
            mediaPlayer = MediaPlayer()

            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()

            mediaPlayer?.setAudioAttributes(audioAttributes)

            // Read latest volume from SharedPreferences robustly
            var userVolume = 1.0f
            try {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val allPrefs = prefs.all
                val volumeVal = allPrefs["flutter.athan_volume"]
                if (volumeVal is Double) {
                    userVolume = volumeVal.toFloat()
                } else if (volumeVal is Float) {
                    userVolume = volumeVal
                } else if (volumeVal is Long) {
                    userVolume = java.lang.Double.longBitsToDouble(volumeVal).toFloat()
                } else if (volumeVal is String) {
                    if (volumeVal.startsWith("VGhpc2lzVGhlUHJlZml4")) {
                        userVolume = volumeVal.replace("VGhpc2lzVGhlUHJlZml4", "").toFloatOrNull() ?: 1.0f
                    } else {
                        userVolume = volumeVal.toFloatOrNull() ?: 1.0f
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing volume from prefs, fallback to 1.0f")
            }
            mediaPlayer?.setVolume(userVolume, userVolume)

            // Request Audio Focus to duck other audio naturally
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                    .setAudioAttributes(audioAttributes)
                    .setAcceptsDelayedFocusGain(true)
                    .setOnAudioFocusChangeListener(audioFocusChangeListener)
                    .build()
                audioManager?.requestAudioFocus(focusRequest!!)
            } else {
                @Suppress("DEPRECATION")
                audioManager?.requestAudioFocus(
                    audioFocusChangeListener,
                    AudioManager.STREAM_ALARM,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
                )
            }

            // Load file from flutter_assets
            val flutterAssetPath = "flutter_assets/$assetPath"
            
            Log.d(TAG, "Attempting to play: $flutterAssetPath")
            
            val afd = context.assets.openFd(flutterAssetPath)
            mediaPlayer?.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            afd.close()

            mediaPlayer?.setOnCompletionListener {
                stop(context)
            }

            mediaPlayer?.setOnPreparedListener { mp ->
                mp.start()
                Log.d(TAG, "Playing Native Athan Successfully: $flutterAssetPath")
            }
            mediaPlayer?.prepareAsync()

        } catch (e: Exception) {
            Log.e(TAG, "Failed to play native audio: \${e.message}")
            e.printStackTrace()
            stop(context)
        }
    }

    fun setVolume(volume: Float) {
        mediaPlayer?.let {
            if (it.isPlaying) {
                it.setVolume(volume, volume)
            }
        }
    }

    fun stop(context: Context?) {
        try {
            mediaPlayer?.setOnCompletionListener(null)
            if (mediaPlayer?.isPlaying == true) {
                mediaPlayer?.stop()
            }
            mediaPlayer?.release()
            mediaPlayer = null
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                focusRequest?.let { audioManager?.abandonAudioFocusRequest(it) }
            } else {
                @Suppress("DEPRECATION")
                audioManager?.abandonAudioFocus(audioFocusChangeListener)
            }
            
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
                Log.d(TAG, "WakeLock released explicitly")
            }
            wakeLock = null

            // Stop Foreground service if any
            context?.stopService(Intent(context, NativeAthanService::class.java))

            // Cancel exact notification only constraint
            val notificationManager = context?.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            notificationManager?.cancel(5001) // ATHAN_NOTIFICATION_ID

            // Reset SharedPreferences naturally
            try {
                val prefs = context?.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                prefs?.edit()?.putBoolean("flutter.athan_is_playing", false)?.apply()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to clear athan_is_playing in prefs: \${e.message}")
            }

            Log.d(TAG, "Native Athan stopped and focus abandoned")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping audio: \${e.message}")
        }
    }
}
