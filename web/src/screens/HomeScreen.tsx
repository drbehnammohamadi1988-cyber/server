import React from 'react';
import { TranslationDict } from '../i18n/translations';
import { AppTheme, ScreenId, Track } from '../types/music';
import {
  DiscIcon,
  EqualizerIcon,
  HeartIcon,
  MoonSunIcon,
  QueueListIcon,
  SettingsGearIcon,
  UploadWaveIcon,
} from '../components/Icons';

interface HomeScreenProps {
  tracks: Track[];
  currentTrack: Track;
  isPlaying: boolean;
  favoriteCount: number;
  playlistCount: number;
  theme: AppTheme;
  reduceMotion: boolean;
  t: TranslationDict;
  onNavigate: (screen: ScreenId) => void;
  onOpenNowPlaying: () => void;
  onPlayTrack: (track: Track) => void;
  onToggleTheme: () => void;
  onTriggerImport: () => void;
}

export const HomeScreen: React.FC<HomeScreenProps> = ({
  tracks,
  currentTrack,
  isPlaying,
  favoriteCount,
  playlistCount,
  theme,
  reduceMotion,
  t,
  onNavigate,
  onOpenNowPlaying,
  onPlayTrack,
  onToggleTheme,
  onTriggerImport,
}) => {
  const isDark = theme === 'dark';

  const moduleItems: { id: ScreenId; label: string; icon: React.ReactNode; badge?: string }[] = [
    { id: 'explore', label: t.nav.explore, icon: <DiscIcon size={17} /> },
    { id: 'albums', label: t.home.albums, icon: <DiscIcon size={17} /> },
    { id: 'artists', label: t.home.artists, icon: <span style={{ fontSize: 13, fontWeight: 700 }}>A–Z</span> },
    { id: 'playlists', label: t.home.playlists, icon: <QueueListIcon size={17} />, badge: String(playlistCount) },
    { id: 'favorites', label: t.home.favorites, icon: <HeartIcon size={17} active={favoriteCount > 0} />, badge: String(favoriteCount) },
    { id: 'equalizer', label: t.home.equalizer, icon: <EqualizerIcon size={17} /> },
    { id: 'queue', label: t.home.queue, icon: <QueueListIcon size={17} /> },
    { id: 'settings', label: t.home.settings, icon: <SettingsGearIcon size={17} /> },
  ];

  return (
    <div className="scroll-clean" style={{ flex: 1, padding: 'calc(18px + var(--safe-top)) 20px 24px' }}>
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 18 }}>
        <div>
          <div
            className="tabular-mono"
            style={{ fontSize: 10.5, fontWeight: 600, letterSpacing: '0.14em', color: 'var(--text-muted)' }}
          >
            {t.appName} · {t.modelCode}
          </div>
          <h1 style={{ margin: '2px 0 0', fontSize: 23, fontWeight: 800, letterSpacing: '-0.02em' }}>
            {t.home.greeting}
          </h1>
          <p style={{ margin: '2px 0 0', fontSize: 12.5, color: 'var(--text-secondary)' }}>
            {t.home.subtitle}
          </p>
        </div>

        <button
          type="button"
          onClick={onToggleTheme}
          aria-label="Toggle Theme"
          className="tactile-btn"
          style={{
            width: 40,
            height: 40,
            borderRadius: '50%',
            display: 'inline-flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: 'var(--text-primary)',
          }}
        >
          <MoonSunIcon isDark={isDark} size={18} />
        </button>
      </div>

      {/* Tactile Turntable Hero Console */}
      <div
        onClick={onOpenNowPlaying}
        className="tactile-pill"
        style={{
          borderRadius: 28,
          padding: 18,
          display: 'flex',
          alignItems: 'center',
          gap: 16,
          marginBottom: 22,
          background: isDark
            ? 'linear-gradient(135deg, #1E232E 0%, #141820 100%)'
            : 'linear-gradient(135deg, #FFFFFF 0%, #ECEFF6 100%)',
        }}
      >
        {/* Mini Platter Preview */}
        <div
          style={{
            position: 'relative',
            width: 78,
            height: 78,
            borderRadius: 20,
            background: isDark ? '#12151C' : '#E3E7F0',
            boxShadow: 'var(--shadow-neu-pressed)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
          }}
        >
          <div
            style={{
              width: 62,
              height: 62,
              borderRadius: '50%',
              background: 'radial-gradient(circle, #1E222B 0%, #090A0D 100%)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              boxShadow: '0 6px 14px rgba(0,0,0,0.35)',
              animation: isPlaying && !reduceMotion ? 'homeSpin 4s linear infinite' : undefined,
            }}
          >
            <img
              src={currentTrack.coverUrl}
              alt={currentTrack.title}
              style={{ width: 26, height: 26, borderRadius: '50%', objectFit: 'cover' }}
            />
          </div>
        </div>

        <div style={{ flex: 1, minWidth: 0 }}>
          <div
            className="tabular-mono"
            style={{ fontSize: 10.5, fontWeight: 600, color: 'var(--text-muted)', letterSpacing: '0.08em' }}
          >
            {isPlaying ? t.nowPlaying.tonearmActive.toUpperCase() : t.home.resumeSession.toUpperCase()}
          </div>
          <div
            style={{
              fontSize: 16.5,
              fontWeight: 700,
              color: 'var(--text-primary)',
              marginTop: 2,
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            {currentTrack.title}
          </div>
          <div style={{ fontSize: 12.5, color: 'var(--text-secondary)', marginTop: 1 }}>
            {currentTrack.artist}
          </div>
        </div>

        <span
          className="tactile-btn"
          style={{
            padding: '8px 14px',
            borderRadius: 999,
            fontSize: 12,
            fontWeight: 700,
            color: 'var(--text-primary)',
            flexShrink: 0,
          }}
        >
          {t.home.openDeck}
        </span>
      </div>

      {/* Studio Modules Pill Grid */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
        <h2 style={{ margin: 0, fontSize: 14, fontWeight: 700, color: 'var(--text-secondary)' }}>
          {t.home.quickAccess}
        </h2>
        <button
          type="button"
          onClick={onTriggerImport}
          className="tactile-pill"
          style={{
            padding: '6px 12px',
            borderRadius: 999,
            fontSize: 11.5,
            fontWeight: 600,
            color: 'var(--text-primary)',
            display: 'inline-flex',
            alignItems: 'center',
            gap: 6,
          }}
        >
          <UploadWaveIcon size={14} />
          <span>{t.home.importFiles}</span>
        </button>
      </div>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(2, 1fr)',
          gap: 10,
          marginBottom: 24,
        }}
      >
        {moduleItems.map((m) => (
          <button
            key={m.id}
            type="button"
            onClick={() => onNavigate(m.id)}
            className="tactile-pill"
            style={{
              padding: '12px 14px',
              borderRadius: 18,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              color: 'var(--text-primary)',
              textAlign: 'start',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <span style={{ color: 'var(--text-secondary)', display: 'inline-flex' }}>{m.icon}</span>
              <span style={{ fontSize: 13.5, fontWeight: 600 }}>{m.label}</span>
            </div>
            {m.badge !== undefined && (
              <span
                className="tabular-mono"
                style={{
                  fontSize: 11,
                  fontWeight: 600,
                  color: 'var(--text-muted)',
                }}
              >
                {m.badge}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Curated Vinyl Pressings Strip */}
      <h2 style={{ margin: '0 0 12px', fontSize: 14, fontWeight: 700, color: 'var(--text-secondary)' }}>
        {t.home.recentPressings}
      </h2>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {tracks.slice(0, 6).map((trk) => {
          const active = trk.id === currentTrack.id;
          return (
            <button
              key={trk.id}
              type="button"
              onClick={() => onPlayTrack(trk)}
              className="tactile-pill"
              style={{
                padding: '9px 14px 9px 10px',
                borderRadius: 999,
                display: 'flex',
                alignItems: 'center',
                gap: 12,
                textAlign: 'start',
                borderColor: active ? 'var(--text-muted)' : undefined,
              }}
            >
              <div
                style={{
                  width: 44,
                  height: 44,
                  borderRadius: '50%',
                  overflow: 'hidden',
                  flexShrink: 0,
                  boxShadow: 'var(--shadow-disc)',
                  position: 'relative',
                }}
              >
                <img src={trk.coverUrl} alt={trk.title} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div
                  style={{
                    fontSize: 14,
                    fontWeight: 700,
                    color: 'var(--text-primary)',
                    whiteSpace: 'nowrap',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                  }}
                >
                  {trk.title}
                </div>
                <div style={{ fontSize: 12, color: 'var(--text-secondary)' }}>{trk.artist}</div>
              </div>
              <span
                className="tabular-mono"
                style={{
                  fontSize: 10.5,
                  fontWeight: 600,
                  color: 'var(--text-muted)',
                  padding: '4px 8px',
                  borderRadius: 999,
                  background: 'var(--bg-recessed)',
                }}
              >
                {trk.format}
              </span>
            </button>
          );
        })}
      </div>

      <style>{`
        @keyframes homeSpin {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }
      `}</style>
    </div>
  );
};
