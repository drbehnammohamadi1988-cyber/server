package com.atelier.vinyl

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.core.content.ContextCompat
import com.atelier.vinyl.audio.PlayerController
import com.atelier.vinyl.model.AppLanguage
import com.atelier.vinyl.model.AppThemeMode
import com.atelier.vinyl.model.ScreenRoute
import com.atelier.vinyl.ui.components.AtelierBottomNavBar
import com.atelier.vinyl.ui.components.FloatingMiniPlayer
import com.atelier.vinyl.ui.screens.AlbumsRouteScreen
import com.atelier.vinyl.ui.screens.ArtistsRouteScreen
import com.atelier.vinyl.ui.screens.EqualizerRouteScreen
import com.atelier.vinyl.ui.screens.ExploreRouteScreen
import com.atelier.vinyl.ui.screens.FavoritesRouteScreen
import com.atelier.vinyl.ui.screens.HomeRouteScreen
import com.atelier.vinyl.ui.screens.LibraryRouteScreen
import com.atelier.vinyl.ui.screens.NowPlayingRouteScreen
import com.atelier.vinyl.ui.screens.PlaylistsRouteScreen
import com.atelier.vinyl.ui.screens.QueueRouteScreen
import com.atelier.vinyl.ui.screens.SearchRouteScreen
import com.atelier.vinyl.ui.screens.SettingsRouteScreen
import com.atelier.vinyl.ui.theme.AtelierTheme
import com.atelier.vinyl.ui.theme.LocalAtelierPalette

class MainActivity : ComponentActivity() {

    private val controller: PlayerController by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContent {
            val settings by controller.settings.collectAsState()
            val isDark = settings.themeMode == AppThemeMode.DARK

            LaunchedEffect(isDark) {
                enableEdgeToEdge(
                    statusBarStyle = if (isDark) SystemBarStyle.dark(android.graphics.Color.TRANSPARENT)
                    else SystemBarStyle.light(android.graphics.Color.TRANSPARENT, android.graphics.Color.TRANSPARENT),
                    navigationBarStyle = if (isDark) SystemBarStyle.dark(android.graphics.Color.TRANSPARENT)
                    else SystemBarStyle.light(android.graphics.Color.TRANSPARENT, android.graphics.Color.TRANSPARENT)
                )
            }

            AtelierTheme(themeMode = settings.themeMode, language = settings.language) {
                AtelierRootApp(controller = controller)
            }
        }
    }
}

@Composable
private fun AtelierRootApp(controller: PlayerController) {
    val palette = LocalAtelierPalette.current
    val tracks by controller.tracks.collectAsState()
    val currentTrack by controller.currentTrack.collectAsState()
    val isPlaying by controller.isPlaying.collectAsState()
    val positionMs by controller.positionMs.collectAsState()
    val durationMs by controller.durationMs.collectAsState()
    val queueIds by controller.queueIds.collectAsState()
    val favoriteIds by controller.favoriteIds.collectAsState()
    val playlists by controller.playlists.collectAsState()
    val shuffle by controller.shuffle.collectAsState()
    val repeat by controller.repeat.collectAsState()
    val volume by controller.volume.collectAsState()
    val settings by controller.settings.collectAsState()
    val spectrum by controller.spectrum.collectAsState()
    val eqEnabled by controller.eqEnabled.collectAsState()
    val eqPresetId by controller.eqPresetId.collectAsState()
    val eqGains by controller.eqGainsDb.collectAsState()
    val sleepRemaining by controller.sleepRemainingSec.collectAsState()
    val screen by controller.screen.collectAsState()

    val importPicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenMultipleDocuments()
    ) { uris ->
        if (uris.isNotEmpty()) controller.importAudioFiles(uris)
    }

    val mediaPermLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestMultiplePermissions()
    ) { grants ->
        val audioPerm = if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_AUDIO else Manifest.permission.READ_EXTERNAL_STORAGE
        if (grants[audioPerm] == true) controller.scanDeviceAudio()
    }

    val requestScan = {
        val perms = buildList {
            add(if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_AUDIO else Manifest.permission.READ_EXTERNAL_STORAGE)
            if (Build.VERSION.SDK_INT >= 33) add(Manifest.permission.POST_NOTIFICATIONS)
            add(Manifest.permission.RECORD_AUDIO)
        }.toTypedArray()
        mediaPermLauncher.launch(perms)
    }

    BackHandler(enabled = screen != ScreenRoute.EXPLORE) {
        controller.navigateBack()
    }

    val activeTrack = currentTrack ?: tracks.firstOrNull()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.canvas)
    ) {
        Box(modifier = Modifier.weight(1f)) {
            if (activeTrack != null) {
                AnimatedContent(
                    targetState = screen,
                    transitionSpec = {
                        if (settings.reduceMotion) {
                            fadeIn(tween(1)) togetherWith fadeOut(tween(1))
                        } else if (targetState == ScreenRoute.NOW_PLAYING || initialState == ScreenRoute.NOW_PLAYING) {
                            (fadeIn(tween(340)) + scaleIn(initialScale = 0.92f, animationSpec = tween(360))) togetherWith
                                (fadeOut(tween(240)) + scaleOut(targetScale = 1.04f, animationSpec = tween(240)))
                        } else {
                            fadeIn(tween(220)) togetherWith fadeOut(tween(180))
                        }
                    },
                    label = "screenTransition"
                ) { route ->
                    when (route) {
                        ScreenRoute.EXPLORE -> ExploreRouteScreen(
                            tracks = tracks,
                            activeTrack = activeTrack,
                            isPlaying = isPlaying,
                            settings = settings,
                            onSelectCenterTrack = controller::selectCenterTrack,
                            onPlayAndOpen = { trk -> controller.playTrack(trk, openDeck = true) },
                            onNavigate = controller::navigateTo,
                            onToggleTheme = {
                                controller.updateSettings {
                                    it.copy(themeMode = if (it.themeMode == AppThemeMode.DARK) AppThemeMode.LIGHT else AppThemeMode.DARK)
                                }
                            },
                            onToggleLanguage = {
                                controller.updateSettings {
                                    it.copy(language = if (it.language == AppLanguage.EN) AppLanguage.FA else AppLanguage.EN)
                                }
                            },
                            onImportAudio = { importPicker.launch(arrayOf("audio/*")) }
                        )

                        ScreenRoute.NOW_PLAYING -> NowPlayingRouteScreen(
                            track = activeTrack,
                            isPlaying = isPlaying,
                            positionMs = positionMs,
                            durationMs = durationMs,
                            shuffle = shuffle,
                            repeatMode = repeat,
                            isFavorite = favoriteIds.contains(activeTrack.id),
                            volume = volume,
                            spectrum = spectrum,
                            playlists = playlists,
                            settings = settings,
                            onBack = controller::navigateBack,
                            onTogglePlay = controller::togglePlayPause,
                            onPrev = controller::skipPrevious,
                            onNext = controller::skipNext,
                            onSeekMs = controller::seekTo,
                            onToggleShuffle = controller::toggleShuffle,
                            onCycleRepeat = controller::cycleRepeat,
                            onToggleFavorite = { controller.toggleFavorite(activeTrack.id) },
                            onVolumeChange = controller::setVolume,
                            onAddToPlaylist = controller::addTrackToPlaylist,
                            onNavigate = controller::navigateTo
                        )

                        ScreenRoute.HOME -> HomeRouteScreen(
                            tracks = tracks,
                            currentTrack = activeTrack,
                            isPlaying = isPlaying,
                            favoriteCount = favoriteIds.size,
                            playlistCount = playlists.size,
                            onNavigate = controller::navigateTo,
                            onOpenNowPlaying = { controller.navigateTo(ScreenRoute.NOW_PLAYING) },
                            onPlayTrack = { controller.playTrack(it, openDeck = true) },
                            onToggleTheme = {
                                controller.updateSettings {
                                    it.copy(themeMode = if (it.themeMode == AppThemeMode.DARK) AppThemeMode.LIGHT else AppThemeMode.DARK)
                                }
                            },
                            onImportAudio = { importPicker.launch(arrayOf("audio/*")) }
                        )

                        ScreenRoute.LIBRARY -> LibraryRouteScreen(
                            tracks = tracks,
                            currentTrackId = activeTrack.id,
                            favoriteIds = favoriteIds,
                            onNavigate = controller::navigateTo,
                            onPlayTrack = { controller.playTrack(it, openDeck = true) },
                            onToggleFavorite = controller::toggleFavorite,
                            onImportAudio = { importPicker.launch(arrayOf("audio/*")) },
                            onScanDevice = requestScan
                        )

                        ScreenRoute.ALBUMS -> AlbumsRouteScreen(
                            tracks = tracks,
                            onBack = { controller.navigateTo(ScreenRoute.LIBRARY) },
                            onPlayAlbum = controller::playPlaylist
                        )

                        ScreenRoute.ARTISTS -> ArtistsRouteScreen(
                            tracks = tracks,
                            onBack = { controller.navigateTo(ScreenRoute.LIBRARY) },
                            onPlayArtist = controller::playPlaylist
                        )

                        ScreenRoute.PLAYLISTS -> PlaylistsRouteScreen(
                            playlists = playlists,
                            tracks = tracks,
                            onBack = { controller.navigateTo(ScreenRoute.LIBRARY) },
                            onCreatePlaylist = controller::createPlaylist,
                            onDeletePlaylist = controller::deletePlaylist,
                            onPlayPlaylist = controller::playPlaylist
                        )

                        ScreenRoute.FAVORITES -> FavoritesRouteScreen(
                            tracks = tracks,
                            favoriteIds = favoriteIds,
                            onBack = { controller.navigateTo(ScreenRoute.LIBRARY) },
                            onPlayTrack = { controller.playTrack(it, openDeck = true) },
                            onToggleFavorite = controller::toggleFavorite
                        )

                        ScreenRoute.SEARCH -> SearchRouteScreen(
                            tracks = tracks,
                            onPlayTrack = { controller.playTrack(it, openDeck = true) }
                        )

                        ScreenRoute.QUEUE -> QueueRouteScreen(
                            tracks = tracks,
                            queueIds = queueIds,
                            currentTrackId = activeTrack.id,
                            onBack = { controller.navigateTo(ScreenRoute.NOW_PLAYING) },
                            onPlayTrack = { controller.playTrack(it, openDeck = true) },
                            onMoveItem = controller::moveQueueItem
                        )

                        ScreenRoute.EQUALIZER -> EqualizerRouteScreen(
                            enabled = eqEnabled,
                            gainsDb = eqGains,
                            presetId = eqPresetId,
                            presets = controller.eqPresets,
                            isFa = settings.language == AppLanguage.FA,
                            onBack = { controller.navigateTo(ScreenRoute.NOW_PLAYING) },
                            onToggleEnabled = controller::toggleEqEnabled,
                            onSelectPreset = controller::selectEqPreset,
                            onBandChange = controller::setEqBand
                        )

                        ScreenRoute.SETTINGS -> SettingsRouteScreen(
                            settings = settings,
                            sleepRemainingSec = sleepRemaining,
                            onBack = controller::navigateBack,
                            onUpdateSettings = controller::updateSettings,
                            onSetSleepTimer = controller::setSleepTimer
                        )
                    }
                }
            }
        }

        if (screen != ScreenRoute.NOW_PLAYING && activeTrack != null && (isPlaying || positionMs > 0L || screen != ScreenRoute.EXPLORE)) {
            FloatingMiniPlayer(
                track = activeTrack,
                isPlaying = isPlaying,
                positionMs = positionMs,
                durationMs = durationMs,
                reduceMotion = settings.reduceMotion,
                onTogglePlay = controller::togglePlayPause,
                onExpand = { controller.navigateTo(ScreenRoute.NOW_PLAYING) }
            )
        }

        if (screen != ScreenRoute.NOW_PLAYING) {
            AtelierBottomNavBar(
                activeRoute = screen,
                onNavigate = controller::navigateTo
            )
        }
    }
}
