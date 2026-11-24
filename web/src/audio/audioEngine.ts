import { EQ_BANDS_META } from '../data/catalog';
import { loadAudioBlob } from '../data/storage';
import { SpectrumSnapshot, Track } from '../types/music';
import { synthesizeTrackWavBlob } from './synthEngine';

/**
 * Studio Web Audio Engine:
 * Routes an HTMLAudioElement through a 5-band BiquadFilter equalizer,
 * master GainNode, and an AnalyserNode for real FFT spectrum feedback.
 */
export class VinylAudioEngine {
  private audio: HTMLAudioElement;
  private ctx: AudioContext | null = null;
  private sourceNode: MediaElementAudioSourceNode | null = null;
  private filters: BiquadFilterNode[] = [];
  private gainNode: GainNode | null = null;
  private analyser: AnalyserNode | null = null;
  private freqBuffer: Uint8Array<ArrayBuffer> = new Uint8Array(new ArrayBuffer(512));

  private urlCache = new Map<string, string>();
  private currentTrackId: string | null = null;
  private eqGains: number[] = [3.5, 2.0, -0.5, -1.5, -1.0];
  private eqEnabled = true;
  private volume = 0.85;
  private vinylCrackle = true;

  // Smoothed spectrum bins for silky decay on pause
  private smoothedBars = new Array<number>(13).fill(0);
  private smoothedBass = 0;
  private smoothedMid = 0;
  private smoothedTreble = 0;

  constructor() {
    this.audio = new Audio();
    this.audio.preload = 'auto';
    this.audio.crossOrigin = 'anonymous';
  }

  public get element(): HTMLAudioElement {
    return this.audio;
  }

  private ensureGraph(): void {
    if (this.ctx) {
      if (this.ctx.state === 'suspended') {
        void this.ctx.resume();
      }
      return;
    }

    const AudioCtx = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
    if (!AudioCtx) return;

    this.ctx = new AudioCtx();
    this.sourceNode = this.ctx.createMediaElementSource(this.audio);

    this.filters = EQ_BANDS_META.map((band, idx) => {
      const f = this.ctx!.createBiquadFilter();
      if (idx === 0) f.type = 'lowshelf';
      else if (idx === EQ_BANDS_META.length - 1) f.type = 'highshelf';
      else f.type = 'peaking';
      f.frequency.value = band.freqHz;
      f.Q.value = 1.15;
      f.gain.value = this.eqEnabled ? (this.eqGains[idx] ?? 0) : 0;
      return f;
    });

    this.gainNode = this.ctx.createGain();
    this.gainNode.gain.value = this.volume;

    this.analyser = this.ctx.createAnalyser();
    this.analyser.fftSize = 1024;
    this.analyser.smoothingTimeConstant = 0.78;
    this.freqBuffer = new Uint8Array(new ArrayBuffer(this.analyser.frequencyBinCount));

    // Wire DSP Chain: Source -> EQ Filters -> Gain -> Analyser -> Destination
    let prev: AudioNode = this.sourceNode;
    for (const f of this.filters) {
      prev.connect(f);
      prev = f;
    }
    prev.connect(this.gainNode);
    this.gainNode.connect(this.analyser);
    this.analyser.connect(this.ctx.destination);
  }

  public setVinylCrackle(enabled: boolean): void {
    if (this.vinylCrackle !== enabled) {
      this.vinylCrackle = enabled;
      // Clear cached synthesized URLs so next synthesis reflects vinyl texture preference
      for (const [key, url] of this.urlCache.entries()) {
        if (key.startsWith('synth:')) {
          URL.revokeObjectURL(url);
          this.urlCache.delete(key);
        }
      }
    }
  }

  public async loadTrack(track: Track, seekSec = 0): Promise<void> {
    if (this.currentTrackId === track.id && this.audio.src) {
      if (Math.abs(this.audio.currentTime - seekSec) > 0.4) {
        this.seek(seekSec);
      }
      return;
    }

    this.currentTrackId = track.id;
    let srcUrl: string | undefined;

    if (track.blobKey) {
      srcUrl = this.urlCache.get(track.blobKey);
      if (!srcUrl) {
        const blob = await loadAudioBlob(track.blobKey);
        if (blob) {
          srcUrl = URL.createObjectURL(blob);
          this.urlCache.set(track.blobKey, srcUrl);
        }
      }
    }

    if (!srcUrl) {
      const cacheKey = `synth:${track.id}`;
      srcUrl = this.urlCache.get(cacheKey);
      if (!srcUrl) {
        const spec = track.synthSpec ?? {
          bpm: 88,
          rootMidi: 57,
          mode: 'minor9',
          warmth: 0.65,
          grooveIntensity: 0.7,
        };
        const wavBlob = synthesizeTrackWavBlob(spec, track.durationSec, this.vinylCrackle);
        srcUrl = URL.createObjectURL(wavBlob);
        this.urlCache.set(cacheKey, srcUrl);
      }
    }

    this.audio.src = srcUrl;
    this.audio.load();

    await new Promise<void>((resolve) => {
      if (this.audio.readyState >= 1) {
        resolve();
        return;
      }
      const onReady = () => {
        this.audio.removeEventListener('loadedmetadata', onReady);
        resolve();
      };
      this.audio.addEventListener('loadedmetadata', onReady, { once: true });
      setTimeout(resolve, 600);
    });

    if (seekSec > 0 && Number.isFinite(this.audio.duration)) {
      this.audio.currentTime = Math.min(seekSec, Math.max(0, this.audio.duration - 0.5));
    }
  }

  public async play(): Promise<boolean> {
    try {
      this.ensureGraph();
      await this.audio.play();
      return true;
    } catch {
      return false;
    }
  }

  public pause(): void {
    this.audio.pause();
  }

  public seek(seconds: number): void {
    if (!Number.isFinite(seconds)) return;
    const dur = Number.isFinite(this.audio.duration) && this.audio.duration > 0 ? this.audio.duration : seconds;
    this.audio.currentTime = Math.max(0, Math.min(seconds, dur));
  }

  public setVolume(v: number): void {
    this.volume = Math.max(0, Math.min(1, v));
    if (this.gainNode) {
      this.gainNode.gain.setTargetAtTime(this.volume, this.ctx?.currentTime ?? 0, 0.02);
    } else {
      this.audio.volume = this.volume;
    }
  }

  public setEqualizer(enabled: boolean, gains: number[]): void {
    this.eqEnabled = enabled;
    this.eqGains = [...gains];
    const now = this.ctx?.currentTime ?? 0;
    this.filters.forEach((filter, i) => {
      const target = enabled ? (gains[i] ?? 0) : 0;
      filter.gain.setTargetAtTime(target, now, 0.03);
    });
  }

  /**
   * Computes real FFT Bass / Mid / Treble energy + 13 symmetrical frequency bars.
   * When paused or silent, values smoothly decay to rest (never fake random noise).
   */
  public sampleSpectrum(): SpectrumSnapshot {
    const isPlaying = !this.audio.paused && !this.audio.ended;

    if (!this.analyser || !isPlaying) {
      for (let i = 0; i < this.smoothedBars.length; i++) {
        this.smoothedBars[i] *= 0.84;
        if (this.smoothedBars[i] < 0.005) this.smoothedBars[i] = 0;
      }
      this.smoothedBass *= 0.84;
      this.smoothedMid *= 0.84;
      this.smoothedTreble *= 0.84;
      return {
        bars: [...this.smoothedBars],
        bass: this.smoothedBass,
        mid: this.smoothedMid,
        treble: this.smoothedTreble,
        rms: (this.smoothedBass + this.smoothedMid + this.smoothedTreble) / 3,
      };
    }

    this.analyser.getByteFrequencyData(this.freqBuffer);
    const sampleRate = this.ctx?.sampleRate ?? 48000;
    const binHz = sampleRate / this.analyser.fftSize;

    const avgBand = (minHz: number, maxHz: number): number => {
      const start = Math.max(1, Math.floor(minHz / binHz));
      const end = Math.min(this.freqBuffer.length - 1, Math.ceil(maxHz / binHz));
      if (end <= start) return 0;
      let sum = 0;
      for (let b = start; b <= end; b++) {
        sum += this.freqBuffer[b];
      }
      return sum / ((end - start + 1) * 255);
    };

    const rawBass = Math.min(1, avgBand(35, 230) * 1.35);
    const rawMid = Math.min(1, avgBand(230, 2200) * 1.55);
    const rawTreble = Math.min(1, avgBand(2200, 9500) * 2.1);

    this.smoothedBass = this.smoothedBass * 0.65 + rawBass * 0.35;
    this.smoothedMid = this.smoothedMid * 0.65 + rawMid * 0.35;
    this.smoothedTreble = this.smoothedTreble * 0.65 + rawTreble * 0.35;

    // Map 13 symmetrical acoustic bands from outer treble -> center bass -> outer treble
    // matching the sculptural symmetrical crest in the reference image
    const ranges: [number, number][] = [
      [3500, 9000],
      [2200, 3500],
      [1400, 2200],
      [850, 1400],
      [420, 850],
      [180, 420],
      [45, 180], // Center bass peak
      [180, 420],
      [420, 850],
      [850, 1400],
      [1400, 2200],
      [2200, 3500],
      [3500, 9000],
    ];

    for (let i = 0; i < ranges.length; i++) {
      const [lo, hi] = ranges[i];
      const boost = i === 6 ? 1.38 : i === 5 || i === 7 ? 1.45 : i >= 3 && i <= 9 ? 1.6 : 2.1;
      const val = Math.min(1, Math.pow(avgBand(lo, hi) * boost, 0.88));
      const lerp = val > this.smoothedBars[i] ? 0.48 : 0.22;
      this.smoothedBars[i] = this.smoothedBars[i] * (1 - lerp) + val * lerp;
    }

    return {
      bars: [...this.smoothedBars],
      bass: this.smoothedBass,
      mid: this.smoothedMid,
      treble: this.smoothedTreble,
      rms: (this.smoothedBass + this.smoothedMid + this.smoothedTreble) / 3,
    };
  }
}

export const audioEngine = new VinylAudioEngine();
