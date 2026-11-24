package com.atelier.vinyl.audio

import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.MediaStore
import android.provider.OpenableColumns
import com.atelier.vinyl.model.CoverMotif
import com.atelier.vinyl.model.VinylTrack
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

object MediaScannerAndImporter {

    private fun detectFormatFromName(name: String): String {
        return when (name.substringAfterLast('.', "").lowercase()) {
            "flac" -> "FLAC"
            "wav" -> "WAV"
            "aac", "m4a" -> "AAC"
            "ogg", "opus" -> "OGG"
            else -> "MP3"
        }
    }

    suspend fun scanDeviceMediaStore(context: Context): List<VinylTrack> = withContext(Dispatchers.IO) {
        val list = mutableListOf<VinylTrack>()
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DISPLAY_NAME
        )
        val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0 AND ${MediaStore.Audio.Media.DURATION} > 8000"
        val sortOrder = "${MediaStore.Audio.Media.DATE_ADDED} DESC"

        runCatching {
            context.contentResolver.query(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                projection,
                selection,
                null,
                sortOrder
            )?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
                val titleCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
                val artistCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
                val albumCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
                val albumIdCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
                val durCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
                val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)

                val motifs = CoverMotif.entries
                var idx = 0
                while (cursor.moveToNext() && idx < 300) {
                    val mediaId = cursor.getLong(idCol)
                    val title = cursor.getString(titleCol).orEmpty().ifBlank { "Untitled" }
                    val artist = cursor.getString(artistCol).orEmpty().ifBlank { "Unknown Artist" }
                    val album = cursor.getString(albumCol).orEmpty().ifBlank { "Device Library" }
                    val albumId = cursor.getLong(albumIdCol)
                    val durationMs = cursor.getLong(durCol).coerceAtLeast(1000L)
                    val displayName = cursor.getString(nameCol).orEmpty()

                    val contentUri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, mediaId)
                    val artUri = ContentUris.withAppendedId(Uri.parse("content://media/external/audio/albumart"), albumId)

                    list.add(
                        VinylTrack(
                            id = "ms-$mediaId",
                            title = title,
                            artist = artist,
                            album = album,
                            durationMs = durationMs,
                            uri = contentUri,
                            format = detectFormatFromName(displayName),
                            coverMotif = motifs[idx % motifs.size],
                            albumArtUri = artUri,
                            isDemo = false
                        )
                    )
                    idx++
                }
            }
        }
        list
    }

    suspend fun importAudioUris(context: Context, uris: List<Uri>): List<VinylTrack> = withContext(Dispatchers.IO) {
        val motifs = CoverMotif.entries
        val imported = mutableListOf<VinylTrack>()

        uris.forEachIndexed { idx, uri ->
            runCatching {
                context.contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
            }
            val displayName = resolveDisplayName(context, uri)
            val retriever = MediaMetadataRetriever()
            var title = displayName.substringBeforeLast('.').ifBlank { "Imported Pressing" }
            var artist = "Local Pressing"
            var album = "Imported Vinyls"
            var durationMs = 180_000L
            var artBytes: ByteArray? = null

            runCatching {
                retriever.setDataSource(context, uri)
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE)
                    ?.takeIf { it.isNotBlank() }?.let { title = it }
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST)
                    ?.takeIf { it.isNotBlank() }?.let { artist = it }
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM)
                    ?.takeIf { it.isNotBlank() }?.let { album = it }
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                    ?.toLongOrNull()?.takeIf { it > 0 }?.let { durationMs = it }
                artBytes = retriever.embeddedPicture
            }
            runCatching { retriever.release() }

            imported.add(
                VinylTrack(
                    id = "imp-${System.currentTimeMillis()}-$idx",
                    title = title,
                    artist = artist,
                    album = album,
                    durationMs = durationMs,
                    uri = uri,
                    format = detectFormatFromName(displayName),
                    coverMotif = motifs[idx % motifs.size],
                    embeddedArtBytes = artBytes,
                    isDemo = false
                )
            )
        }
        imported
    }

    private fun resolveDisplayName(context: Context, uri: Uri): String {
        runCatching {
            context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                if (c.moveToFirst()) {
                    val idx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (idx >= 0) return c.getString(idx) ?: "track.mp3"
                }
            }
        }
        return uri.lastPathSegment ?: "track.mp3"
    }
}
