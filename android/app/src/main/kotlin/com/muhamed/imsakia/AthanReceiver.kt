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
        val prayerName = intent.getStringExtra("prayer_name") ?: "الصلاة"
        val prayerKey = intent.getStringExtra("prayer_key") ?: "dhuhr"
        val alarmId = intent.getIntExtra("alarm_id", 0)
        
        val serviceIntent = Intent(context, AthanService::class.java).apply {
            putExtra("prayer_name", prayerName)
            putExtra("prayer_key", prayerKey)
            putExtra("alarm_id", alarmId)
        }
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (e: Exception) { e.printStackTrace() }

        // Force Wake Screen & Start Activity early if possible
        try {
            val intentToMain = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                putExtra("trigger_athan_overlay", true)
                putExtra("prayer_name", prayerName)
            }
            context.startActivity(intentToMain)
            System.err.println("!!! ATHAN RECEIVER: Early startActivity attempt sent !!!")
            
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val wakeLock = powerManager.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
                "Imsakia:WakeLock"
            )
            wakeLock.acquire(15000) // 15 seconds
        } catch (e: Exception) { e.printStackTrace() }
    }
}