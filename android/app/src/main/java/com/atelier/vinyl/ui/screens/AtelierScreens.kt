package com.atelier.vinyl.ui.screens

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.GenericShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.atelier.vinyl.audio.CoverArtRenderer
import com.atelier.vinyl.model.AppLanguage
import com.atelier.vinyl.model.AppSettingsState
import com.atelier.vinyl.model.AppThemeMode
import com.atelier.vinyl.model.EqPreset
import com.atelier.vinyl.model.Playlist
import com.atelier.vinyl.model.RepeatMode
import com.atelier.vinyl.model.ScreenRoute
import com.atelier.vinyl.model.SpectrumFrame
import com.atelier.vinyl.model.TurntablePhase
import com.atelier.vinyl.model.VinylTrack
import com.atelier.vinyl.ui.components.AudioVisualizerDeck
import com.atelier.vinyl.ui.components.OrbitalExploreWheel
import com.atelier.vinyl.ui.components.TactileHardwareButton
import com.atelier.vinyl.ui.components.TactileTransportDeck
import com.atelier.vinyl.ui.components.TurntableDeckCanvas
import com.atelier.vinyl.ui.components.formatClockMs
import com.atelier.vinyl.ui.theme.LocalAtelierPalette
import com.atelier.vinyl.ui.theme.LocalAtelierStrings

@Composable
private fun ScreenTopBar(
    title: String,
    onBack: (() -> Unit)? = null,
    rightContent: @Composable (() -> Unit)? = null
) {
    val palette = LocalAtelierPalette.current
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
        modifier = Modifier
            .fillMaxWidth()
            .statusBarsPadding()
            .padding(horizontal = 20.dp, vertical = 12.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (onBack != null) {
                TactileHardwareButton(
                    onClick = onBack,
                    modifier = Modifier.size(36.dp),
                    shape = CircleShape
                ) {
                    Text("<", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary)
                }
                Spacer(Modifier.width(12.dp))
            }
            Text(title, fontSize = 22.sp, fontWeight = FontWeight.ExtraBold, color = palette.textPrimary)
        }
        rightContent?.invoke()
    }
}

@Composable
fun ExploreRouteScreen(
    tracks: List<VinylTrack>,
    activeTrack: VinylTrack,
    isPlaying: Boolean,
    settings: AppSettingsState,
    onSelectCenterTrack: (VinylTrack) -> Unit,
    onPlayAndOpen: (VinylTrack) -> Unit,
    onNavigate: (ScreenRoute) -> Unit,
    onToggleTheme: () -> Unit,
    onToggleLanguage: () -> Unit,
    onImportAudio: () -> Unit
) {
    val palette = LocalAtelierPalette.current
    val strings = LocalAtelierStrings.current
    var menuExpanded by remember { mutableStateOf(false) }

    Column(modifier = Modifier.fillMaxSize()) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .padding(horizontal = 22.dp, vertical = 12.dp)
        ) {
            Row(verticalAlignment = Alignment.Bottom) {
                Text(strings.explore, fontSize = 23.sp, fontWeight = FontWeight.ExtraBold, color = palette.textPrimary)
                Spacer(Modifier.width(10.dp))
                Text(
                    "${tracks.size} ${strings.pressings}",
                    fontSize = 11.sp,
                    fontFamily = FontFamily.Monospace,
                    color = palette.textMuted
                )
            }
            Box {
                Text(
                    text = "•••",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = palette.textPrimary,
                    modifier = Modifier
                        .clip(CircleShape)
                        .clickable { menuExpanded = true }
                        .padding(8.dp)
                )
                DropdownMenu(expanded = menuExpanded, onDismissRequest = { menuExpanded = false }) {
                    DropdownMenuItem(text = { Text(strings.importAudio) }, onClick = { menuExpanded = false; onImportAudio() })
                    DropdownMenuItem(text = { Text(strings.equalizer) }, onClick = { menuExpanded = false; onNavigate(ScreenRoute.EQUALIZER) })
                    DropdownMenuItem(text = { Text(strings.queue) }, onClick = { menuExpanded = false; onNavigate(ScreenRoute.QUEUE) })
                    DropdownMenuItem(text = { Text(strings.settings) }, onClick = { menuExpanded = false; onNavigate(ScreenRoute.SETTINGS) })
                    DropdownMenuItem(
                        text = { Text(if (settings.themeMode == AppThemeMode.DARK) strings.lightMode else strings.darkMode) },
                        onClick = { menuExpanded = false; onToggleTheme() }
                    )
                    DropdownMenuItem(
                        text = { Text(if (settings.language == AppLanguage.EN) "فارسی (RTL)" else "English (LTR)") },
                        onClick = { menuExpanded = false; onToggleLanguage() }
                    )
                }
            }
        }

        OrbitalExploreWheel(
            tracks = tracks,
            activeTrackId = activeTrack.id,
            isPlaying = isPlaying,
            reduceMotion = settings.reduceMotion,
            hapticsEnabled = settings.hapticsEnabled,
            onSelectCenterTrack = onSelectCenterTrack,
            onPlayAndOpen = onPlayAndOpen,
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
fun NowPlayingRouteScreen(
    track: VinylTrack,
    isPlaying: Boolean,
    positionMs: Long,
    durationMs: Long,
    shuffle: Boolean,
    repeatMode: RepeatMode,
    isFavorite: Boolean,
    volume: Float,
    spectrum: SpectrumFrame,
    playlists: List<Playlist>,
    settings: AppSettingsState,
    onBack: () -> Unit,
    onTogglePlay: () -> Unit,
    onPrev: () -> Unit,
    onNext: () -> Unit,
    onSeekMs: (Long) -> Unit,
    onToggleShuffle: () -> Unit,
    onCycleRepeat: () -> Unit,
    onToggleFavorite: () -> Unit,
    onVolumeChange: (Float) -> Unit,
    onAddToPlaylist: (String, String) -> Unit,
    onNavigate: (ScreenRoute) -> Unit
) {
    val palette = LocalAtelierPalette.current
    val strings = LocalAtelierStrings.current
    val context = LocalContext.current
    val coverBitmap = remember(track.id) { CoverArtRenderer.getBitmap(context, track) }
    var phase by remember { mutableStateOf(if (isPlaying) TurntablePhase.PLAYING else TurntablePhase.PARKED) }
    var menuExpanded by remember { mutableStateOf(false) }

    val phaseText = when (phase) {
        TurntablePhase.CUEING_IN -> strings.cueing
        TurntablePhase.PLAYING, TurntablePhase.SCRATCHING -> strings.stylusTracking
        TurntablePhase.PAUSED_HOVER -> strings.cueHover
        TurntablePhase.PARKED, TurntablePhase.RETURNING -> strings.parked
    }

    val curvedDomeShape = remember {
        GenericShape { size, _ ->
            moveTo(0f, 38f)
            quadraticTo(size.width / 2f, -20f, size.width, 38f)
            lineTo(size.width, size.height)
            lineTo(0f, size.height)
            close()
        }
    }

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .fillMaxSize()
            .background(palette.canvas)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .padding(horizontal = 18.dp, vertical = 10.dp)
        ) {
            Text(
                text = "<",
                fontSize = 22.sp,
                fontWeight = FontWeight.Medium,
                color = palette.textPrimary,
                modifier = Modifier
                    .clip(CircleShape)
                    .clickable(onClick = onBack)
                    .padding(horizontal = 10.dp, vertical = 4.dp)
            )
            Text(phaseText, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = palette.textSecondary)
            Box {
                Text(
                    text = "•••",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = palette.textPrimary,
                    modifier = Modifier
                        .clip(CircleShape)
                        .clickable { menuExpanded = true }
                        .padding(horizontal = 10.dp, vertical = 4.dp)
                )
                DropdownMenu(expanded = menuExpanded, onDismissRequest = { menuExpanded = false }) {
                    playlists.forEach { pl ->
                        DropdownMenuItem(
                            text = { Text("+ ${pl.name}") },
                            onClick = { menuExpanded = false; onAddToPlaylist(pl.id, track.id) }
                        )
                    }
                    DropdownMenuItem(text = { Text(strings.equalizer) }, onClick = { menuExpanded = false; onNavigate(ScreenRoute.EQUALIZER) })
                    DropdownMenuItem(text = { Text(strings.settings) }, onClick = { menuExpanded = false; onNavigate(ScreenRoute.SETTINGS) })
                }
            }
        }

        Box(modifier = Modifier.padding(horizontal = 22.dp)) {
            TurntableDeckCanvas(
                coverBitmap = coverBitmap,
                isPlaying = isPlaying,
                positionMs = positionMs,
                durationMs = durationMs,
                reduceMotion = settings.reduceMotion,
                onTogglePlay = onTogglePlay,
                onSeekMs = onSeekMs,
                onPhaseChanged = { phase = it }
            )
        }

        Spacer(Modifier.height(10.dp))

        Text(
            text = track.title,
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            color = palette.textPrimary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(horizontal = 24.dp)
        )
        Text(
            text = track.artist,
            fontSize = 13.5.sp,
            fontWeight = FontWeight.Medium,
            color = palette.textSecondary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )

        Spacer(Modifier.height(10.dp))

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceBetween,
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .clip(curvedDomeShape)
                .background(Brush.verticalGradient(listOf(palette.surface, palette.surfaceElevated)))
                .navigationBarsPadding()
                .padding(top = 24.dp, bottom = 18.dp, start = 20.dp, end = 20.dp)
        ) {
            AudioVisualizerDeck(
                spectrum = spectrum,
                isPlaying = isPlaying,
                positionMs = positionMs,
                durationMs = durationMs,
                reduceMotion = settings.reduceMotion,
                onSeekMs = onSeekMs
            )

            TactileTransportDeck(
                isPlaying = isPlaying,
                shuffle = shuffle,
                repeatMode = repeatMode,
                isFavorite = isFavorite,
                volume = volume,
                onTogglePlay = onTogglePlay,
                onPrev = onPrev,
                onNext = onNext,
                onToggleShuffle = onToggleShuffle,
                onCycleRepeat = onCycleRepeat,
                onToggleFavorite = onToggleFavorite,
                onVolumeChange = onVolumeChange,
                onOpenQueue = { onNavigate(ScreenRoute.QUEUE) },
                onOpenEq = { onNavigate(ScreenRoute.EQUALIZER) }
            )
        }
    }
}

@Composable
fun HomeRouteScreen(
    tracks: List<VinylTrack>,
    currentTrack: VinylTrack,
    isPlaying: Boolean,
    favoriteCount: Int,
    playlistCount: Int,
    onNavigate: (ScreenRoute) -> Unit,
    onOpenNowPlaying: () -> Unit,
    onPlayTrack: (VinylTrack) -> Unit,
    onToggleTheme: () -> Unit,
    onImportAudio: () -> Unit
) {
    val palette = LocalAtelierPalette.current
    val strings = LocalAtelierStrings.current
    val context = LocalContext.current

    LazyColumn(
        contentPadding = PaddingValues(bottom = 24.dp),
        modifier = Modifier.fillMaxSize()
    ) {
        item {
            ScreenTopBar(
                title = strings.homeGreeting,
                rightContent = {
                    TactileHardwareButton(onClick = onToggleTheme, modifier = Modifier.size(38.dp)) {
                        Text(if (palette.isDark) "☀" else "☾", fontSize = 15.sp, color = palette.textPrimary)
                    }
                }
            )
        }
        item {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp)
                    .shadow(14.dp, RoundedCornerShape(26.dp), ambientColor = palette.shadowDark)
                    .clip(RoundedCornerShape(26.dp))
                    .background(Brush.linearGradient(listOf(palette.surface, palette.deckPlinth)))
                    .border(1.dp, palette.highlightRim, RoundedCornerShape(26.dp))
                    .clickable(onClick = onOpenNowPlaying)
                    .padding(16.dp)
            ) {
                val bmp = remember(currentTrack.id) { CoverArtRenderer.getBitmap(context, currentTrack).asImageBitmap() }
                Image(
                    bitmap = bmp,
                    contentDescription = currentTrack.title,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.size(64.dp).clip(CircleShape)
                )
                Spacer(Modifier.width(14.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(if (isPlaying) strings.stylusTracking else strings.homeSubtitle, fontSize = 10.5.sp, color = palette.textMuted)
                    Text(currentTrack.title, fontSize = 16.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary)
                    Text(currentTrack.artist, fontSize = 12.5.sp, color = palette.textSecondary)
                }
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(999.dp))
                        .background(palette.surface)
                        .border(1.dp, palette.highlightRim, RoundedCornerShape(999.dp))
                        .padding(horizontal = 14.dp, vertical = 8.dp)
                ) {
                    Text(strings.openDeck, fontSize = 12.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary)
                }
            }
            Spacer(Modifier.height(18.dp))
        }
        item {
            val modules = listOf(
                Triple(strings.albums, ScreenRoute.ALBUMS, null),
                Triple(strings.artists, ScreenRoute.ARTISTS, null),
                Triple(strings.playlists, ScreenRoute.PLAYLISTS, playlistCount.toString()),
                Triple(strings.favorites, ScreenRoute.FAVORITES, favoriteCount.toString()),
                Triple(strings.equalizer, ScreenRoute.EQUALIZER, null),
                Triple(strings.queue, ScreenRoute.QUEUE, null),
                Triple(strings.settings, ScreenRoute.SETTINGS, null),
            )
            LazyRow(
                contentPadding = PaddingValues(horizontal = 20.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                item {
                    PillChip(strings.importAudio, onClick = onImportAudio)
                }
                items(modules) { (label, route, badge) ->
                    PillChip(if (badge != null) "$label · $badge" else label, onClick = { onNavigate(route) })
                }
            }
            Spacer(Modifier.height(18.dp))
        }
        items(tracks) { trk ->
            TrackListRow(track = trk, isCurrent = trk.id == currentTrack.id, onClick = { onPlayTrack(trk) })
        }
    }
}

@Composable
fun LibraryRouteScreen(
    tracks: List<VinylTrack>,
    currentTrackId: String,
    favoriteIds: Set<String>,
    onNavigate: (ScreenRoute) -> Unit,
    onPlayTrack: (VinylTrack) -> Unit,
    onToggleFavorite: (String) -> Unit,
    onImportAudio: () -> Unit,
    onScanDevice: () -> Unit
) {
    val strings = LocalAtelierStrings.current
    Column(modifier = Modifier.fillMaxSize()) {
        ScreenTopBar(
            title = strings.library,
            rightContent = {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    PillChip(strings.scanDevice, onClick = onScanDevice)
                    PillChip(strings.importAudio, onClick = onImportAudio)
                }
            }
        )
        LazyRow(
            contentPadding = PaddingValues(horizontal = 20.dp, vertical = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            item { PillChip(strings.albums) { onNavigate(ScreenRoute.ALBUMS) } }
            item { PillChip(strings.artists) { onNavigate(ScreenRoute.ARTISTS) } }
            item { PillChip(strings.playlists) { onNavigate(ScreenRoute.PLAYLISTS) } }
            item { PillChip(strings.favorites) { onNavigate(ScreenRoute.FAVORITES) } }
        }
        LazyColumn(contentPadding = PaddingValues(vertical = 10.dp), modifier = Modifier.weight(1f)) {
            items(tracks) { trk ->
                TrackListRow(
                    track = trk,
                    isCurrent = trk.id == currentTrackId,
                    trailing = {
                        Text(
                            text = if (favoriteIds.contains(trk.id)) "♥" else "♡",
                            fontSize = 17.sp,
                            color = if (favoriteIds.contains(trk.id)) Color(0xFFC25967) else LocalAtelierPalette.current.textMuted,
                            modifier = Modifier.clickable { onToggleFavorite(trk.id) }.padding(8.dp)
                        )
                    },
                    onClick = { onPlayTrack(trk) }
                )
            }
        }
    }
}

@Composable
fun AlbumsRouteScreen(
    tracks: List<VinylTrack>,
    onBack: () -> Unit,
    onPlayAlbum: (List<VinylTrack>) -> Unit
) {
    val strings = LocalAtelierStrings.current
    val palette = LocalAtelierPalette.current
    val context = LocalContext.current
    val albums = remember(tracks) { tracks.groupBy { it.album }.entries.toList() }

    Column(modifier = Modifier.fillMaxSize()) {
        ScreenTopBar(strings.albums, onBack = onBack)
        LazyVerticalGrid(
            columns = GridCells.Fixed(2),
            contentPadding = PaddingValues(18.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.weight(1f)
        ) {
            items(albums) { (albumName, items) ->
                val lead = items.first()
                val bmp = remember(lead.id) { CoverArtRenderer.getBitmap(context, lead).asImageBitmap() }
                Column(
                    modifier = Modifier
                        .shadow(10.dp, RoundedCornerShape(22.dp), ambientColor = palette.shadowDark)
                        .clip(RoundedCornerShape(22.dp))
                        .background(palette.surface)
                        .border(1.dp, palette.highlightRim, RoundedCornerShape(22.dp))
                        .clickable { onPlayAlbum(items) }
                        .padding(10.dp)
                ) {
                    Image(
                        bitmap = bmp,
                        contentDescription = albumName,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.fillMaxWidth().aspectRatio(1f).clip(RoundedCornerShape(16.dp))
                    )
                    Spacer(Modifier.height(8.dp))
                    Text(albumName, fontSize = 13.5.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text("${lead.artist} · ${items.size}", fontSize = 11.5.sp, color = palette.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
        }
    }
}

@Composable
fun ArtistsRouteScreen(
    tracks: List<VinylTrack>,
    onBack: () -> Unit,
    onPlayArtist: (List<VinylTrack>) -> Unit
) {
    val strings = LocalAtelierStrings.current
    val artists = remember(tracks) { tracks.groupBy { it.artist }.entries.toList() }
    Column(modifier = Modifier.fillMaxSize()) {
        ScreenTopBar(strings.artists, onBack = onBack)
        LazyColumn(contentPadding = PaddingValues(vertical = 8.dp), modifier = Modifier.weight(1f)) {
            items(artists) { (artistName, items) ->
                val lead = items.first()
                TrackListRow(
                    track = lead.copy(title = artistName, artist = "${items.size} ${strings.pressings}"),
                    isCurrent = false,
                    onClick = { onPlayArtist(items) }
                )
            }
        }
    }
}

@Composable
fun PlaylistsRouteScreen(
    playlists: List<Playlist>,
    tracks: List<VinylTrack>,
    onBack: () -> Unit,
    onCreatePlaylist: (String) -> Unit,
    onDeletePlaylist: (String) -> Unit,
    onPlayPlaylist: (List<VinylTrack>) -> Unit
) {
    val strings = LocalAtelierStrings.current
    val palette = LocalAtelierPalette.current
    val trackMap = remember(tracks) { tracks.associateBy { it.id } }
    var name by remember { mutableStateOf("") }

    Column(modifier = Modifier.fillMaxSize()) {
        ScreenTopBar(strings.playlists, onBack = onBack)
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 6.dp)
                .clip(RoundedCornerShape(999.dp))
                .background(palette.recessed)
                .padding(horizontal = 16.dp, vertical = 8.dp)
        ) {
            BasicTextField(
                value = name,
                onValueChange = { name = it },
                singleLine = true,
                textStyle = TextStyle(color = palette.textPrimary, fontSize = 13.5.sp),
                cursorBrush = SolidColor(palette.textPrimary),
                decorationBox = { inner ->
                    if (name.isEmpty()) Text(strings.createPlaylistHint, color = palette.textMuted, fontSize = 13.5.sp)
                    inner()
                },
                modifier = Modifier.weight(1f)
            )
            PillChip(strings.create) {
                if (name.isNotBlank()) {
                    onCreatePlaylist(name)
                    name = ""
                }
            }
        }

        LazyColumn(contentPadding = PaddingValues(20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            items(playlists) { pl ->
                val items = pl.trackIds.mapNotNull { trackMap[it] }
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .shadow(10.dp, RoundedCornerShape(22.dp), ambientColor = palette.shadowDark)
                        .clip(RoundedCornerShape(22.dp))
                        .background(palette.surface)
                        .clickable(enabled = items.isNotEmpty()) { onPlayPlaylist(items) }
                        .padding(16.dp)
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(pl.name, fontSize = 15.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary)
                        Text("${items.size} ${strings.pressings}", fontSize = 12.sp, color = palette.textSecondary)
                    }
                    Text(
                        text = "×",
                        fontSize = 18.sp,
                        color = palette.textMuted,
                        modifier = Modifier.clickable { onDeletePlaylist(pl.id) }.padding(8.dp)
                    )
                }
            }
        }
    }
}

@Composable
fun FavoritesRouteScreen(
    tracks: List<VinylTrack>,
    favoriteIds: Set<String>,
    onBack: () -> Unit,
    onPlayTrack: (VinylTrack) -> Unit,
    onToggleFavorite: (String) -> Unit
) {
    val strings = LocalAtelierStrings.current
    val favs = remember(tracks, favoriteIds) { tracks.filter { favoriteIds.contains(it.id) } }
    Column(modifier = Modifier.fillMaxSize()) {
        ScreenTopBar(strings.favorites, onBack = onBack)
        LazyColumn(contentPadding = PaddingValues(vertical = 8.dp), modifier = Modifier.weight(1f)) {
            items(favs) { trk ->
                TrackListRow(
                    track = trk,
                    isCurrent = false,
                    trailing = {
                        Text(
                            text = "♥",
                            fontSize = 17.sp,
                            color = Color(0xFFC25967),
                            modifier = Modifier.clickable { onToggleFavorite(trk.id) }.padding(8.dp)
                        )
                    },
                    onClick = { onPlayTrack(trk) }
                )
            }
        }
    }
}

@Composable
fun SearchRouteScreen(
    tracks: List<VinylTrack>,
    onPlayTrack: (VinylTrack) -> Unit
) {
    val strings = LocalAtelierStrings.current
    val palette = LocalAtelierPalette.current
    var query by remember { mutableStateOf("") }
    val filtered = remember(tracks, query) {
        val q = query.trim().lowercase()
        if (q.isEmpty()) tracks
        else tracks.filter {
            it.title.lowercase().contains(q) ||
                it.artist.lowercase().contains(q) ||
                it.album.lowercase().contains(q) ||
                it.format.lowercase().contains(q)
        }
    }

    Column(modifier = Modifier.fillMaxSize()) {
        ScreenTopBar(strings.search)
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 6.dp)
                .clip(RoundedCornerShape(999.dp))
                .background(palette.recessed)
                .padding(horizontal = 18.dp, vertical = 12.dp)
        ) {
            BasicTextField(
                value = query,
                onValueChange = { query = it },
                singleLine = true,
                textStyle = TextStyle(color = palette.textPrimary, fontSize = 14.sp),
                cursorBrush = SolidColor(palette.textPrimary),
                decorationBox = { inner ->
                    if (query.isEmpty()) Text(strings.searchHint, color = palette.textMuted, fontSize = 14.sp)
                    inner()
                },
                modifier = Modifier.fillMaxWidth()
            )
        }
        LazyColumn(contentPadding = PaddingValues(vertical = 8.dp), modifier = Modifier.weight(1f)) {
            items(filtered) { trk ->
                TrackListRow(track = trk, isCurrent = false, onClick = { onPlayTrack(trk) })
            }
        }
    }
}

@Composable
fun QueueRouteScreen(
    tracks: List<VinylTrack>,
    queueIds: List<String>,
    currentTrackId: String,
    onBack: () -> Unit,
    onPlayTrack: (VinylTrack) -> Unit,
    onMoveItem: (Int, Int) -> Unit
) {
    val strings = LocalAtelierStrings.current
    val palette = LocalAtelierPalette.current
    val map = remember(tracks) { tracks.associateBy { it.id } }
    val items = remember(queueIds, map) { queueIds.mapNotNull { map[it] } }

    Column(modifier = Modifier.fillMaxSize()) {
        ScreenTopBar(strings.queue, onBack = onBack)
        LazyColumn(contentPadding = PaddingValues(vertical = 8.dp), modifier = Modifier.weight(1f)) {
            itemsIndexed(items) { idx, trk ->
                TrackListRow(
                    track = trk,
                    isCurrent = trk.id == currentTrackId,
                    trailing = {
                        Row {
                            Text("↑", color = palette.textSecondary, modifier = Modifier.clickable { onMoveItem(idx, -1) }.padding(8.dp))
                            Text("↓", color = palette.textSecondary, modifier = Modifier.clickable { onMoveItem(idx, 1) }.padding(8.dp))
                        }
                    },
                    onClick = { onPlayTrack(trk) }
                )
            }
        }
    }
}

@Composable
fun EqualizerRouteScreen(
    enabled: Boolean,
    gainsDb: List<Float>,
    presetId: String,
    presets: List<EqPreset>,
    isFa: Boolean,
    onBack: () -> Unit,
    onToggleEnabled: () -> Unit,
    onSelectPreset: (EqPreset) -> Unit,
    onBandChange: (Int, Float) -> Unit
) {
    val strings = LocalAtelierStrings.current
    val palette = LocalAtelierPalette.current
    val bandLabels = listOf("60Hz", "230Hz", "910Hz", "3.6k", "14kHz")

    Column(modifier = Modifier.fillMaxSize()) {
        ScreenTopBar(
            title = strings.equalizer,
            onBack = onBack,
            rightContent = {
                PillChip(if (enabled) strings.eqActive else strings.eqBypass, onClick = onToggleEnabled)
            }
        )

        Column(modifier = Modifier.padding(horizontal = 20.dp)) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .shadow(12.dp, RoundedCornerShape(26.dp), ambientColor = palette.shadowDark)
                    .clip(RoundedCornerShape(26.dp))
                    .background(palette.surface)
                    .padding(16.dp)
            ) {
                bandLabels.forEachIndexed { idx, label ->
                    val valDb = gainsDb.getOrElse(idx) { 0f }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(label, fontFamily = FontFamily.Monospace, fontSize = 12.sp, color = palette.textSecondary, modifier = Modifier.width(52.dp))
                        Slider(
                            value = valDb,
                            onValueChange = { onBandChange(idx, it) },
                            valueRange = -12f..12f,
                            enabled = enabled,
                            modifier = Modifier.weight(1f)
                        )
                        Text(
                            "${if (valDb > 0f) "+" else ""}${String.format("%.1f", valDb)}",
                            fontFamily = FontFamily.Monospace,
                            fontSize = 11.sp,
                            color = palette.textPrimary,
                            modifier = Modifier.width(42.dp)
                        )
                    }
                }
            }

            Spacer(Modifier.height(16.dp))
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(presets) { preset ->
                    PillChip(
                        text = if (isFa) preset.nameFa else preset.nameEn,
                        active = preset.id == presetId,
                        onClick = { onSelectPreset(preset) }
                    )
                }
            }
        }
    }
}

@Composable
fun SettingsRouteScreen(
    settings: AppSettingsState,
    sleepRemainingSec: Int?,
    onBack: () -> Unit,
    onUpdateSettings: ((AppSettingsState) -> AppSettingsState) -> Unit,
    onSetSleepTimer: (Int?) -> Unit
) {
    val strings = LocalAtelierStrings.current
    val palette = LocalAtelierPalette.current

    Column(modifier = Modifier.fillMaxSize()) {
        ScreenTopBar(strings.settings, onBack = onBack)
        Column(
            verticalArrangement = Arrangement.spacedBy(14.dp),
            modifier = Modifier.padding(horizontal = 20.dp)
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                PillChip(strings.lightMode, active = settings.themeMode == AppThemeMode.LIGHT) {
                    onUpdateSettings { it.copy(themeMode = AppThemeMode.LIGHT) }
                }
                PillChip(strings.darkMode, active = settings.themeMode == AppThemeMode.DARK) {
                    onUpdateSettings { it.copy(themeMode = AppThemeMode.DARK) }
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                PillChip("English (LTR)", active = settings.language == AppLanguage.EN) {
                    onUpdateSettings { it.copy(language = AppLanguage.EN) }
                }
                PillChip("فارسی (RTL)", active = settings.language == AppLanguage.FA) {
                    onUpdateSettings { it.copy(language = AppLanguage.FA) }
                }
            }
            Text(
                "${strings.sleepTimer}${sleepRemainingSec?.let { " · ${it / 60}m" } ?: ""}",
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                color = palette.textSecondary
            )
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(listOf<Int?>(null, 15, 30, 45, 60)) { mins ->
                    PillChip(mins?.let { "${it}m" } ?: strings.off, active = settings.sleepTimerMinutes == mins) {
                        onSetSleepTimer(mins)
                    }
                }
            }
            PillChip(
                "${strings.hapticsLabel}: ${if (settings.hapticsEnabled) "ON" else "OFF"}",
                active = settings.hapticsEnabled
            ) {
                onUpdateSettings { it.copy(hapticsEnabled = !it.hapticsEnabled) }
            }
            PillChip(
                "${strings.reduceMotionLabel}: ${if (settings.reduceMotion) "ON" else "OFF"}",
                active = settings.reduceMotion
            ) {
                onUpdateSettings { it.copy(reduceMotion = !it.reduceMotion) }
            }
        }
    }
}

@Composable
private fun PillChip(
    text: String,
    active: Boolean = false,
    onClick: () -> Unit
) {
    val palette = LocalAtelierPalette.current
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .shadow(if (active) 2.dp else 6.dp, RoundedCornerShape(999.dp), ambientColor = palette.shadowDark)
            .clip(RoundedCornerShape(999.dp))
            .background(if (active) palette.recessed else palette.surface)
            .border(1.dp, palette.highlightRim, RoundedCornerShape(999.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 8.dp)
    ) {
        Text(text, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = palette.textPrimary)
    }
}

@Composable
private fun TrackListRow(
    track: VinylTrack,
    isCurrent: Boolean,
    trailing: (@Composable () -> Unit)? = null,
    onClick: () -> Unit
) {
    val palette = LocalAtelierPalette.current
    val context = LocalContext.current
    val bmp = remember(track.id) { CoverArtRenderer.getBitmap(context, track).asImageBitmap() }

    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 5.dp)
            .shadow(8.dp, RoundedCornerShape(999.dp), ambientColor = palette.shadowDark)
            .clip(RoundedCornerShape(999.dp))
            .background(palette.surface)
            .border(1.dp, if (isCurrent) palette.textMuted else palette.highlightRim, RoundedCornerShape(999.dp))
            .clickable(onClick = onClick)
            .padding(start = 8.dp, end = 14.dp, top = 7.dp, bottom = 7.dp)
    ) {
        Image(
            bitmap = bmp,
            contentDescription = track.title,
            contentScale = ContentScale.Crop,
            modifier = Modifier.size(44.dp).clip(CircleShape)
        )
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(track.title, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text("${track.artist} · ${formatClockMs(track.durationMs)} · ${track.format}", fontSize = 11.5.sp, color = palette.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        trailing?.invoke()
    }
}
