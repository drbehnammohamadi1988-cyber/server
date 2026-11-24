package com.atelier.vinyl.audio

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.net.Uri
import com.atelier.vinyl.model.CoverMotif
import com.atelier.vinyl.model.VinylTrack
import java.util.concurrent.ConcurrentHashMap

object CoverArtRenderer {
    private val cache = ConcurrentHashMap<String, Bitmap>()

    fun getBitmap(context: Context, track: VinylTrack): Bitmap {
        cache[track.id]?.let { return it }

        val decoded = when {
            track.embeddedArtBytes != null -> {
                BitmapFactory.decodeByteArray(track.embeddedArtBytes, 0, track.embeddedArtBytes.size)
            }
            track.albumArtUri != null && track.albumArtUri != Uri.EMPTY -> {
                runCatching {
                    context.contentResolver.openInputStream(track.albumArtUri)?.use { stream ->
                        BitmapFactory.decodeStream(stream)
                    }
                }.getOrNull()
            }
            else -> null
        }

        val result = decoded ?: renderMotifBitmap(track.coverMotif)
        cache[track.id] = result
        return result
    }

    fun renderMotifBitmap(motif: CoverMotif, size: Int = 360): Bitmap {
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        val s = size.toFloat()

        when (motif) {
            CoverMotif.ARCHIVE_DAYLIGHT -> {
                p.shader = LinearGradient(
                    0f, 0f, s, s,
                    intArrayOf(0xFF1F2227.toInt(), 0xFF0B0C0F.toInt(), 0xFF282B32.toInt()),
                    null, Shader.TileMode.CLAMP
                )
                c.drawRect(0f, 0f, s, s, p)
                p.shader = null
                p.color = 0x18FFFFFF
                p.style = Paint.Style.STROKE
                p.strokeWidth = 2f
                c.drawCircle(s * 0.5f, s * 0.5f, s * 0.39f, p)
                p.style = Paint.Style.FILL
                c.save()
                c.rotate(-90f, s * 0.5f, s * 0.5f)
                p.color = 0xFFF2F4F8.toInt()
                p.textAlign = Paint.Align.CENTER
                p.typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
                p.textSize = s * 0.12f
                c.drawText("ARCHIVE", s * 0.5f, s * 0.54f, p)
                p.color = 0x99FFFFFF.toInt()
                p.textSize = s * 0.042f
                c.drawText("THE EDITION", s * 0.5f, s * 0.42f, p)
                c.restore()
            }

            CoverMotif.HORIZON_YELLOW -> {
                p.shader = LinearGradient(
                    0f, 0f, s, s,
                    intArrayOf(0xFFECEE45.toInt(), 0xFFD4D928.toInt(), 0xFF22252A.toInt()),
                    null, Shader.TileMode.CLAMP
                )
                c.drawRect(0f, 0f, s, s, p)
                p.shader = null
                p.color = 0xD817191D.toInt()
                val path = Path().apply {
                    moveTo(s * 0.45f, s * 0.14f)
                    lineTo(s * 0.95f, s * 0.1f)
                    lineTo(s * 0.98f, s * 0.95f)
                    lineTo(s * 0.30f, s * 0.98f)
                    close()
                }
                c.drawPath(path, p)
                p.color = 0xFF0E1013.toInt()
                p.typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
                p.textSize = s * 0.095f
                c.drawText("HORIZON", s * 0.14f, s * 0.42f, p)
                p.color = 0xFFF2F562.toInt()
                p.textSize = s * 0.045f
                c.drawText("SOLAR 04", s * 0.16f, s * 0.52f, p)
            }

            CoverMotif.DREAMS_STRIPE -> {
                c.drawColor(0xFFF2F3F6.toInt())
                p.color = 0xFF181A1E.toInt()
                c.save()
                c.rotate(-38f, s * 0.5f, s * 0.5f)
                c.drawRoundRect(RectF(-s * 0.25f, s * 0.08f, s * 1.25f, s * 0.26f), 40f, 40f, p)
                c.drawRoundRect(RectF(-s * 0.25f, s * 0.41f, s * 1.25f, s * 0.59f), 40f, 40f, p)
                c.drawRoundRect(RectF(-s * 0.25f, s * 0.74f, s * 1.25f, s * 0.92f), 40f, 40f, p)
                c.restore()
                p.color = 0xFFF4F5F8.toInt()
                c.drawCircle(s * 0.5f, s * 0.5f, s * 0.17f, p)
                p.color = 0xFF181A1E.toInt()
                p.style = Paint.Style.STROKE
                p.strokeWidth = 6f
                c.drawCircle(s * 0.5f, s * 0.5f, s * 0.17f, p)
            }

            CoverMotif.CASSETTE_PORTRAIT -> {
                p.shader = LinearGradient(
                    0f, 0f, s, s,
                    intArrayOf(0xFFFAFBFD.toInt(), 0xFFE5E8EE.toInt()),
                    null, Shader.TileMode.CLAMP
                )
                c.drawRect(0f, 0f, s, s, p)
                p.shader = null
                p.color = 0xFF16181C.toInt()
                c.drawCircle(s * 0.52f, s * 0.45f, s * 0.24f, p)
                c.drawRoundRect(RectF(s * 0.25f, s * 0.62f, s * 0.75f, s * 1.05f), 60f, 60f, p)
            }

            CoverMotif.CRIMSON_BAUHAUS -> {
                c.drawColor(0xFFECEEF3.toInt())
                p.color = 0xFFA4AAB6.toInt()
                c.drawRect(s * 0.5f, 0f, s, s, p)
                p.color = 0xFFD2D6DF.toInt()
                c.drawCircle(s * 0.5f, s * 0.5f, s * 0.30f, p)
                p.color = 0xFF1E222A.toInt()
                c.drawArc(RectF(s * 0.2f, s * 0.2f, s * 0.8f, s * 0.8f), -90f, 180f, true, p)
                p.color = 0xFFF4F5F8.toInt()
                c.drawCircle(s * 0.5f, s * 0.5f, s * 0.11f, p)
            }

            CoverMotif.FORGOTTEN_MIST -> {
                p.shader = RadialGradient(
                    s * 0.4f, s * 0.35f, s * 0.7f,
                    intArrayOf(Color.WHITE, 0xFFD7DCE5.toInt(), 0xFF9BA3B4.toInt()),
                    null, Shader.TileMode.CLAMP
                )
                c.drawRect(0f, 0f, s, s, p)
                p.shader = null
                p.color = 0xFF2D323E.toInt()
                p.textAlign = Paint.Align.CENTER
                p.typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
                p.textSize = s * 0.06f
                c.drawText("FORGOTTEN", s * 0.5f, s * 0.52f, p)
            }

            CoverMotif.PHANTOM_ARCH -> {
                p.shader = LinearGradient(
                    0f, 0f, 0f, s,
                    intArrayOf(0xFFE7EAEF.toInt(), 0xFFB9C0CE.toInt()),
                    null, Shader.TileMode.CLAMP
                )
                c.drawRect(0f, 0f, s, s, p)
                p.shader = null
                p.color = 0xFF20232B.toInt()
                c.drawCircle(s * 0.5f, s * 0.45f, s * 0.20f, p)
                c.drawRect(s * 0.30f, s * 0.45f, s * 0.70f, s * 0.85f, p)
                p.color = 0xFFE3E6EC.toInt()
                c.drawCircle(s * 0.5f, s * 0.46f, s * 0.12f, p)
                c.drawRect(s * 0.38f, s * 0.46f, s * 0.62f, s * 0.85f, p)
            }

            CoverMotif.ONE_WEEK_IVORY -> {
                p.shader = RadialGradient(
                    s * 0.38f, s * 0.32f, s * 0.72f,
                    intArrayOf(0xFFF7F8FA.toInt(), 0xFFE6E8EE.toInt(), 0xFFD2D6E0.toInt()),
                    null, Shader.TileMode.CLAMP
                )
                c.drawRect(0f, 0f, s, s, p)
                p.shader = null
                p.color = 0x241E222A
                p.style = Paint.Style.STROKE
                p.strokeWidth = 2f
                c.drawCircle(s * 0.5f, s * 0.5f, s * 0.41f, p)
                p.style = Paint.Style.FILL
                p.color = 0xFF181A20.toInt()
                p.textAlign = Paint.Align.CENTER
                p.typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
                p.textSize = s * 0.055f
                c.drawText("ONE WEEK LAST", s * 0.5f, s * 0.68f, p)
                p.color = 0xFF6B7384.toInt()
                p.textSize = s * 0.036f
                c.drawText("ATELIER · 33⅓", s * 0.5f, s * 0.35f, p)
            }

            CoverMotif.NOCTURNE_SILVER -> {
                p.shader = LinearGradient(
                    0f, 0f, s, s,
                    intArrayOf(0xFF222630.toInt(), 0xFF0E1015.toInt()),
                    null, Shader.TileMode.CLAMP
                )
                c.drawRect(0f, 0f, s, s, p)
                p.shader = null
                p.color = 0xFFD9DFE9.toInt()
                c.drawCircle(s * 0.5f, s * 0.5f, s * 0.21f, p)
                p.color = 0xFF14171F.toInt()
                p.textAlign = Paint.Align.CENTER
                p.typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
                p.textSize = s * 0.048f
                c.drawText("NOCTURNE", s * 0.5f, s * 0.52f, p)
            }

            CoverMotif.SOLSTICE_SLATE -> {
                c.drawColor(0xFFDDE2EC.toInt())
                p.color = 0xFF4B5568.toInt()
                c.drawCircle(s * 0.5f, s * 0.44f, s * 0.24f, p)
                p.color = 0xE6F2F4F8.toInt()
                c.drawRect(s * 0.15f, s * 0.54f, s * 0.85f, s * 0.88f, p)
            }
        }

        return bmp
    }
}
