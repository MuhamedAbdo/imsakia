package com.muhamed.imsakia

import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.Manifest
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {

    private val NOTIFICATIONS_CHANNEL = "imsakia/notifications"
    private val ATHAN_CONTROL_CHANNEL = "imsakia/athan_control"
    private val NOTIFICATION_PERMISSION_CODE = 1001
    private val TAG = "MainActivity"

    // Stores athan intent args from onCreate so Flutter can query them via
    // 'getPendingAthanIntent' after the engine is booted (cold-start path).
    private var pendingAthanArgs: Map<String, String?>? = null

    // ── onCreate: apply window flags so screen wakes for Athan ──────────────
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Keep screen on, show on lock-screen, turn screen on — required for
        // the full-screen Athan overlay to appear when the device is locked.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }

        requestNotificationPermission()

        // Handle the case where this Activity was started by AthanReceiver or
        // the background service to show the Athan overlay.
        handleAthanIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAthanIntent(intent)
    }

    /**
     * If the launching intent carries `show_athan=true`, signal Dart to
     * navigate to the AthanOverlayScreen.  This is the bridge called when
     * the background service fires an explicit Intent to wake the app.
     */
    private fun handleAthanIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("show_athan", false) != true) return

        val args = mapOf(
            "prayer" to (intent.getStringExtra("prayer_ar") ?: "الصلاة"),
            "prayerEn" to (intent.getStringExtra("prayer_en") ?: "Prayer"),
            "image" to (intent.getStringExtra("prayer_image") ?: "")
        )

        // Store for the cold-start path (Flutter will call getPendingAthanIntent).
        pendingAthanArgs = args

        Log.d(TAG, "handleAthanIntent: show_athan=true detected — signalling Dart via open_athan.")
        // Post with a delay so the Flutter engine is guaranteed to be running.
        window.decorView.postDelayed({
            try {
                val engine = FlutterEngineCache.getInstance().get("main_engine")
                if (engine != null) {
                    MethodChannel(engine.dartExecutor.binaryMessenger, ATHAN_CONTROL_CHANNEL)
                        .invokeMethod("open_athan", args)
                    Log.d(TAG, "handleAthanIntent: open_athan invoked successfully.")
                } else {
                    Log.w(TAG, "handleAthanIntent: engine not cached yet — Flutter will poll via getPendingAthanIntent.")
                }
            } catch (e: Exception) {
                Log.e(TAG, "handleAthanIntent channel invocation error: ${e.message}")
            }
        }, 500)
    }

    // ── configureFlutterEngine: register MethodChannels + cache engine ───────
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Cache the engine so AthanReceiver can reach it without the activity.
        FlutterEngineCache.getInstance().put("main_engine", flutterEngine)

        // ── Channel 1: Notification / Battery settings (existing) ──────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOTIFICATIONS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestNotificationPermission" -> {
                    requestNotificationPermission()
                    result.success(true)
                }
                "openNotificationSettings" -> {
                    openNotificationSettings()
                    result.success(true)
                }
                "openBatteryOptimizationSettings" -> {
                    openBatteryOptimizationSettings()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // ── Channel 2: Athan control (new) ──────────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ATHAN_CONTROL_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                /**
                 * Called by the background Dart isolate when an Athan triggers.
                 * We fire an explicit Intent back to MainActivity with show_athan=true
                 * so the OS guarantees the Activity is brought to front on the lock screen.
                 */
                "launchAthanOverlay" -> {
                    val prayerAr = call.argument<String>("prayer") ?: "الصلاة"
                    val prayerEn = call.argument<String>("prayerEn") ?: "Prayer"
                    val image = call.argument<String>("image") ?: ""
                    Log.d(TAG, "launchAthanOverlay called: $prayerAr ($prayerEn)")
                    launchAthanOverlay(prayerAr, prayerEn, image)
                    result.success(true)
                }

                /**
                 * Returns a PendingIntent action string for the Stop button.
                 * Used by Dart to build the native PendingIntent-based action.
                 */
                "getStopAthanAction" -> {
                    result.success(AthanReceiver.ACTION_STOP_ATHAN)
                }

                /**
                 * Called by Flutter's initState to check whether MainActivity
                 * was launched with a show_athan intent (handles cold-start
                 * when the MethodChannel call from postDelayed arrives before
                 * the Dart handler is registered).
                 */
                "getPendingAthanIntent" -> {
                    val args = pendingAthanArgs
                    pendingAthanArgs = null   // consume once
                    if (args != null) {
                        Log.d(TAG, "getPendingAthanIntent: returning pending args for ${args["prayer"]}")
                        result.success(args)
                    } else {
                        result.success(null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    /**
     * Launches the main Activity with `show_athan=true` so the app
     * comes to the foreground and Dart's `onNewIntent` / `onResume` routes
     * to the AthanOverlayScreen.
     */
    private fun launchAthanOverlay(prayerAr: String, prayerEn: String, image: String) {
        try {
            val intent = Intent(applicationContext, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("show_athan", true)
                putExtra("prayer_ar", prayerAr)
                putExtra("prayer_en", prayerEn)
                putExtra("prayer_image", image)
            }
            applicationContext.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "launchAthanOverlay failed: ${e.message}")
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this, Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_CODE
                )
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (ContextCompat.checkSelfPermission(
                    this, Manifest.permission.SCHEDULE_EXACT_ALARM
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.SCHEDULE_EXACT_ALARM),
                    NOTIFICATION_PERMISSION_CODE
                )
            }
        }
    }

    private fun openNotificationSettings() {
        try {
            val intent = Intent()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                intent.action = "android.settings.APP_NOTIFICATION_SETTINGS"
                intent.putExtra("android.provider.extra.APP_PACKAGE", packageName)
            } else {
                intent.action = "android.settings.APPLICATION_DETAILS_SETTINGS"
                intent.data = Uri.fromParts("package", packageName, null)
            }
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun openBatteryOptimizationSettings() {
        try {
            val intent = Intent()
            intent.action = "android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"
            intent.data = Uri.parse("package:$packageName")
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
