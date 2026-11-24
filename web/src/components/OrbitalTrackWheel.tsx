import React, { useEffect, useRef, useState } from 'react';
import { AppTheme, Track } from '../types/music';

interface OrbitalTrackWheelProps {
  tracks: Track[];
  activeTrackId: string;
  isPlaying: boolean;
  isRtl: boolean;
  theme: AppTheme;
  reduceMotion: boolean;
  hapticsEnabled: boolean;
  playLabel: string;
  playingLabel: string;
  onSelectCenterTrack: (track: Track) => void;
  onPlayAndOpen: (track: Track, sourceRect: DOMRect | null) => void;
}

function clamp(v: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, v));
}

export const OrbitalTrackWheel: React.FC<OrbitalTrackWheelProps> = ({
  tracks,
  activeTrackId,
  isPlaying,
  isRtl,
  theme,
  reduceMotion,
  hapticsEnabled,
  playLabel,
  playingLabel,
  onSelectCenterTrack,
  onPlayAndOpen,
}) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const discRefs = useRef<Record<string, HTMLDivElement | null>>({});

  const initialIdx = Math.max(
    0,
    tracks.findIndex((t) => t.id === activeTrackId)
  );

  const [size, setSize] = useState({ w: 390, h: 560 });
  const [scrollPos, setScrollPos] = useState<number>(initialIdx);

  const physRef = useRef({
    pos: initialIdx,
    vel: 0,
    targetPos: null as number | null,
    isDragging: false,
    startY: 0,
    lastY: 0,
    lastTime: 0,
    totalMovedPx: 0,
    lastSnappedIdx: initialIdx,
    lastFrameTs: performance.now(),
  });

  const tracksRef = useRef(tracks);
  tracksRef.current = tracks;
  const hapticsRef = useRef(hapticsEnabled);
  hapticsRef.current = hapticsEnabled;
  const onSelectRef = useRef(onSelectCenterTrack);
  onSelectRef.current = onSelectCenterTrack;

  // Keep synced when activeTrackId changes externally (e.g., Next/Prev in MiniPlayer)
  useEffect(() => {
    const idx = tracks.findIndex((t) => t.id === activeTrackId);
    if (idx >= 0 && !physRef.current.isDragging && Math.abs(physRef.current.pos - idx) > 0.05) {
      if (reduceMotion) {
        physRef.current.pos = idx;
        physRef.current.vel = 0;
        physRef.current.targetPos = null;
        setScrollPos(idx);
      } else {
        physRef.current.targetPos = idx;
      }
      physRef.current.lastSnappedIdx = idx;
    }
  }, [activeTrackId, tracks, reduceMotion]);

  // Container dimensions observer
  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    const ro = new ResizeObserver((entries) => {
      const rect = entries[0]?.contentRect;
      if (rect && rect.width > 0 && rect.height > 0) {
        setSize({ w: rect.width, h: rect.height });
      }
    });
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  // Inertia, friction & critically-damped detent spring physics loop
  useEffect(() => {
    let rafId = 0;

    const tick = (now: number) => {
      const p = physRef.current;
      const dt = clamp((now - p.lastFrameTs) / 1000, 0.001, 0.05);
      p.lastFrameTs = now;

      const maxIdx = Math.max(0, tracksRef.current.length - 1);

      if (!p.isDragging) {
        if (p.targetPos !== null) {
          // Spring directly toward programmatically clicked / selected detent
          const diff = p.targetPos - p.pos;
          const springForce = diff * 125;
          const damping = -p.vel * 20;
          p.vel += (springForce + damping) * dt;
          p.pos += p.vel * dt;

          if (Math.abs(diff) < 0.002 && Math.abs(p.vel) < 0.01) {
            p.pos = p.targetPos;
            p.vel = 0;
            p.targetPos = null;
          }
        } else {
          // Inertial coast + exponential friction
          p.pos += p.vel * dt;
          p.vel *= Math.exp(-5.4 * dt);

          // Rubber-band boundary clamp
          if (p.pos < 0) {
            p.pos += (0 - p.pos) * clamp(dt * 18, 0, 1);
            p.vel *= 0.65;
          } else if (p.pos > maxIdx) {
            p.pos += (maxIdx - p.pos) * clamp(dt * 18, 0, 1);
            p.vel *= 0.65;
          }

          // Engage magnetic detent snap once velocity settles
          if (Math.abs(p.vel) < 1.35) {
            const nearest = clamp(Math.round(p.pos), 0, maxIdx);
            const diff = nearest - p.pos;
            p.vel += (diff * 110 - p.vel * 18) * dt;
            p.pos += p.vel * dt;

            if (Math.abs(diff) < 0.0015 && Math.abs(p.vel) < 0.008) {
              p.pos = nearest;
              p.vel = 0;
            }
          }
        }

        // Haptic tick & selection callback whenever crossing nearest detent
        const snapped = clamp(Math.round(p.pos), 0, maxIdx);
        if (snapped !== p.lastSnappedIdx) {
          p.lastSnappedIdx = snapped;
          if (hapticsRef.current && typeof navigator !== 'undefined' && navigator.vibrate) {
            navigator.vibrate(7);
          }
          const trk = tracksRef.current[snapped];
          if (trk) onSelectRef.current(trk);
        }

        setScrollPos(p.pos);
      }

      rafId = requestAnimationFrame(tick);
    };

    rafId = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(rafId);
  }, []);

  const stepPx = Math.max(82, size.h * 0.168);

  const handlePointerDown = (e: React.PointerEvent<HTMLDivElement>) => {
    // Allow direct button clicks inside active capsule without stealing event immediately
    const target = e.target as HTMLElement;
    if (target.closest('button[data-play-btn="true"]')) return;

    const p = physRef.current;
    p.isDragging = true;
    p.targetPos = null;
    p.vel = 0;
    p.startY = e.clientY;
    p.lastY = e.clientY;
    p.lastTime = performance.now();
    p.totalMovedPx = 0;
    try {
      e.currentTarget.setPointerCapture(e.pointerId);
    } catch {
      // ignore
    }
  };

  const handlePointerMove = (e: React.PointerEvent<HTMLDivElement>) => {
    const p = physRef.current;
    if (!p.isDragging) return;

    const now = performance.now();
    const dy = e.clientY - p.lastY;
    const dt = Math.max(0.004, (now - p.lastTime) / 1000);
    p.lastY = e.clientY;
    p.lastTime = now;
    p.totalMovedPx += Math.abs(dy);

    const maxIdx = Math.max(0, tracks.length - 1);
    const deltaIdx = -dy / stepPx;

    // Rubber-band resistance at ends
    const outOfBounds = (p.pos <= 0 && deltaIdx < 0) || (p.pos >= maxIdx && deltaIdx > 0);
    p.pos += outOfBounds ? deltaIdx * 0.32 : deltaIdx;
    const instantVel = (outOfBounds ? deltaIdx * 0.32 : deltaIdx) / dt;
    p.vel = p.vel * 0.45 + instantVel * 0.55;

    const snapped = clamp(Math.round(p.pos), 0, maxIdx);
    if (snapped !== p.lastSnappedIdx) {
      p.lastSnappedIdx = snapped;
      if (hapticsEnabled && typeof navigator !== 'undefined' && navigator.vibrate) {
        navigator.vibrate(7);
      }
      const trk = tracks[snapped];
      if (trk) onSelectCenterTrack(trk);
    }

    setScrollPos(p.pos);
  };

  const handlePointerUp = (e: React.PointerEvent<HTMLDivElement>) => {
    const p = physRef.current;
    if (!p.isDragging) return;
    p.isDragging = false;
    try {
      e.currentTarget.releasePointerCapture(e.pointerId);
    } catch {
      // ignore
    }
  };

  const handleWheel = (e: React.WheelEvent<HTMLDivElement>) => {
    const p = physRef.current;
    p.targetPos = null;
    p.vel = clamp(p.vel + e.deltaY * 0.018, -12, 12);
  };

  // Orbital geometry constants derived precisely from reference proportions
  const { w, h } = size;
  const hubX = isRtl ? -w * 0.06 : w * 1.06;
  const hubY = h * 0.49;
  const radius = w * 0.89;
  const anglePerItem = 0.275; // radians between neighboring pressings
  const centerDiscSize = Math.min(96, Math.max(80, w * 0.242));
  const isDark = theme === 'dark';

  return (
    <div
      ref={containerRef}
      onPointerDown={handlePointerDown}
      onPointerMove={handlePointerMove}
      onPointerUp={handlePointerUp}
      onPointerCancel={handlePointerUp}
      onWheel={handleWheel}
      style={{
        position: 'relative',
        width: '100%',
        height: '100%',
        overflow: 'hidden',
        touchAction: 'none',
        cursor: physRef.current.isDragging ? 'grabbing' : 'grab',
      }}
    >
      {tracks.map((track, idx) => {
        const d = idx - scrollPos;
        if (Math.abs(d) > 3.7) return null;

        const theta = d * anglePerItem;
        const arcX = isRtl ? hubX + radius * Math.cos(theta) : hubX - radius * Math.cos(theta);
        const arcY = hubY + radius * Math.sin(theta);

        const scale = clamp(1 - Math.abs(d) * 0.112, 0.58, 1);
        const opacity = clamp(1 - Math.pow(Math.abs(d), 1.25) * 0.195, 0, 1);
        const blurPx = reduceMotion ? 0 : Math.max(0, (Math.abs(d) - 0.85) * 0.72);

        // Text tilts radially along wheel spoke! (Above center tilts clockwise in LTR, below counter-clockwise)
        const tiltDeg = isRtl ? d * 9.5 : -d * 9.5;

        // White floating pill capsule dissolves smoothly away when off-center
        const capsuleFactor = clamp(1 - Math.abs(d) * 2.15, 0, 1);
        const isCentered = Math.abs(d) < 0.35;
        const discDiameter = centerDiscSize * scale;
        const discLeft = arcX - discDiameter / 2;
        const discTop = arcY - discDiameter / 2;

        // Capsule geometry wrapping the centered disc and extending horizontally toward edge
        const capsulePad = 7;
        const capsuleHeight = centerDiscSize + capsulePad * 2;
        const capsuleWidth = Math.min(w - 22, w * 0.855);
        const capsuleLeft = isRtl
          ? arcX + centerDiscSize / 2 + capsulePad - capsuleWidth
          : arcX - centerDiscSize / 2 - capsulePad;
        const capsuleTop = arcY - capsuleHeight / 2;

        const isCurrentTrackPlaying = isPlaying && track.id === activeTrackId;

        return (
          <React.Fragment key={track.id}>
            {/* White / Charcoal Soft-Neumorphic Active Capsule */}
            {capsuleFactor > 0.02 && (
              <div
                onClick={() => {
                  if (physRef.current.totalMovedPx > 8) return;
                  const rect = discRefs.current[track.id]?.getBoundingClientRect() ?? null;
                  onPlayAndOpen(track, rect);
                }}
                style={{
                  position: 'absolute',
                  left: capsuleLeft,
                  top: capsuleTop,
                  width: capsuleWidth,
                  height: capsuleHeight,
                  borderRadius: 999,
                  background: isDark
                    ? 'linear-gradient(145deg, rgba(32,37,48,0.96), rgba(22,26,34,0.98))'
                    : 'linear-gradient(145deg, #FFFFFF, #F7F8FC)',
                  border: `1px solid ${isDark ? 'rgba(255,255,255,0.09)' : 'rgba(255,255,255,0.98)'}`,
                  boxShadow: isDark
                    ? '0 20px 44px -10px rgba(0,0,0,0.75), inset 0 1px 0 rgba(255,255,255,0.08)'
                    : '0 18px 42px -10px rgba(128,142,168,0.28), 0 4px 12px rgba(128,142,168,0.10)',
                  opacity: capsuleFactor,
                  transform: `scale(${0.96 + capsuleFactor * 0.04})`,
                  zIndex: 8,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'flex-end',
                  paddingInlineStart: centerDiscSize + 24,
                  paddingInlineEnd: 16,
                  cursor: 'pointer',
                  pointerEvents: isCentered ? 'auto' : 'none',
                }}
              >
                <div style={{ flex: 1, minWidth: 0, paddingInlineEnd: 10 }}>
                  <div
                    style={{
                      fontSize: 16,
                      fontWeight: 700,
                      color: 'var(--text-primary)',
                      whiteSpace: 'nowrap',
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                      lineHeight: 1.25,
                    }}
                  >
                    {track.title}
                  </div>
                  <div
                    style={{
                      fontSize: 12.5,
                      fontWeight: 500,
                      color: 'var(--text-secondary)',
                      marginTop: 2,
                      whiteSpace: 'nowrap',
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                    }}
                  >
                    {track.artist}
                  </div>
                </div>

                <button
                  type="button"
                  data-play-btn="true"
                  onClick={(ev) => {
                    ev.stopPropagation();
                    const rect = discRefs.current[track.id]?.getBoundingClientRect() ?? null;
                    onPlayAndOpen(track, rect);
                  }}
                  className="tactile-pill"
                  style={{
                    height: 32,
                    padding: '0 15px',
                    borderRadius: 999,
                    fontSize: 12,
                    fontWeight: 600,
                    color: 'var(--text-primary)',
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: 5,
                    flexShrink: 0,
                  }}
                >
                  {isCurrentTrackPlaying ? playingLabel : playLabel}
                </button>
              </div>
            )}

            {/* Circular Vinyl Disc Cover */}
            <div
              ref={(el) => {
                discRefs.current[track.id] = el;
              }}
              onClick={() => {
                if (physRef.current.totalMovedPx > 8) return;
                if (isCentered) {
                  const rect = discRefs.current[track.id]?.getBoundingClientRect() ?? null;
                  onPlayAndOpen(track, rect);
                } else {
                  physRef.current.targetPos = idx;
                }
              }}
              style={{
                position: 'absolute',
                left: discLeft,
                top: discTop,
                width: discDiameter,
                height: discDiameter,
                borderRadius: '50%',
                opacity,
                filter: blurPx > 0.15 ? `blur(${blurPx.toFixed(2)}px)` : undefined,
                zIndex: Math.round(20 - Math.abs(d) * 3),
                boxShadow: isDark
                  ? '0 14px 28px -6px rgba(0,0,0,0.75), 0 0 0 1px rgba(255,255,255,0.08)'
                  : '0 14px 26px -6px rgba(26,32,46,0.22), 0 2px 6px rgba(26,32,46,0.10), 0 0 0 1.5px rgba(255,255,255,0.88)',
                overflow: 'hidden',
                cursor: 'pointer',
                transform: isCurrentTrackPlaying ? 'scale(1.02)' : undefined,
                transition: 'box-shadow 0.25s ease',
              }}
            >
              <img
                src={track.coverUrl}
                alt={track.title}
                draggable={false}
                style={{
                  width: '100%',
                  height: '100%',
                  objectFit: 'cover',
                  display: 'block',
                  animation: isCurrentTrackPlaying && !reduceMotion ? 'vinylSpinSlow 8s linear infinite' : undefined,
                }}
              />
              {/* Subtle glossy disc sheen */}
              <div
                style={{
                  position: 'absolute',
                  inset: 0,
                  borderRadius: '50%',
                  background:
                    'linear-gradient(135deg, rgba(255,255,255,0.22) 0%, rgba(255,255,255,0) 48%, rgba(0,0,0,0.16) 100%)',
                  pointerEvents: 'none',
                }}
              />
              {/* Precision disc center ring */}
              <div
                style={{
                  position: 'absolute',
                  left: '50%',
                  top: '50%',
                  width: Math.max(8, discDiameter * 0.12),
                  height: Math.max(8, discDiameter * 0.12),
                  borderRadius: '50%',
                  transform: 'translate(-50%, -50%)',
                  background: isDark ? 'rgba(18,21,28,0.86)' : 'rgba(244,246,250,0.9)',
                  border: '1px solid rgba(255,255,255,0.65)',
                  boxShadow: 'inset 0 1px 2px rgba(0,0,0,0.35)',
                  pointerEvents: 'none',
                }}
              />
            </div>

            {/* Tilted Peripheral Track Title & Artist (hidden smoothly once capsule takes over) */}
            {capsuleFactor < 0.85 && (
              <div
                onClick={() => {
                  if (physRef.current.totalMovedPx > 8) return;
                  physRef.current.targetPos = idx;
                }}
                style={{
                  position: 'absolute',
                  left: isRtl ? undefined : arcX + discDiameter / 2 + 16,
                  right: isRtl ? w - (arcX - discDiameter / 2 - 16) : undefined,
                  top: arcY - 22,
                  width: 170,
                  opacity: opacity * (1 - capsuleFactor),
                  filter: blurPx > 0.15 ? `blur(${blurPx.toFixed(2)}px)` : undefined,
                  transform: `rotate(${tiltDeg.toFixed(2)}deg) scale(${(0.76 + scale * 0.24).toFixed(3)})`,
                  transformOrigin: isRtl ? 'right center' : 'left center',
                  zIndex: Math.round(16 - Math.abs(d) * 3),
                  cursor: 'pointer',
                  pointerEvents: capsuleFactor > 0.45 ? 'none' : 'auto',
                }}
              >
                <div
                  style={{
                    fontSize: 15.5,
                    fontWeight: 600,
                    color: 'var(--text-primary)',
                    lineHeight: 1.25,
                    whiteSpace: 'nowrap',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                  }}
                >
                  {track.title}
                </div>
                <div
                  style={{
                    fontSize: 12,
                    fontWeight: 500,
                    color: 'var(--text-secondary)',
                    marginTop: 2,
                    whiteSpace: 'nowrap',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                  }}
                >
                  {track.artist}
                </div>
              </div>
            )}
          </React.Fragment>
        );
      })}
      <style>{`
        @keyframes vinylSpinSlow {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }
      `}</style>
    </div>
  );
};
