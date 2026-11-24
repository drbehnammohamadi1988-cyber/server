package com.atelier.vinyl.ui.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import com.atelier.vinyl.audio.CoverArtRenderer
import com.atelier.vinyl.model.VinylTrack
import com.atelier.vinyl.ui.theme.LocalAtelierPalette
import com.atelier.vinyl.ui.theme.LocalAtelierStrings
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin

object OrbitalGeometry {
    const val ANGLE_PER_ITEM_RAD = 0.275f

    data class ItemPlacement(
        val xPx: Float,
        val yPx: Float,
        val scale: Float,
        val opacity: Float,
        val tiltDeg: Float,
        val blurDp: Float,
        val capsuleFactor: Float
    )

    fun computePlacement(
        offsetFromCenter: Float,
        widthPx: Float,
        heightPx: Float,
        isRtl: Boolean,
        reduceMotion: Boolean
    ): ItemPlacement {
        val hubX = if (isRtl) -widthPx * 0.06f else widthPx * 1.06f
        val hubY = heightPx * 0.49f
        val radius = widthPx * 0.89f
        val theta = offsetFromCenter * ANGLE_PER_ITEM_RAD

        val xPx = if (isRtl) hubX + radius * cos(theta) else hubX - radius * cos(theta)
        val yPx = hubY + radius * sin(theta)

        val absD = abs(offsetFromCenter)
        val scale = (1f - absD * 0.112f).coerceIn(0.58f, 1f)
        val opacity = (1f - absD.pow(1.25f) * 0.195f).coerceIn(0f, 1f)
        val tiltDeg = if (isRtl) offsetFromCenter * 9.5f else -offsetFromCenter * 9.5f
        val blurDp = if (reduceMotion) 0f else ((absD - 0.85f) * 0.72f).coerceAtLeast(0f)
        val capsuleFactor = (1f - absD * 2.15f).coerceIn(0f, 1f)

        return ItemPlacement(xPx, yPx, scale, opacity, tiltDeg, blurDp, capsuleFactor)
    }
}

@Composable
fun OrbitalExploreWheel(
    tracks: List<VinylTrack>,
    activeTrackId: String,
    isPlaying: Boolean,
    reduceMotion: Boolean,
    hapticsEnabled: Boolean,
    onSelectCenterTrack: (VinylTrack) -> Unit,
    onPlayAndOpen: (VinylTrack) -> Unit,
    modifier: Modifier = Modifier
) {
    val palette = LocalAtelierPalette.current
    val strings = LocalAtelierStrings.current
    val haptics = LocalHapticFeedback.current
    val isRtl = LocalLayoutDirection.current == LayoutDirection.Rtl
    val context = LocalContext.current
    val density = LocalDensity.current

    val initialIdx = remember(tracks) {
        tracks.indexOfFirst { it.id == activeTrackId }.coerceAtLeast(0)
    }

    var scrollPos by remember { mutableFloatStateOf(initialIdx.toFloat()) }
    var velocity by remember { mutableFloatStateOf(0f) }
    var targetPos by remember { mutableStateOf<Float?>(null) }
    var isDragging by remember { mutableStateOf(false) }
    var lastSnappedIdx by remember { mutableIntStateOf(initialIdx) }

    val latestTracks by rememberUpdatedState(tracks)
    val latestOnSelect by rememberUpdatedState(onSelectCenterTrack)
    val latestHaptics by rememberUpdatedState(hapticsEnabled)

    LaunchedEffect(activeTrackId, tracks) {
        val idx = tracks.indexOfFirst { it.id == activeTrackId }
        if (idx >= 0 && !isDragging && abs(scrollPos - idx) > 0.05f) {
            if (reduceMotion) {
                scrollPos = idx.toFloat()
                velocity = 0f
                targetPos = null
            } else {
                targetPos = idx.toFloat()
            }
            lastSnappedIdx = idx
        }
    }

    LaunchedEffect(Unit) {
        var lastNs = 0L
        while (true) {
            withFrameNanos { frameNs ->
                val dt = if (lastNs == 0L) 0.016f else ((frameNs - lastNs) / 1_000_000_000f).coerceIn(0.001f, 0.05f)
                lastNs = frameNs
                val maxIdx = (latestTracks.size - 1).coerceAtLeast(0).toFloat()

                if (!isDragging) {
                    val tp = targetPos
                    if (tp != null) {
                        val diff = tp - scrollPos
                        velocity += (diff * 125f - velocity * 20f) * dt
                        scrollPos += velocity * dt
                        if (abs(diff) < 0.002f && abs(velocity) < 0.01f) {
                            scrollPos = tp
                            velocity = 0f
                            targetPos = null
                        }
                    } else {
                        scrollPos += velocity * dt
                        velocity *= exp(-5.4f * dt)

                        if (scrollPos < 0f) {
                            scrollPos += (0f - scrollPos) * (dt * 18f).coerceIn(0f, 1f)
                            velocity *= 0.65f
                        } else if (scrollPos > maxIdx) {
                            scrollPos += (maxIdx - scrollPos) * (dt * 18f).coerceIn(0f, 1f)
                            velocity *= 0.65f
                        }

                        if (abs(velocity) < 1.35f) {
                            val nearest = scrollPos.roundToInt().toFloat().coerceIn(0f, maxIdx)
                            val diff = nearest - scrollPos
                            velocity += (diff * 110f - velocity * 18f) * dt
                            scrollPos += velocity * dt
                            if (abs(diff) < 0.0015f && abs(velocity) < 0.008f) {
                                scrollPos = nearest
                                velocity = 0f
                            }
                        }
                    }

                    val snapped = scrollPos.roundToInt().coerceIn(0, (latestTracks.size - 1).coerceAtLeast(0))
                    if (snapped != lastSnappedIdx) {
                        lastSnappedIdx = snapped
                        if (latestHaptics) haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        latestTracks.getOrNull(snapped)?.let(latestOnSelect)
                    }
                }
            }
        }
    }

    val spinTransition = rememberInfiniteTransition(label = "discSpin")
    val slowSpinDeg by spinTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(tween(8000, easing = LinearEasing), RepeatMode.Restart),
        label = "slowSpin"
    )

    BoxWithConstraints(
        modifier = modifier
            .fillMaxSize()
            .pointerInput(tracks.size) {
                val tracker = VelocityTracker()
                val stepPx = maxOf(140f, size.height * 0.168f)
                detectDragGestures(
                    onDragStart = {
                        isDragging = true
                        targetPos = null
                        velocity = 0f
                        tracker.resetTracking()
                    },
                    onDragEnd = {
                        isDragging = false
                        val vy = tracker.calculateVelocity().y
                        velocity = (-vy / stepPx).coerceIn(-14f, 14f)
                    },
                    onDragCancel = { isDragging = false },
                    onDrag = { change, dragAmount ->
                        change.consume()
                        tracker.addPosition(change.uptimeMillis, change.position)
                        val maxIdx = (latestTracks.size - 1).coerceAtLeast(0).toFloat()
                        val deltaIdx = -dragAmount.y / stepPx
                        val outOfBounds = (scrollPos <= 0f && deltaIdx < 0f) || (scrollPos >= maxIdx && deltaIdx > 0f)
                        scrollPos += if (outOfBounds) deltaIdx * 0.32f else deltaIdx
                        val snapped = scrollPos.roundToInt().coerceIn(0, (latestTracks.size - 1).coerceAtLeast(0))
                        if (snapped != lastSnappedIdx) {
                            lastSnappedIdx = snapped
                            if (latestHaptics) haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                            latestTracks.getOrNull(snapped)?.let(latestOnSelect)
                        }
                    }
                )
            }
    ) {
        val wPx = constraints.maxWidth.toFloat()
        val hPx = constraints.maxHeight.toFloat()
        val centerDiscPx = with(density) { minOf(96.dp.toPx(), maxOf(78.dp.toPx(), wPx * 0.238f)) }
        val capsulePadPx = with(density) { 7.dp.toPx() }
        val capsuleHeightPx = centerDiscPx + capsulePadPx * 2f
        val capsuleWidthPx = minOf(wPx - with(density) { 22.dp.toPx() }, wPx * 0.855f)

        tracks.forEachIndexed { idx, track ->
            val d = idx - scrollPos
            if (abs(d) > 3.85f) return@forEachIndexed

            val pl = OrbitalGeometry.computePlacement(d, wPx, hPx, isRtl, reduceMotion)
            val discDiameterPx = centerDiscPx * pl.scale
            val discDiameterDp = with(density) { discDiameterPx.toDp() }
            val isCentered = abs(d) < 0.35f
            val isThisPlaying = isPlaying && track.id == activeTrackId
            val bitmap = remember(track.id) { CoverArtRenderer.getBitmap(context, track).asImageBitmap() }

            // Active White / Charcoal Capsule
            if (pl.capsuleFactor > 0.02f) {
                val capLeftPx = if (isRtl) {
                    (wPx - (pl.xPx + centerDiscPx / 2f + capsulePadPx))
                } else {
                    pl.xPx - centerDiscPx / 2f - capsulePadPx
                }
                val capTopPx = pl.yPx - capsuleHeightPx / 2f

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                    modifier = Modifier
                        .offset { IntOffset(capLeftPx.roundToInt(), capTopPx.roundToInt()) }
                        .width(with(density) { capsuleWidthPx.toDp() })
                        .height(with(density) { capsuleHeightPx.toDp() })
                        .zIndex(8f)
                        .graphicsLayer {
                            alpha = pl.capsuleFactor
                            scaleX = 0.96f + pl.capsuleFactor * 0.04f
                            scaleY = 0.96f + pl.capsuleFactor * 0.04f
                        }
                        .shadow(16.dp, RoundedCornerShape(999.dp), ambientColor = palette.shadowDark, spotColor = palette.shadowDark)
                        .clip(RoundedCornerShape(999.dp))
                        .background(
                            Brush.linearGradient(listOf(palette.surface, palette.surfaceElevated))
                        )
                        .border(1.dp, palette.highlightRim, RoundedCornerShape(999.dp))
                        .clickable(enabled = isCentered) { onPlayAndOpen(track) }
                        .padding(start = with(density) { (centerDiscPx + 22f).toDp() }, end = 16.dp)
                ) {
                    Column(modifier = Modifier.weight(1f).padding(end = 8.dp)) {
                        Text(
                            text = track.title,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            color = palette.textPrimary,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        Spacer(Modifier.height(2.dp))
                        Text(
                            text = track.artist,
                            fontSize = 12.5.sp,
                            fontWeight = FontWeight.Medium,
                            color = palette.textSecondary,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }

                    Box(
                        contentAlignment = Alignment.Center,
                        modifier = Modifier
                            .height(32.dp)
                            .shadow(6.dp, RoundedCornerShape(999.dp), ambientColor = palette.shadowDark)
                            .clip(RoundedCornerShape(999.dp))
                            .background(palette.surface)
                            .border(1.dp, palette.highlightRim, RoundedCornerShape(999.dp))
                            .clickable { onPlayAndOpen(track) }
                            .padding(horizontal = 15.dp)
                    ) {
                        Text(
                            text = if (isThisPlaying) strings.playing else strings.play,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = palette.textPrimary
                        )
                    }
                }
            }

            // Circular Disc Cover
            val discVisualLeft = if (isRtl) {
                (wPx - (pl.xPx + discDiameterPx / 2f)).roundToInt()
            } else {
                (pl.xPx - discDiameterPx / 2f).roundToInt()
            }
            val discVisualTop = (pl.yPx - discDiameterPx / 2f).roundToInt()

            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .offset { IntOffset(discVisualLeft, discVisualTop) }
                    .size(discDiameterDp)
                    .zIndex(20f - abs(d) * 3f)
                    .alpha(pl.opacity)
                    .then(if (pl.blurDp > 0.15f) Modifier.blur(pl.blurDp.dp) else Modifier)
                    .shadow(14.dp, CircleShape, ambientColor = palette.shadowDark, spotColor = palette.shadowDark)
                    .clip(CircleShape)
                    .border(1.5.dp, palette.highlightRim, CircleShape)
                    .clickable {
                        if (isCentered) onPlayAndOpen(track) else targetPos = idx.toFloat()
                    }
            ) {
                Image(
                    bitmap = bitmap,
                    contentDescription = track.title,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .fillMaxSize()
                        .graphicsLayer {
                            if (isThisPlaying && !reduceMotion) rotationZ = slowSpinDeg
                        }
                )
                Canvas(modifier = Modifier.fillMaxSize()) {
                    drawCircle(
                        brush = Brush.linearGradient(
                            listOf(Color(0x38FFFFFF), Color.Transparent, Color(0x28000000))
                        )
                    )
                }
                Box(
                    modifier = Modifier
                        .size(discDiameterDp * 0.12f)
                        .clip(CircleShape)
                        .background(if (palette.isDark) Color(0xDC12151C) else Color(0xE6F4F6FA))
                        .border(1.dp, Color(0xA6FFFFFF), CircleShape)
                )
            }

            // Peripheral Tilted Labels
            if (pl.capsuleFactor < 0.85f) {
                val textLeftPx = if (isRtl) {
                    (wPx - (pl.xPx - discDiameterPx / 2f - with(density) { 16.dp.toPx() }) - with(density) { 165.dp.toPx() }).roundToInt()
                } else {
                    (pl.xPx + discDiameterPx / 2f + with(density) { 16.dp.toPx() }).roundToInt()
                }
                val textTopPx = (pl.yPx - with(density) { 21.dp.toPx() }).roundToInt()

                Column(
                    modifier = Modifier
                        .offset { IntOffset(textLeftPx, textTopPx) }
                        .width(165.dp)
                        .zIndex(16f - abs(d) * 3f)
                        .alpha(pl.opacity * (1f - pl.capsuleFactor))
                        .then(if (pl.blurDp > 0.15f) Modifier.blur(pl.blurDp.dp) else Modifier)
                        .graphicsLayer {
                            rotationZ = pl.tiltDeg
                            val textScale = 0.76f + pl.scale * 0.24f
                            scaleX = textScale
                            scaleY = textScale
                            transformOrigin = TransformOrigin(if (isRtl) 1f else 0f, 0.5f)
                        }
                        .clickable { targetPos = idx.toFloat() }
                ) {
                    Text(
                        text = track.title,
                        fontSize = 15.5.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = palette.textPrimary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Text(
                        text = track.artist,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium,
                        color = palette.textSecondary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
        }
    }
}
