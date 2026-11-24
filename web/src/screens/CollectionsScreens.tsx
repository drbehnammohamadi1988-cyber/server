import React, { useMemo, useState } from 'react';
import { TranslationDict } from '../i18n/translations';
import { formatClock } from '../components/AudioVisualizer';
import { BackChevronIcon, HeartIcon, PlusIcon, SearchLensIcon } from '../components/Icons';
import { Playlist, Track } from '../types/music';

interface SubHeaderProps {
  title: string;
  isRtl: boolean;
  onBack?: () => void;
}

const SubHeader: React.FC<SubHeaderProps> = ({ title, isRtl, onBack }) => (
  <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 16 }}>
    {onBack && (
      <button
        type="button"
        onClick={onBack}
        className="tactile-btn"
        aria-label="Back"
        style={{
          width: 34,
          height: 34,
          borderRadius: '50%',
          display: 'inline-flex',
          alignItems: 'center',
          justifyContent: 'center',
          color: 'var(--text-primary)',
        }}
      >
        <BackChevronIcon size={18} rtl={isRtl} />
      </button>
    )}
    <h1 style={{ margin: 0, fontSize: 22, fontWeight: 800, letterSpacing: '-0.02em' }}>{title}</h1>
  </div>
);

export const AlbumsScreen: React.FC<{
  tracks: Track[];
  isRtl: boolean;
  t: TranslationDict;
  onBack: () => void;
  onPlayList: (tracks: Track[]) => void;
}> = ({ tracks, isRtl, t, onBack, onPlayList }) => {
  const albums = useMemo(() => {
    const map = new Map<string, Track[]>();
    for (const trk of tracks) {
      const list = map.get(trk.album) ?? [];
      list.push(trk);
      map.set(trk.album, list);
    }
    return Array.from(map.entries()).map(([name, items]) => ({ name, items, lead: items[0] }));
  }, [tracks]);

  return (
    <div className="scroll-clean" style={{ flex: 1, padding: 'calc(18px + var(--safe-top)) 20px 24px' }}>
      <SubHeader title={t.albums.title} isRtl={isRtl} onBack={onBack} />
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 14 }}>
        {albums.map((alb) => (
          <div
            key={alb.name}
            onClick={() => onPlayList(alb.items)}
            className="tactile-pill"
            style={{ borderRadius: 22, padding: 12, display: 'flex', flexDirection: 'column', gap: 10 }}
          >
            <div
              style={{
                width: '100%',
                aspectRatio: '1',
                borderRadius: 16,
                overflow: 'hidden',
                boxShadow: 'var(--shadow-disc)',
              }}
            >
              <img src={alb.lead.coverUrl} alt={alb.name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
            </div>
            <div>
              <div style={{ fontSize: 13.5, fontWeight: 700, color: 'var(--text-primary)' }}>{alb.name}</div>
              <div style={{ fontSize: 11.5, color: 'var(--text-secondary)', marginTop: 2 }}>
                {alb.lead.artist} · {alb.items.length} {t.albums.tracksUnit}
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export const ArtistsScreen: React.FC<{
  tracks: Track[];
  isRtl: boolean;
  t: TranslationDict;
  onBack: () => void;
  onPlayList: (tracks: Track[]) => void;
}> = ({ tracks, isRtl, t, onBack, onPlayList }) => {
  const artists = useMemo(() => {
    const map = new Map<string, Track[]>();
    for (const trk of tracks) {
      const list = map.get(trk.artist) ?? [];
      list.push(trk);
      map.set(trk.artist, list);
    }
    return Array.from(map.entries()).map(([name, items]) => ({ name, items, lead: items[0] }));
  }, [tracks]);

  return (
    <div className="scroll-clean" style={{ flex: 1, padding: 'calc(18px + var(--safe-top)) 20px 24px' }}>
      <SubHeader title={t.artists.title} isRtl={isRtl} onBack={onBack} />
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {artists.map((art) => (
          <button
            key={art.name}
            type="button"
            onClick={() => onPlayList(art.items)}
            className="tactile-pill"
            style={{
              padding: '10px 14px',
              borderRadius: 999,
              display: 'flex',
              alignItems: 'center',
              gap: 12,
              textAlign: 'start',
            }}
          >
            <img
              src={art.lead.coverUrl}
              alt={art.name}
              style={{ width: 46, height: 46, borderRadius: '50%', objectFit: 'cover', boxShadow: 'var(--shadow-disc)' }}
            />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--text-primary)' }}>{art.name}</div>
              <div style={{ fontSize: 12, color: 'var(--text-secondary)' }}>
                {art.items.length} {t.artists.tracksUnit}
              </div>
            </div>
            <span className="tactile-btn" style={{ padding: '6px 12px', borderRadius: 999, fontSize: 11.5, fontWeight: 600 }}>
              {t.explore.play}
            </span>
          </button>
        ))}
      </div>
    </div>
  );
};

export const PlaylistsScreen: React.FC<{
  playlists: Playlist[];
  tracks: Track[];
  isRtl: boolean;
  t: TranslationDict;
  onBack: () => void;
  onCreatePlaylist: (name: string) => void;
  onDeletePlaylist: (id: string) => void;
  onRemoveTrackFromPlaylist: (playlistId: string, trackId: string) => void;
  onPlayPlaylist: (tracks: Track[]) => void;
}> = ({
  playlists,
  tracks,
  isRtl,
  t,
  onBack,
  onCreatePlaylist,
  onDeletePlaylist,
  onRemoveTrackFromPlaylist,
  onPlayPlaylist,
}) => {
  const [nameInput, setNameInput] = useState('');
  const [expandedId, setExpandedId] = useState<string | null>(playlists[0]?.id ?? null);

  const trackMap = useMemo(() => new Map(tracks.map((trk) => [trk.id, trk])), [tracks]);

  return (
    <div className="scroll-clean" style={{ flex: 1, padding: 'calc(18px + var(--safe-top)) 20px 24px' }}>
      <SubHeader title={t.playlists.title} isRtl={isRtl} onBack={onBack} />

      {/* Create Playlist Form */}
      <form
        onSubmit={(e) => {
          e.preventDefault();
          const trimmed = nameInput.trim();
          if (!trimmed) return;
          onCreatePlaylist(trimmed);
          setNameInput('');
        }}
        className="recessed-well"
        style={{
          borderRadius: 999,
          padding: '5px 6px 5px 14px',
          display: 'flex',
          alignItems: 'center',
          gap: 8,
          marginBottom: 18,
        }}
      >
        <input
          type="text"
          value={nameInput}
          onChange={(e) => setNameInput(e.target.value)}
          placeholder={t.playlists.namePlaceholder}
          style={{
            flex: 1,
            border: 'none',
            background: 'transparent',
            color: 'var(--text-primary)',
            fontSize: 13,
            outline: 'none',
          }}
        />
        <button
          type="submit"
          className="tactile-btn"
          style={{
            padding: '7px 14px',
            borderRadius: 999,
            fontSize: 12,
            fontWeight: 700,
            color: 'var(--text-primary)',
            display: 'inline-flex',
            alignItems: 'center',
            gap: 5,
          }}
        >
          <PlusIcon size={14} />
          <span>{t.playlists.createBtn}</span>
        </button>
      </form>

      {playlists.length === 0 ? (
        <div className="recessed-well" style={{ borderRadius: 20, padding: 22, textAlign: 'center', color: 'var(--text-secondary)' }}>
          {t.playlists.empty}
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {playlists.map((pl) => {
            const items = pl.trackIds.map((id) => trackMap.get(id)).filter(Boolean) as Track[];
            const isOpen = expandedId === pl.id;
            return (
              <div key={pl.id} className="tactile-pill" style={{ borderRadius: 22, padding: 14 }}>
                <div
                  onClick={() => setExpandedId(isOpen ? null : pl.id)}
                  style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', cursor: 'pointer' }}
                >
                  <div>
                    <div style={{ fontSize: 15, fontWeight: 700, color: 'var(--text-primary)' }}>{pl.name}</div>
                    <div style={{ fontSize: 12, color: 'var(--text-secondary)', marginTop: 2 }}>
                      {items.length} {t.playlists.tracksUnit}
                    </div>
                  </div>
                  <div style={{ display: 'flex', gap: 8 }}>
                    {items.length > 0 && (
                      <button
                        type="button"
                        onClick={(e) => {
                          e.stopPropagation();
                          onPlayPlaylist(items);
                        }}
                        className="tactile-btn"
                        style={{ padding: '6px 12px', borderRadius: 999, fontSize: 11.5, fontWeight: 700, color: 'var(--text-primary)' }}
                      >
                        {t.playlists.playAll}
                      </button>
                    )}
                    <button
                      type="button"
                      onClick={(e) => {
                        e.stopPropagation();
                        onDeletePlaylist(pl.id);
                      }}
                      style={{
                        border: 'none',
                        background: 'transparent',
                        color: 'var(--text-muted)',
                        fontSize: 11.5,
                        fontWeight: 600,
                        cursor: 'pointer',
                      }}
                    >
                      {t.playlists.deletePlaylist}
                    </button>
                  </div>
                </div>

                {isOpen && (
                  <div style={{ marginTop: 12, display: 'flex', flexDirection: 'column', gap: 6 }}>
                    {items.length === 0 ? (
                      <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>{t.playlists.addTrackPrompt}</div>
                    ) : (
                      items.map((trk) => (
                        <div
                          key={trk.id}
                          style={{
                            display: 'flex',
                            alignItems: 'center',
                            gap: 10,
                            padding: '6px 8px',
                            borderRadius: 12,
                            background: 'var(--bg-recessed)',
                          }}
                        >
                          <img
                            src={trk.coverUrl}
                            alt=""
                            style={{ width: 32, height: 32, borderRadius: '50%', objectFit: 'cover' }}
                          />
                          <div
                            onClick={() => onPlayPlaylist([trk, ...items.filter((x) => x.id !== trk.id)])}
                            style={{ flex: 1, minWidth: 0, cursor: 'pointer' }}
                          >
                            <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-primary)' }}>{trk.title}</div>
                            <div style={{ fontSize: 11, color: 'var(--text-secondary)' }}>{trk.artist}</div>
                          </div>
                          <button
                            type="button"
                            onClick={() => onRemoveTrackFromPlaylist(pl.id, trk.id)}
                            style={{
                              border: 'none',
                              background: 'transparent',
                              color: 'var(--text-muted)',
                              fontSize: 13,
                              cursor: 'pointer',
                            }}
                          >
                            ×
                          </button>
                        </div>
                      ))
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

export const FavoritesScreen: React.FC<{
  tracks: Track[];
  favoriteIds: string[];
  isRtl: boolean;
  t: TranslationDict;
  onBack: () => void;
  onPlayTrack: (track: Track) => void;
  onToggleFavorite: (id: string) => void;
}> = ({ tracks, favoriteIds, isRtl, t, onBack, onPlayTrack, onToggleFavorite }) => {
  const favTracks = tracks.filter((trk) => favoriteIds.includes(trk.id));

  return (
    <div className="scroll-clean" style={{ flex: 1, padding: 'calc(18px + var(--safe-top)) 20px 24px' }}>
      <SubHeader title={t.favorites.title} isRtl={isRtl} onBack={onBack} />
      {favTracks.length === 0 ? (
        <div className="recessed-well" style={{ borderRadius: 22, padding: 26, textAlign: 'center' }}>
          <div style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--text-primary)' }}>{t.favorites.emptyTitle}</div>
          <div style={{ fontSize: 12, color: 'var(--text-secondary)', marginTop: 6 }}>{t.favorites.emptySubtitle}</div>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {favTracks.map((trk) => (
            <div
              key={trk.id}
              onClick={() => onPlayTrack(trk)}
              className="tactile-pill"
              style={{ borderRadius: 999, padding: '8px 14px 8px 9px', display: 'flex', alignItems: 'center', gap: 12 }}
            >
              <img
                src={trk.coverUrl}
                alt={trk.title}
                style={{ width: 44, height: 44, borderRadius: '50%', objectFit: 'cover', boxShadow: 'var(--shadow-disc)' }}
              />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--text-primary)' }}>{trk.title}</div>
                <div style={{ fontSize: 12, color: 'var(--text-secondary)' }}>
                  {trk.artist} · {formatClock(trk.durationSec)}
                </div>
              </div>
              <button
                type="button"
                onClick={(e) => {
                  e.stopPropagation();
                  onToggleFavorite(trk.id);
                }}
                style={{ border: 'none', background: 'transparent', color: '#C25967', cursor: 'pointer', padding: 6 }}
              >
                <HeartIcon size={17} active />
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export const SearchScreen: React.FC<{
  tracks: Track[];
  t: TranslationDict;
  onPlayTrack: (track: Track) => void;
}> = ({ tracks, t, onPlayTrack }) => {
  const [query, setQuery] = useState('');
  const [formatFilter, setFormatFilter] = useState<string | null>(null);

  const formats = ['FLAC', 'WAV', 'MP3', 'AAC', 'OGG'];

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return tracks.filter((trk) => {
      if (formatFilter && trk.format !== formatFilter) return false;
      if (!q) return true;
      return (
        trk.title.toLowerCase().includes(q) ||
        trk.artist.toLowerCase().includes(q) ||
        trk.album.toLowerCase().includes(q) ||
        trk.format.toLowerCase().includes(q)
      );
    });
  }, [tracks, query, formatFilter]);

  return (
    <div className="scroll-clean" style={{ flex: 1, padding: 'calc(18px + var(--safe-top)) 20px 24px' }}>
      <h1 style={{ margin: '0 0 14px', fontSize: 22, fontWeight: 800, letterSpacing: '-0.02em' }}>
        {t.search.title}
      </h1>

      <div
        className="recessed-well"
        style={{
          borderRadius: 999,
          padding: '10px 16px',
          display: 'flex',
          alignItems: 'center',
          gap: 10,
          marginBottom: 14,
        }}
      >
        <SearchLensIcon size={17} />
        <input
          type="search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder={t.search.placeholder}
          style={{
            flex: 1,
            border: 'none',
            background: 'transparent',
            color: 'var(--text-primary)',
            fontSize: 13.5,
            outline: 'none',
          }}
        />
      </div>

      {/* Format Filter Chips */}
      <div style={{ display: 'flex', gap: 8, overflowX: 'auto', paddingBottom: 14 }}>
        {formats.map((fmt) => {
          const active = formatFilter === fmt;
          return (
            <button
              key={fmt}
              type="button"
              onClick={() => setFormatFilter(active ? null : fmt)}
              className={active ? 'tactile-btn is-pressed' : 'tactile-pill'}
              style={{
                padding: '6px 12px',
                borderRadius: 999,
                fontSize: 11,
                fontWeight: 700,
                color: active ? 'var(--text-primary)' : 'var(--text-secondary)',
              }}
            >
              {fmt}
            </button>
          );
        })}
      </div>

      {filtered.length === 0 ? (
        <div className="recessed-well" style={{ borderRadius: 20, padding: 24, textAlign: 'center', color: 'var(--text-secondary)' }}>
          {t.search.noResults}
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {filtered.map((trk) => (
            <button
              key={trk.id}
              type="button"
              onClick={() => onPlayTrack(trk)}
              className="tactile-pill"
              style={{
                borderRadius: 999,
                padding: '8px 14px 8px 9px',
                display: 'flex',
                alignItems: 'center',
                gap: 12,
                textAlign: 'start',
              }}
            >
              <img
                src={trk.coverUrl}
                alt={trk.title}
                style={{ width: 42, height: 42, borderRadius: '50%', objectFit: 'cover', boxShadow: 'var(--shadow-disc)' }}
              />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--text-primary)' }}>{trk.title}</div>
                <div style={{ fontSize: 11.5, color: 'var(--text-secondary)' }}>
                  {trk.artist} · {trk.album}
                </div>
              </div>
              <span className="tabular-mono" style={{ fontSize: 10.5, color: 'var(--text-muted)' }}>
                {trk.format}
              </span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
};
