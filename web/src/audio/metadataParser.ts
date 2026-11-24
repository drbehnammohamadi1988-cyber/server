import { Track } from '../types/music';
import { generateCoverArt, CoverMotif } from '../data/artworkGenerator';

export interface ParsedAudioMeta {
  title: string;
  artist: string;
  album: string;
  year?: string;
  coverUrl?: string;
  format: Track['format'];
  durationSec: number;
  sampleRateHz: number;
}

function detectFormat(file: File): Track['format'] {
  const ext = file.name.split('.').pop()?.toLowerCase() ?? '';
  if (ext === 'flac') return 'FLAC';
  if (ext === 'wav') return 'WAV';
  if (ext === 'aac' || ext === 'm4a') return 'AAC';
  if (ext === 'ogg' || ext === 'opus') return 'OGG';
  return 'MP3';
}

function decodeTextBytes(bytes: Uint8Array, encoding: number): string {
  try {
    if (encoding === 0) {
      return new TextDecoder('latin1').decode(bytes).replace(/\0+$/, '').trim();
    }
    if (encoding === 1) {
      if (bytes.length >= 2 && bytes[0] === 0xff && bytes[1] === 0xfe) {
        return new TextDecoder('utf-16le').decode(bytes.subarray(2)).replace(/\0+$/, '').trim();
      }
      if (bytes.length >= 2 && bytes[0] === 0xfe && bytes[1] === 0xff) {
        return new TextDecoder('utf-16be').decode(bytes.subarray(2)).replace(/\0+$/, '').trim();
      }
      return new TextDecoder('utf-16le').decode(bytes).replace(/\0+$/, '').trim();
    }
    if (encoding === 2) {
      return new TextDecoder('utf-16be').decode(bytes).replace(/\0+$/, '').trim();
    }
    return new TextDecoder('utf-8').decode(bytes).replace(/\0+$/, '').trim();
  } catch {
    return '';
  }
}

function bytesToDataUrl(bytes: Uint8Array, mime: string): string {
  const blob = new Blob([bytes], { type: mime || 'image/jpeg' });
  return URL.createObjectURL(blob);
}

function parseId3v2(buf: Uint8Array): Partial<ParsedAudioMeta> {
  const res: Partial<ParsedAudioMeta> = {};
  if (buf.length < 10 || buf[0] !== 0x49 || buf[1] !== 0x44 || buf[2] !== 0x33) {
    return res;
  }

  const version = buf[3];
  const tagSize =
    ((buf[6] & 0x7f) << 21) |
    ((buf[7] & 0x7f) << 14) |
    ((buf[8] & 0x7f) << 7) |
    (buf[9] & 0x7f);
  const limit = Math.min(buf.length, 10 + tagSize);
  let pos = 10;

  // Extended header skip
  if ((buf[5] & 0x40) !== 0 && pos + 4 <= limit) {
    const extSize =
      version === 4
        ? ((buf[pos] & 0x7f) << 21) | ((buf[pos + 1] & 0x7f) << 14) | ((buf[pos + 2] & 0x7f) << 7) | (buf[pos + 3] & 0x7f)
        : (buf[pos] << 24) | (buf[pos + 1] << 16) | (buf[pos + 2] << 8) | buf[pos + 3];
    pos += Math.max(4, extSize);
  }

  while (pos + 10 <= limit) {
    const frameId = String.fromCharCode(buf[pos], buf[pos + 1], buf[pos + 2], buf[pos + 3]);
    if (!/^[A-Z0-9]{4}$/.test(frameId)) break;

    const frameSize =
      version === 4
        ? ((buf[pos + 4] & 0x7f) << 21) |
          ((buf[pos + 5] & 0x7f) << 14) |
          ((buf[pos + 6] & 0x7f) << 7) |
          (buf[pos + 7] & 0x7f)
        : (buf[pos + 4] << 24) | (buf[pos + 5] << 16) | (buf[pos + 6] << 8) | buf[pos + 7];

    pos += 10;
    if (frameSize <= 0 || pos + frameSize > limit) break;

    const data = buf.subarray(pos, pos + frameSize);
    if (frameId === 'TIT2' && data.length > 1) {
      res.title = decodeTextBytes(data.subarray(1), data[0]);
    } else if (frameId === 'TPE1' && data.length > 1) {
      res.artist = decodeTextBytes(data.subarray(1), data[0]);
    } else if (frameId === 'TALB' && data.length > 1) {
      res.album = decodeTextBytes(data.subarray(1), data[0]);
    } else if ((frameId === 'TDRC' || frameId === 'TYER') && data.length > 1) {
      res.year = decodeTextBytes(data.subarray(1), data[0]).slice(0, 4);
    } else if (frameId === 'APIC' && data.length > 4 && !res.coverUrl) {
      const enc = data[0];
      let p = 1;
      while (p < data.length && data[p] !== 0) p++;
      const mime = new TextDecoder('latin1').decode(data.subarray(1, p)) || 'image/jpeg';
      p += 2; // null + picture type
      if (enc === 1 || enc === 2) {
        while (p + 1 < data.length && !(data[p] === 0 && data[p + 1] === 0)) p += 2;
        p += 2;
      } else {
        while (p < data.length && data[p] !== 0) p++;
        p += 1;
      }
      if (p < data.length) {
        res.coverUrl = bytesToDataUrl(data.subarray(p), mime);
      }
    }

    pos += frameSize;
  }

  return res;
}

function parseFlacMetadata(buf: Uint8Array): Partial<ParsedAudioMeta> {
  const res: Partial<ParsedAudioMeta> = {};
  if (buf.length < 8 || String.fromCharCode(buf[0], buf[1], buf[2], buf[3]) !== 'fLaC') {
    return res;
  }
  let pos = 4;
  while (pos + 4 <= buf.length) {
    const header = buf[pos];
    const isLast = (header & 0x80) !== 0;
    const blockType = header & 0x7f;
    const len = (buf[pos + 1] << 16) | (buf[pos + 2] << 8) | buf[pos + 3];
    pos += 4;
    if (pos + len > buf.length) break;

    const block = buf.subarray(pos, pos + len);
    if (blockType === 4 && block.length >= 8) {
      // VORBIS_COMMENT (little endian lengths)
      const view = new DataView(block.buffer, block.byteOffset, block.byteLength);
      let cPos = 0;
      const vendorLen = view.getUint32(cPos, true);
      cPos += 4 + vendorLen;
      if (cPos + 4 <= block.length) {
        const count = view.getUint32(cPos, true);
        cPos += 4;
        for (let i = 0; i < count && cPos + 4 <= block.length; i++) {
          const itemLen = view.getUint32(cPos, true);
          cPos += 4;
          if (cPos + itemLen > block.length) break;
          const comment = new TextDecoder('utf-8').decode(block.subarray(cPos, cPos + itemLen));
          cPos += itemLen;
          const eq = comment.indexOf('=');
          if (eq > 0) {
            const k = comment.slice(0, eq).toUpperCase();
            const v = comment.slice(eq + 1).trim();
            if (k === 'TITLE') res.title = v;
            if (k === 'ARTIST') res.artist = v;
            if (k === 'ALBUM') res.album = v;
            if (k === 'DATE') res.year = v.slice(0, 4);
          }
        }
      }
    } else if (blockType === 6 && block.length > 32 && !res.coverUrl) {
      // PICTURE block
      const view = new DataView(block.buffer, block.byteOffset, block.byteLength);
      let p = 4;
      const mimeLen = view.getUint32(p, false);
      p += 4;
      const mime = new TextDecoder('latin1').decode(block.subarray(p, p + mimeLen));
      p += mimeLen;
      const descLen = view.getUint32(p, false);
      p += 4 + descLen + 16;
      if (p + 4 <= block.length) {
        const dataLen = view.getUint32(p, false);
        p += 4;
        if (p + dataLen <= block.length) {
          res.coverUrl = bytesToDataUrl(block.subarray(p, p + dataLen), mime);
        }
      }
    }

    pos += len;
    if (isLast) break;
  }
  return res;
}

function probeAudioDuration(file: File): Promise<number> {
  if (typeof Audio === 'undefined' || typeof URL.createObjectURL !== 'function') {
    return Promise.resolve(180);
  }
  return new Promise((resolve) => {
    const url = URL.createObjectURL(file);
    const audio = new Audio();
    audio.preload = 'metadata';
    const cleanup = () => URL.revokeObjectURL(url);
    audio.onloadedmetadata = () => {
      const dur = Number.isFinite(audio.duration) && audio.duration > 0 ? audio.duration : 180;
      cleanup();
      resolve(Math.round(dur));
    };
    audio.onerror = () => {
      cleanup();
      resolve(180);
    };
    audio.src = url;
  });
}

const FALLBACK_MOTIFS: CoverMotif[] = [
  'archive_daylight',
  'dreams_stripe',
  'crimson_bauhaus',
  'nocturne_silver',
  'solstice_slate',
];

export async function extractAudioMetadata(file: File, indexHint = 0): Promise<ParsedAudioMeta> {
  const headerSlice = file.slice(0, Math.min(file.size, 2 * 1024 * 1024));
  const buf = new Uint8Array(await headerSlice.arrayBuffer());
  const format = detectFormat(file);

  const id3 = parseId3v2(buf);
  const flac = format === 'FLAC' ? parseFlacMetadata(buf) : {};
  const durationSec = await probeAudioDuration(file);

  const rawName = file.name.replace(/\.[^/.]+$/, '').replace(/[_]+/g, ' ').trim();
  const dashSplit = rawName.split(' - ');
  const inferredArtist = dashSplit.length >= 2 ? dashSplit[0].trim() : 'Local Pressing';
  const inferredTitle = dashSplit.length >= 2 ? dashSplit.slice(1).join(' - ').trim() : rawName || 'Untitled Pressing';

  const fallbackCover = generateCoverArt(FALLBACK_MOTIFS[indexHint % FALLBACK_MOTIFS.length]);

  return {
    title: flac.title || id3.title || inferredTitle,
    artist: flac.artist || id3.artist || inferredArtist,
    album: flac.album || id3.album || 'Imported Vinyls',
    year: flac.year || id3.year || '2026',
    coverUrl: flac.coverUrl || id3.coverUrl || fallbackCover,
    format,
    durationSec,
    sampleRateHz: 44100,
  };
}
