import React from 'react';
import { TranslationDict } from '../i18n/translations';
import { AppTheme, Track } from '../types/music';
import { MoreDotsIcon, UploadWaveIcon } from '../components/Icons';
import { OrbitalTrackWheel } from '../components/OrbitalTrackWheel';

interface ExploreScreenProps {
  tracks: Track[];
  activeTrackId: string;
  isPlaying: boolean;
  isRtl: boolean;
  theme: AppTheme;
  reduceMotion: boolean;
  hapticsEnabled: boolean;
  t: TranslationDict;
  onSelectCenterTrack: (track: Track) => void;
  onPlayAndOpen: (track: Track, discRect: DOMRect | null) => void;
  onOpenQuickMenu: () => void;
  onTriggerImport: () => void;
}

export const ExploreScreen: React.FC<ExploreScreenProps> = ({
  tracks,
  activeTrackId,
  isPlaying,
  isRtl,
  theme,
  reduceMotion,
  hapticsEnabled,
  t,
  onSelectCenterTrack,
  onPlayAndOpen,
  onOpenQuickMenu,
  onTriggerImport,
}) => {
  return (
    <div
      style={{
        flex: 1,
        display: 'flex',
        flexDirection: 'column',
        minHeight: 0,
        position: 'relative',
      }}
    >
      {/* Top Bar matching reference ("Explore" bold + subtle action controls) */}
      <header
        style={{
          padding: 'calc(16px + var(--safe-top)) 22px 8px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          zIndex: 25,
          flexShrink: 0,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 10 }}>
          <h1
            style={{
              margin: 0,
              fontSize: 22,
              fontWeight: 700,
              letterSpacing: '-0.02em',
              color: 'var(--text-primary)',
            }}
          >
            {t.explore.title}
          </h1>
          <span
            className="tabular-mono"
            style={{
              fontSize: 11,
              fontWeight: 600,
              color: 'var(--text-muted)',
            }}
          >
            {tracks.length} {t.explore.tracksCount}
          </span>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <button
            type="button"
            onClick={onTriggerImport}
            aria-label={t.explore.importAudio}
            title={t.explore.importAudio}
            style={{
              width: 34,
              height: 34,
              borderRadius: '50%',
              border: 'none',
              background: 'transparent',
              color: 'var(--text-secondary)',
              display: 'inline-flex',
              alignItems: 'center',
              justifyContent: 'center',
              cursor: 'pointer',
            }}
          >
            <UploadWaveIcon size={18} />
          </button>

          <button
            type="button"
            onClick={onOpenQuickMenu}
            aria-label="Menu"
            style={{
              width: 34,
              height: 34,
              borderRadius: '50%',
              border: 'none',
              background: 'transparent',
              color: 'var(--text-primary)',
              display: 'inline-flex',
              alignItems: 'center',
              justifyContent: 'center',
              cursor: 'pointer',
            }}
          >
            <MoreDotsIcon size={21} />
          </button>
        </div>
      </header>

      {/* Curved Orbital Disc Wheel */}
      <div style={{ flex: 1, minHeight: 0, position: 'relative' }}>
        <OrbitalTrackWheel
          tracks={tracks}
          activeTrackId={activeTrackId}
          isPlaying={isPlaying}
          isRtl={isRtl}
          theme={theme}
          reduceMotion={reduceMotion}
          hapticsEnabled={hapticsEnabled}
          playLabel={t.explore.play}
          playingLabel={t.explore.playing}
          onSelectCenterTrack={onSelectCenterTrack}
          onPlayAndOpen={onPlayAndOpen}
        />
      </div>
    </div>
  );
};
