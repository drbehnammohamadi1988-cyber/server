package com.atelier.vinyl.ui.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.atelier.vinyl.audio.CoverArtRenderer
import com.atelier.vinyl.model.RepeatMode as TrackRepeatMode
import com.atelier.vinyl.model.ScreenRoute
import com.atelier.vinyl.model.SpectrumFrame
import com.atelier.vinyl.model.VinylTrack
import com.atelier.vinyl.ui.theme.LocalAtelierPalette
import com.atelier.vinyl.ui.theme.LocalAtelierStrings

fun formatClockMs(ms: Long): String {
    val totalSec = (ms / 1000L).coerceAtLeast(0L)
    val m = totalSec / 60L
    val s = totalSec % 60L
    return "$m:${s.toString().padStart(2, '0')}"
}

@Composable
fun AudioVisualizerDeck(
    spectrum: SpectrumFrame,
    isPlaying: Boolean,
    positionMs: Long,
    durationMs: Long,
    reduceMotion: Boolean,
    onSeekMs: (Long) -> Unit,
    modifier: Modifier = Modifier
) {
    val palette = LocalAtelierPalette.current
    val restHeights = remember { listOf(6f, 9f, 13f, 19f, 25f, 30f, 34f, 30f, 25f, 19f, 13f, 9f, 6f) }

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = modifier.fillMaxWidth()
    ) {
        // Real FFT Spectrum Bars
        Canvas(
            modifier = Modifier
                .width(136.dp)
                .height(44.dp)
        ) {
            val barW = 2.8.dp.toPx()
            val gap = (size.width - barW * 13f) / 12f
            for (i in 0 until 13) {
                val raw = if (reduceMotion) (if (isPlaying) 0.35f else 0f) else spectrum.bars.getOrElse(i) { 0f }
                val rest = restHeights[i]
                val hDp = (rest * 0.44f + raw * rest * 1.18f).coerceIn(4f, 42f)
                val barH = hDp.dp.toPx()
                val x = i * (barW + gap)
                val y = (size.height - barH) / 2f
                val isCore = i in 4..8
                drawRoundRect(
                    color = (if (isCore) palette.visualizerActive else palette.visualizerRest).copy(alpha = 0.45f + raw * 0.55f),
                    topLeft = Offset(x, y),
                    size = Size(barW, barH),
                    cornerRadius = CornerRadius(barW, barW)
                )
            }
        }

        Spacer(Modifier.height(8.dp))

        Text(
            text = "${formatClockMs(positionMs)} / ${formatClockMs(durationMs)}",
            fontFamily = FontFamily.Monospace,
            fontSize = 13.5.sp,
            fontWeight = FontWeight.SemiBold,
            color = palette.textPrimary
        )

        Spacer(Modifier.height(6.dp))

        val progress = if (durationMs > 0L) (positionMs.toFloat() / durationMs.toFloat()).coerceIn(0f, 1f) else 0f
        Slider(
            value = progress,
            onValueChange = { ratio -> onSeekMs((ratio * durationMs).toLong()) },
            colors = SliderDefaults.colors(
                thumbColor = palette.textPrimary,
                activeTrackColor = palette.textPrimary,
                inactiveTrackColor = palette.recessed
            ),
            modifier = Modifier
                .fillMaxWidth(0.82f)
                .height(24.dp)
        )
    }
}

@Composable
fun TactileTransportDeck(
    isPlaying: Boolean,
    shuffle: Boolean,
    repeatMode: TrackRepeatMode,
    isFavorite: Boolean,
    volume: Float,
    onTogglePlay: () -> Unit,
    onPrev: () -> Unit,
    onNext: () -> Unit,
    onToggleShuffle: () -> Unit,
    onCycleRepeat: () -> Unit,
    onToggleFavorite: () -> Unit,
    onVolumeChange: (Float) -> Unit,
    onOpenQueue: () -> Unit,
    onOpenEq: () -> Unit
) {
    val palette = LocalAtelierPalette.current
    var showVolume by remember { mutableStateOf(false) }

    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
        if (showVolume) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .padding(bottom = 8.dp)
                    .width(220.dp)
                    .shadow(10.dp, RoundedCornerShape(999.dp))
                    .clip(RoundedCornerShape(999.dp))
                    .background(palette.surface)
                    .padding(horizontal = 14.dp, vertical = 4.dp)
            ) {
                Text("Vol", fontSize = 11.sp, color = palette.textSecondary)
                Slider(
                    value = volume,
                    onValueChange = onVolumeChange,
                    modifier = Modifier.weight(1f).padding(horizontal = 8.dp)
                )
                Text("${(volume * 100).toInt()}", fontSize = 11.sp, fontFamily = FontFamily.Monospace, color = palette.textPrimary)
            }
        }

        Row(
            horizontalArrangement = Arrangement.spacedBy(18.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Left Capsule Prev
            TactileHardwareButton(
                onClick = onPrev,
                modifier = Modifier.width(82.dp).height(46.dp),
                shape = RoundedCornerShape(999.dp)
            ) {
                Canvas(Modifier.size(18.dp)) {
                    drawRoundRect(palette.textPrimary, Offset(2.dp.toPx(), 3.dp.toPx()), Size(2.dp.toPx(), 12.dp.toPx()), CornerRadius(1f, 1f))
                    val p = Path().apply {
                        moveTo(15.dp.toPx(), 3.dp.toPx())
                        lineTo(6.dp.toPx(), 9.dp.toPx())
                        lineTo(15.dp.toPx(), 15.dp.toPx())
                        close()
                    }
                    drawPath(p, palette.textPrimary)
                }
            }

            // Center Circular Play/Pause Dial
            TactileHardwareButton(
                onClick = onTogglePlay,
                modifier = Modifier.size(72.dp),
                shape = CircleShape
            ) {
                val morphFraction by animateFloatAsState(
                    targetValue = if (isPlaying) 1f else 0f,
                    animationSpec = spring(stiffness = 420f, dampingRatio = 0.72f),
                    label = "playPauseMorph"
                )
                Box(contentAlignment = Alignment.Center, modifier = Modifier.fillMaxSize()) {
                    // Top LED notch
                    Box(
                        modifier = Modifier
                            .align(Alignment.TopCenter)
                            .padding(top = 10.dp)
                            .width(2.5.dp)
                            .height(6.dp)
                            .clip(CircleShape)
                            .background(if (isPlaying) palette.accentLed else palette.textMuted)
                    )
                    Canvas(modifier = Modifier.padding(top = 5.dp).size(22.dp)) {
                        val s = size.width
                        if (morphFraction > 0.5f) {
                            drawRoundRect(palette.textPrimary, Offset(s * 0.28f, s * 0.22f), Size(s * 0.14f, s * 0.56f), CornerRadius(3f, 3f))
                            drawRoundRect(palette.textPrimary, Offset(s * 0.58f, s * 0.22f), Size(s * 0.14f, s * 0.56f), CornerRadius(3f, 3f))
                        } else {
                            val p = Path().apply {
                                moveTo(s * 0.30f, s * 0.20f)
                                lineTo(s * 0.78f, s * 0.50f)
                                lineTo(s * 0.30f, s * 0.80f)
                                close()
                            }
                            drawPath(p, palette.textPrimary)
                        }
                    }
                }
            }

            // Right Capsule Next
            TactileHardwareButton(
                onClick = onNext,
                modifier = Modifier.width(82.dp).height(46.dp),
                shape = RoundedCornerShape(999.dp)
            ) {
                Canvas(Modifier.size(18.dp)) {
                    drawRoundRect(palette.textPrimary, Offset(14.dp.toPx(), 3.dp.toPx()), Size(2.dp.toPx(), 12.dp.toPx()), CornerRadius(1f, 1f))
                    val p = Path().apply {
                        moveTo(3.dp.toPx(), 3.dp.toPx())
                        lineTo(12.dp.toPx(), 9.dp.toPx())
                        lineTo(3.dp.toPx(), 15.dp.toPx())
                        close()
                    }
                    drawPath(p, palette.textPrimary)
                }
            }
        }

        Spacer(Modifier.height(14.dp))

        Row(
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth(0.86f)
        ) {
            MicroSwitchChip("SHF", shuffle, onToggleShuffle)
            MicroSwitchChip("FAV", isFavorite, onToggleFavorite, activeTint = Color(0xFFC25967))
            MicroSwitchChip("VOL", showVolume, { showVolume = !showVolume })
            MicroSwitchChip("EQ", false, onOpenEq)
            MicroSwitchChip("QUE", false, onOpenQueue)
            MicroSwitchChip(
                when (repeatMode) {
                    TrackRepeatMode.OFF -> "RPT"
                    TrackRepeatMode.ALL -> "ALL"
                    TrackRepeatMode.ONE -> "1x"
                },
                repeatMode != TrackRepeatMode.OFF,
                onCycleRepeat
            )
        }
    }
}

@Composable
fun TactileHardwareButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    shape: androidx.compose.ui.graphics.Shape = CircleShape,
    content: @Composable () -> Unit
) {
    val palette = LocalAtelierPalette.current
    val interactionSource = remember { MutableInteractionSource() }
    val pressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed) 0.94f else 1f,
        animationSpec = spring(stiffness = 500f, dampingRatio = 0.7f),
        label = "btnScale"
    )

    Box(
        contentAlignment = Alignment.Center,
        modifier = modifier
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .shadow(if (pressed) 2.dp else 10.dp, shape, ambientColor = palette.shadowDark, spotColor = palette.shadowDark)
            .clip(shape)
            .background(
                if (pressed) Brush.linearGradient(listOf(palette.recessed, palette.deckPlinth))
                else Brush.linearGradient(listOf(palette.surfaceElevated, palette.deckPlinth))
            )
            .border(1.dp, palette.highlightRim, shape)
            .clickable(interactionSource = interactionSource, indication = null, onClick = onClick)
    ) {
        content()
    }
}

@Composable
private fun MicroSwitchChip(
    label: String,
    active: Boolean,
    onClick: () -> Unit,
    activeTint: Color? = null
) {
    val palette = LocalAtelierPalette.current
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .clip(RoundedCornerShape(999.dp))
            .background(if (active) palette.recessed else Color.Transparent)
            .border(1.dp, if (active) palette.highlightRim else Color.Transparent, RoundedCornerShape(999.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 9.dp, vertical = 6.dp)
    ) {
        Text(
            text = label,
            fontSize = 10.5.sp,
            fontFamily = FontFamily.Monospace,
            fontWeight = FontWeight.Bold,
            color = if (active) (activeTint ?: palette.textPrimary) else palette.textSecondary
        )
    }
}

@Composable
fun FloatingMiniPlayer(
    track: VinylTrack,
    isPlaying: Boolean,
    positionMs: Long,
    durationMs: Long,
    reduceMotion: Boolean,
    onTogglePlay: () -> Unit,
    onExpand: () -> Unit
) {
    val palette = LocalAtelierPalette.current
    val context = LocalContext.current
    val bitmap = remember(track.id) { CoverArtRenderer.getBitmap(context, track).asImageBitmap() }

    val spinTransition = rememberInfiniteTransition(label = "miniSpin")
    val spinDeg by spinTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(tween(3600, easing = LinearEasing), RepeatMode.Restart),
        label = "miniSpinDeg"
    )
    var dragAccum by remember { mutableFloatStateOf(0f) }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = 6.dp)
            .shadow(16.dp, RoundedCornerShape(999.dp), ambientColor = palette.shadowDark, spotColor = palette.shadowDark)
            .clip(RoundedCornerShape(999.dp))
            .background(palette.surface.copy(alpha = 0.94f))
            .border(1.dp, palette.highlightRim, RoundedCornerShape(999.dp))
            .pointerInput(Unit) {
                detectVerticalDragGestures(
                    onDragStart = { dragAccum = 0f },
                    onVerticalDrag = { _, dy ->
                        dragAccum += dy
                        if (dragAccum < -36f) {
                            dragAccum = 0f
                            onExpand()
                        }
                    }
                )
            }
            .clickable(onClick = onExpand)
            .padding(horizontal = 12.dp, vertical = 8.dp)
    ) {
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(Color(0xFF0C0D10))
                ) {
                    Image(
                        bitmap = bitmap,
                        contentDescription = track.title,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier
                            .fillMaxSize()
                            .graphicsLayer { if (isPlaying && !reduceMotion) rotationZ = spinDeg }
                    )
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(palette.surface)
                    )
                }

                Spacer(Modifier.width(12.dp))

                Column(modifier = Modifier.weight(1f)) {
                    Text(track.title, fontSize = 13.5.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(track.artist, fontSize = 11.5.sp, color = palette.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }

                TactileHardwareButton(
                    onClick = onTogglePlay,
                    modifier = Modifier.size(38.dp),
                    shape = CircleShape
                ) {
                    Text(
                        text = if (isPlaying) "II" else "▶",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        color = palette.textPrimary
                    )
                }
            }
            Spacer(Modifier.height(4.dp))
            val ratio = if (durationMs > 0L) (positionMs.toFloat() / durationMs.toFloat()).coerceIn(0f, 1f) else 0f
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp)
                    .height(2.dp)
                    .clip(RoundedCornerShape(99.dp))
                    .background(palette.recessed)
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(ratio)
                        .height(2.dp)
                        .background(palette.textPrimary)
                )
            }
        }
    }
}

@Composable
fun AtelierBottomNavBar(
    activeRoute: ScreenRoute,
    onNavigate: (ScreenRoute) -> Unit
) {
    val palette = LocalAtelierPalette.current
    val strings = LocalAtelierStrings.current

    val isLibrary = activeRoute in setOf(
        ScreenRoute.LIBRARY, ScreenRoute.ALBUMS, ScreenRoute.ARTISTS, ScreenRoute.PLAYLISTS, ScreenRoute.FAVORITES
    )

    Row(
        horizontalArrangement = Arrangement.SpaceAround,
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .background(palette.surfaceElevated.copy(alpha = 0.92f))
            .navigationBarsPadding()
            .height(60.dp)
            .padding(horizontal = 12.dp)
    ) {
        NavIconItem(active = activeRoute == ScreenRoute.HOME, label = strings.homeGreeting, onClick = { onNavigate(ScreenRoute.HOME) }) { color, active ->
            Canvas(Modifier.size(21.dp)) {
                val p = Path().apply {
                    moveTo(size.width * 0.15f, size.height * 0.45f)
                    lineTo(size.width * 0.5f, size.height * 0.14f)
                    lineTo(size.width * 0.85f, size.height * 0.45f)
                    lineTo(size.width * 0.85f, size.height * 0.86f)
                    lineTo(size.width * 0.15f, size.height * 0.86f)
                    close()
                }
                drawPath(p, color, style = if (active) androidx.compose.ui.graphics.drawscope.Fill else Stroke(width = 3.5f))
            }
        }

        // Signature Saturn Vinyl Planet Icon matching reference center tab
        NavIconItem(active = activeRoute == ScreenRoute.EXPLORE, label = strings.explore, onClick = { onNavigate(ScreenRoute.EXPLORE) }) { color, active ->
            Canvas(Modifier.size(24.dp)) {
                drawCircle(
                    color = color,
                    radius = size.minDimension * 0.24f,
                    style = if (active) androidx.compose.ui.graphics.drawscope.Fill else Stroke(width = 3.5f)
                )
                rotate(-24f) {
                    drawOval(
                        color = color,
                        topLeft = Offset(size.width * 0.08f, size.height * 0.37f),
                        size = Size(size.width * 0.84f, size.height * 0.26f),
                        style = Stroke(width = if (active) 4.2f else 3.4f, cap = StrokeCap.Round)
                    )
                }
            }
        }

        NavIconItem(active = activeRoute == ScreenRoute.SEARCH, label = strings.search, onClick = { onNavigate(ScreenRoute.SEARCH) }) { color, _ ->
            Canvas(Modifier.size(20.dp)) {
                drawCircle(color, radius = size.minDimension * 0.30f, center = Offset(size.width * 0.44f, size.height * 0.44f), style = Stroke(3.6f))
                drawLine(color, Offset(size.width * 0.66f, size.height * 0.66f), Offset(size.width * 0.86f, size.height * 0.86f), strokeWidth = 3.8f, cap = StrokeCap.Round)
            }
        }

        NavIconItem(active = isLibrary, label = strings.library, onClick = { onNavigate(ScreenRoute.LIBRARY) }) { color, active ->
            Canvas(Modifier.size(20.dp)) {
                val p = Path().apply {
                    moveTo(size.width * 0.24f, size.height * 0.14f)
                    lineTo(size.width * 0.76f, size.height * 0.14f)
                    lineTo(size.width * 0.76f, size.height * 0.88f)
                    lineTo(size.width * 0.50f, size.height * 0.70f)
                    lineTo(size.width * 0.24f, size.height * 0.88f)
                    close()
                }
                drawPath(p, color, style = if (active) androidx.compose.ui.graphics.drawscope.Fill else Stroke(width = 3.5f))
            }
        }
    }
}

@Composable
private fun NavIconItem(
    active: Boolean,
    label: String,
    onClick: () -> Unit,
    icon: @Composable (Color, Boolean) -> Unit
) {
    val palette = LocalAtelierPalette.current
    val tint = if (active) palette.textPrimary else palette.textMuted
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .clip(RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 6.dp)
    ) {
        icon(tint, active)
        Spacer(Modifier.height(4.dp))
        Box(
            modifier = Modifier
                .width(if (active) 14.dp else 0.dp)
                .height(2.dp)
                .clip(CircleShape)
                .background(palette.textPrimary)
        )
    }
}
