import React, { useRef } from 'react';
import { motion } from 'framer-motion';
import { AppTheme, Track } from '../types/music';
import { MorphPlayPauseIcon } from './Icons';

interface MiniPlayerProps {
  track: Track;
  isPlaying: boolean;
  currentTimeSec: number;
  durationSec: number;
  theme: AppTheme;
  reduceMotion: boolean;
  onTogglePlay: () => void;
  onExpand: (discRect: DOMRect | null) => void;
}

export const MiniPlayer: React.FC<MiniPlayerProps> = ({
  track,
  isPlaying,
  currentTimeSec,
  durationSec,
  theme,
  reduceMotion,
  onTogglePlay,
  onExpand,
}) => {
  const discRef = useRef<HTMLDivElement>(null);
  const touchStartY = useRef<number | null>(null);
  const progressPct = durationSec > 0 ? Math.min(100, (currentTimeSec / durationSec) * 100) : 0;
  const isDark = theme === 'dark';

  return (
    <motion.div
      initial={reduceMotion ? { opacity: 1 } : { y: 24, opacity: 0, scale: 0.96 }}
      animate={{ y: 0, opacity: 1, scale: 1 }}
      exit={reduceMotion ? { opacity: 0 } : { y: 24, opacity: 0, scale: 0.96 }}
      transition={{ type: 'spring', stiffness: 360, damping: 30 }}
      onPointerDown={(e) => {
        touchStartY.current = e.clientY;
      }}
      onPointerUp={(e) => {
        if (touchStartY.current !== null && touchStartY.current - e.clientY > 28) {
          onExpand(discRef.current?.getBoundingClientRect() ?? null);
        }
        touchStartY.current = null;
      }}
      onClick={(e) => {
        if ((e.target as HTMLElement).closest('button[data-mini-play="true"]')) return;
        onExpand(discRef.current?.getBoundingClientRect() ?? null);
      }}
      style={{
        position: 'relative',
        margin: '0 14px 10px',
        padding: '8px 12px',
        borderRadius: 999,
        background: 'var(--bg-miniplayer)',
        backdropFilter: 'blur(18px)',
        WebkitBackdropFilter: 'blur(18px)',
        border: `1px solid ${isDark ? 'rgba(255,255,255,0.09)' : 'rgba(255,255,255,0.96)'}`,
        boxShadow: isDark
          ? '0 16px 34px -8px rgba(0,0,0,0.75), inset 0 1px 0 rgba(255,255,255,0.08)'
          : '0 16px 34px -8px rgba(128,142,168,0.28), 0 4px 10px rgba(128,142,168,0.10)',
        display: 'flex',
        alignItems: 'center',
        gap: 11,
        cursor: 'pointer',
        overflow: 'hidden',
        zIndex: 40,
      }}
    >
      {/* Spinning Micro Vinyl Disc */}
      <div
        ref={discRef}
        style={{
          position: 'relative',
          width: 40,
          height: 40,
          borderRadius: '50%',
          overflow: 'hidden',
          flexShrink: 0,
          background: '#0C0D10',
          boxShadow: '0 4px 10px rgba(0,0,0,0.22), 0 0 0 1.5px rgba(255,255,255,0.25)',
        }}
      >
        <img
          src={track.coverUrl}
          alt={track.title}
          style={{
            width: '100%',
            height: '100%',
            objectFit: 'cover',
            borderRadius: '50%',
            animation: isPlaying && !reduceMotion ? 'miniVinylSpin 3.6s linear infinite' : undefined,
          }}
        />
        <div
          style={{
            position: 'absolute',
            left: '50%',
            top: '50%',
            width: 8,
            height: 8,
            borderRadius: '50%',
            transform: 'translate(-50%, -50%)',
            background: isDark ? '#181C24' : '#F4F5F8',
            border: '1px solid rgba(255,255,255,0.75)',
          }}
        />
      </div>

      {/* Track Title & Artist */}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          style={{
            fontSize: 13.5,
            fontWeight: 700,
            color: 'var(--text-primary)',
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
        >
          {track.title}
        </div>
        <div
          style={{
            fontSize: 11.5,
            fontWeight: 500,
            color: 'var(--text-secondary)',
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
        >
          {track.artist}
        </div>
      </div>

      {/* Tactile Play / Pause Pill */}
      <button
        type="button"
        data-mini-play="true"
        aria-label={isPlaying ? 'Pause' : 'Play'}
        onClick={(e) => {
          e.stopPropagation();
          onTogglePlay();
        }}
        className="tactile-btn"
        style={{
          width: 38,
          height: 38,
          borderRadius: '50%',
          display: 'inline-flex',
          alignItems: 'center',
          justifyContent: 'center',
          color: 'var(--text-primary)',
          flexShrink: 0,
        }}
      >
        <MorphPlayPauseIcon isPlaying={isPlaying} size={17} />
      </button>

      {/* Hairline Progress Bar Along Bottom Edge */}
      <div
        style={{
          position: 'absolute',
          left: 34,
          right: 34,
          bottom: 2,
          height: 2,
          borderRadius: 99,
          background: isDark ? 'rgba(255,255,255,0.06)' : 'rgba(130,142,168,0.16)',
          overflow: 'hidden',
        }}
      >
        <div
          style={{
            width: `${progressPct}%`,
            height: '100%',
            background: isDark ? '#CED8EA' : '#252A34',
            transition: 'width 0.2s linear',
          }}
        />
      </div>

      <style>{`
        @keyframes miniVinylSpin {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }
      `}</style>
    </motion.div>
  );
};
