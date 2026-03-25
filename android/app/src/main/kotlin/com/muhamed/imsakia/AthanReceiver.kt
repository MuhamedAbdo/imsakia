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

/**
 * AthanReceiver — Native BroadcastReceiver for the Athan Stop action.
 *
 * When the user taps the "إيقاف الأذان" (Stop Athan) button on the notification,
 * the OS delivers a broadcast to this receiver BEFORE Dart gets a chance to handle it.
 *
 * Strategy:
 *  1. Immediately cancel the Athan notification in native Kotlin (instant UI response).
 *  2. Invoke the Flutter MethodChannel `imsakia/athan_control` → `stopAudio` to tell
 *     the background Dart isolate to kill the AudioPlayer.
 *  3. Clear the `athan_is_playing` SharedPreferences flag natively as a safety net.
 */
class AthanReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_STOP_ATHAN = "com.muhamed.imsakia.STOP_ATHAN"
        const val CHANNEL_NAME = "imsakia/athan_control"
        private const val TAG = "AthanReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_STOP_ATHAN) return

        Log.d(TAG, "STOP_ATHAN broadcast received — killing audio immediately.")

        // 1. Cancel every notification instantly (native, zero latency).
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancelAll()

        // 2. Clear the SharedPreferences athan_is_playing flag natively.
        //    This ensures main.dart's onResume check doesn't re-launch the overlay.
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().putBoolean("flutter.athan_is_playing", false).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to clear athan_is_playing in prefs: ${e.message}")
        }

        // 3. Signal the Flutter engine via MethodChannel on the main thread.
        //    We use the cached engine (registered by MainActivity as "main_engine").
        Handler(Looper.getMainLooper()).post {
            try {
                val engine = FlutterEngineCache.getInstance().get("main_engine")
                if (engine != null) {
                    MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME)
                        .invokeMethod("stopAudio", null)
                    Log.d(TAG, "MethodChannel stopAudio invoked on cached engine.")
                } else {
                    Log.w(TAG, "No cached Flutter engine found — audio stop relies on Dart fallback.")
                }
            } catch (e: Exception) {
                Log.e(TAG, "MethodChannel invocation failed: ${e.message}")
            }
        }
    }
}
