import { SynthSpec } from '../types/music';

function midiToFreq(midi: number): number {
  return 440 * Math.pow(2, (midi - 69) / 12);
}

const CHORD_MODES: Record<SynthSpec['mode'], number[][]> = {
  minor9: [
    [0, 3, 7, 10, 14],
    [5, 8, 12, 15, 19],
    [3, 7, 10, 14, 17],
    [7, 10, 14, 17, 21],
  ],
  maj7: [
    [0, 4, 7, 11, 14],
    [5, 9, 12, 16, 19],
    [2, 5, 9, 12, 16],
    [7, 11, 14, 17, 21],
  ],
  dorian: [
    [0, 3, 7, 10, 14],
    [2, 5, 9, 12, 16],
    [7, 10, 14, 17, 19],
    [5, 9, 12, 15, 19],
  ],
  ambient: [
    [0, 7, 12, 14, 19],
    [-4, 3, 7, 11, 14],
    [5, 12, 17, 19, 24],
    [2, 9, 14, 16, 21],
  ],
};

function writeString(view: DataView, offset: number, str: string): void {
  for (let i = 0; i < str.length; i++) {
    view.setUint8(offset + i, str.charCodeAt(i));
  }
}

/**
 * Synthesizes a genuine musical PCM WAV Blob (with warm Rhodes-like FM chords,
 * sub-bass pulse, melodic arpeggio, percussive transients, and optional vinyl texture)
 * so built-in tracks play real audible audio and drive genuine FFT spectrum analysis.
 */
export function synthesizeTrackWavBlob(
  spec: SynthSpec,
  targetDurationSec: number,
  includeVinylCrackle: boolean
): Blob {
  const sampleRate = 24000;
  const totalSamples = Math.max(sampleRate * 10, Math.floor(targetDurationSec * sampleRate));

  // Synthesize an 8-bar musical phrase seamlessly, then arrange across full track duration
  const beatSec = 60 / spec.bpm;
  const barSec = beatSec * 4;
  const phraseBars = 8;
  const phraseSamples = Math.floor(barSec * phraseBars * sampleRate);
  const phrase = new Float32Array(phraseSamples);

  const chords = CHORD_MODES[spec.mode];
  const barSamples = Math.floor(barSec * sampleRate);
  const stepSamples = Math.floor((beatSec / 2) * sampleRate); // 8th-note steps

  // Simple deterministic PRNG for hi-hat crispness & micro-vinyl crackle
  let seed = (spec.rootMidi * 9301 + Math.round(spec.bpm * 49)) >>> 0;
  const nextRand = () => {
    seed = (seed * 1664525 + 1013904223) >>> 0;
    return (seed / 0xffffffff) * 2 - 1;
  };

  for (let bar = 0; bar < phraseBars; bar++) {
    const chord = chords[bar % chords.length];
    const barStart = bar * barSamples;

    // 1. Warm Rhodes Pad / Electric Piano chord per bar
    for (let n = 0; n < chord.length; n++) {
      const freq = midiToFreq(spec.rootMidi + chord[n]);
      const omega = (2 * Math.PI * freq) / sampleRate;
      const harmonic2 = omega * 2;
      const amp = 0.085 / (1 + n * 0.22);

      for (let i = 0; i < barSamples; i++) {
        const idx = barStart + i;
        if (idx >= phraseSamples) break;
        const t = i / barSamples;
        // Soft attack + gentle analog decay envelope
        const env = Math.min(1, i / (sampleRate * 0.045)) * Math.exp(-t * 1.45) * (1 - Math.pow(t, 8));
        const mod = Math.sin(i * harmonic2) * (0.25 * (1 - t));
        phrase[idx] += (Math.sin(i * omega + mod) + 0.22 * Math.sin(i * harmonic2)) * amp * env;
      }
    }

    // 2. Deep Sub-Bass Root & Fifth Groove
    for (let beat = 0; beat < 4; beat++) {
      const noteOffset = beat === 2 ? chord[2] : chord[0];
      const bassFreq = midiToFreq(spec.rootMidi - 12 + noteOffset);
      const omega = (2 * Math.PI * bassFreq) / sampleRate;
      const start = barStart + Math.floor(beat * beatSec * sampleRate);
      const len = Math.floor(beatSec * 0.85 * sampleRate);

      for (let i = 0; i < len; i++) {
        const idx = start + i;
        if (idx >= phraseSamples) break;
        const t = i / len;
        const env = Math.min(1, i / (sampleRate * 0.015)) * Math.exp(-t * 2.2);
        phrase[idx] += (Math.sin(i * omega) * 0.24 + Math.sin(i * omega * 2) * 0.05) * env;
      }
    }

    // 3. Delicate Pluck Arpeggio (Mid & High-Mid)
    const stepsInBar = 8;
    for (let s = 0; s < stepsInBar; s++) {
      if ((s + bar) % 3 === 1 && spec.mode === 'ambient') continue;
      const note = chord[(s + bar * 2) % chord.length] + 12;
      const freq = midiToFreq(spec.rootMidi + note);
      const omega = (2 * Math.PI * freq) / sampleRate;
      const start = barStart + s * stepSamples;
      const len = Math.floor(stepSamples * 1.35);

      for (let i = 0; i < len; i++) {
        const idx = start + i;
        if (idx >= phraseSamples) break;
        const t = i / len;
        const env = Math.min(1, i / (sampleRate * 0.008)) * Math.exp(-t * 4.5);
        const bell = Math.sin(i * omega) + 0.3 * Math.sin(i * omega * 2.0) * Math.exp(-t * 6);
        phrase[idx] += bell * 0.075 * env;
      }
    }

    // 4. Tactile Percussion (Kick on 1 & 3, crisp brush hat on 8ths)
    if (spec.grooveIntensity > 0.35) {
      for (let s = 0; s < 8; s++) {
        const start = barStart + s * stepSamples;
        const isKick = s === 0 || s === 4 || (s === 6 && spec.grooveIntensity > 0.72);
        const isSnare = (s === 2 || s === 6) && spec.grooveIntensity > 0.55;

        if (isKick) {
          const kLen = Math.floor(sampleRate * 0.16);
          let phase = 0;
          for (let i = 0; i < kLen; i++) {
            const idx = start + i;
            if (idx >= phraseSamples) break;
            const t = i / kLen;
            const f = 46 + 108 * Math.exp(-t * 14);
            phase += (2 * Math.PI * f) / sampleRate;
            const env = Math.min(1, i / 40) * Math.exp(-t * 5.2);
            phrase[idx] += Math.sin(phase) * 0.28 * spec.grooveIntensity * env;
          }
        }

        if (isSnare) {
          const sLen = Math.floor(sampleRate * 0.09);
          for (let i = 0; i < sLen; i++) {
            const idx = start + i;
            if (idx >= phraseSamples) break;
            const t = i / sLen;
            const env = Math.exp(-t * 9.5);
            const snap = Math.sin((2 * Math.PI * 190 * i) / sampleRate) * 0.06 + nextRand() * 0.09;
            phrase[idx] += snap * spec.grooveIntensity * env;
          }
        }

        // Subtle high-frequency brushed hi-hat
        const hLen = Math.floor(sampleRate * 0.032);
        let prev = 0;
        for (let i = 0; i < hLen; i++) {
          const idx = start + i;
          if (idx >= phraseSamples) break;
          const t = i / hLen;
          const white = nextRand();
          const hp = white - prev;
          prev = white * 0.7;
          const accent = s % 2 === 1 ? 1.0 : 0.55;
          phrase[idx] += hp * 0.045 * accent * spec.grooveIntensity * Math.exp(-t * 11);
        }
      }
    }
  }

  // Assemble full WAV buffer (16-bit PCM mono, lightweight & crisp)
  const wavBuffer = new ArrayBuffer(44 + totalSamples * 2);
  const view = new DataView(wavBuffer);

  writeString(view, 0, 'RIFF');
  view.setUint32(4, 36 + totalSamples * 2, true);
  writeString(view, 8, 'WAVE');
  writeString(view, 12, 'fmt ');
  view.setUint32(16, 16, true); // PCM chunk size
  view.setUint16(20, 1, true); // PCM format
  view.setUint16(22, 1, true); // mono
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, sampleRate * 2, true);
  view.setUint16(32, 2, true);
  view.setUint16(34, 16, true);
  writeString(view, 36, 'data');
  view.setUint32(40, totalSamples * 2, true);

  const fadeSamples = Math.floor(sampleRate * 1.2);
  for (let i = 0; i < totalSamples; i++) {
    let sample = phrase[i % phraseSamples];

    // Macro section dynamics (subtle gentle swell across song structure)
    const sectionPos = (i / totalSamples) * Math.PI * 3;
    const dynamicGain = 0.86 + 0.14 * Math.sin(sectionPos);
    sample *= dynamicGain;

    // Optional warm analog vinyl noise floor + occasional dust micro-tic
    if (includeVinylCrackle) {
      const r = nextRand();
      sample += r * 0.0028 * spec.warmth;
      if (Math.abs(r) > 0.9994) {
        sample += r * 0.032;
      }
    }

    // Intro/Outro smooth fades
    if (i < fadeSamples) {
      sample *= i / fadeSamples;
    } else if (i > totalSamples - fadeSamples) {
      sample *= (totalSamples - i) / fadeSamples;
    }

    // Soft analog tape saturation (tanh-like limiter)
    const clamped = Math.tanh(sample * 1.15);
    view.setInt16(44 + i * 2, Math.max(-32767, Math.min(32767, Math.round(clamped * 31000))), true);
  }

  return new Blob([wavBuffer], { type: 'audio/wav' });
}
