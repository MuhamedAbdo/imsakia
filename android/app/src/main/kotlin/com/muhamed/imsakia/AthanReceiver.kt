package com.muhamed.imsakia

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class AthanReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_STOP_ATHAN = "com.muhamed.imsakia.STOP_ATHAN"
        const val CHANNEL_NAME = "imsakia/athan_control"
        private const val TAG = "AthanReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_STOP_ATHAN) return

        Log.d(TAG, "STOP_ATHAN broadcast received.")

        // 1. Instantly stop native audio playback (Production-grade 0-latency)
        NativeAudioController.stop(context)

        // 2. Signal the Flutter engine via MethodChannel (if available) to sync UI state
        Handler(Looper.getMainLooper()).post {
            try {
                val engine = FlutterEngineCache.getInstance().get("main_engine")
                if (engine != null) {
                    MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME)
                        .invokeMethod("stopAudio", null)
                }
            } catch (e: Exception) {
                Log.e(TAG, "MethodChannel invocation failed: \${e.message}")
            }
        }
    }
}
