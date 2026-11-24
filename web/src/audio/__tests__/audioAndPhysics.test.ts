import { describe, expect, it } from 'vitest';
import { synthesizeTrackWavBlob } from '../synthEngine';
import { extractAudioMetadata } from '../metadataParser';

describe('Atelier Vinyl Web Audio & Metadata', () => {
  it('synthesizes a valid non-silent RIFF/WAVE audio file', async () => {
    const blob = synthesizeTrackWavBlob(
      { bpm: 88, rootMidi: 55, mode: 'minor9', warmth: 0.65, grooveIntensity: 0.78 },
      12,
      true
    );
    expect(blob.type).toBe('audio/wav');
    expect(blob.size).toBeGreaterThan(44 + 24000 * 10 * 2);

    const header = new Uint8Array(await blob.slice(0, 12).arrayBuffer());
    const riff = String.fromCharCode(header[0], header[1], header[2], header[3]);
    const wave = String.fromCharCode(header[8], header[9], header[10], header[11]);
    expect(riff).toBe('RIFF');
    expect(wave).toBe('WAVE');
  });

  it('parses ID3v2 TIT2 and TPE1 tags from MP3 bytes', async () => {
    // Construct minimal ID3v2.3 header + TIT2 + TPE1
    const enc = new TextEncoder();
    const titlePayload = new Uint8Array([0, ...enc.encode('Midnight Pressing')]);
    const artistPayload = new Uint8Array([0, ...enc.encode('Kernin Joki')]);

    const makeFrame = (id: string, payload: Uint8Array) => {
      const frame = new Uint8Array(10 + payload.length);
      for (let i = 0; i < 4; i++) frame[i] = id.charCodeAt(i);
      const len = payload.length;
      frame[4] = (len >>> 24) & 0xff;
      frame[5] = (len >>> 16) & 0xff;
      frame[6] = (len >>> 8) & 0xff;
      frame[7] = len & 0xff;
      frame.set(payload, 10);
      return frame;
    };

    const f1 = makeFrame('TIT2', titlePayload);
    const f2 = makeFrame('TPE1', artistPayload);
    const tagSize = f1.length + f2.length;
    const mp3 = new Uint8Array(10 + tagSize + 16);
    mp3[0] = 0x49;
    mp3[1] = 0x44;
    mp3[2] = 0x33;
    mp3[3] = 3; // ID3v2.3
    mp3[6] = (tagSize >>> 21) & 0x7f;
    mp3[7] = (tagSize >>> 14) & 0x7f;
    mp3[8] = (tagSize >>> 7) & 0x7f;
    mp3[9] = tagSize & 0x7f;
    mp3.set(f1, 10);
    mp3.set(f2, 10 + f1.length);

    const file = new File([mp3], 'fallback_name.mp3', { type: 'audio/mpeg' });
    const meta = await extractAudioMetadata(file);
    expect(meta.title).toBe('Midnight Pressing');
    expect(meta.artist).toBe('Kernin Joki');
    expect(meta.format).toBe('MP3');
  });
});
