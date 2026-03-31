package com.muhamed.imsakia

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AthanReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "AthanReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val prayerEn = intent.getStringExtra("prayer_en") ?: "Prayer"
        Log.i(TAG, "[NATIVE_TRIGGER] $prayerEn - Native trigger logic DISABLED (Handled by Flutter Background Isolate)")
        
        // Native Athan triggering has been migrated to the Flutter Background Service.
        // The one-minute precision tick inside the Dart Isolate is now responsible for 
        // playing audio and showing the notification overlay.
    }
}
