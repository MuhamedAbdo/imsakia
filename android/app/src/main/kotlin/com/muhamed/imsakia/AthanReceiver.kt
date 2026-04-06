package com.muhamed.imsakia

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager

class AthanReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        System.err.println("!!! ATHAN RECEIVER: Triggered !!!")
        
        // Start Service
        val serviceIntent = Intent(context, AthanService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (e: Exception) { e.printStackTrace() }

        // Force Wake Screen
        try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val wakeLock = powerManager.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
                "Imsakia:WakeLock"
            )
            wakeLock.acquire(15000) // 15 seconds
        } catch (e: Exception) { e.printStackTrace() }
    }
}