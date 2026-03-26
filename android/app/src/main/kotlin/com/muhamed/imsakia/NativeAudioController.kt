package com.muhamed.imsakia

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.util.Log

object NativeAudioController {
    private const val TAG = "NativeAudioController"
    private var mediaPlayer: MediaPlayer? = null
    private var audioManager: AudioManager? = null
    private var focusRequest: AudioFocusRequest? = null
    private var wakeLock: PowerManager.WakeLock? = null

    private val audioFocusChangeListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            AudioManager.AUDIOFOCUS_LOSS -> stop()
        }
    }

    fun play(context: Context, assetPath: String, lock: PowerManager.WakeLock? = null) {
        stop() // Guard against multiple simultaneous athans
        wakeLock = lock

        try {
            audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager?
            mediaPlayer = MediaPlayer()

            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()

            mediaPlayer?.setAudioAttributes(audioAttributes)

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
            // The Dart path typically looks like "assets/audio/athan.mp3"
            val flutterAssetPath = "flutter_assets/$assetPath"
            
            Log.d(TAG, "Attempting to play: $flutterAssetPath")
            
            val afd = context.assets.openFd(flutterAssetPath)
            mediaPlayer?.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            afd.close()

            mediaPlayer?.setOnCompletionListener {
                stop()
            }

            // prepareAsync prevents blocking the main thread (BroadcastReceiver/Activity)
            mediaPlayer?.setOnPreparedListener { mp ->
                mp.start()
                Log.d(TAG, "Playing Native Athan Successfully: $flutterAssetPath")
            }
            mediaPlayer?.prepareAsync()

        } catch (e: Exception) {
            Log.e(TAG, "Failed to play native audio: ${e.message}")
            e.printStackTrace()
            stop()
        }
    }

    fun stop() {
        try {
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
            
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                    Log.d(TAG, "WakeLock released explicitly")
                }
            }
            wakeLock = null

            Log.d(TAG, "Native Athan stopped and focus abandoned")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping audio: ${e.message}")
        }
    }
}
