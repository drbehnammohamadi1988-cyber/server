package com.atelier.vinyl.model

import android.net.Uri

enum class RepeatMode {
    OFF, ALL, ONE
}

enum class AppThemeMode {
    LIGHT, DARK
}

enum class AppLanguage {
    EN, FA
}

enum class ScreenRoute {
    HOME,
    EXPLORE,
    NOW_PLAYING,
    LIBRARY,
    ALBUMS,
    ARTISTS,
    PLAYLISTS,
    FAVORITES,
    SEARCH,
    QUEUE,
    EQUALIZER,
    SETTINGS
}

enum class TurntablePhase {
    PARKED,
    CUEING_IN,
    PLAYING,
    PAUSED_HOVER,
    RETURNING,
    SCRATCHING
}

enum class CoverMotif {
    ARCHIVE_DAYLIGHT,
    HORIZON_YELLOW,
    DREAMS_STRIPE,
    CASSETTE_PORTRAIT,
    CRIMSON_BAUHAUS,
    FORGOTTEN_MIST,
    PHANTOM_ARCH,
    ONE_WEEK_IVORY,
    NOCTURNE_SILVER,
    SOLSTICE_SLATE
}

data class SynthSpec(
    val bpm: Float,
    val rootMidi: Int,
    val mode: String,
    val warmth: Float,
    val grooveIntensity: Float
)

data class VinylTrack(
    val id: String,
    val title: String,
    val artist: String,
    val album: String,
    val durationMs: Long,
    val uri: Uri,
    val format: String,
    val coverMotif: CoverMotif,
    val embeddedArtBytes: ByteArray? = null,
    val albumArtUri: Uri? = null,
    val isDemo: Boolean = false,
    val synthSpec: SynthSpec? = null
)

data class Playlist(
    val id: String,
    val name: String,
    val trackIds: List<String>,
    val createdAtMs: Long = System.currentTimeMillis()
)

data class EqPreset(
    val id: String,
    val nameEn: String,
    val nameFa: String,
    val gainsDb: List<Float>
)

data class SpectrumFrame(
    val bars: List<Float> = List(13) { 0f },
    val bass: Float = 0f,
    val mid: Float = 0f,
    val treble: Float = 0f
)

data class AppSettingsState(
    val themeMode: AppThemeMode = AppThemeMode.LIGHT,
    val language: AppLanguage = AppLanguage.EN,
    val reduceMotion: Boolean = false,
    val hapticsEnabled: Boolean = true,
    val vinylCrackle: Boolean = true,
    val sleepTimerMinutes: Int? = null
)
