package com.atelier.vinyl.audio

import android.app.Application
import android.content.ComponentName
import android.content.Context
import android.media.audiofx.Equalizer
import android.media.audiofx.Visualizer
import android.net.Uri
import android.os.Bundle
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.session.MediaController
import androidx.media3.session.SessionCommand
import androidx.media3.session.SessionToken
import com.atelier.vinyl.model.AppLanguage
import com.atelier.vinyl.model.AppSettingsState
import com.atelier.vinyl.model.AppThemeMode
import com.atelier.vinyl.model.EqPreset
import com.atelier.vinyl.model.Playlist
import com.atelier.vinyl.model.RepeatMode
import com.atelier.vinyl.model.ScreenRoute
import com.atelier.vinyl.model.SpectrumFrame
import com.atelier.vinyl.model.VinylTrack
import com.google.common.util.concurrent.ListenableFuture
import com.google.common.util.concurrent.MoreExecutors
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.hypot
import kotlin.math.min
import kotlin.math.pow

private val Context.vinylDataStore by preferencesDataStore(name = "atelier_lp01_prefs")

class PlayerController(application: Application) : AndroidViewModel(application) {

    private val ctx: Context = application.applicationContext

    private val _tracks = MutableStateFlow<List<VinylTrack>>(emptyList())
    val tracks: StateFlow<List<VinylTrack>> = _tracks.asStateFlow()

    private val _currentTrack = MutableStateFlow<VinylTrack?>(null)
    val currentTrack: StateFlow<VinylTrack?> = _currentTrack.asStateFlow()

    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()

    private val _positionMs = MutableStateFlow(0L)
    val positionMs: StateFlow<Long> = _positionMs.asStateFlow()

    private val _durationMs = MutableStateFlow(165_000L)
    val durationMs: StateFlow<Long> = _durationMs.asStateFlow()

    private val _queueIds = MutableStateFlow<List<String>>(emptyList())
    val queueIds: StateFlow<List<String>> = _queueIds.asStateFlow()

    private val _favoriteIds = MutableStateFlow<Set<String>>(setOf("trk-daylight", "trk-one-week-last", "trk-horizon"))
    val favoriteIds: StateFlow<Set<String>> = _favoriteIds.asStateFlow()

    private val _playlists = MutableStateFlow<List<Playlist>>(emptyList())
    val playlists: StateFlow<List<Playlist>> = _playlists.asStateFlow()

    private val _shuffle = MutableStateFlow(false)
    val shuffle: StateFlow<Boolean> = _shuffle.asStateFlow()

    private val _repeat = MutableStateFlow(RepeatMode.ALL)
    val repeat: StateFlow<RepeatMode> = _repeat.asStateFlow()

    private val _volume = MutableStateFlow(0.85f)
    val volume: StateFlow<Float> = _volume.asStateFlow()

    private val _settings = MutableStateFlow(AppSettingsState())
    val settings: StateFlow<AppSettingsState> = _settings.asStateFlow()

    private val _spectrum = MutableStateFlow(SpectrumFrame())
    val spectrum: StateFlow<SpectrumFrame> = _spectrum.asStateFlow()

    private val _eqEnabled = MutableStateFlow(true)
    val eqEnabled: StateFlow<Boolean> = _eqEnabled.asStateFlow()

    private val _eqPresetId = MutableStateFlow("vinyl_warm")
    val eqPresetId: StateFlow<String> = _eqPresetId.asStateFlow()

    private val _eqGainsDb = MutableStateFlow(listOf(3.5f, 2.0f, -0.5f, -1.5f, -1.0f))
    val eqGainsDb: StateFlow<List<Float>> = _eqGainsDb.asStateFlow()

    private val _sleepRemainingSec = MutableStateFlow<Int?>(null)
    val sleepRemainingSec: StateFlow<Int?> = _sleepRemainingSec.asStateFlow()

    private val _screen = MutableStateFlow(ScreenRoute.EXPLORE)
    val screen: StateFlow<ScreenRoute> = _screen.asStateFlow()

    private val _previousScreen = MutableStateFlow(ScreenRoute.EXPLORE)
    val previousScreen: StateFlow<ScreenRoute> = _previousScreen.asStateFlow()

    private val _lastBrowseScreen = MutableStateFlow(ScreenRoute.EXPLORE)

    val eqPresets = listOf(
        EqPreset("flat", "Reference Flat", "مرجع خنثی", listOf(0f, 0f, 0f, 0f, 0f)),
        EqPreset("vinyl_warm", "Warm Analog", "گرمای آنالوگ", listOf(3.5f, 2.0f, -0.5f, -1.5f, -1.0f)),
        EqPreset("deep_bass", "Deep Plinth Bass", "بیس عمیق", listOf(6.0f, 3.5f, 0f, 1.0f, 2.0f)),
        EqPreset("vocal_clarity", "Vocal Presence", "وضوح صدا", listOf(-1.5f, 0.5f, 3.5f, 4.0f, 2.0f)),
        EqPreset("late_night", "Late Night", "شبانه نرم", listOf(2.5f, 1.0f, -1.0f, 1.5f, 2.5f)),
    )

    private var controllerFuture: ListenableFuture<MediaController>? = null
    private var mediaController: MediaController? = null
    private var equalizer: Equalizer? = null
    private var visualizer: Visualizer? = null
    private var sleepJob: Job? = null
    private val smoothedBars = FloatArray(13)

    init {
        viewModelScope.launch {
            initializeCatalogAndRestoreState()
        }
        connectMediaService()
        startProgressLoop()
    }

    private suspend fun initializeCatalogAndRestoreState() {
        val demos = kotlinx.coroutines.withContext(Dispatchers.IO) {
            ProceduralPressingGenerator.ensureDemoTracks(ctx)
        }
        val prefs = ctx.vinylDataStore.data.first()

        val theme = if (prefs[KEY_THEME] == "DARK") AppThemeMode.DARK else AppThemeMode.LIGHT
        val lang = if (prefs[KEY_LANG] == "FA") AppLanguage.FA else AppLanguage.EN
        _settings.value = AppSettingsState(
            themeMode = theme,
            language = lang,
            reduceMotion = prefs[KEY_REDUCE_MOTION] ?: false,
            hapticsEnabled = prefs[KEY_HAPTICS] ?: true,
            vinylCrackle = prefs[KEY_CRACKLE] ?: true
        )
        _shuffle.value = prefs[KEY_SHUFFLE] ?: false
        _repeat.value = runCatching { RepeatMode.valueOf(prefs[KEY_REPEAT] ?: "ALL") }.getOrDefault(RepeatMode.ALL)
        _volume.value = prefs[KEY_VOLUME] ?: 0.85f
        _eqEnabled.value = prefs[KEY_EQ_ENABLED] ?: true
        _eqPresetId.value = prefs[KEY_EQ_PRESET] ?: "vinyl_warm"

        prefs[KEY_EQ_GAINS]?.let { raw ->
            val parts = raw.split(",").mapNotNull { it.toFloatOrNull() }
            if (parts.size == 5) _eqGainsDb.value = parts
        }

        prefs[KEY_FAVORITES]?.let { raw ->
            _favoriteIds.value = raw.split(",").filter { it.isNotBlank() }.toSet()
        }

        val defaultPlaylists = listOf(
            Playlist("pl-atelier", "Atelier Reference Crate", listOf("trk-daylight", "trk-one-week-last", "trk-horizon", "trk-dreams")),
            Playlist("pl-mono", "Monochrome Minimal", listOf("trk-forgotten", "trk-phantom", "trk-nocturne"))
        )
        _playlists.value = prefs[KEY_PLAYLISTS]?.let { decodePlaylists(it) } ?: defaultPlaylists

        _tracks.value = demos
        _queueIds.value = demos.map { it.id }

        val savedId = prefs[KEY_LAST_TRACK_ID] ?: "trk-daylight"
        val restored = demos.firstOrNull { it.id == savedId } ?: demos.firstOrNull()
        _currentTrack.value = restored
        if (restored != null) {
            _durationMs.value = restored.durationMs
            _positionMs.value = prefs[KEY_LAST_POS_MS] ?: 0L
        }
    }

    private fun connectMediaService() {
        val token = SessionToken(ctx, ComponentName(ctx, PlaybackService::class.java))
        val future = MediaController.Builder(ctx, token).buildAsync()
        controllerFuture = future
        future.addListener({
            runCatching {
                val ctrl = future.get()
                mediaController = ctrl
                ctrl.volume = _volume.value
                syncRepeatShuffleToPlayer(ctrl)

                ctrl.addListener(object : Player.Listener {
                    override fun onIsPlayingChanged(playing: Boolean) {
                        _isPlaying.value = playing
                        if (!playing) decaySpectrum()
                    }

                    override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
                        val id = mediaItem?.mediaId ?: return
                        _tracks.value.firstOrNull { it.id == id }?.let { trk ->
                            _currentTrack.value = trk
                            _durationMs.value = trk.durationMs
                            persistPlaybackState()
                        }
                    }

                    override fun onPlaybackStateChanged(playbackState: Int) {
                        if (playbackState == Player.STATE_READY && ctrl.duration > 0) {
                            _durationMs.value = ctrl.duration
                        }
                    }
                })

                val existingSessionId = AudioSessionBridge.currentAudioSessionId
                if (existingSessionId > 0) {
                    attachAudioEffects(existingSessionId)
                } else {
                    ctrl.sendCustomCommand(SessionCommand(PlaybackService.CMD_QUERY_AUDIO_SESSION, Bundle.EMPTY), Bundle.EMPTY)
                        .addListener({
                            val sid = AudioSessionBridge.currentAudioSessionId
                            if (sid > 0) attachAudioEffects(sid)
                        }, MoreExecutors.directExecutor())
                }
                AudioSessionBridge.observe { sid -> attachAudioEffects(sid) }

                // Load initial track cleanly without auto-playing until user taps Play
                _currentTrack.value?.let { prepareMediaQueue(it, autoPlay = false, seekMs = _positionMs.value) }
            }
        }, MoreExecutors.directExecutor())
    }

    fun attachAudioEffects(audioSessionId: Int) {
        if (audioSessionId <= 0) return
        runCatching {
            equalizer?.release()
            equalizer = Equalizer(0, audioSessionId).apply {
                enabled = _eqEnabled.value
                applyEqBandsToHardware(this, _eqGainsDb.value)
            }
        }
        runCatching {
            visualizer?.release()
            visualizer = Visualizer(audioSessionId).apply {
                captureSize = Visualizer.getCaptureSizeRange()[1].coerceAtMost(1024)
                setDataCaptureListener(object : Visualizer.OnDataCaptureListener {
                    override fun onWaveFormDataCapture(v: Visualizer?, waveform: ByteArray?, samplingRate: Int) = Unit
                    override fun onFftDataCapture(v: Visualizer?, fft: ByteArray?, samplingRate: Int) {
                        if (fft != null && _isPlaying.value) {
                            updateFftSpectrum(fft)
                        }
                    }
                }, Visualizer.getMaxCaptureRate() / 2, false, true)
                enabled = true
            }
        }
    }

    private fun applyEqBandsToHardware(eq: Equalizer, gainsDb: List<Float>) {
        val numBands = eq.numberOfBands.toInt()
        val range = eq.bandLevelRange
        val minMb = range[0].toFloat()
        val maxMb = range[1].toFloat()
        for (i in 0 until min(numBands, gainsDb.size)) {
            val millibels = (gainsDb[i] * 100f).coerceIn(minMb, maxMb).toInt().toShort()
            eq.setBandLevel(i.toShort(), millibels)
        }
    }

    private fun updateFftSpectrum(fft: ByteArray) {
        val n = fft.size / 2
        if (n < 16) return
        val magnitudes = FloatArray(n)
        magnitudes[0] = kotlin.math.abs(fft[0].toInt()).toFloat()
        for (k in 1 until n) {
            val re = fft[2 * k].toFloat()
            val im = fft[2 * k + 1].toFloat()
            magnitudes[k] = hypot(re, im)
        }

        fun bandAvg(startBin: Int, endBin: Int): Float {
            val s = startBin.coerceIn(1, n - 1)
            val e = endBin.coerceIn(s, n - 1)
            var sum = 0f
            for (i in s..e) sum += magnitudes[i]
            return ((sum / (e - s + 1)) / 68f).coerceIn(0f, 1f)
        }

        val bass = bandAvg(1, 7)
        val mid = bandAvg(8, 36)
        val treble = bandAvg(37, min(n - 1, 140))

        val ranges = arrayOf(
            90 to 130, 62 to 90, 42 to 62, 26 to 42, 15 to 26, 8 to 15,
            1 to 7,
            8 to 15, 15 to 26, 26 to 42, 42 to 62, 62 to 90, 90 to 130
        )

        val outBars = List(13) { idx ->
            val (s, e) = ranges[idx]
            val target = bandAvg(s, e).pow(0.85f)
            smoothedBars[idx] = smoothedBars[idx] * 0.6f + target * 0.4f
            smoothedBars[idx]
        }

        _spectrum.value = SpectrumFrame(bars = outBars, bass = bass, mid = mid, treble = treble)
    }

    private fun decaySpectrum() {
        viewModelScope.launch {
            repeat(12) {
                if (_isPlaying.value) return@launch
                for (i in smoothedBars.indices) smoothedBars[i] *= 0.78f
                _spectrum.value = _spectrum.value.copy(
                    bars = smoothedBars.toList(),
                    bass = _spectrum.value.bass * 0.78f,
                    mid = _spectrum.value.mid * 0.78f,
                    treble = _spectrum.value.treble * 0.78f
                )
                delay(32)
            }
        }
    }

    private fun startProgressLoop() {
        viewModelScope.launch {
            var persistTicks = 0
            while (true) {
                val ctrl = mediaController
                if (ctrl != null && ctrl.mediaItemCount > 0) {
                    _positionMs.value = ctrl.currentPosition.coerceAtLeast(0L)
                    if (ctrl.duration > 0) _durationMs.value = ctrl.duration
                    persistTicks++
                    if (persistTicks >= 6) {
                        persistTicks = 0
                        persistPlaybackState()
                    }
                }
                delay(180)
            }
        }
    }

    private fun prepareMediaQueue(startTrack: VinylTrack, autoPlay: Boolean, seekMs: Long = 0L) {
        val ctrl = mediaController ?: return
        val allMap = _tracks.value.associateBy { it.id }
        val qTracks = _queueIds.value.mapNotNull { allMap[it] }.ifEmpty { _tracks.value }
        val startIndex = qTracks.indexOfFirst { it.id == startTrack.id }.coerceAtLeast(0)

        val mediaItems = qTracks.map { trk ->
            MediaItem.Builder()
                .setMediaId(trk.id)
                .setUri(trk.uri)
                .setMediaMetadata(
                    MediaMetadata.Builder()
                        .setTitle(trk.title)
                        .setArtist(trk.artist)
                        .setAlbumTitle(trk.album)
                        .build()
                )
                .build()
        }

        ctrl.setMediaItems(mediaItems, startIndex, seekMs)
        ctrl.prepare()
        ctrl.playWhenReady = autoPlay
        _currentTrack.value = startTrack
        _durationMs.value = startTrack.durationMs
        _positionMs.value = seekMs
    }

    fun navigateTo(route: ScreenRoute) {
        val current = _screen.value
        if (route != current) {
            if (current in setOf(ScreenRoute.HOME, ScreenRoute.EXPLORE, ScreenRoute.LIBRARY, ScreenRoute.SEARCH)) {
                _lastBrowseScreen.value = current
            }
            _previousScreen.value = current
            _screen.value = route
        }
    }

    fun navigateBack() {
        val current = _screen.value
        if (current == ScreenRoute.NOW_PLAYING) {
            _screen.value = _lastBrowseScreen.value
        } else {
            val prev = _previousScreen.value
            _screen.value = if (prev == current) ScreenRoute.EXPLORE else prev
        }
    }

    fun playTrack(track: VinylTrack, openDeck: Boolean = false) {
        if (!_queueIds.value.contains(track.id)) {
            _queueIds.value = listOf(track.id) + _queueIds.value
        }
        prepareMediaQueue(track, autoPlay = true, seekMs = 0L)
        if (openDeck) navigateTo(ScreenRoute.NOW_PLAYING)
        persistPlaybackState()
    }

    fun selectCenterTrack(track: VinylTrack) {
        if (!_isPlaying.value) {
            _currentTrack.value = track
            _durationMs.value = track.durationMs
            _positionMs.value = 0L
            prepareMediaQueue(track, autoPlay = false, seekMs = 0L)
        }
    }

    fun togglePlayPause() {
        val ctrl = mediaController ?: return
        if (ctrl.isPlaying) {
            ctrl.pause()
        } else {
            if (ctrl.mediaItemCount == 0 && _currentTrack.value != null) {
                prepareMediaQueue(_currentTrack.value!!, autoPlay = true, seekMs = _positionMs.value)
            } else {
                ctrl.play()
            }
        }
    }

    fun seekTo(ms: Long) {
        val clamped = ms.coerceIn(0L, _durationMs.value.coerceAtLeast(1L))
        _positionMs.value = clamped
        mediaController?.seekTo(clamped)
    }

    fun skipNext() {
        mediaController?.seekToNextMediaItem()
    }

    fun skipPrevious() {
        val ctrl = mediaController ?: return
        if (ctrl.currentPosition > 3000L) {
            ctrl.seekTo(0L)
        } else {
            ctrl.seekToPreviousMediaItem()
        }
    }

    fun toggleShuffle() {
        _shuffle.value = !_shuffle.value
        mediaController?.let { syncRepeatShuffleToPlayer(it) }
        persistPlaybackState()
    }

    fun cycleRepeat() {
        _repeat.value = when (_repeat.value) {
            RepeatMode.OFF -> RepeatMode.ALL
            RepeatMode.ALL -> RepeatMode.ONE
            RepeatMode.ONE -> RepeatMode.OFF
        }
        mediaController?.let { syncRepeatShuffleToPlayer(it) }
        persistPlaybackState()
    }

    private fun syncRepeatShuffleToPlayer(ctrl: MediaController) {
        ctrl.shuffleModeEnabled = _shuffle.value
        ctrl.repeatMode = when (_repeat.value) {
            RepeatMode.OFF -> Player.REPEAT_MODE_OFF
            RepeatMode.ALL -> Player.REPEAT_MODE_ALL
            RepeatMode.ONE -> Player.REPEAT_MODE_ONE
        }
    }

    fun setVolume(v: Float) {
        val clamped = v.coerceIn(0f, 1f)
        _volume.value = clamped
        mediaController?.volume = clamped
        persistPlaybackState()
    }

    fun toggleFavorite(trackId: String) {
        val cur = _favoriteIds.value.toMutableSet()
        if (!cur.add(trackId)) cur.remove(trackId)
        _favoriteIds.value = cur
        persistPlaybackState()
    }

    fun addToQueue(trackId: String) {
        val updated = _queueIds.value.filter { it != trackId } + trackId
        _queueIds.value = updated
        _currentTrack.value?.let { prepareMediaQueue(it, autoPlay = _isPlaying.value, seekMs = _positionMs.value) }
    }

    fun playPlaylist(list: List<VinylTrack>) {
        if (list.isEmpty()) return
        _queueIds.value = list.map { it.id }
        playTrack(list.first(), openDeck = true)
    }

    fun createPlaylist(name: String) {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return
        _playlists.value = listOf(Playlist("pl-${System.currentTimeMillis()}", trimmed, emptyList())) + _playlists.value
        persistPlaylists()
    }

    fun deletePlaylist(id: String) {
        _playlists.value = _playlists.value.filterNot { it.id == id }
        persistPlaylists()
    }

    fun addTrackToPlaylist(playlistId: String, trackId: String) {
        _playlists.value = _playlists.value.map { pl ->
            if (pl.id == playlistId && !pl.trackIds.contains(trackId)) pl.copy(trackIds = pl.trackIds + trackId) else pl
        }
        persistPlaylists()
    }

    fun moveQueueItem(index: Int, delta: Int) {
        val list = _queueIds.value.toMutableList()
        val target = index + delta
        if (index !in list.indices || target !in list.indices) return
        val item = list.removeAt(index)
        list.add(target, item)
        _queueIds.value = list
    }

    fun toggleEqEnabled() {
        _eqEnabled.value = !_eqEnabled.value
        runCatching { equalizer?.enabled = _eqEnabled.value }
        persistPlaybackState()
    }

    fun selectEqPreset(preset: EqPreset) {
        _eqPresetId.value = preset.id
        _eqGainsDb.value = preset.gainsDb
        _eqEnabled.value = true
        equalizer?.let { eq ->
            runCatching {
                eq.enabled = true
                applyEqBandsToHardware(eq, preset.gainsDb)
            }
        }
        persistPlaybackState()
    }

    fun setEqBand(bandIdx: Int, gainDb: Float) {
        val next = _eqGainsDb.value.toMutableList()
        if (bandIdx in next.indices) {
            next[bandIdx] = gainDb.coerceIn(-12f, 12f)
            _eqGainsDb.value = next
            _eqPresetId.value = "custom"
            equalizer?.let { eq -> runCatching { applyEqBandsToHardware(eq, next) } }
            persistPlaybackState()
        }
    }

    fun updateSettings(transform: (AppSettingsState) -> AppSettingsState) {
        val next = transform(_settings.value)
        _settings.value = next
        viewModelScope.launch {
            ctx.vinylDataStore.edit { p ->
                p[KEY_THEME] = next.themeMode.name
                p[KEY_LANG] = next.language.name
                p[KEY_REDUCE_MOTION] = next.reduceMotion
                p[KEY_HAPTICS] = next.hapticsEnabled
                p[KEY_CRACKLE] = next.vinylCrackle
            }
        }
    }

    fun setSleepTimer(minutes: Int?) {
        sleepJob?.cancel()
        _settings.value = _settings.value.copy(sleepTimerMinutes = minutes)
        if (minutes == null || minutes <= 0) {
            _sleepRemainingSec.value = null
            return
        }
        _sleepRemainingSec.value = minutes * 60
        sleepJob = viewModelScope.launch {
            while ((_sleepRemainingSec.value ?: 0) > 0) {
                delay(1000)
                val next = (_sleepRemainingSec.value ?: 0) - 1
                _sleepRemainingSec.value = next
                if (next <= 0) {
                    mediaController?.pause()
                    _settings.value = _settings.value.copy(sleepTimerMinutes = null)
                    _sleepRemainingSec.value = null
                    break
                }
            }
        }
    }

    fun scanDeviceAudio() {
        viewModelScope.launch {
            val found = MediaScannerAndImporter.scanDeviceMediaStore(ctx)
            if (found.isNotEmpty()) {
                val existingIds = _tracks.value.map { it.id }.toSet()
                val fresh = found.filterNot { existingIds.contains(it.id) }
                if (fresh.isNotEmpty()) {
                    _tracks.value = fresh + _tracks.value
                    _queueIds.value = fresh.map { it.id } + _queueIds.value
                }
            }
        }
    }

    fun importAudioFiles(uris: List<Uri>) {
        if (uris.isEmpty()) return
        viewModelScope.launch {
            val imported = MediaScannerAndImporter.importAudioUris(ctx, uris)
            if (imported.isNotEmpty()) {
                _tracks.value = imported + _tracks.value
                _queueIds.value = imported.map { it.id } + _queueIds.value
                playTrack(imported.first(), openDeck = true)
            }
        }
    }

    private fun persistPlaybackState() {
        viewModelScope.launch {
            ctx.vinylDataStore.edit { p ->
                p[KEY_LAST_TRACK_ID] = _currentTrack.value?.id ?: "trk-daylight"
                p[KEY_LAST_POS_MS] = _positionMs.value
                p[KEY_SHUFFLE] = _shuffle.value
                p[KEY_REPEAT] = _repeat.value.name
                p[KEY_VOLUME] = _volume.value
                p[KEY_EQ_ENABLED] = _eqEnabled.value
                p[KEY_EQ_PRESET] = _eqPresetId.value
                p[KEY_EQ_GAINS] = _eqGainsDb.value.joinToString(",")
                p[KEY_FAVORITES] = _favoriteIds.value.joinToString(",")
            }
        }
    }

    private fun persistPlaylists() {
        val arr = JSONArray()
        _playlists.value.forEach { pl ->
            val obj = JSONObject()
            obj.put("id", pl.id)
            obj.put("name", pl.name)
            obj.put("trackIds", JSONArray(pl.trackIds))
            arr.put(obj)
        }
        viewModelScope.launch {
            ctx.vinylDataStore.edit { p -> p[KEY_PLAYLISTS] = arr.toString() }
        }
    }

    private fun decodePlaylists(json: String): List<Playlist>? = runCatching {
        val arr = JSONArray(json)
        List(arr.length()) { i ->
            val obj = arr.getJSONObject(i)
            val ids = obj.getJSONArray("trackIds")
            Playlist(
                id = obj.getString("id"),
                name = obj.getString("name"),
                trackIds = List(ids.length()) { j -> ids.getString(j) }
            )
        }
    }.getOrNull()

    override fun onCleared() {
        visualizer?.release()
        equalizer?.release()
        controllerFuture?.let { MediaController.releaseFuture(it) }
        super.onCleared()
    }

    companion object {
        private val KEY_THEME = stringPreferencesKey("theme")
        private val KEY_LANG = stringPreferencesKey("language")
        private val KEY_REDUCE_MOTION = booleanPreferencesKey("reduce_motion")
        private val KEY_HAPTICS = booleanPreferencesKey("haptics")
        private val KEY_CRACKLE = booleanPreferencesKey("crackle")
        private val KEY_LAST_TRACK_ID = stringPreferencesKey("last_track_id")
        private val KEY_LAST_POS_MS = longPreferencesKey("last_pos_ms")
        private val KEY_SHUFFLE = booleanPreferencesKey("shuffle")
        private val KEY_REPEAT = stringPreferencesKey("repeat")
        private val KEY_VOLUME = floatPreferencesKey("volume")
        private val KEY_EQ_ENABLED = booleanPreferencesKey("eq_enabled")
        private val KEY_EQ_PRESET = stringPreferencesKey("eq_preset")
        private val KEY_EQ_GAINS = stringPreferencesKey("eq_gains")
        private val KEY_FAVORITES = stringPreferencesKey("favorites")
        private val KEY_PLAYLISTS = stringPreferencesKey("playlists")
    }
}
