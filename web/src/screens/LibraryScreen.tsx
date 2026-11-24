import React, { useState } from 'react';
import { TranslationDict } from '../i18n/translations';
import { formatClock } from '../components/AudioVisualizer';
import { HeartIcon, PlusIcon, QueueListIcon, UploadWaveIcon } from '../components/Icons';
import { Playlist, ScreenId, Track } from '../types/music';

interface LibraryScreenProps {
  tracks: Track[];
  currentTrackId: string;
  favoriteIds: string[];
  playlists: Playlist[];
  importing: boolean;
  t: TranslationDict;
  onNavigate: (screen: ScreenId) => void;
  onPlayTrack: (track: Track) => void;
  onToggleFavorite: (trackId: string) => void;
  onAddToQueue: (trackId: string) => void;
  onAddToPlaylist: (playlistId: string, trackId: string) => void;
  onRemoveImportedTrack: (trackId: string) => void;
  onTriggerImport: () => void;
}

export const LibraryScreen: React.FC<LibraryScreenProps> = ({
  tracks,
  currentTrackId,
  favoriteIds,
  playlists,
  importing,
  t,
  onNavigate,
  onPlayTrack,
  onToggleFavorite,
  onAddToQueue,
  onAddToPlaylist,
  onRemoveImportedTrack,
  onTriggerImport,
}) => {
  const [pickerTrackId, setPickerTrackId] = useState<string | null>(null);

  const subTabs: { screen: ScreenId; label: string }[] = [
    { screen: 'albums', label: t.library.albums },
    { screen: 'artists', label: t.library.artists },
    { screen: 'playlists', label: t.library.playlists },
    { screen: 'favorites', label: t.library.favorites },
  ];

  return (
    <div className="scroll-clean" style={{ flex: 1, padding: 'calc(18px + var(--safe-top)) 20px 24px' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
        <h1 style={{ margin: 0, fontSize: 22, fontWeight: 800, letterSpacing: '-0.02em' }}>
          {t.library.title}
        </h1>
        <button
          type="button"
          onClick={onTriggerImport}
          className="tactile-pill"
          style={{
            padding: '8px 14px',
            borderRadius: 999,
            fontSize: 12,
            fontWeight: 700,
            color: 'var(--text-primary)',
            display: 'inline-flex',
            alignItems: 'center',
            gap: 6,
          }}
        >
          <UploadWaveIcon size={15} />
          <span>{importing ? t.library.importing : t.library.importBtn}</span>
        </button>
      </div>

      {/* Category Pills */}
      <div style={{ display: 'flex', gap: 8, overflowX: 'auto', paddingBottom: 12 }}>
        {subTabs.map((tab) => (
          <button
            key={tab.screen}
            type="button"
            onClick={() => onNavigate(tab.screen)}
            className="tactile-pill"
            style={{
              padding: '7px 14px',
              borderRadius: 999,
              fontSize: 12.5,
              fontWeight: 600,
              color: 'var(--text-primary)',
              whiteSpace: 'nowrap',
            }}
          >
            {tab.label}
          </button>
        ))}
      </div>

      <p style={{ margin: '0 0 14px', fontSize: 11.5, color: 'var(--text-muted)' }}>
        {t.library.supportedFormats}
      </p>

      {tracks.length === 0 ? (
        <div className="recessed-well" style={{ borderRadius: 22, padding: 24, textAlign: 'center', color: 'var(--text-secondary)' }}>
          {t.library.emptyTracks}
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {tracks.map((trk) => {
            const isCurrent = trk.id === currentTrackId;
            const isFav = favoriteIds.includes(trk.id);
            return (
              <div
                key={trk.id}
                className="tactile-pill"
                style={{
                  borderRadius: 22,
                  padding: '9px 12px',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: 8,
                  borderColor: isCurrent ? 'var(--text-muted)' : undefined,
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: 11 }}>
                  <div
                    onClick={() => onPlayTrack(trk)}
                    style={{
                      width: 46,
                      height: 46,
                      borderRadius: '50%',
                      overflow: 'hidden',
                      flexShrink: 0,
                      boxShadow: 'var(--shadow-disc)',
                      cursor: 'pointer',
                    }}
                  >
                    <img src={trk.coverUrl} alt={trk.title} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                  </div>

                  <div onClick={() => onPlayTrack(trk)} style={{ flex: 1, minWidth: 0, cursor: 'pointer' }}>
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
                    <div style={{ fontSize: 11.5, color: 'var(--text-secondary)' }}>
                      {trk.artist} · {formatClock(trk.durationSec)} · {trk.format}
                    </div>
                  </div>

                  <button
                    type="button"
                    onClick={() => onToggleFavorite(trk.id)}
                    aria-label="Favorite"
                    style={{
                      border: 'none',
                      background: 'transparent',
                      color: isFav ? '#C25967' : 'var(--text-muted)',
                      padding: 6,
                      cursor: 'pointer',
                    }}
                  >
                    <HeartIcon size={16} active={isFav} />
                  </button>

                  <button
                    type="button"
                    onClick={() => onAddToQueue(trk.id)}
                    aria-label={t.library.addToQueue}
                    title={t.library.addToQueue}
                    style={{
                      border: 'none',
                      background: 'transparent',
                      color: 'var(--text-secondary)',
                      padding: 6,
                      cursor: 'pointer',
                    }}
                  >
                    <QueueListIcon size={16} />
                  </button>

                  <button
                    type="button"
                    onClick={() => setPickerTrackId((cur) => (cur === trk.id ? null : trk.id))}
                    aria-label={t.nowPlaying.addToPlaylist}
                    title={t.nowPlaying.addToPlaylist}
                    style={{
                      border: 'none',
                      background: 'transparent',
                      color: 'var(--text-secondary)',
                      padding: 6,
                      cursor: 'pointer',
                    }}
                  >
                    <PlusIcon size={16} />
                  </button>
                </div>

                {pickerTrackId === trk.id && (
                  <div
                    className="recessed-well"
                    style={{
                      borderRadius: 14,
                      padding: '8px 10px',
                      display: 'flex',
                      flexWrap: 'wrap',
                      gap: 6,
                      alignItems: 'center',
                    }}
                  >
                    {playlists.map((pl) => {
                      const inPl = pl.trackIds.includes(trk.id);
                      return (
                        <button
                          key={pl.id}
                          type="button"
                          onClick={() => {
                            onAddToPlaylist(pl.id, trk.id);
                            setPickerTrackId(null);
                          }}
                          className="tactile-pill"
                          style={{
                            padding: '5px 10px',
                            borderRadius: 999,
                            fontSize: 11,
                            fontWeight: 600,
                            color: 'var(--text-primary)',
                          }}
                        >
                          {inPl ? '✓ ' : '+ '}
                          {pl.name}
                        </button>
                      );
                    })}
                    {!trk.isDemo && (
                      <button
                        type="button"
                        onClick={() => {
                          onRemoveImportedTrack(trk.id);
                          setPickerTrackId(null);
                        }}
                        style={{
                          marginInlineStart: 'auto',
                          border: 'none',
                          background: 'transparent',
                          color: '#C25967',
                          fontSize: 11,
                          fontWeight: 700,
                          cursor: 'pointer',
                        }}
                      >
                        {t.library.deleteTrack}
                      </button>
                    )}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};
