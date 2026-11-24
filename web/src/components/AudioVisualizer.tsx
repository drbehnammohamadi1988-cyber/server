import React, { useEffect, useRef, useState } from 'react';
import { audioEngine } from '../audio/audioEngine';
import { AppTheme, SpectrumSnapshot } from '../types/music';

interface AudioVisualizerProps {
  isPlaying: boolean;
  currentTimeSec: number;
  durationSec: number;
  theme: AppTheme;
  reduceMotion: boolean;
  isVisible?: boolean;
  onSeek: (sec: number) => void;
}

export function formatClock(sec: number): string {
  if (!Number.isFinite(sec) || sec < 0) return '0:00';
  const total = Math.floor(sec);
  const mins = Math.floor(total / 60);
  const secs = total % 60;
  return `${mins}:${secs.toString().padStart(2, '0')}`;
}

export const AudioVisualizer: React.FC<AudioVisualizerProps> = ({
  isPlaying,
  currentTimeSec,
  durationSec,
  theme,
  reduceMotion,
  isVisible = true,
  onSeek,
}) => {
  const [spectrum, setSpectrum] = useState<SpectrumSnapshot>(() => ({
    bars: new Array(13).fill(0),
    bass: 0,
    mid: 0,
    treble: 0,
    rms: 0,
  }));

  const scrubberRef = useRef<HTMLDivElement>(null);
  const draggingRef = useRef(false);

  // Sample real Web Audio FFT spectrum on animation frame (pauses when offscreen/hidden)
  useEffect(() => {
    let rafId = 0;
    let active = true;

    const update = () => {
      if (!active) return;
      if (isVisible && !document.hidden) {
        const snap = audioEngine.sampleSpectrum();
        setSpectrum(snap);
      }
      rafId = requestAnimationFrame(update);
    };

    rafId = requestAnimationFrame(update);
    return () => {
      active = false;
      cancelAnimationFrame(rafId);
    };
  }, [isPlaying, isVisible]);

  const seekFromClientX = (clientX: number) => {
    const el = scrubberRef.current;
    if (!el || durationSec <= 0) return;
    const rect = el.getBoundingClientRect();
    const isRtl = getComputedStyle(el).direction === 'rtl';
    let ratio = (clientX - rect.left) / rect.width;
    if (isRtl) ratio = 1 - ratio;
    ratio = Math.max(0, Math.min(1, ratio));
    onSeek(ratio * durationSec);
  };

  const progressPct = durationSec > 0 ? Math.min(100, Math.max(0, (currentTimeSec / durationSec) * 100)) : 0;
  const isDark = theme === 'dark';

  // Symmetrical baseline silhouette heights (in px) matching reference soundwave crest
  const restHeights = [6, 9, 13, 19, 25, 30, 34, 30, 25, 19, 13, 9, 6];

  return (
    <div style={{ width: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10 }}>
      {/* Real FFT Frequency Bars (Bass at center, Mid flanking, Treble outer) */}
      <div
        aria-label="Live Audio Frequency Visualizer"
        style={{
          height: 44,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 4.5,
        }}
      >
        {spectrum.bars.map((val, idx) => {
          const rest = restHeights[idx] ?? 10;
          const activeVal = reduceMotion ? (isPlaying ? 0.35 : 0) : val;
          // At rest: slender serene crest (min 4px..14px); when playing: dynamic FFT amplitude
          const baseRest = rest * 0.44;
          const barHeight = Math.min(42, Math.max(4, baseRest + activeVal * rest * 1.18));
          const isCenterEnergy = idx >= 4 && idx <= 8;
          const opacity = 0.42 + activeVal * 0.58;

          return (
            <div
              key={idx}
              style={{
                width: 2.5,
                height: barHeight,
                borderRadius: 99,
                background: isCenterEnergy
                  ? isDark
                    ? `rgba(214, 224, 242, ${opacity})`
                    : `rgba(60, 68, 84, ${opacity})`
                  : isDark
                  ? `rgba(148, 162, 188, ${opacity * 0.9})`
                  : `rgba(128, 138, 158, ${opacity * 0.9})`,
                transition: 'height 65ms linear',
              }}
            />
          );
        })}
      </div>

      {/* Digital Clock Readout matching reference tabular digital counter */}
      <div
        className="tabular-mono"
        style={{
          fontSize: 13.5,
          fontWeight: 600,
          letterSpacing: '0.06em',
          color: 'var(--text-primary)',
          display: 'flex',
          alignItems: 'center',
          gap: 6,
          direction: 'ltr',
        }}
      >
        <span>{formatClock(currentTimeSec)}</span>
        <span style={{ color: 'var(--text-muted)' }}>/</span>
        <span style={{ color: 'var(--text-secondary)' }}>{formatClock(durationSec)}</span>
      </div>

      {/* Slim Recessed Interactive Progress Scrubber */}
      <div
        ref={scrubberRef}
        role="slider"
        aria-label="Playback Progress"
        aria-valuemin={0}
        aria-valuemax={Math.round(durationSec)}
        aria-valuenow={Math.round(currentTimeSec)}
        onPointerDown={(e) => {
          draggingRef.current = true;
          e.currentTarget.setPointerCapture(e.pointerId);
          seekFromClientX(e.clientX);
        }}
        onPointerMove={(e) => {
          if (draggingRef.current) seekFromClientX(e.clientX);
        }}
        onPointerUp={(e) => {
          draggingRef.current = false;
          try {
            e.currentTarget.releasePointerCapture(e.pointerId);
          } catch {
            // ignore
          }
        }}
        style={{
          width: '82%',
          maxWidth: 280,
          padding: '7px 0',
          cursor: 'pointer',
          touchAction: 'none',
        }}
      >
        <div
          style={{
            position: 'relative',
            height: 4,
            borderRadius: 99,
            background: isDark ? 'rgba(255,255,255,0.08)' : 'rgba(130, 142, 166, 0.22)',
            boxShadow: isDark
              ? 'inset 0 1px 2px rgba(0,0,0,0.75)'
              : 'inset 0 1px 2px rgba(130,142,166,0.3)',
          }}
        >
          <div
            style={{
              position: 'absolute',
              insetInlineStart: 0,
              top: 0,
              bottom: 0,
              width: `${progressPct}%`,
              borderRadius: 99,
              background: isDark
                ? 'linear-gradient(90deg, #7E8CA6, #D8E0EE)'
                : 'linear-gradient(90deg, #8A95AA, #252A34)',
            }}
          />
          <div
            style={{
              position: 'absolute',
              insetInlineStart: `${progressPct}%`,
              top: '50%',
              width: 12,
              height: 12,
              borderRadius: '50%',
              transform: 'translate(-50%, -50%)',
              background: isDark ? '#E4EAF6' : '#FFFFFF',
              border: `1.5px solid ${isDark ? '#58647A' : '#586274'}`,
              boxShadow: isDark
                ? '0 2px 6px rgba(0,0,0,0.75)'
                : '0 2px 6px rgba(60,70,90,0.28)',
            }}
          />
        </div>
      </div>
    </div>
  );
};
