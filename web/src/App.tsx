import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { AnimatePresence } from 'framer-motion';
import { audioEngine } from './audio/audioEngine';
import { extractAudioMetadata } from './audio/metadataParser';
import { BottomNav } from './components/BottomNav';
import { FlyingDiscPayload, FlyingDiscTransition } from './components/FlyingDiscTransition';
import { MiniPlayer } from './components/MiniPlayer';
import { DEFAULT_TRACKS } from './data/catalog';
import {
  deleteAudioBlob,
  loadImportedTracks,
  loadPlaybackState,
  loadPlaylists,
  loadSettings,
  saveAudioBlob,
  saveImportedTracks,
  savePlaybackState,
  savePlaylists,
  saveSettings,
} from './data/storage';
import { TRANSLATIONS } from './i18n/translations';
import {
  AlbumsScreen,
  ArtistsScreen,
  FavoritesScreen,
  PlaylistsScreen,
  SearchScreen,
} from './screens/CollectionsScreens';
import { EqualizerScreen, QueueScreen, SettingsScreen } from './screens/ConsoleScreens';
import { ExploreScreen } from './screens/ExploreScreen';
import { HomeScreen } from './screens/HomeScreen';
import { LibraryScreen } from './screens/LibraryScreen';
import { NowPlayingScreen } from './screens/NowPlayingScreen';
import { AppSettings, PersistedPlaybackState, Playlist, ScreenId, Track } from './types/music';

export const App: React.FC = () => {
  const [settings, setSettings] = useState<AppSettings>(() => loadSettings());
  const [importedTracks, setImportedTracks] = useState<Track[]>(() => loadImportedTracks());
  const [playlists, setPlaylists] = useState<Playlist[]>(() => loadPlaylists());
  const [playback, setPlayback] = useState<PersistedPlaybackState>(() => loadPlaybackState());

  const [screen, setScreen] = useState<ScreenId>('explore');
  const [previousScreen, setPreviousScreen] = useState<ScreenId>('explore');
  const [lastBrowseScreen, setLastBrowseScreen] = useState<ScreenId>('explore');
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTimeSec, setCurrentTimeSec] = useState<number>(() => playback.positionSec);
  const [importing, setImporting] = useState(false);
  const [toastMsg, setToastMsg] = useState<string | null>(null);
  const [exploreMenuOpen, setExploreMenuOpen] = useState(false);
  const [sleepRemainingSec, setSleepRemainingSec] = useState<number | null>(() =>
    settings.sleepTimerMinutes ? settings.sleepTimerMinutes * 60 : null
  );
  const [flyingDisc, setFlyingDisc] = useState<FlyingDiscPayload | null>(null);

  const fileInputRef = useRef<HTMLInputElement>(null);
  const shellRef = useRef<HTMLDivElement>(null);
  const isScrubbingRef = useRef(false);

  const allTracks = useMemo(() => [...importedTracks, ...DEFAULT_TRACKS], [importedTracks]);
  const trackMap = useMemo(() => new Map(allTracks.map((trk) => [trk.id, trk])), [allTracks]);

  const currentTrack = useMemo(() => {
    if (playback.currentTrackId && trackMap.has(playback.currentTrackId)) {
      return trackMap.get(playback.currentTrackId)!;
    }
    return DEFAULT_TRACKS.find((trk) => trk.id === 'trk-daylight') ?? allTracks[0];
  }, [playback.currentTrackId, trackMap, allTracks]);

  const t = TRANSLATIONS[settings.language];
  const isRtl = settings.language === 'fa';

  const showToast = useCallback((msg: string) => {
    setToastMsg(msg);
    setTimeout(() => {
      setToastMsg((cur) => (cur === msg ? null : cur));
    }, 2600);
  }, []);

  // Apply theme & RTL document attributes
  useEffect(() => {
    document.documentElement.setAttribute('data-theme', settings.theme);
    document.documentElement.setAttribute('dir', isRtl ? 'rtl' : 'ltr');
    document.documentElement.setAttribute('lang', settings.language);
    const metaTheme = document.querySelector('meta[name="theme-color"]');
    if (metaTheme) {
      metaTheme.setAttribute('content', settings.theme === 'dark' ? '#0E1015' : '#F3F4F8');
    }
    saveSettings(settings);
  }, [settings, isRtl]);

  // Apply audio engine settings & EQ
  useEffect(() => {
    audioEngine.setVolume(playback.volume);
    audioEngine.setEqualizer(playback.eqEnabled, playback.eqGains);
    audioEngine.setVinylCrackle(settings.vinylWarmthCrackle);
  }, [playback.volume, playback.eqEnabled, playback.eqGains, settings.vinylWarmthCrackle]);

  // Persist playlists, imported tracks & playback state
  useEffect(() => {
    savePlaylists(playlists);
  }, [playlists]);

  useEffect(() => {
    saveImportedTracks(importedTracks);
  }, [importedTracks]);

  useEffect(() => {
    savePlaybackState({ ...playback, positionSec: currentTimeSec });
  }, [playback, currentTimeSec]);

  // Sync audio element timeupdate & ended events
  const nextTrackRef = useRef<() => void>(() => {});

  useEffect(() => {
    const el = audioEngine.element;

    const onTime = () => {
      if (!isScrubbingRef.current) {
        setCurrentTimeSec(el.currentTime);
      }
    };

    const onEnded = () => {
      if (playback.repeat === 'one') {
        audioEngine.seek(0);
        void audioEngine.play();
      } else {
        nextTrackRef.current();
      }
    };

    const onPlay = () => setIsPlaying(true);
    const onPause = () => setIsPlaying(false);

    el.addEventListener('timeupdate', onTime);
    el.addEventListener('ended', onEnded);
    el.addEventListener('play', onPlay);
    el.addEventListener('pause', onPause);

    return () => {
      el.removeEventListener('timeupdate', onTime);
      el.removeEventListener('ended', onEnded);
      el.removeEventListener('play', onPlay);
      el.removeEventListener('pause', onPause);
    };
  }, [playback.repeat]);

  // Sleep timer countdown
  useEffect(() => {
    if (sleepRemainingSec === null || sleepRemainingSec <= 0) return;
    const id = setInterval(() => {
      setSleepRemainingSec((prev) => {
        if (prev === null) return null;
        if (prev <= 1) {
          audioEngine.pause();
          setIsPlaying(false);
          setSettings((s) => ({ ...s, sleepTimerMinutes: null }));
          return null;
        }
        return prev - 1;
      });
    }, 1000);
    return () => clearInterval(id);
  }, [sleepRemainingSec]);

  const navigateTo = useCallback(
    (nextScreen: ScreenId) => {
      if (nextScreen !== screen) {
        if (screen === 'explore' || screen === 'home' || screen === 'library' || screen === 'search') {
          setLastBrowseScreen(screen);
        }
        setPreviousScreen(screen);
        setScreen(nextScreen);
      }
    },
    [screen]
  );

  const playTrack = useCallback(
    async (track: Track, openDeck = false, startSec = 0) => {
      setPlayback((prev) => ({
        ...prev,
        currentTrackId: track.id,
        queueIds: prev.queueIds.includes(track.id) ? prev.queueIds : [track.id, ...prev.queueIds],
      }));
      setCurrentTimeSec(startSec);
      if (openDeck) {
        if (screen === 'explore' || screen === 'home' || screen === 'library' || screen === 'search') {
          setLastBrowseScreen(screen);
        }
        if (screen !== 'now_playing') setPreviousScreen(screen);
        setScreen('now_playing');
      }
      await audioEngine.loadTrack(track, startSec);
      const ok = await audioEngine.play();
      setIsPlaying(ok);
    },
    [screen]
  );

  const selectTrackWithoutPlaying = useCallback(async (track: Track) => {
    setPlayback((prev) => ({ ...prev, currentTrackId: track.id }));
    await audioEngine.loadTrack(track, 0);
  }, []);

  const togglePlay = useCallback(async () => {
    if (isPlaying) {
      audioEngine.pause();
      setIsPlaying(false);
    } else {
      await audioEngine.loadTrack(currentTrack, currentTimeSec);
      const ok = await audioEngine.play();
      setIsPlaying(ok);
    }
  }, [isPlaying, currentTrack, currentTimeSec]);

  const handleNext = useCallback(() => {
    const queue = playback.queueIds.length > 0 ? playback.queueIds : allTracks.map((trk) => trk.id);
    if (queue.length === 0) return;

    if (playback.shuffle && queue.length > 1) {
      const candidates = queue.filter((id) => id !== currentTrack.id);
      const pick = candidates[Math.floor(Math.random() * candidates.length)];
      const trk = trackMap.get(pick) ?? allTracks[0];
      void playTrack(trk, false, 0);
      return;
    }

    const idx = queue.indexOf(currentTrack.id);
    if (idx === -1 || idx === queue.length - 1) {
      if (playback.repeat === 'all') {
        const trk = trackMap.get(queue[0]) ?? allTracks[0];
        void playTrack(trk, false, 0);
      } else {
        audioEngine.pause();
        audioEngine.seek(0);
        setCurrentTimeSec(0);
        setIsPlaying(false);
      }
      return;
    }

    const nextTrk = trackMap.get(queue[idx + 1]) ?? allTracks[0];
    void playTrack(nextTrk, false, 0);
  }, [playback.queueIds, playback.shuffle, playback.repeat, currentTrack.id, allTracks, trackMap, playTrack]);

  nextTrackRef.current = handleNext;

  const handlePrev = useCallback(() => {
    if (currentTimeSec > 3) {
      audioEngine.seek(0);
      setCurrentTimeSec(0);
      return;
    }
    const queue = playback.queueIds.length > 0 ? playback.queueIds : allTracks.map((trk) => trk.id);
    const idx = queue.indexOf(currentTrack.id);
    const prevIdx = idx <= 0 ? queue.length - 1 : idx - 1;
    const prevTrk = trackMap.get(queue[prevIdx]) ?? allTracks[0];
    void playTrack(prevTrk, false, 0);
  }, [currentTimeSec, playback.queueIds, currentTrack.id, allTracks, trackMap, playTrack]);

  const handleSeek = useCallback((sec: number) => {
    setCurrentTimeSec(sec);
    audioEngine.seek(sec);
  }, []);

  const handleScrubStateChange = useCallback((scrubbing: boolean) => {
    isScrubbingRef.current = scrubbing;
  }, []);

  const triggerFlyingOpen = useCallback(
    (track: Track, fromRect: DOMRect | null, shouldPlay: boolean) => {
      if (fromRect && shellRef.current && !settings.reduceMotion) {
        const shellRect = shellRef.current.getBoundingClientRect();
        const deckSize = Math.min(348, shellRect.width - 44);
        const vinylD = deckSize * 0.94 * 0.72;
        const targetLeft = shellRect.left + (shellRect.width - deckSize) / 2 + deckSize * 0.44 - vinylD / 2;
        const targetTop = shellRect.top + 62 + deckSize * 0.48 - vinylD / 2;

        setFlyingDisc({
          id: Date.now(),
          coverUrl: track.coverUrl,
          fromRect: {
            left: fromRect.left,
            top: fromRect.top,
            width: fromRect.width,
            height: fromRect.height,
          },
          toRect: {
            left: targetLeft,
            top: targetTop,
            width: vinylD,
            height: vinylD,
          },
        });
      }

      if (shouldPlay) {
        void playTrack(track, true, track.id === currentTrack.id ? currentTimeSec : 0);
      } else {
        if (screen === 'explore' || screen === 'home' || screen === 'library' || screen === 'search') {
          setLastBrowseScreen(screen);
        }
        if (screen !== 'now_playing') setPreviousScreen(screen);
        setScreen('now_playing');
      }
    },
    [settings.reduceMotion, playTrack, currentTrack.id, currentTimeSec, screen]
  );

  const handleBackFromNowPlaying = useCallback(
    (platterRect: DOMRect | null) => {
      if (platterRect && shellRef.current && !settings.reduceMotion) {
        const shellRect = shellRef.current.getBoundingClientRect();
        const vinylD = platterRect.width * 0.74;
        const fromLeft = platterRect.left + platterRect.width * 0.44 - vinylD / 2;
        const fromTop = platterRect.top + platterRect.height * 0.48 - vinylD / 2;

        setFlyingDisc({
          id: Date.now(),
          coverUrl: currentTrack.coverUrl,
          fromRect: { left: fromLeft, top: fromTop, width: vinylD, height: vinylD },
          toRect: {
            left: shellRect.left + 26,
            top: shellRect.bottom - 110,
            width: 40,
            height: 40,
          },
          reverse: true,
        });
      }
      setScreen(lastBrowseScreen === 'now_playing' ? 'explore' : lastBrowseScreen);
    },
    [settings.reduceMotion, currentTrack.coverUrl, lastBrowseScreen]
  );

  // Real local audio file import + binary ID3/FLAC extraction
  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files || files.length === 0) return;

    setImporting(true);
    try {
      const newlyAdded: Track[] = [];
      for (let i = 0; i < files.length; i++) {
        const file = files[i];
        const meta = await extractAudioMetadata(file, i);
        const id = `imp-${Date.now()}-${i}`;
        const blobKey = `blob-${id}`;
        await saveAudioBlob(blobKey, file);

        newlyAdded.push({
          id,
          title: meta.title,
          artist: meta.artist,
          album: meta.album,
          durationSec: meta.durationSec,
          coverUrl: meta.coverUrl ?? DEFAULT_TRACKS[0].coverUrl,
          accentHex: '#4C566A',
          format: meta.format,
          sampleRateHz: meta.sampleRateHz,
          year: meta.year,
          isDemo: false,
          blobKey,
        });
      }

      if (newlyAdded.length > 0) {
        setImportedTracks((prev) => [...newlyAdded, ...prev]);
        setPlayback((prev) => ({
          ...prev,
          queueIds: [...newlyAdded.map((x) => x.id), ...prev.queueIds],
        }));
        showToast(`${newlyAdded.length} ${t.common.importedToast}`);
        void playTrack(newlyAdded[0], true, 0);
      }
    } catch {
      showToast(t.common.errorAudioFormat);
    } finally {
      setImporting(false);
      e.target.value = '';
    }
  };

  const toggleFavorite = (trackId: string) => {
    setPlayback((prev) => {
      const exists = prev.favoriteIds.includes(trackId);
      return {
        ...prev,
        favoriteIds: exists
          ? prev.favoriteIds.filter((id) => id !== trackId)
          : [trackId, ...prev.favoriteIds],
      };
    });
  };

  const addToQueue = (trackId: string) => {
    setPlayback((prev) => ({
      ...prev,
      queueIds: [...prev.queueIds.filter((id) => id !== trackId), trackId],
    }));
    showToast(t.library.addToQueue);
  };

  const addToPlaylist = (playlistId: string, trackId: string) => {
    setPlaylists((prev) =>
      prev.map((pl) => {
        if (pl.id !== playlistId) return pl;
        const exists = pl.trackIds.includes(trackId);
        return {
          ...pl,
          trackIds: exists ? pl.trackIds : [...pl.trackIds, trackId],
        };
      })
    );
  };

  const showBottomChrome = screen !== 'now_playing';

  return (
    <div className="app-stage">
      <div
        ref={shellRef}
        className="device-shell"
        dir={isRtl ? 'rtl' : 'ltr'}
      >
        <input
          ref={fileInputRef}
          type="file"
          multiple
          accept="audio/*,.mp3,.wav,.flac,.aac,.m4a,.ogg,.opus"
          onChange={handleFileChange}
          style={{ display: 'none' }}
        />

        {/* Shared Element Flying Disc Bridge */}
        <FlyingDiscTransition payload={flyingDisc} onComplete={() => setFlyingDisc(null)} />

        {/* Toast Notification */}
        {toastMsg && (
          <div
            className="tactile-pill"
            style={{
              position: 'absolute',
              top: 'calc(14px + var(--safe-top))',
              left: '50%',
              transform: 'translateX(-50%)',
              padding: '8px 16px',
              borderRadius: 999,
              fontSize: 12,
              fontWeight: 700,
              color: 'var(--text-primary)',
              zIndex: 120,
              whiteSpace: 'nowrap',
            }}
          >
            {toastMsg}
          </div>
        )}

        {/* Explore Quick Menu Drawer */}
        {exploreMenuOpen && (
          <div
            onClick={() => setExploreMenuOpen(false)}
            style={{
              position: 'absolute',
              inset: 0,
              background: 'rgba(10, 12, 18, 0.22)',
              zIndex: 80,
              display: 'flex',
              justifyContent: 'flex-end',
              alignItems: 'flex-start',
              padding: 'calc(58px + var(--safe-top)) 18px 0',
            }}
          >
            <div
              onClick={(e) => e.stopPropagation()}
              className="tactile-pill"
              style={{
                width: 224,
                borderRadius: 20,
                padding: 10,
                display: 'flex',
                flexDirection: 'column',
                gap: 4,
              }}
            >
              {[
                { label: t.home.equalizer, action: () => navigateTo('equalizer') },
                { label: t.home.queue, action: () => navigateTo('queue') },
                { label: t.home.playlists, action: () => navigateTo('playlists') },
                { label: t.home.settings, action: () => navigateTo('settings') },
                {
                  label: settings.theme === 'dark' ? t.settings.lightMode : t.settings.darkMode,
                  action: () =>
                    setSettings((s) => ({ ...s, theme: s.theme === 'dark' ? 'light' : 'dark' })),
                },
                {
                  label: settings.language === 'en' ? t.settings.persian : t.settings.english,
                  action: () =>
                    setSettings((s) => ({ ...s, language: s.language === 'en' ? 'fa' : 'en' })),
                },
              ].map((item) => (
                <button
                  key={item.label}
                  type="button"
                  onClick={() => {
                    item.action();
                    setExploreMenuOpen(false);
                  }}
                  style={{
                    textAlign: 'start',
                    padding: '9px 12px',
                    borderRadius: 12,
                    border: 'none',
                    background: 'transparent',
                    color: 'var(--text-primary)',
                    fontSize: 13,
                    fontWeight: 600,
                    cursor: 'pointer',
                  }}
                >
                  {item.label}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Active Screen Viewport */}
        <main style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column', position: 'relative' }}>
          <AnimatePresence mode="wait">
            {screen === 'explore' && (
              <ExploreScreen
                key="explore"
                tracks={allTracks}
                activeTrackId={currentTrack.id}
                isPlaying={isPlaying}
                isRtl={isRtl}
                theme={settings.theme}
                reduceMotion={settings.reduceMotion}
                hapticsEnabled={settings.hapticsEnabled}
                t={t}
                onSelectCenterTrack={(trk) => {
                  if (!isPlaying) void selectTrackWithoutPlaying(trk);
                }}
                onPlayAndOpen={(trk, rect) => triggerFlyingOpen(trk, rect, true)}
                onOpenQuickMenu={() => setExploreMenuOpen((o) => !o)}
                onTriggerImport={() => fileInputRef.current?.click()}
              />
            )}

            {screen === 'now_playing' && (
              <NowPlayingScreen
                key="now_playing"
                track={currentTrack}
                isPlaying={isPlaying}
                currentTimeSec={currentTimeSec}
                durationSec={
                  Number.isFinite(audioEngine.element.duration) && audioEngine.element.duration > 0
                    ? audioEngine.element.duration
                    : currentTrack.durationSec
                }
                shuffle={playback.shuffle}
                repeat={playback.repeat}
                isFavorite={playback.favoriteIds.includes(currentTrack.id)}
                volume={playback.volume}
                theme={settings.theme}
                isRtl={isRtl}
                reduceMotion={settings.reduceMotion}
                playlists={playlists}
                sleepRemainingSec={sleepRemainingSec}
                t={t}
                onBack={handleBackFromNowPlaying}
                onTogglePlay={() => void togglePlay()}
                onPrev={handlePrev}
                onNext={handleNext}
                onSeek={handleSeek}
                onScrubStateChange={handleScrubStateChange}
                onToggleShuffle={() => setPlayback((p) => ({ ...p, shuffle: !p.shuffle }))}
                onCycleRepeat={() =>
                  setPlayback((p) => ({
                    ...p,
                    repeat: p.repeat === 'off' ? 'all' : p.repeat === 'all' ? 'one' : 'off',
                  }))
                }
                onToggleFavorite={() => toggleFavorite(currentTrack.id)}
                onVolumeChange={(v) => setPlayback((p) => ({ ...p, volume: v }))}
                onOpenQueue={() => navigateTo('queue')}
                onOpenEq={() => navigateTo('equalizer')}
                onAddToPlaylist={addToPlaylist}
                onOpenSettings={() => navigateTo('settings')}
              />
            )}

            {screen === 'home' && (
              <HomeScreen
                key="home"
                tracks={allTracks}
                currentTrack={currentTrack}
                isPlaying={isPlaying}
                favoriteCount={playback.favoriteIds.length}
                playlistCount={playlists.length}
                theme={settings.theme}
                reduceMotion={settings.reduceMotion}
                t={t}
                onNavigate={navigateTo}
                onOpenNowPlaying={() => navigateTo('now_playing')}
                onPlayTrack={(trk) => void playTrack(trk, true, 0)}
                onToggleTheme={() =>
                  setSettings((s) => ({ ...s, theme: s.theme === 'dark' ? 'light' : 'dark' }))
                }
                onTriggerImport={() => fileInputRef.current?.click()}
              />
            )}

            {screen === 'library' && (
              <LibraryScreen
                key="library"
                tracks={allTracks}
                currentTrackId={currentTrack.id}
                favoriteIds={playback.favoriteIds}
                playlists={playlists}
                importing={importing}
                t={t}
                onNavigate={navigateTo}
                onPlayTrack={(trk) => void playTrack(trk, true, 0)}
                onToggleFavorite={toggleFavorite}
                onAddToQueue={addToQueue}
                onAddToPlaylist={addToPlaylist}
                onRemoveImportedTrack={(id) => {
                  const found = importedTracks.find((x) => x.id === id);
                  if (found?.blobKey) void deleteAudioBlob(found.blobKey);
                  setImportedTracks((prev) => prev.filter((x) => x.id !== id));
                  setPlayback((prev) => ({
                    ...prev,
                    queueIds: prev.queueIds.filter((q) => q !== id),
                    favoriteIds: prev.favoriteIds.filter((f) => f !== id),
                  }));
                }}
                onTriggerImport={() => fileInputRef.current?.click()}
              />
            )}

            {screen === 'albums' && (
              <AlbumsScreen
                key="albums"
                tracks={allTracks}
                isRtl={isRtl}
                t={t}
                onBack={() => navigateTo('library')}
                onPlayList={(list) => {
                  setPlayback((p) => ({ ...p, queueIds: list.map((x) => x.id) }));
                  if (list[0]) void playTrack(list[0], true, 0);
                }}
              />
            )}

            {screen === 'artists' && (
              <ArtistsScreen
                key="artists"
                tracks={allTracks}
                isRtl={isRtl}
                t={t}
                onBack={() => navigateTo('library')}
                onPlayList={(list) => {
                  setPlayback((p) => ({ ...p, queueIds: list.map((x) => x.id) }));
                  if (list[0]) void playTrack(list[0], true, 0);
                }}
              />
            )}

            {screen === 'playlists' && (
              <PlaylistsScreen
                key="playlists"
                playlists={playlists}
                tracks={allTracks}
                isRtl={isRtl}
                t={t}
                onBack={() => navigateTo('library')}
                onCreatePlaylist={(name) =>
                  setPlaylists((prev) => [
                    { id: `pl-${Date.now()}`, name, trackIds: [], createdAt: Date.now() },
                    ...prev,
                  ])
                }
                onDeletePlaylist={(id) => setPlaylists((prev) => prev.filter((p) => p.id !== id))}
                onRemoveTrackFromPlaylist={(plId, trkId) =>
                  setPlaylists((prev) =>
                    prev.map((p) =>
                      p.id === plId ? { ...p, trackIds: p.trackIds.filter((x) => x !== trkId) } : p
                    )
                  )
                }
                onPlayPlaylist={(list) => {
                  setPlayback((p) => ({ ...p, queueIds: list.map((x) => x.id) }));
                  if (list[0]) void playTrack(list[0], true, 0);
                }}
              />
            )}

            {screen === 'favorites' && (
              <FavoritesScreen
                key="favorites"
                tracks={allTracks}
                favoriteIds={playback.favoriteIds}
                isRtl={isRtl}
                t={t}
                onBack={() => navigateTo('library')}
                onPlayTrack={(trk) => void playTrack(trk, true, 0)}
                onToggleFavorite={toggleFavorite}
              />
            )}

            {screen === 'search' && (
              <SearchScreen
                key="search"
                tracks={allTracks}
                t={t}
                onPlayTrack={(trk) => void playTrack(trk, true, 0)}
              />
            )}

            {screen === 'queue' && (
              <QueueScreen
                key="queue"
                tracks={allTracks}
                queueIds={playback.queueIds}
                currentTrackId={currentTrack.id}
                isRtl={isRtl}
                t={t}
                onBack={() => navigateTo('now_playing')}
                onPlayTrack={(trk) => void playTrack(trk, true, 0)}
                onMoveItem={(idx, delta) =>
                  setPlayback((prev) => {
                    const next = [...prev.queueIds];
                    const target = idx + delta;
                    if (target < 0 || target >= next.length) return prev;
                    const [item] = next.splice(idx, 1);
                    next.splice(target, 0, item);
                    return { ...prev, queueIds: next };
                  })
                }
                onRemoveItem={(idx) =>
                  setPlayback((prev) => ({
                    ...prev,
                    queueIds: prev.queueIds.filter((_, i) => i !== idx),
                  }))
                }
                onClearUpcoming={() =>
                  setPlayback((prev) => ({ ...prev, queueIds: [currentTrack.id] }))
                }
              />
            )}

            {screen === 'equalizer' && (
              <EqualizerScreen
                key="equalizer"
                enabled={playback.eqEnabled}
                gains={playback.eqGains}
                presetId={playback.eqPresetId}
                isRtl={isRtl}
                isFa={settings.language === 'fa'}
                t={t}
                onBack={() => navigateTo('now_playing')}
                onToggleEnabled={() => setPlayback((p) => ({ ...p, eqEnabled: !p.eqEnabled }))}
                onSelectPreset={(presetId, gains) =>
                  setPlayback((p) => ({ ...p, eqPresetId: presetId, eqGains: [...gains], eqEnabled: true }))
                }
                onBandChange={(bandIdx, db) =>
                  setPlayback((p) => {
                    const nextGains = [...p.eqGains];
                    nextGains[bandIdx] = db;
                    return { ...p, eqPresetId: 'custom', eqGains: nextGains };
                  })
                }
              />
            )}

            {screen === 'settings' && (
              <SettingsScreen
                key="settings"
                settings={settings}
                sleepRemainingSec={sleepRemainingSec}
                t={t}
                onBack={() => navigateTo(previousScreen)}
                onUpdateSettings={(patch) => setSettings((s) => ({ ...s, ...patch }))}
                onSetSleepTimer={(mins) => {
                  setSettings((s) => ({ ...s, sleepTimerMinutes: mins }));
                  setSleepRemainingSec(mins ? mins * 60 : null);
                }}
              />
            )}
          </AnimatePresence>
        </main>

        {/* Floating Mini Player (visible outside Now Playing when active/playing or resumed) */}
        {showBottomChrome && (isPlaying || currentTimeSec > 0 || screen !== 'explore') && (
          <AnimatePresence>
            <MiniPlayer
              track={currentTrack}
              isPlaying={isPlaying}
              currentTimeSec={currentTimeSec}
              durationSec={currentTrack.durationSec}
              theme={settings.theme}
              reduceMotion={settings.reduceMotion}
              onTogglePlay={() => void togglePlay()}
              onExpand={(rect) => triggerFlyingOpen(currentTrack, rect, false)}
            />
          </AnimatePresence>
        )}

        {/* Minimal Bottom Navigation */}
        {showBottomChrome && (
          <BottomNav
            activeScreen={screen}
            theme={settings.theme}
            labels={t.nav}
            onNavigate={navigateTo}
          />
        )}
      </div>
    </div>
  );
};

export default App;
