import { AppSettings, PersistedPlaybackState, Playlist, Track } from '../types/music';
import { DEFAULT_PLAYLISTS, DEFAULT_TRACKS } from './catalog';

const DB_NAME = 'atelier_lp01_db';
const DB_VERSION = 1;
const STORE_FILES = 'audio_files';
const LS_SETTINGS = 'atelier_settings_v1';
const LS_PLAYBACK = 'atelier_playback_v1';
const LS_PLAYLISTS = 'atelier_playlists_v1';
const LS_IMPORTED_TRACKS = 'atelier_imported_tracks_v1';

function openDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains(STORE_FILES)) {
        db.createObjectStore(STORE_FILES);
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

export async function saveAudioBlob(key: string, blob: Blob): Promise<void> {
  try {
    const db = await openDb();
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(STORE_FILES, 'readwrite');
      tx.objectStore(STORE_FILES).put(blob, key);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  } catch {
    // Graceful no-op in restricted browsing contexts
  }
}

export async function loadAudioBlob(key: string): Promise<Blob | null> {
  try {
    const db = await openDb();
    return await new Promise<Blob | null>((resolve, reject) => {
      const tx = db.transaction(STORE_FILES, 'readonly');
      const req = tx.objectStore(STORE_FILES).get(key);
      req.onsuccess = () => resolve((req.result as Blob) ?? null);
      req.onerror = () => reject(req.error);
    });
  } catch {
    return null;
  }
}

export async function deleteAudioBlob(key: string): Promise<void> {
  try {
    const db = await openDb();
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(STORE_FILES, 'readwrite');
      tx.objectStore(STORE_FILES).delete(key);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  } catch {
    // ignore
  }
}

export function loadSettings(): AppSettings {
  const prefersReduced =
    typeof window !== 'undefined' &&
    window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
  const fallback: AppSettings = {
    theme: 'light',
    language: 'en',
    reduceMotion: Boolean(prefersReduced),
    hapticsEnabled: true,
    vinylWarmthCrackle: true,
    sleepTimerMinutes: null,
  };
  try {
    const raw = localStorage.getItem(LS_SETTINGS);
    if (!raw) return fallback;
    return { ...fallback, ...JSON.parse(raw) };
  } catch {
    return fallback;
  }
}

export function saveSettings(settings: AppSettings): void {
  try {
    localStorage.setItem(LS_SETTINGS, JSON.stringify(settings));
  } catch {
    // ignore
  }
}

export function loadPlaybackState(): PersistedPlaybackState {
  const fallback: PersistedPlaybackState = {
    currentTrackId: 'trk-daylight',
    positionSec: 0,
    queueIds: DEFAULT_TRACKS.map((t) => t.id),
    shuffle: false,
    repeat: 'all',
    volume: 0.85,
    favoriteIds: ['trk-daylight', 'trk-one-week-last', 'trk-horizon'],
    eqPresetId: 'vinyl_warm',
    eqGains: [3.5, 2.0, -0.5, -1.5, -1.0],
    eqEnabled: true,
  };
  try {
    const raw = localStorage.getItem(LS_PLAYBACK);
    if (!raw) return fallback;
    return { ...fallback, ...JSON.parse(raw) };
  } catch {
    return fallback;
  }
}

export function savePlaybackState(state: PersistedPlaybackState): void {
  try {
    localStorage.setItem(LS_PLAYBACK, JSON.stringify(state));
  } catch {
    // ignore
  }
}

export function loadPlaylists(): Playlist[] {
  try {
    const raw = localStorage.getItem(LS_PLAYLISTS);
    if (!raw) return DEFAULT_PLAYLISTS;
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : DEFAULT_PLAYLISTS;
  } catch {
    return DEFAULT_PLAYLISTS;
  }
}

export function savePlaylists(playlists: Playlist[]): void {
  try {
    localStorage.setItem(LS_PLAYLISTS, JSON.stringify(playlists));
  } catch {
    // ignore
  }
}

export function loadImportedTracks(): Track[] {
  try {
    const raw = localStorage.getItem(LS_IMPORTED_TRACKS);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

export function saveImportedTracks(tracks: Track[]): void {
  try {
    localStorage.setItem(LS_IMPORTED_TRACKS, JSON.stringify(tracks));
  } catch {
    // ignore
  }
}
