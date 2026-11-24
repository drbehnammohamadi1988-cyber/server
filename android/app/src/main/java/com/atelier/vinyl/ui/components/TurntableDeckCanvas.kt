package com.atelier.vinyl.ui.components

import android.graphics.Bitmap
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.widthIn
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.atelier.vinyl.model.TurntablePhase
import com.atelier.vinyl.ui.theme.LocalAtelierPalette
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.roundToInt
import kotlin.math.sin

object TurntableKinematics {
    const val RPM_33_DEG_PER_SEC = 200f // 33⅓ RPM * 360 / 60 = 200 deg/sec
    const val ARM_PARK_DEG = -2.5f
    const val ARM_OUTER_GROOVE_DEG = 19.5f
    const val ARM_INNER_GROOVE_DEG = 34.5f

    fun targetArmAngle(progress: Float): Float {
        val p = progress.coerceIn(0f, 1f)
        return ARM_OUTER_GROOVE_DEG + (ARM_INNER_GROOVE_DEG - ARM_OUTER_GROOVE_DEG) * p
    }
}

@Composable
fun TurntableDeckCanvas(
    coverBitmap: Bitmap,
    isPlaying: Boolean,
    positionMs: Long,
    durationMs: Long,
    reduceMotion: Boolean,
    onTogglePlay: () -> Unit,
    onSeekMs: (Long) -> Unit,
    onPhaseChanged: (TurntablePhase) -> Unit,
    modifier: Modifier = Modifier
) {
    val palette = LocalAtelierPalette.current
    val coverImage = remember(coverBitmap) { coverBitmap.asImageBitmap() }

    val latestIsPlaying by rememberUpdatedState(isPlaying)
    val latestPosMs by rememberUpdatedState(positionMs)
    val latestDurMs by rememberUpdatedState(durationMs)
    val latestReduceMotion by rememberUpdatedState(reduceMotion)
    val latestOnSeek by rememberUpdatedState(onSeekMs)
    val latestOnTogglePlay by rememberUpdatedState(onTogglePlay)
    val latestOnPhase by rememberUpdatedState(onPhaseChanged)

    var discAngleDeg by remember { mutableFloatStateOf(24f) }
    var angularVelDeg by remember { mutableFloatStateOf(0f) }
    var armAngleDeg by remember {
        mutableFloatStateOf(if (isPlaying) TurntableKinematics.ARM_OUTER_GROOVE_DEG else TurntableKinematics.ARM_PARK_DEG)
    }
    var cueZ by remember { mutableFloatStateOf(0f) }
    var phase by remember { mutableStateOf(if (isPlaying) TurntablePhase.PLAYING else TurntablePhase.PARKED) }
    var cueTimer by remember { mutableFloatStateOf(0f) }
    var rpmMultiplier by remember { mutableFloatStateOf(1f) }
    var isScratching by remember { mutableStateOf(false) }
    var scratchTimeMs by remember { mutableStateOf(positionMs) }
    var lastPointerAngle by remember { mutableFloatStateOf(0f) }

    LaunchedEffect(Unit) {
        var lastNs = 0L
        var lastReported = phase
        while (true) {
            withFrameNanos { frameNs ->
                val dt = if (lastNs == 0L) 0.016f else ((frameNs - lastNs) / 1_000_000_000f).coerceIn(0.001f, 0.05f)
                lastNs = frameNs

                val dur = latestDurMs.coerceAtLeast(1L).toFloat()
                val curMs = if (isScratching) scratchTimeMs else latestPosMs
                val progress = (curMs / dur).coerceIn(0f, 1f)
                val targetAngle = TurntableKinematics.targetArmAngle(progress)

                fun lerp(a: Float, b: Float, t: Float) = a + (b - a) * t.coerceIn(0f, 1f)

                if (isScratching) {
                    phase = TurntablePhase.SCRATCHING
                    cueZ = lerp(cueZ, 0f, dt * 14f)
                    armAngleDeg = lerp(armAngleDeg, targetAngle, dt * 18f)
                } else if (latestIsPlaying) {
                    if (phase == TurntablePhase.PARKED || phase == TurntablePhase.RETURNING) {
                        phase = TurntablePhase.CUEING_IN
                        cueTimer = 0f
                    }
                    if (phase == TurntablePhase.CUEING_IN) {
                        cueTimer += dt
                        if (latestReduceMotion) {
                            armAngleDeg = targetAngle
                            cueZ = 0f
                            phase = TurntablePhase.PLAYING
                        } else {
                            when {
                                cueTimer < 0.20f -> cueZ = lerp(cueZ, 1f, dt * 14f)
                                cueTimer < 0.72f -> {
                                    cueZ = lerp(cueZ, 1f, dt * 10f)
                                    armAngleDeg = lerp(armAngleDeg, targetAngle, dt * 7.5f)
                                }
                                cueTimer < 1.05f -> {
                                    armAngleDeg = lerp(armAngleDeg, targetAngle, dt * 10f)
                                    cueZ = lerp(cueZ, 0f, dt * 9.5f)
                                }
                                else -> {
                                    cueZ = 0f
                                    phase = TurntablePhase.PLAYING
                                }
                            }
                        }
                    } else {
                        phase = TurntablePhase.PLAYING
                        cueZ = lerp(cueZ, 0f, dt * 10f)
                        armAngleDeg = lerp(armAngleDeg, targetAngle, dt * 10f)
                    }

                    val targetVel = if (latestReduceMotion) 0f else TurntableKinematics.RPM_33_DEG_PER_SEC * rpmMultiplier
                    angularVelDeg = lerp(angularVelDeg, targetVel, dt * 3.1f)
                } else {
                    val atBoundary = curMs <= 120L || curMs >= latestDurMs - 350L
                    if (atBoundary && abs(armAngleDeg - TurntableKinematics.ARM_PARK_DEG) > 0.7f) {
                        phase = TurntablePhase.RETURNING
                        cueZ = lerp(cueZ, 1f, dt * 10f)
                        if (cueZ > 0.45f) armAngleDeg = lerp(armAngleDeg, TurntableKinematics.ARM_PARK_DEG, dt * 6.5f)
                        if (abs(armAngleDeg - TurntableKinematics.ARM_PARK_DEG) <= 0.9f) {
                            armAngleDeg = TurntableKinematics.ARM_PARK_DEG
                            phase = TurntablePhase.PARKED
                        }
                    } else if (atBoundary) {
                        phase = TurntablePhase.PARKED
                        armAngleDeg = lerp(armAngleDeg, TurntableKinematics.ARM_PARK_DEG, dt * 10f)
                        cueZ = lerp(cueZ, 0f, dt * 8f)
                    } else {
                        phase = TurntablePhase.PAUSED_HOVER
                        cueZ = lerp(cueZ, 0.68f, dt * 9f)
                        armAngleDeg = lerp(armAngleDeg, targetAngle, dt * 8f)
                    }

                    angularVelDeg = lerp(angularVelDeg, 0f, dt * 2.4f)
                    if (angularVelDeg < 0.5f) angularVelDeg = 0f
                }

                if (!isScratching) {
                    discAngleDeg = (discAngleDeg + angularVelDeg * dt) % 360f
                }

                if (phase != lastReported) {
                    lastReported = phase
                    latestOnPhase(phase)
                }
            }
        }
    }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .widthIn(max = 356.dp)
            .aspectRatio(1.06f)
    ) {
        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(1.06f)
                .pointerInput(Unit) {
                    detectTapGestures { tap ->
                        val w = size.width.toFloat()
                        val h = size.height.toFloat()
                        val pad = w * 0.028f
                        val topOffset = pad * 1.45f
                        val deckW = w - pad * 2
                        val deckH = h - topOffset - pad * 0.9f
                        val knobCx = pad + deckW * 0.115f
                        val knobCy = topOffset + deckH * 0.87f
                        val knobR = deckW * 0.08f
                        val btnCx = pad + deckW * 0.885f
                        val btnCy = topOffset + deckH * 0.87f
                        val btnR = deckW * 0.08f

                        if (hypot(tap.x - btnCx, tap.y - btnCy) <= btnR * 1.35f) {
                            latestOnTogglePlay()
                        } else if (hypot(tap.x - knobCx, tap.y - knobCy) <= knobR * 1.35f) {
                            rpmMultiplier = if (rpmMultiplier == 1f) 1.35f else 1f
                        }
                    }
                }
                .pointerInput(Unit) {
                    detectDragGestures(
                        onDragStart = { start ->
                            val w = size.width.toFloat()
                            val h = size.height.toFloat()
                            val pad = w * 0.028f
                            val topOffset = pad * 1.45f
                            val deckW = w - pad * 2
                            val deckH = h - topOffset - pad * 0.9f
                            val cx = pad + deckW * 0.44f
                            val cy = topOffset + deckH * 0.51f
                            val vinylR = deckH * 0.405f
                            val dist = hypot(start.x - cx, start.y - cy)
                            if (dist in (vinylR * 0.14f)..(vinylR * 1.05f)) {
                                isScratching = true
                                scratchTimeMs = latestPosMs
                                lastPointerAngle = atan2(start.y - cy, start.x - cx)
                            }
                        },
                        onDragEnd = { isScratching = false },
                        onDragCancel = { isScratching = false },
                        onDrag = { change, _ ->
                            if (!isScratching) return@detectDragGestures
                            change.consume()
                            val w = size.width.toFloat()
                            val h = size.height.toFloat()
                            val pad = w * 0.028f
                            val topOffset = pad * 1.45f
                            val deckW = w - pad * 2
                            val deckH = h - topOffset - pad * 0.9f
                            val cx = pad + deckW * 0.44f
                            val cy = topOffset + deckH * 0.51f
                            val ptrAngle = atan2(change.position.y - cy, change.position.x - cx)
                            var deltaRad = ptrAngle - lastPointerAngle
                            while (deltaRad > PI) deltaRad -= (2 * PI).toFloat()
                            while (deltaRad < -PI) deltaRad += (2 * PI).toFloat()
                            lastPointerAngle = ptrAngle
                            val deltaDeg = (deltaRad * 180f / PI.toFloat())
                            discAngleDeg = (discAngleDeg + deltaDeg) % 360f
                            val msPerDeg = 10_000f / 360f
                            scratchTimeMs = (scratchTimeMs + (deltaDeg * msPerDeg).toLong())
                                .coerceIn(0L, latestDurMs.coerceAtLeast(1L))
                            latestOnSeek(scratchTimeMs)
                        }
                    )
                }
        ) {
            drawTurntableHardware(
                isDark = palette.isDark,
                discAngleDeg = discAngleDeg,
                armAngleDeg = armAngleDeg,
                cueZ = cueZ,
                rpmMultiplier = rpmMultiplier,
                isPlayingPhase = phase == TurntablePhase.PLAYING || phase == TurntablePhase.CUEING_IN,
                coverImage = coverImage
            )
        }
    }
}

private fun DrawScope.drawTurntableHardware(
    isDark: Boolean,
    discAngleDeg: Float,
    armAngleDeg: Float,
    cueZ: Float,
    rpmMultiplier: Float,
    isPlayingPhase: Boolean,
    coverImage: androidx.compose.ui.graphics.ImageBitmap
) {
    val w = size.width
    val h = size.height
    val pad = w * 0.028f
    val topOffset = pad * 1.45f
    val deckW = w - pad * 2
    val deckH = h - topOffset - pad * 0.9f
    val rx = deckW * 0.045f

    // 1. Top edge brass/steel hinge pins matching reference
    val hingeW = deckW * 0.052f
    val hingeH = topOffset * 0.95f
    listOf(pad + deckW * 0.43f, pad + deckW * 0.56f).forEach { hx ->
        drawRoundRect(
            brush = Brush.horizontalGradient(
                if (isDark) listOf(Color(0xFF5A6170), Color(0xFF9BA3B4), Color(0xFF262A34))
                else listOf(Color(0xFFA58E63), Color(0xFFDFCA9A), Color(0xFF6C5A3C))
            ),
            topLeft = Offset(hx, topOffset - hingeH * 0.85f),
            size = Size(hingeW, hingeH),
            cornerRadius = CornerRadius(4f, 4f)
        )
    }

    // 2. Plinth Outer Ambient Shadow
    drawRoundRect(
        color = if (isDark) Color(0xAA000000) else Color(0x3D828EA8),
        topLeft = Offset(pad + w * 0.012f, topOffset + w * 0.024f),
        size = Size(deckW, deckH),
        cornerRadius = CornerRadius(rx, rx)
    )

    // 3. Brushed Anodized Metal Chassis Body
    drawRoundRect(
        brush = Brush.linearGradient(
            colors = if (isDark) listOf(Color(0xFF232833), Color(0xFF1A1E27), Color(0xFF13161D))
            else listOf(Color(0xFFF6F7FA), Color(0xFFECEEF3), Color(0xFFE1E5EE)),
            start = Offset(pad, topOffset),
            end = Offset(pad + deckW, topOffset + deckH)
        ),
        topLeft = Offset(pad, topOffset),
        size = Size(deckW, deckH),
        cornerRadius = CornerRadius(rx, rx)
    )

    // Subtle brushed horizontal grain lines clipped inside chassis
    val chassisPath = Path().apply {
        addRoundRect(
            androidx.compose.ui.geometry.RoundRect(
                left = pad, top = topOffset, right = pad + deckW, bottom = topOffset + deckH,
                cornerRadius = CornerRadius(rx, rx)
            )
        )
    }
    clipPath(chassisPath) {
        val lineCount = 48
        for (i in 0 until lineCount) {
            val ly = topOffset + (i.toFloat() / lineCount) * deckH
            drawLine(
                color = if (isDark) {
                    if (i % 2 == 0) Color(0x06FFFFFF) else Color(0x0C000000)
                } else {
                    if (i % 2 == 0) Color(0x28FFFFFF) else Color(0x0A949EB0)
                },
                start = Offset(pad, ly),
                end = Offset(pad + deckW, ly),
                strokeWidth = 1.2f
            )
        }
    }

    drawRoundRect(
        color = if (isDark) Color(0x14FFFFFF) else Color(0xEBFFFFFF),
        topLeft = Offset(pad, topOffset),
        size = Size(deckW, deckH),
        cornerRadius = CornerRadius(rx, rx),
        style = Stroke(width = 1.5f)
    )

    // Corner micro fasteners
    val screwInset = deckW * 0.048f
    listOf(
        Offset(pad + screwInset, topOffset + screwInset),
        Offset(pad + deckW - screwInset, topOffset + screwInset),
        Offset(pad + screwInset, topOffset + deckH - screwInset),
        Offset(pad + deckW - screwInset, topOffset + deckH - screwInset)
    ).forEach { sc ->
        drawCircle(if (isDark) Color(0xFF0D0F14) else Color(0xFFC6CCD8), radius = 3.2f, center = sc)
        drawCircle(if (isDark) Color(0xFF323846) else Color(0xFFFAFBFD), radius = 2.0f, center = sc - Offset(0.7f, 0.7f))
    }

    // 4. Recessed Platter Well
    val platterCx = pad + deckW * 0.44f
    val platterCy = topOffset + deckH * 0.51f
    val platterCenter = Offset(platterCx, platterCy)
    val vinylR = deckH * 0.405f
    val platterR = vinylR * 1.045f

    drawCircle(
        color = if (isDark) Color(0xFF101319) else Color(0xFFDEE2EA),
        radius = platterR,
        center = platterCenter
    )
    drawCircle(
        color = if (isDark) Color(0xCC000000) else Color(0x44828EA8),
        radius = platterR,
        center = platterCenter,
        style = Stroke(width = 3f)
    )

    // Strobe dots around platter rim
    rotate(discAngleDeg, pivot = platterCenter) {
        for (i in 0 until 60) {
            val a = (i / 60f) * (2f * PI.toFloat())
            val p0 = Offset(platterCx + cos(a) * vinylR * 1.012f, platterCy + sin(a) * vinylR * 1.012f)
            val p1 = Offset(platterCx + cos(a) * vinylR * 1.032f, platterCy + sin(a) * vinylR * 1.032f)
            drawLine(
                color = if (isDark) Color(0x2CD2DCF0) else Color(0x47737E94),
                start = p0, end = p1, strokeWidth = 1.4f
            )
        }
    }

    // 5. Vinyl Disc Body + Grooves + Fixed-Light Anisotropic Sheen + Rotating Cover Label
    drawCircle(
        color = if (isDark) Color(0xD8000000) else Color(0x4D121620),
        radius = vinylR,
        center = platterCenter + Offset(4f, 7f)
    )
    drawCircle(
        brush = Brush.radialGradient(
            colors = listOf(Color(0xFF1C1F27), Color(0xFF0A0B0F), Color(0xFF050608)),
            center = platterCenter - Offset(vinylR * 0.22f, vinylR * 0.22f),
            radius = vinylR * 1.15f
        ),
        radius = vinylR,
        center = platterCenter
    )

    // Micro grooves
    val labelR = vinylR * 0.345f
    val grooveStart = vinylR * 0.39f
    val grooveEnd = vinylR * 0.965f
    for (i in 0 until 64) {
        val r = grooveStart + (grooveEnd - grooveStart) * (i / 64f)
        val isBandGap = i == 18 || i == 40 || i == 56
        drawCircle(
            color = if (isBandGap) Color(0x18FFFFFF) else if (i % 3 == 0) Color(0x0BFFFFFF) else Color(0x70000000),
            radius = r,
            center = platterCenter,
            style = Stroke(width = if (isBandGap) 2.0f else 0.9f)
        )
    }

    // Stationary Bow-Tie Anisotropic Reflections anchored to Fixed Top-Left Studio Light
    listOf(-42f, 138f).forEach { sheenAngle ->
        rotate(sheenAngle, pivot = platterCenter) {
            drawArc(
                brush = Brush.linearGradient(
                    colors = listOf(
                        Color.Transparent,
                        Color(0x22FFFFFF),
                        Color(0x42FFFFFF),
                        Color(0x22FFFFFF),
                        Color.Transparent
                    ),
                    start = Offset(platterCx, platterCy - vinylR * 0.36f),
                    end = Offset(platterCx + vinylR, platterCy + vinylR * 0.36f)
                ),
                startAngle = -19f,
                sweepAngle = 38f,
                useCenter = true,
                topLeft = Offset(platterCx - vinylR * 0.98f, platterCy - vinylR * 0.98f),
                size = Size(vinylR * 1.96f, vinylR * 1.96f)
            )
        }
    }

    // Rotating Center Label with Album Cover Art
    rotate(discAngleDeg, pivot = platterCenter) {
        drawCircle(Color(0xFFEAECEF), radius = labelR, center = platterCenter)
        val artR = labelR * 0.93f
        val artPath = Path().apply {
            addOval(Rect(platterCx - artR, platterCy - artR, platterCx + artR, platterCy + artR))
        }
        clipPath(artPath) {
            drawImage(
                image = coverImage,
                dstOffset = IntOffset((platterCx - artR).roundToInt(), (platterCy - artR).roundToInt()),
                dstSize = IntSize((artR * 2f).roundToInt(), (artR * 2f).roundToInt())
            )
        }
    }

    // Center brushed steel spindle + directional shadow
    val spindleR = vinylR * 0.052f
    drawCircle(Color(0x5A000000), radius = spindleR * 1.18f, center = platterCenter + Offset(2f, 2.5f))
    drawCircle(
        brush = Brush.radialGradient(
            listOf(Color.White, Color(0xFFB7BECB), Color(0xFF5B6270)),
            center = platterCenter - Offset(spindleR * 0.3f, spindleR * 0.3f),
            radius = spindleR * 1.2f
        ),
        radius = spindleR,
        center = platterCenter
    )

    // 6. Bottom-Left Rotary Knob (with 3-spoke Y selector)
    val knobCx = pad + deckW * 0.115f
    val knobCy = topOffset + deckH * 0.87f
    val knobCenter = Offset(knobCx, knobCy)
    val knobR = deckW * 0.072f
    drawCircle(if (isDark) Color(0xAA000000) else Color(0x558C98AF), radius = knobR, center = knobCenter + Offset(3f, 5f))
    drawCircle(
        brush = Brush.linearGradient(
            if (isDark) listOf(Color(0xFF2C313E), Color(0xFF161922))
            else listOf(Color(0xFFF7F8FB), Color(0xFFDDE1EA))
        ),
        radius = knobR,
        center = knobCenter
    )
    drawCircle(
        color = if (isDark) Color(0x18FFFFFF) else Color(0xE8FFFFFF),
        radius = knobR,
        center = knobCenter,
        style = Stroke(width = 1.4f)
    )
    drawCircle(
        color = if (isDark) Color(0x70000000) else Color(0x40828EA8),
        radius = knobR * 0.72f,
        center = knobCenter,
        style = Stroke(width = 1.2f)
    )
    val knobAngleRad = if (rpmMultiplier > 1.1f) 0.45f else 0f
    listOf(-PI.toFloat() / 2f, PI.toFloat() / 6f, 5f * PI.toFloat() / 6f).forEach { a ->
        val ra = a + knobAngleRad
        drawLine(
            color = if (isDark) Color(0x70D2DCF0) else Color(0x88697388),
            start = knobCenter,
            end = Offset(knobCx + cos(ra) * knobR * 0.72f, knobCy + sin(ra) * knobR * 0.72f),
            strokeWidth = 1.6f
        )
    }

    // 7. Bottom-Right Circular Start/Stop Button
    val btnCx = pad + deckW * 0.885f
    val btnCy = topOffset + deckH * 0.87f
    val btnCenter = Offset(btnCx, btnCy)
    val btnR = deckW * 0.068f
    drawCircle(if (isDark) Color(0xAA000000) else Color(0x4D8C98AF), radius = btnR, center = btnCenter + Offset(2.5f, 4f))
    drawCircle(
        brush = Brush.linearGradient(
            if (isDark) listOf(Color(0xFF292E3A), Color(0xFF14171F))
            else listOf(Color(0xFFF8F9FC), Color(0xFFDFE3EC))
        ),
        radius = btnR,
        center = btnCenter
    )
    drawCircle(
        color = if (isPlayingPhase) {
            if (isDark) Color(0x88D2E0F5) else Color(0x66414C62)
        } else {
            if (isDark) Color(0x16FFFFFF) else Color(0x44828EA8)
        },
        radius = btnR * 0.84f,
        center = btnCenter,
        style = Stroke(width = 1.6f)
    )

    // 8. Independent Mechanical Tonearm & Gimbal (Top-Right)
    val pivotX = pad + deckW * 0.875f
    val pivotY = topOffset + deckH * 0.168f
    val pivot = Offset(pivotX, pivotY)
    val armBaseR = deckW * 0.088f

    // Armrest clip
    drawRoundRect(
        color = if (isDark) Color(0xFF2D323E) else Color(0xFF8D95A5),
        topLeft = Offset(pad + deckW * 0.885f - 5f, topOffset + deckH * 0.48f - 10f),
        size = Size(10f, 20f),
        cornerRadius = CornerRadius(4f, 4f)
    )

    // Gimbal housing
    drawCircle(if (isDark) Color(0xFF12151C) else Color(0xFFD9DDE7), radius = armBaseR, center = pivot)
    drawCircle(
        brush = Brush.radialGradient(
            if (isDark) listOf(Color(0xFF4C5364), Color(0xFF252A34), Color(0xFF14171E))
            else listOf(Color.White, Color(0xFFD6DBE5), Color(0xFFA5AEBF)),
            center = pivot - Offset(armBaseR * 0.25f, armBaseR * 0.25f),
            radius = armBaseR * 0.9f
        ),
        radius = armBaseR * 0.78f,
        center = pivot
    )

    val armLen = deckH * 0.56f
    val tubeTipY = armLen * 0.84f
    val headshellOffsetX = -deckW * 0.048f
    val shadowOff = Offset(5f + cueZ * 11f, 6f + cueZ * 12f)

    // Shadow pass beneath tonearm
    rotate(armAngleDeg, pivot = pivot + shadowOff) {
        drawLine(
            color = if (isDark) Color(0x88000000) else Color(0x361C2230),
            start = pivot + shadowOff - Offset(0f, deckH * 0.08f),
            end = pivot + shadowOff + Offset(headshellOffsetX, armLen),
            strokeWidth = deckW * 0.022f,
            cap = StrokeCap.Round
        )
    }

    // Tonearm physical pass
    rotate(armAngleDeg, pivot = pivot) {
        // Counterweight barrel
        val cwW = deckW * 0.056f
        val cwH = deckH * 0.115f
        drawRoundRect(
            brush = Brush.horizontalGradient(
                listOf(Color(0xFF4E5462), Color(0xFFEDF0F6), Color(0xFF7A8294), Color(0xFF2D313B))
            ),
            topLeft = Offset(pivotX - cwW / 2f, pivotY - cwH * 0.85f),
            size = Size(cwW, cwH),
            cornerRadius = CornerRadius(4f, 4f)
        )
        drawRoundRect(
            color = Color(0xFF17191F),
            topLeft = Offset(pivotX - cwW * 0.44f, pivotY - cwH * 0.88f),
            size = Size(cwW * 0.88f, cwH * 0.2f),
            cornerRadius = CornerRadius(3f, 3f)
        )

        // Precision tube
        drawLine(
            color = if (isDark) Color(0xFFC2CAD8) else Color(0xFF20242C),
            start = pivot,
            end = Offset(pivotX, pivotY + tubeTipY),
            strokeWidth = deckW * 0.017f,
            cap = StrokeCap.Round
        )
        drawLine(
            color = if (isDark) Color(0xFFC2CAD8) else Color(0xFF20242C),
            start = Offset(pivotX, pivotY + tubeTipY),
            end = Offset(pivotX + headshellOffsetX, pivotY + armLen),
            strokeWidth = deckW * 0.015f,
            cap = StrokeCap.Round
        )

        // Headshell & Stylus
        val hsCenter = Offset(pivotX + headshellOffsetX, pivotY + armLen - deckH * 0.01f)
        rotate(14f, pivot = hsCenter) {
            val hsW = deckW * 0.036f
            val hsH = deckH * 0.086f
            drawRoundRect(
                color = if (isDark) Color(0xFF2D323E) else Color(0xFF181B22),
                topLeft = Offset(hsCenter.x - hsW / 2f, hsCenter.y - hsH * 0.3f),
                size = Size(hsW, hsH),
                cornerRadius = CornerRadius(3f, 3f)
            )
            drawCircle(
                color = if (isPlayingPhase) Color(0xFFE4ECFA) else Color(0xFF7D8698),
                radius = 2.6f,
                center = Offset(hsCenter.x, hsCenter.y + hsH * 0.68f)
            )
        }

        // Gimbal top yoke cap
        drawCircle(if (isDark) Color(0xFF20242E) else Color(0xFF323743), radius = armBaseR * 0.34f, center = pivot)
        drawCircle(if (isDark) Color(0xFF8C96AB) else Color(0xFFA6AEBE), radius = armBaseR * 0.14f, center = pivot - Offset(1.5f, 1.5f))
    }
}
