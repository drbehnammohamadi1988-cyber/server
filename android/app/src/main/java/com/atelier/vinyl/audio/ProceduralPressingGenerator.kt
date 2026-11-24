package com.atelier.vinyl.audio

import android.content.Context
import android.net.Uri
import com.atelier.vinyl.model.CoverMotif
import com.atelier.vinyl.model.SynthSpec
import com.atelier.vinyl.model.VinylTrack
import java.io.File
import java.io.FileOutputStream
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.tanh

/**
 * Generates clean studio PCM WAV audio pressings locally on first app launch
 * so all built-in showcase tracks produce real audible playback via Media3 ExoPlayer
 * and drive real FFT spectrum + Equalizer hardware DSP.
 */
object ProceduralPressingGenerator {

    private data class SeedTrack(
        val id: String,
        val title: String,
        val artist: String,
        val album: String,
        val durationSec: Int,
        val format: String,
        val motif: CoverMotif,
        val spec: SynthSpec
    )

    private val catalogSeeds = listOf(
        SeedTrack("trk-forgotten", "Forgotten", "Nguyen, Shane", "Porcelain Echoes", 194, "FLAC", CoverMotif.FORGOTTEN_MIST, SynthSpec(78f, 57, "ambient", 0.72f, 0.38f)),
        SeedTrack("trk-dreams", "Dreams", "Miles, Esther", "Monochrome Study", 176, "FLAC", CoverMotif.DREAMS_STRIPE, SynthSpec(92f, 60, "maj7", 0.58f, 0.68f)),
        SeedTrack("trk-horizon", "Horizon", "Kristin", "Solaris 04", 188, "WAV", CoverMotif.HORIZON_YELLOW, SynthSpec(104f, 62, "dorian", 0.45f, 0.85f)),
        SeedTrack("trk-daylight", "Day light", "Kernin Joki", "The Archive", 165, "FLAC", CoverMotif.ARCHIVE_DAYLIGHT, SynthSpec(88f, 55, "minor9", 0.65f, 0.78f)),
        SeedTrack("trk-cassette", "Cassette", "Black, Marvin", "Magnetic Tape", 204, "WAV", CoverMotif.CASSETTE_PORTRAIT, SynthSpec(82f, 53, "minor9", 0.84f, 0.64f)),
        SeedTrack("trk-crimson", "Crimson", "Henry, Arthur", "Bauhaus Sessions", 182, "AAC", CoverMotif.CRIMSON_BAUHAUS, SynthSpec(96f, 58, "dorian", 0.55f, 0.74f)),
        SeedTrack("trk-phantom", "Phantom", "Flores, Juanita", "Porcelain Echoes", 212, "MP3", CoverMotif.PHANTOM_ARCH, SynthSpec(74f, 52, "ambient", 0.78f, 0.45f)),
        SeedTrack("trk-one-week-last", "One Week Last", "Justin Bibber", "Atelier Pressings", 165, "FLAC", CoverMotif.ONE_WEEK_IVORY, SynthSpec(90f, 60, "minor9", 0.68f, 0.76f)),
        SeedTrack("trk-nocturne", "Nocturne in Silver", "Kernin Joki", "The Archive", 198, "FLAC", CoverMotif.NOCTURNE_SILVER, SynthSpec(84f, 56, "maj7", 0.72f, 0.58f)),
        SeedTrack("trk-solstice", "Winter Solstice", "Miles, Esther", "Monochrome Study", 171, "OGG", CoverMotif.SOLSTICE_SLATE, SynthSpec(86f, 59, "maj7", 0.62f, 0.62f)),
    )

    fun ensureDemoTracks(context: Context): List<VinylTrack> {
        val dir = File(context.filesDir, "pressings").apply { mkdirs() }
        return catalogSeeds.map { seed ->
            val file = File(dir, "${seed.id}.wav")
            if (!file.exists() || file.length() < 1024) {
                writeWavFile(file, seed.spec, seed.durationSec)
            }
            VinylTrack(
                id = seed.id,
                title = seed.title,
                artist = seed.artist,
                album = seed.album,
                durationMs = seed.durationSec * 1000L,
                uri = Uri.fromFile(file),
                format = seed.format,
                coverMotif = seed.motif,
                isDemo = true,
                synthSpec = seed.spec
            )
        }
    }

    private fun midiToFreq(midi: Int): Double = 440.0 * 2.0.pow((midi - 69) / 12.0)

    private fun writeWavFile(file: File, spec: SynthSpec, targetDurationSec: Int) {
        val sampleRate = 22050
        val totalSamples = targetDurationSec * sampleRate
        val beatSec = 60.0 / spec.bpm
        val barSec = beatSec * 4.0
        val phraseBars = 4
        val phraseSamples = (barSec * phraseBars * sampleRate).toInt()
        val phrase = FloatArray(phraseSamples)

        val chords = when (spec.mode) {
            "maj7" -> arrayOf(intArrayOf(0, 4, 7, 11, 14), intArrayOf(5, 9, 12, 16, 19), intArrayOf(2, 5, 9, 12, 16), intArrayOf(7, 11, 14, 17, 21))
            "dorian" -> arrayOf(intArrayOf(0, 3, 7, 10, 14), intArrayOf(2, 5, 9, 12, 16), intArrayOf(7, 10, 14, 17, 19), intArrayOf(5, 9, 12, 15, 19))
            "ambient" -> arrayOf(intArrayOf(0, 7, 12, 14, 19), intArrayOf(-4, 3, 7, 11, 14), intArrayOf(5, 12, 17, 19, 24), intArrayOf(2, 9, 14, 16, 21))
            else -> arrayOf(intArrayOf(0, 3, 7, 10, 14), intArrayOf(5, 8, 12, 15, 19), intArrayOf(3, 7, 10, 14, 17), intArrayOf(7, 10, 14, 17, 21))
        }

        val barSamples = (barSec * sampleRate).toInt()
        val stepSamples = ((beatSec / 2.0) * sampleRate).toInt()
        var seed = (spec.rootMidi * 9301 + (spec.bpm * 49).toInt()).toLong()

        fun nextRand(): Float {
            seed = (seed * 1664525L + 1013904223L) and 0xffffffffL
            return (seed.toDouble() / 0xffffffffL.toDouble()).toFloat() * 2f - 1f
        }

        for (bar in 0 until phraseBars) {
            val chord = chords[bar % chords.size]
            val barStart = bar * barSamples

            for (n in chord.indices) {
                val freq = midiToFreq(spec.rootMidi + chord[n])
                val omega = (2.0 * PI * freq) / sampleRate
                val amp = (0.09 / (1.0 + n * 0.24)).toFloat()
                for (i in 0 until barSamples) {
                    val idx = barStart + i
                    if (idx >= phraseSamples) break
                    val t = i.toDouble() / barSamples
                    val env = minOf(1.0, i / (sampleRate * 0.04)) * exp(-t * 1.45) * (1.0 - t.pow(8.0))
                    phrase[idx] += (sin(i * omega) + 0.22 * sin(i * omega * 2.0)).toFloat() * amp * env.toFloat()
                }
            }

            for (beat in 0 until 4) {
                val bassFreq = midiToFreq(spec.rootMidi - 12 + if (beat == 2) chord[2] else chord[0])
                val omega = (2.0 * PI * bassFreq) / sampleRate
                val start = barStart + (beat * beatSec * sampleRate).toInt()
                val len = (beatSec * 0.85 * sampleRate).toInt()
                for (i in 0 until len) {
                    val idx = start + i
                    if (idx >= phraseSamples) break
                    val t = i.toDouble() / len
                    val env = minOf(1.0, i / (sampleRate * 0.015)) * exp(-t * 2.3)
                    phrase[idx] += (sin(i * omega) * 0.24).toFloat() * env.toFloat()
                }
            }

            if (spec.grooveIntensity > 0.35f) {
                for (s in 0 until 8) {
                    val start = barStart + s * stepSamples
                    if (s == 0 || s == 4) {
                        val kLen = (sampleRate * 0.15).toInt()
                        var phase = 0.0
                        for (i in 0 until kLen) {
                            val idx = start + i
                            if (idx >= phraseSamples) break
                            val t = i.toDouble() / kLen
                            val f = 46.0 + 104.0 * exp(-t * 14.0)
                            phase += (2.0 * PI * f) / sampleRate
                            phrase[idx] += (sin(phase) * 0.26 * spec.grooveIntensity * exp(-t * 5.0)).toFloat()
                        }
                    }
                    val hLen = (sampleRate * 0.03).toInt()
                    for (i in 0 until hLen) {
                        val idx = start + i
                        if (idx >= phraseSamples) break
                        val t = i.toDouble() / hLen
                        phrase[idx] += nextRand() * 0.03f * spec.grooveIntensity * exp(-t * 10.0).toFloat()
                    }
                }
            }
        }

        val dataBytes = totalSamples * 2
        val header = ByteArray(44)
        fun putStr(off: Int, str: String) {
            str.forEachIndexed { idx, ch -> header[off + idx] = ch.code.toByte() }
        }
        fun putIntLE(off: Int, v: Int) {
            header[off] = (v and 0xff).toByte()
            header[off + 1] = ((v ushr 8) and 0xff).toByte()
            header[off + 2] = ((v ushr 16) and 0xff).toByte()
            header[off + 3] = ((v ushr 24) and 0xff).toByte()
        }
        fun putShortLE(off: Int, v: Int) {
            header[off] = (v and 0xff).toByte()
            header[off + 1] = ((v ushr 8) and 0xff).toByte()
        }

        putStr(0, "RIFF")
        putIntLE(4, 36 + dataBytes)
        putStr(8, "WAVE")
        putStr(12, "fmt ")
        putIntLE(16, 16)
        putShortLE(20, 1)
        putShortLE(22, 1)
        putIntLE(24, sampleRate)
        putIntLE(28, sampleRate * 2)
        putShortLE(32, 2)
        putShortLE(34, 16)
        putStr(36, "data")
        putIntLE(40, dataBytes)

        val chunk = ByteArray(16384)
        var chunkPos = 0
        FileOutputStream(file).use { out ->
            out.write(header)
            val fadeSamples = sampleRate
            for (i in 0 until totalSamples) {
                var s = phrase[i % phraseSamples]
                if (i < fadeSamples) s *= i.toFloat() / fadeSamples
                else if (i > totalSamples - fadeSamples) s *= (totalSamples - i).toFloat() / fadeSamples
                val sample16 = (tanh(s.toDouble() * 1.1) * 30500.0).toInt().coerceIn(-32767, 32767)
                chunk[chunkPos++] = (sample16 and 0xff).toByte()
                chunk[chunkPos++] = ((sample16 ushr 8) and 0xff).toByte()
                if (chunkPos == chunk.size) {
                    out.write(chunk, 0, chunkPos)
                    chunkPos = 0
                }
            }
            if (chunkPos > 0) out.write(chunk, 0, chunkPos)
        }
    }
}
