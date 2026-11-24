export type RepeatMode = 'off' | 'all' | 'one';

export type AppTheme = 'light' | 'dark';

export type AppLanguage = 'en' | 'fa';

export type ScreenId =
  | 'home'
  | 'explore'
  | 'now_playing'
  | 'library'
  | 'albums'
  | 'artists'
  | 'playlists'
  | 'favorites'
  | 'search'
  | 'queue'
  | 'equalizer'
  | 'settings';

export type TurntablePhase =
  | 'parked'
  | 'cueing_in'
  | 'playing'
  | 'paused_hover'
  | 'returning'
  | 'scratching';

export interface SynthSpec {
  bpm: number;
  rootMidi: number;
  mode: 'minor9' | 'maj7' | 'dorian' | 'ambient';
  warmth: number;
  grooveIntensity: number;
}

export interface Track {
  id: string;
  title: string;
  artist: string;
  album: string;
  durationSec: number;
  coverUrl: string;
  accentHex: string;
  format: 'MP3' | 'WAV' | 'FLAC' | 'AAC' | 'OGG' | 'STUDIO';
  sampleRateHz: number;
  bitrateKbps?: number;
  year?: string;
  isDemo?: boolean;
  synthSpec?: SynthSpec;
  blobKey?: string; // IndexedDB key for imported user audio files
}

export interface Playlist {
  id: string;
  name: string;
  description?: string;
  trackIds: string[];
  createdAt: number;
}

export interface EqualizerBand {
  id: string;
  label: string;
  freqHz: number;
  gainDb: number; // -12 to +12
}

export interface EqualizerPreset {
  id: string;
  nameEn: string;
  nameFa: string;
  gains: number[]; // 5 values matching bands
}

export interface SpectrumSnapshot {
  bars: number[]; // 13 normalized [0..1] bars
  bass: number;
  mid: number;
  treble: number;
  rms: number;
}

export interface AppSettings {
  theme: AppTheme;
  language: AppLanguage;
  reduceMotion: boolean;
  hapticsEnabled: boolean;
  vinylWarmthCrackle: boolean;
  sleepTimerMinutes: number | null;
}

export interface PersistedPlaybackState {
  currentTrackId: string | null;
  positionSec: number;
  queueIds: string[];
  shuffle: boolean;
  repeat: RepeatMode;
  volume: number;
  favoriteIds: string[];
  eqPresetId: string;
  eqGains: number[];
  eqEnabled: boolean;
}
