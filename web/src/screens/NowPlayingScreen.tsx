import React, { useRef, useState } from 'react';
import { motion } from 'framer-motion';
import { TranslationDict } from '../i18n/translations';
import { AppTheme, Playlist, RepeatMode, Track, TurntablePhase } from '../types/music';
import { AudioVisualizer } from '../components/AudioVisualizer';
import { BackChevronIcon, MoreDotsIcon } from '../components/Icons';
import { TactileControls } from '../components/TactileControls';
import { TurntableCanvas } from '../components/TurntableCanvas';

interface NowPlayingScreenProps {
  track: Track;
  isPlaying: boolean;
  currentTimeSec: number;
  durationSec: number;
  shuffle: boolean;
  repeat: RepeatMode;
  isFavorite: boolean;
  volume: number;
  theme: AppTheme;
  isRtl: boolean;
  reduceMotion: boolean;
  playlists: Playlist[];
  sleepRemainingSec: number | null;
  t: TranslationDict;
  onBack: (platterRect: DOMRect | null) => void;
  onTogglePlay: () => void;
  onPrev: () => void;
  onNext: () => void;
  onSeek: (sec: number) => void;
  onScrubStateChange: (scrubbing: boolean) => void;
  onToggleShuffle: () => void;
  onCycleRepeat: () => void;
  onToggleFavorite: () => void;
  onVolumeChange: (v: number) => void;
  onOpenQueue: () => void;
  onOpenEq: () => void;
  onAddToPlaylist: (playlistId: string, trackId: string) => void;
  onOpenSettings: () => void;
}

export const NowPlayingScreen: React.FC<NowPlayingScreenProps> = ({
  track,
  isPlaying,
  currentTimeSec,
  durationSec,
  shuffle,
  repeat,
  isFavorite,
  volume,
  theme,
  isRtl,
  reduceMotion,
  playlists,
  sleepRemainingSec,
  t,
  onBack,
  onTogglePlay,
  onPrev,
  onNext,
  onSeek,
  onScrubStateChange,
  onToggleShuffle,
  onCycleRepeat,
  onToggleFavorite,
  onVolumeChange,
  onOpenQueue,
  onOpenEq,
  onAddToPlaylist,
  onOpenSettings,
}) => {
  const deckWrapperRef = useRef<HTMLDivElement>(null);
  const [phase, setPhase] = useState<TurntablePhase>(isPlaying ? 'playing' : 'parked');
  const [menuOpen, setMenuOpen] = useState(false);

  const phaseLabel =
    phase === 'cueing_in'
      ? t.nowPlaying.tonearmCueing
      : phase === 'playing' || phase === 'scratching'
      ? t.nowPlaying.tonearmActive
      : phase === 'paused_hover'
      ? t.nowPlaying.tonearmHover
      : t.nowPlaying.tonearmParked;

  const isDark = theme === 'dark';

  return (
    <motion.div
      initial={reduceMotion ? { opacity: 1 } : { opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={reduceMotion ? { opacity: 0 } : { opacity: 0 }}
      transition={{ duration: 0.28 }}
      style={{
        flex: 1,
        display: 'flex',
        flexDirection: 'column',
        minHeight: 0,
        position: 'relative',
        background: 'var(--bg-canvas)',
      }}
    >
      {/* Top Bar matching reference: Back chevron + subtle telemetry pill + Menu dots */}
      <header
        style={{
          padding: 'calc(12px + var(--safe-top)) 18px 4px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          zIndex: 30,
          flexShrink: 0,
        }}
      >
        <button
          type="button"
          onClick={() => onBack(deckWrapperRef.current?.getBoundingClientRect() ?? null)}
          aria-label={t.common.back}
          style={{
            width: 36,
            height: 36,
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
          <BackChevronIcon size={22} rtl={isRtl} />
        </button>

        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 8,
            fontSize: 11,
            fontWeight: 600,
            color: 'var(--text-secondary)',
            letterSpacing: '0.02em',
          }}
        >
          <span
            style={{
              width: 6,
              height: 6,
              borderRadius: '50%',
              background:
                phase === 'playing' || phase === 'cueing_in'
                  ? isDark
                    ? '#D8E3F6'
                    : '#262B36'
                  : 'var(--text-muted)',
            }}
          />
          <span>{phaseLabel}</span>
          {sleepRemainingSec !== null && sleepRemainingSec > 0 && (
            <span className="tabular-mono" style={{ opacity: 0.85 }}>
              · {Math.ceil(sleepRemainingSec / 60)}
              {t.common.minShort}
            </span>
          )}
        </div>

        <button
          type="button"
          onClick={() => setMenuOpen((o) => !o)}
          aria-label="Options"
          style={{
            width: 36,
            height: 36,
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
          <MoreDotsIcon size={22} />
        </button>
      </header>

      {/* Contextual Action Sheet for Turntable Menu */}
      {menuOpen && (
        <div
          style={{
            position: 'absolute',
            top: 'calc(54px + var(--safe-top))',
            insetInlineEnd: 18,
            width: 230,
            borderRadius: 18,
            padding: 10,
            background: 'var(--bg-surface)',
            border: `1px solid var(--border-highlight)`,
            boxShadow: 'var(--shadow-neu-soft)',
            zIndex: 60,
            display: 'flex',
            flexDirection: 'column',
            gap: 4,
          }}
        >
          <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--text-muted)', padding: '4px 8px' }}>
            {t.nowPlaying.addToPlaylist}
          </div>
          {playlists.map((pl) => {
            const alreadyIn = pl.trackIds.includes(track.id);
            return (
              <button
                key={pl.id}
                type="button"
                onClick={() => {
                  onAddToPlaylist(pl.id, track.id);
                  setMenuOpen(false);
                }}
                style={{
                  textAlign: 'start',
                  padding: '8px 10px',
                  borderRadius: 10,
                  border: 'none',
                  background: alreadyIn ? 'var(--bg-recessed)' : 'transparent',
                  color: 'var(--text-primary)',
                  fontSize: 12.5,
                  fontWeight: 600,
                  cursor: 'pointer',
                  display: 'flex',
                  justifyContent: 'space-between',
                }}
              >
                <span>{pl.name}</span>
                <span style={{ color: 'var(--text-muted)' }}>{alreadyIn ? '✓' : '+'}</span>
              </button>
            );
          })}
          <div style={{ height: 1, background: 'var(--border-hairline)', margin: '4px 0' }} />
          <button
            type="button"
            onClick={() => {
              setMenuOpen(false);
              onOpenEq();
            }}
            style={{
              textAlign: 'start',
              padding: '8px 10px',
              borderRadius: 10,
              border: 'none',
              background: 'transparent',
              color: 'var(--text-primary)',
              fontSize: 12.5,
              fontWeight: 600,
              cursor: 'pointer',
            }}
          >
            {t.home.equalizer}
          </button>
          <button
            type="button"
            onClick={() => {
              setMenuOpen(false);
              onOpenSettings();
            }}
            style={{
              textAlign: 'start',
              padding: '8px 10px',
              borderRadius: 10,
              border: 'none',
              background: 'transparent',
              color: 'var(--text-primary)',
              fontSize: 12.5,
              fontWeight: 600,
              cursor: 'pointer',
            }}
          >
            {t.home.settings}
          </button>
        </div>
      )}

      {/* Upper Turntable Plinth Stage */}
      <motion.div
        ref={deckWrapperRef}
        initial={reduceMotion ? { opacity: 1 } : { scale: 0.94, opacity: 0.25, y: 14 }}
        animate={{ scale: 1, opacity: 1, y: 0 }}
        transition={{ type: 'spring', stiffness: 280, damping: 26 }}
        style={{
          padding: '2px 22px 0',
          display: 'flex',
          justifyContent: 'center',
          flexShrink: 0,
        }}
      >
        <TurntableCanvas
          track={track}
          isPlaying={isPlaying}
          currentTimeSec={currentTimeSec}
          durationSec={durationSec}
          theme={theme}
          reduceMotion={reduceMotion}
          isVisible
          onTogglePlay={onTogglePlay}
          onSeek={onSeek}
          onScrubStateChange={onScrubStateChange}
          onPhaseChange={setPhase}
        />
      </motion.div>

      {/* Track Title & Artist Metadata */}
      <motion.div
        initial={reduceMotion ? { opacity: 1 } : { opacity: 0, y: 12 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.08, duration: 0.3 }}
        style={{
          padding: '10px 24px 8px',
          textAlign: 'center',
          flexShrink: 0,
        }}
      >
        <h2
          style={{
            margin: 0,
            fontSize: 20,
            fontWeight: 700,
            letterSpacing: '-0.02em',
            color: 'var(--text-primary)',
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
        >
          {track.title}
        </h2>
        <p
          style={{
            margin: '4px 0 0',
            fontSize: 13.5,
            fontWeight: 500,
            color: 'var(--text-secondary)',
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
        >
          {track.artist}
        </p>
      </motion.div>

      {/* Lower Convex Curved White / Obsidian Deck with FFT Visualizer & Physical Transport */}
      <motion.div
        initial={reduceMotion ? { opacity: 1 } : { opacity: 0, y: 28 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.1, type: 'spring', stiffness: 260, damping: 26 }}
        className="lower-arc-deck"
        style={{
          flex: 1,
          minHeight: 0,
          marginTop: 8,
          borderTopLeftRadius: '54% 28px',
          borderTopRightRadius: '54% 28px',
          padding: '18px 20px calc(22px + var(--safe-bottom))',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'space-evenly',
          gap: 10,
        }}
      >
        <AudioVisualizer
          isPlaying={isPlaying}
          currentTimeSec={currentTimeSec}
          durationSec={durationSec}
          theme={theme}
          reduceMotion={reduceMotion}
          isVisible
          onSeek={onSeek}
        />

        <TactileControls
          isPlaying={isPlaying}
          shuffle={shuffle}
          repeat={repeat}
          isFavorite={isFavorite}
          volume={volume}
          theme={theme}
          isRtl={isRtl}
          onTogglePlay={onTogglePlay}
          onPrev={onPrev}
          onNext={onNext}
          onToggleShuffle={onToggleShuffle}
          onCycleRepeat={onCycleRepeat}
          onToggleFavorite={onToggleFavorite}
          onVolumeChange={onVolumeChange}
          onOpenQueue={onOpenQueue}
          onOpenEq={onOpenEq}
        />
      </motion.div>
    </motion.div>
  );
};
