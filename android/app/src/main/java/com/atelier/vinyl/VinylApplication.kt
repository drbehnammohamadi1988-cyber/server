package com.atelier.vinyl

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

class VinylApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                PLAYBACK_CHANNEL_ID,
                "Atelier LP-01 Playback",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Active turntable playback & lock-screen controls"
                setShowBadge(false)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm?.createNotificationChannel(channel)
        }
    }

    companion object {
        const val PLAYBACK_CHANNEL_ID = "atelier_playback_channel"
    }
}
