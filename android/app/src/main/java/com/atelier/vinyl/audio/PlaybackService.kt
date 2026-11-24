package com.atelier.vinyl.audio

import android.app.PendingIntent
import android.content.Intent
import android.os.Bundle
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import androidx.media3.session.SessionCommand
import androidx.media3.session.SessionResult
import com.atelier.vinyl.MainActivity
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

/**
 * Background Media3 playback service supporting notification controls,
 * lock-screen metadata, audio focus, and audioSessionId exposure for EQ & FFT.
 */
@OptIn(UnstableApi::class)
class PlaybackService : MediaSessionService() {

    private var player: ExoPlayer? = null
    private var mediaSession: MediaSession? = null

    override fun onCreate() {
        super.onCreate()
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(C.USAGE_MEDIA)
            .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
            .build()

        val exoPlayer = ExoPlayer.Builder(this)
            .setAudioAttributes(audioAttributes, true)
            .setHandleAudioBecomingNoisy(true)
            .build()

        exoPlayer.addListener(object : Player.Listener {
            override fun onAudioSessionIdChanged(audioSessionId: Int) {
                AudioSessionBridge.updateSessionId(audioSessionId)
            }
        })
        AudioSessionBridge.updateSessionId(exoPlayer.audioSessionId)
        player = exoPlayer

        val launchIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        mediaSession = MediaSession.Builder(this, exoPlayer)
            .setSessionActivity(pendingIntent)
            .setCallback(object : MediaSession.Callback {
                override fun onCustomCommand(
                    session: MediaSession,
                    controller: MediaSession.ControllerInfo,
                    customCommand: SessionCommand,
                    args: Bundle
                ): ListenableFuture<SessionResult> {
                    if (customCommand.customAction == CMD_QUERY_AUDIO_SESSION) {
                        val resultBundle = Bundle().apply {
                            putInt(EXTRA_AUDIO_SESSION_ID, exoPlayer.audioSessionId)
                        }
                        return Futures.immediateFuture(SessionResult(SessionResult.RESULT_SUCCESS, resultBundle))
                    }
                    return super.onCustomCommand(session, controller, customCommand, args)
                }
            })
            .build()
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? = mediaSession

    override fun onTaskRemoved(rootIntent: Intent?) {
        val p = player
        if (p == null || !p.playWhenReady || p.mediaItemCount == 0) {
            stopSelf()
        }
    }

    override fun onDestroy() {
        mediaSession?.run {
            player.release()
            release()
            mediaSession = null
        }
        player = null
        super.onDestroy()
    }

    companion object {
        const val CMD_QUERY_AUDIO_SESSION = "com.atelier.vinyl.QUERY_AUDIO_SESSION"
        const val EXTRA_AUDIO_SESSION_ID = "audio_session_id"
    }
}

object AudioSessionBridge {
    @Volatile
    var currentAudioSessionId: Int = 0
        private set

    private var listener: ((Int) -> Unit)? = null

    fun updateSessionId(id: Int) {
        if (id > 0) {
            currentAudioSessionId = id
            listener?.invoke(id)
        }
    }

    fun observe(onChange: (Int) -> Unit) {
        listener = onChange
        if (currentAudioSessionId > 0) {
            onChange(currentAudioSessionId)
        }
    }
}
