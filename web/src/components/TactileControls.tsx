import React, { useState } from 'react';
import { AppTheme, RepeatMode } from '../types/music';
import {
  EqualizerIcon,
  HeartIcon,
  MorphPlayPauseIcon,
  QueueListIcon,
  RepeatIcon,
  ShuffleIcon,
  SkipNextIcon,
  SkipPrevIcon,
  VolumeIcon,
} from './Icons';

interface TactileControlsProps {
  isPlaying: boolean;
  shuffle: boolean;
  repeat: RepeatMode;
  isFavorite: boolean;
  volume: number;
  theme: AppTheme;
  isRtl: boolean;
  onTogglePlay: () => void;
  onPrev: () => void;
  onNext: () => void;
  onToggleShuffle: () => void;
  onCycleRepeat: () => void;
  onToggleFavorite: () => void;
  onVolumeChange: (v: number) => void;
  onOpenQueue: () => void;
  onOpenEq: () => void;
}

export const TactileControls: React.FC<TactileControlsProps> = ({
  isPlaying,
  shuffle,
  repeat,
  isFavorite,
  volume,
  theme,
  isRtl,
  onTogglePlay,
  onPrev,
  onNext,
  onToggleShuffle,
  onCycleRepeat,
  onToggleFavorite,
  onVolumeChange,
  onOpenQueue,
  onOpenEq,
}) => {
  const [showVolumePopover, setShowVolumePopover] = useState(false);
  const isDark = theme === 'dark';

  const microBtnStyle = (active = false): React.CSSProperties => ({
    width: 34,
    height: 34,
    borderRadius: '50%',
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    border: `1px solid ${isDark ? 'rgba(255,255,255,0.08)' : 'rgba(255,255,255,0.9)'}`,
    background: active
      ? isDark
        ? 'linear-gradient(145deg, #272D3A, #1B202A)'
        : 'linear-gradient(145deg, #E8ECF4, #F7F8FC)'
      : 'transparent',
    boxShadow: active ? 'var(--shadow-neu-pressed)' : 'none',
    color: active ? 'var(--text-primary)' : 'var(--text-secondary)',
    cursor: 'pointer',
    transition: 'all 0.16s ease',
  });

  return (
    <div style={{ width: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14, position: 'relative' }}>
      {/* Volume Floating Slider Drawer */}
      {showVolumePopover && (
        <div
          className="tactile-pill"
          style={{
            position: 'absolute',
            top: -46,
            left: '50%',
            transform: 'translateX(-50%)',
            padding: '8px 14px',
            borderRadius: 999,
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            zIndex: 30,
            width: 210,
          }}
        >
          <VolumeIcon muted={volume === 0} size={16} />
          <input
            type="range"
            min={0}
            max={1}
            step={0.01}
            value={volume}
            aria-label="Volume"
            onChange={(e) => onVolumeChange(parseFloat(e.target.value))}
            style={{
              width: '100%',
              accentColor: isDark ? '#B7C5DE' : '#2C3340',
              cursor: 'pointer',
            }}
          />
          <span className="tabular-mono" style={{ fontSize: 11, color: 'var(--text-secondary)', minWidth: 28 }}>
            {Math.round(volume * 100)}
          </span>
        </div>
      )}

      {/* Primary Reference Hardware Transport Deck: [Prev Pill] [Center Play/Pause Dial] [Next Pill] */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 18,
          width: '100%',
        }}
      >
        {/* Left Capsule Previous Button */}
        <button
          type="button"
          onClick={onPrev}
          aria-label="Previous Track"
          className="tactile-btn"
          style={{
            width: 82,
            height: 46,
            borderRadius: 999,
            display: 'inline-flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: 'var(--text-primary)',
            position: 'relative',
          }}
        >
          <div
            style={{
              position: 'absolute',
              inset: 4,
              borderRadius: 999,
              border: `1px solid ${isDark ? 'rgba(255,255,255,0.05)' : 'rgba(148,160,184,0.18)'}`,
              pointerEvents: 'none',
            }}
          />
          <SkipPrevIcon size={18} rtl={isRtl} />
        </button>

        {/* Center Raised Circular Play/Pause Rotary Dial */}
        <button
          type="button"
          onClick={onTogglePlay}
          aria-label={isPlaying ? 'Pause' : 'Play'}
          className="tactile-btn"
          style={{
            width: 72,
            height: 72,
            borderRadius: '50%',
            display: 'inline-flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: 'var(--text-primary)',
            position: 'relative',
          }}
        >
          {/* Inner concave dish ring matching reference image */}
          <div
            style={{
              position: 'absolute',
              inset: 7,
              borderRadius: '50%',
              background: isDark
                ? 'linear-gradient(145deg, #141820, #1F2430)'
                : 'linear-gradient(145deg, #E9ECF3, #FFFFFF)',
              boxShadow: isDark
                ? 'inset 2px 3px 6px rgba(0,0,0,0.7), inset -2px -2px 5px rgba(255,255,255,0.04)'
                : 'inset 2px 3px 6px rgba(145,156,178,0.22), inset -2px -2px 5px rgba(255,255,255,0.9)',
              pointerEvents: 'none',
            }}
          />
          {/* Top vertical mechanical indicator notch / LED */}
          <span
            style={{
              position: 'absolute',
              top: 10,
              left: '50%',
              transform: 'translateX(-50%)',
              width: 2.2,
              height: 6,
              borderRadius: 99,
              background: isPlaying
                ? isDark
                  ? '#DCE6F8'
                  : '#222732'
                : 'var(--text-muted)',
              boxShadow: isPlaying
                ? isDark
                  ? '0 0 6px rgba(220,230,248,0.65)'
                  : '0 0 4px rgba(34,39,50,0.25)'
                : 'none',
              zIndex: 2,
            }}
          />
          <div style={{ position: 'relative', zIndex: 2, marginTop: 4 }}>
            <MorphPlayPauseIcon isPlaying={isPlaying} size={22} />
          </div>
        </button>

        {/* Right Capsule Next Button */}
        <button
          type="button"
          onClick={onNext}
          aria-label="Next Track"
          className="tactile-btn"
          style={{
            width: 82,
            height: 46,
            borderRadius: 999,
            display: 'inline-flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: 'var(--text-primary)',
            position: 'relative',
          }}
        >
          <div
            style={{
              position: 'absolute',
              inset: 4,
              borderRadius: 999,
              border: `1px solid ${isDark ? 'rgba(255,255,255,0.05)' : 'rgba(148,160,184,0.18)'}`,
              pointerEvents: 'none',
            }}
          />
          <SkipNextIcon size={18} rtl={isRtl} />
        </button>
      </div>

      {/* Secondary Studio Switches: Shuffle · Favorite · Volume · EQ · Queue · Repeat */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          width: '86%',
          maxWidth: 304,
          paddingTop: 2,
        }}
      >
        <button
          type="button"
          onClick={onToggleShuffle}
          aria-label="Shuffle"
          style={microBtnStyle(shuffle)}
        >
          <ShuffleIcon size={16} />
        </button>

        <button
          type="button"
          onClick={onToggleFavorite}
          aria-label="Favorite"
          style={{
            ...microBtnStyle(isFavorite),
            color: isFavorite ? (isDark ? '#E79CA7' : '#B94A5A') : 'var(--text-secondary)',
          }}
        >
          <HeartIcon size={16} active={isFavorite} />
        </button>

        <button
          type="button"
          onClick={() => setShowVolumePopover((v) => !v)}
          aria-label="Volume"
          style={microBtnStyle(showVolumePopover)}
        >
          <VolumeIcon muted={volume === 0} size={16} />
        </button>

        <button
          type="button"
          onClick={onOpenEq}
          aria-label="Equalizer"
          style={microBtnStyle(false)}
        >
          <EqualizerIcon size={16} />
        </button>

        <button
          type="button"
          onClick={onOpenQueue}
          aria-label="Queue"
          style={microBtnStyle(false)}
        >
          <QueueListIcon size={16} />
        </button>

        <button
          type="button"
          onClick={onCycleRepeat}
          aria-label="Repeat"
          style={microBtnStyle(repeat !== 'off')}
        >
          <RepeatIcon mode={repeat} size={16} />
        </button>
      </div>
    </div>
  );
};
