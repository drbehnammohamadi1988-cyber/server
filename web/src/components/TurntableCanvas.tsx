import React, { useEffect, useRef, useState } from 'react';
import { AppTheme, Track, TurntablePhase } from '../types/music';

interface TurntableCanvasProps {
  track: Track;
  isPlaying: boolean;
  currentTimeSec: number;
  durationSec: number;
  theme: AppTheme;
  reduceMotion: boolean;
  isVisible?: boolean;
  onTogglePlay: () => void;
  onSeek: (newTimeSec: number) => void;
  onScrubStateChange?: (scrubbing: boolean) => void;
  onPhaseChange?: (phase: TurntablePhase) => void;
}

const RPM_33_RAD_PER_SEC = (33.333333 / 60) * Math.PI * 2; // 3.49066 rad/s
const ARM_PARK_DEG = -2.5;
const ARM_OUTER_GROOVE_DEG = 19.5;
const ARM_INNER_GROOVE_DEG = 34.5;

function clamp(v: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, v));
}

function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

function createBrushedMetalPattern(theme: AppTheme): HTMLCanvasElement {
  const c = document.createElement('canvas');
  c.width = 256;
  c.height = 256;
  const ctx = c.getContext('2d');
  if (!ctx) return c;

  const base = theme === 'dark' ? '#1C2029' : '#EAECEF';
  ctx.fillStyle = base;
  ctx.fillRect(0, 0, 256, 256);

  // Subtle horizontal hairline brushed grain
  let seed = 42197;
  const rand = () => {
    seed = (seed * 1664525 + 1013904223) >>> 0;
    return seed / 0xffffffff;
  };

  for (let y = 0; y < 256; y++) {
    const streak = rand();
    if (theme === 'dark') {
      ctx.fillStyle = streak > 0.5 ? `rgba(255,255,255,${0.012 + streak * 0.018})` : `rgba(0,0,0,${0.04 + streak * 0.05})`;
    } else {
      ctx.fillStyle = streak > 0.5 ? `rgba(255,255,255,${0.14 + streak * 0.16})` : `rgba(148,158,176,${0.03 + streak * 0.045})`;
    }
    ctx.fillRect(0, y, 256, 1);
  }
  return c;
}

function drawRoundedRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  r: number
): void {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.quadraticCurveTo(x + w, y, x + w, y + r);
  ctx.lineTo(x + w, y + h - r);
  ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  ctx.lineTo(x + r, y + h);
  ctx.quadraticCurveTo(x, y + h, x, y + h - r);
  ctx.lineTo(x, y + r);
  ctx.quadraticCurveTo(x, y, x + r, y);
  ctx.closePath();
}

export const TurntableCanvas: React.FC<TurntableCanvasProps> = ({
  track,
  isPlaying,
  currentTimeSec,
  durationSec,
  theme,
  reduceMotion,
  isVisible = true,
  onTogglePlay,
  onSeek,
  onScrubStateChange,
  onPhaseChange,
}) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  // Physics state kept in mutable ref for 60/120fps jitter-free animation loop
  const physRef = useRef({
    discAngle: 0.42,
    angularVel: 0,
    armAngleDeg: isPlaying ? ARM_OUTER_GROOVE_DEG : ARM_PARK_DEG,
    cueZ: isPlaying ? 0 : 0, // 0 = seated/parked, 1 = lifted clear of vinyl
    phase: (isPlaying ? 'playing' : 'parked') as TurntablePhase,
    cueTimer: 0,
    swapProgress: 1, // 0..1 incoming pressing glide
    knobPress: 0,
    startBtnPress: 0,
    rpmMultiplier: 1, // 1 = 33⅓ RPM, 1.35 = 45 RPM pitch toggle via corner knob
    isScratching: false,
    scratchLastPointerAngle: 0,
    scratchVirtualTime: currentTimeSec,
    lastFrameTs: performance.now(),
  });

  const propsRef = useRef({
    isPlaying,
    currentTimeSec,
    durationSec,
    theme,
    reduceMotion,
    isVisible,
    track,
  });
  propsRef.current = { isPlaying, currentTimeSec, durationSec, theme, reduceMotion, isVisible, track };

  const coverImgRef = useRef<HTMLImageElement | null>(null);
  const prevCoverImgRef = useRef<HTMLImageElement | null>(null);
  const prevTrackIdRef = useRef<string>(track.id);
  const metalCanvasRef = useRef<HTMLCanvasElement | null>(null);
  const [size, setSize] = useState(320);

  // Rebuild brushed metal offscreen texture when theme changes
  useEffect(() => {
    metalCanvasRef.current = createBrushedMetalPattern(theme);
  }, [theme]);

  // Load cover art image & trigger smooth vinyl swap when track changes
  useEffect(() => {
    if (prevTrackIdRef.current !== track.id) {
      prevCoverImgRef.current = coverImgRef.current;
      physRef.current.swapProgress = reduceMotion ? 1 : 0;
      prevTrackIdRef.current = track.id;
    }

    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => {
      coverImgRef.current = img;
    };
    img.src = track.coverUrl;
  }, [track.id, track.coverUrl, reduceMotion]);

  // Responsive square deck sizing
  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    const ro = new ResizeObserver((entries) => {
      const w = entries[0]?.contentRect.width ?? 320;
      setSize(Math.max(220, Math.round(w)));
    });
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  // Main physics & high-DPI canvas render loop (pauses cleanly when offscreen or document hidden)
  useEffect(() => {
    let rafId = 0;
    let lastReportedPhase: TurntablePhase = physRef.current.phase;

    const renderFrame = (now: number) => {
      const {
        isPlaying: playing,
        currentTimeSec: timeSec,
        durationSec: durSec,
        theme: curTheme,
        reduceMotion: reduced,
        isVisible: visible,
      } = propsRef.current;

      if (!visible || document.hidden) {
        physRef.current.lastFrameTs = now;
        rafId = requestAnimationFrame(renderFrame);
        return;
      }

      const dt = clamp((now - physRef.current.lastFrameTs) / 1000, 0.001, 0.05);
      physRef.current.lastFrameTs = now;
      const p = physRef.current;

      const progress = durSec > 0 ? clamp((p.isScratching ? p.scratchVirtualTime : timeSec) / durSec, 0, 1) : 0;
      const targetTrackAngle = lerp(ARM_OUTER_GROOVE_DEG, ARM_INNER_GROOVE_DEG, progress);

      // Determine mechanical state machine
      if (p.isScratching) {
        p.phase = 'scratching';
        p.cueZ = lerp(p.cueZ, 0, clamp(dt * 14, 0, 1));
        p.armAngleDeg = lerp(p.armAngleDeg, targetTrackAngle, clamp(dt * 18, 0, 1));
      } else if (playing) {
        if (p.phase === 'parked' || p.phase === 'returning') {
          p.phase = 'cueing_in';
          p.cueTimer = 0;
        }
        if (p.phase === 'cueing_in') {
          p.cueTimer += dt;
          if (reduced) {
            p.armAngleDeg = targetTrackAngle;
            p.cueZ = 0;
            p.phase = 'playing';
          } else {
            // Stage 1 (0..0.2s): Lift tonearm off rest; Stage 2 (0.15..0.65s): Swing over groove; Stage 3 (0.65..0.95s): Drop stylus
            if (p.cueTimer < 0.2) {
              p.cueZ = lerp(p.cueZ, 1.0, clamp(dt * 14, 0, 1));
            } else if (p.cueTimer < 0.72) {
              p.cueZ = lerp(p.cueZ, 1.0, clamp(dt * 10, 0, 1));
              p.armAngleDeg = lerp(p.armAngleDeg, targetTrackAngle, clamp(dt * 7.5, 0, 1));
            } else if (p.cueTimer < 1.05) {
              p.armAngleDeg = lerp(p.armAngleDeg, targetTrackAngle, clamp(dt * 10, 0, 1));
              p.cueZ = lerp(p.cueZ, 0.0, clamp(dt * 9.5, 0, 1));
            } else {
              p.cueZ = 0;
              p.phase = 'playing';
            }
          }
        } else {
          p.phase = 'playing';
          p.cueZ = lerp(p.cueZ, 0, clamp(dt * 10, 0, 1));
          p.armAngleDeg = lerp(p.armAngleDeg, targetTrackAngle, clamp(dt * 10, 0, 1));
        }

        // Direct-drive motor spin-up to 33⅓ RPM
        const targetVel = reduced ? 0 : RPM_33_RAD_PER_SEC * p.rpmMultiplier;
        p.angularVel = lerp(p.angularVel, targetVel, clamp(dt * 3.1, 0, 1));
      } else {
        // Paused or Parked
        const atStartOrEnd = timeSec <= 0.1 || (durSec > 0 && timeSec >= durSec - 0.35);
        if (atStartOrEnd && Math.abs(p.armAngleDeg - ARM_PARK_DEG) > 0.6) {
          p.phase = 'returning';
          p.cueZ = lerp(p.cueZ, 1.0, clamp(dt * 10, 0, 1));
          if (p.cueZ > 0.45) {
            p.armAngleDeg = lerp(p.armAngleDeg, ARM_PARK_DEG, clamp(dt * 6.5, 0, 1));
          }
          if (Math.abs(p.armAngleDeg - ARM_PARK_DEG) <= 0.8) {
            p.armAngleDeg = ARM_PARK_DEG;
            p.phase = 'parked';
          }
        } else if (atStartOrEnd) {
          p.phase = 'parked';
          p.armAngleDeg = lerp(p.armAngleDeg, ARM_PARK_DEG, clamp(dt * 10, 0, 1));
          p.cueZ = lerp(p.cueZ, 0, clamp(dt * 8, 0, 1));
        } else {
          p.phase = 'paused_hover';
          p.cueZ = lerp(p.cueZ, 0.68, clamp(dt * 9, 0, 1));
          p.armAngleDeg = lerp(p.armAngleDeg, targetTrackAngle, clamp(dt * 8, 0, 1));
        }

        // Smooth platter brake inertia coast-down
        p.angularVel = lerp(p.angularVel, 0, clamp(dt * 2.4, 0, 1));
        if (p.angularVel < 0.008) p.angularVel = 0;
      }

      if (!p.isScratching) {
        p.discAngle = (p.discAngle + p.angularVel * dt) % (Math.PI * 2);
      }

      if (p.swapProgress < 1) {
        p.swapProgress = Math.min(1, p.swapProgress + dt * 2.6);
      }
      p.knobPress = lerp(p.knobPress, 0, clamp(dt * 12, 0, 1));
      p.startBtnPress = lerp(p.startBtnPress, 0, clamp(dt * 12, 0, 1));

      if (p.phase !== lastReportedPhase) {
        lastReportedPhase = p.phase;
        onPhaseChange?.(p.phase);
      }

      // Draw hardware layers
      const canvas = canvasRef.current;
      if (canvas) {
        const dpr = Math.min(window.devicePixelRatio || 1, 2.5);
        const w = size;
        const h = Math.round(size * 0.94);
        if (canvas.width !== Math.round(w * dpr) || canvas.height !== Math.round(h * dpr)) {
          canvas.width = Math.round(w * dpr);
          canvas.height = Math.round(h * dpr);
        }
        const ctx = canvas.getContext('2d');
        if (ctx) {
          ctx.save();
          ctx.scale(dpr, dpr);
          drawTurntableScene(ctx, w, h, curTheme, p, coverImgRef.current, prevCoverImgRef.current, metalCanvasRef.current);
          ctx.restore();
        }
      }

      rafId = requestAnimationFrame(renderFrame);
    };

    rafId = requestAnimationFrame(renderFrame);
    return () => cancelAnimationFrame(rafId);
  }, [size, onPhaseChange]);

  // Interactive geometry hit-testing (Vinyl scratch, Bottom-left rotary knob, Bottom-right Start/Stop button)
  const getLayoutMetrics = (w: number) => {
    const h = Math.round(w * 0.94);
    const pad = w * 0.028;
    const deckW = w - pad * 2;
    const deckH = h - pad * 2.2;
    const platterCx = pad + deckW * 0.44;
    const platterCy = pad * 1.4 + deckH * 0.51;
    const vinylRadius = deckH * 0.405;
    const knobCx = pad + deckW * 0.115;
    const knobCy = pad * 1.4 + deckH * 0.87;
    const knobR = deckW * 0.072;
    const btnCx = pad + deckW * 0.885;
    const btnCy = pad * 1.4 + deckH * 0.87;
    const btnR = deckW * 0.068;
    return { platterCx, platterCy, vinylRadius, knobCx, knobCy, knobR, btnCx, btnCy, btnR };
  };

  const handlePointerDown = (e: React.PointerEvent<HTMLCanvasElement>) => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    const m = getLayoutMetrics(rect.width);

    // 1. Check bottom-right start/stop physical button
    if (Math.hypot(x - m.btnCx, y - m.btnCy) <= m.btnR * 1.35) {
      physRef.current.startBtnPress = 1;
      onTogglePlay();
      return;
    }

    // 2. Check bottom-left rotary knob (toggles 33⅓ vs 45 RPM speed feel)
    if (Math.hypot(x - m.knobCx, y - m.knobCy) <= m.knobR * 1.35) {
      physRef.current.knobPress = 1;
      physRef.current.rpmMultiplier = physRef.current.rpmMultiplier === 1 ? 1.35 : 1;
      return;
    }

    // 3. Check vinyl platter touch for rotary scratching / seeking
    const dist = Math.hypot(x - m.platterCx, y - m.platterCy);
    if (dist <= m.vinylRadius * 1.04 && dist >= m.vinylRadius * 0.12) {
      canvas.setPointerCapture(e.pointerId);
      const ptrAngle = Math.atan2(y - m.platterCy, x - m.platterCx);
      physRef.current.isScratching = true;
      physRef.current.scratchLastPointerAngle = ptrAngle;
      physRef.current.scratchVirtualTime = propsRef.current.currentTimeSec;
      onScrubStateChange?.(true);
    }
  };

  const handlePointerMove = (e: React.PointerEvent<HTMLCanvasElement>) => {
    if (!physRef.current.isScratching) return;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    const m = getLayoutMetrics(rect.width);

    const ptrAngle = Math.atan2(y - m.platterCy, x - m.platterCx);
    let delta = ptrAngle - physRef.current.scratchLastPointerAngle;
    while (delta > Math.PI) delta -= Math.PI * 2;
    while (delta < -Math.PI) delta += Math.PI * 2;

    physRef.current.scratchLastPointerAngle = ptrAngle;
    physRef.current.discAngle = (physRef.current.discAngle + delta) % (Math.PI * 2);

    // 1 full clockwise revolution = +10 seconds scrub (scaled cleanly)
    const secPerRad = 10 / (Math.PI * 2);
    const dur = Math.max(1, propsRef.current.durationSec);
    physRef.current.scratchVirtualTime = clamp(
      physRef.current.scratchVirtualTime + delta * secPerRad,
      0,
      dur - 0.25
    );
    onSeek(physRef.current.scratchVirtualTime);
  };

  const handlePointerUp = (e: React.PointerEvent<HTMLCanvasElement>) => {
    if (!physRef.current.isScratching) return;
    try {
      canvasRef.current?.releasePointerCapture(e.pointerId);
    } catch {
      // ignore
    }
    physRef.current.isScratching = false;
    onScrubStateChange?.(false);
  };

  return (
    <div
      ref={containerRef}
      style={{
        width: '100%',
        maxWidth: 348,
        margin: '0 auto',
        position: 'relative',
        touchAction: 'none',
      }}
    >
      <canvas
        ref={canvasRef}
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
        onPointerUp={handlePointerUp}
        onPointerCancel={handlePointerUp}
        style={{
          width: size,
          height: Math.round(size * 0.94),
          display: 'block',
          cursor: 'grab',
        }}
        aria-label={`Turntable deck playing ${track.title} by ${track.artist}`}
      />
    </div>
  );
};

function drawTurntableScene(
  ctx: CanvasRenderingContext2D,
  w: number,
  h: number,
  theme: AppTheme,
  p: {
    discAngle: number;
    angularVel: number;
    armAngleDeg: number;
    cueZ: number;
    swapProgress: number;
    knobPress: number;
    startBtnPress: number;
    rpmMultiplier: number;
    phase: TurntablePhase;
  },
  coverImg: HTMLImageElement | null,
  prevCoverImg: HTMLImageElement | null,
  metalCanvas: HTMLCanvasElement | null
): void {
  ctx.clearRect(0, 0, w, h);

  const isDark = theme === 'dark';
  const pad = w * 0.028;
  const topOffset = pad * 1.45;
  const deckW = w - pad * 2;
  const deckH = h - topOffset - pad * 0.9;
  const rx = deckW * 0.045;

  // 1. Top-edge metallic hinge pins (exact architectural detail from reference!)
  const hingeW = deckW * 0.052;
  const hingeH = topOffset * 0.95;
  const hingePositions = [pad + deckW * 0.43, pad + deckW * 0.56];
  for (const hx of hingePositions) {
    const hg = ctx.createLinearGradient(hx, 0, hx + hingeW, 0);
    if (isDark) {
      hg.addColorStop(0, '#5A6170');
      hg.addColorStop(0.35, '#9BA3B4');
      hg.addColorStop(0.7, '#3D424E');
      hg.addColorStop(1, '#262A34');
    } else {
      hg.addColorStop(0, '#A58E63');
      hg.addColorStop(0.35, '#DFCA9A');
      hg.addColorStop(0.7, '#99825A');
      hg.addColorStop(1, '#6C5A3C');
    }
    ctx.fillStyle = hg;
    drawRoundedRect(ctx, hx, topOffset - hingeH * 0.85, hingeW, hingeH, 2.5);
    ctx.fill();
  }

  // 2. Plinth outer studio drop shadow
  ctx.save();
  ctx.shadowColor = isDark ? 'rgba(0,0,0,0.78)' : 'rgba(130, 142, 168, 0.34)';
  ctx.shadowBlur = w * 0.065;
  ctx.shadowOffsetX = w * 0.012;
  ctx.shadowOffsetY = w * 0.028;
  drawRoundedRect(ctx, pad, topOffset, deckW, deckH, rx);
  ctx.fillStyle = isDark ? '#1A1E27' : '#ECEEF3';
  ctx.fill();
  ctx.restore();

  // 3. Brushed anodized metal chassis surface
  ctx.save();
  drawRoundedRect(ctx, pad, topOffset, deckW, deckH, rx);
  ctx.clip();

  if (metalCanvas) {
    const pat = ctx.createPattern(metalCanvas, 'repeat');
    if (pat) {
      ctx.fillStyle = pat;
      ctx.fillRect(pad, topOffset, deckW, deckH);
    }
  } else {
    ctx.fillStyle = isDark ? '#1A1E27' : '#ECEEF3';
    ctx.fillRect(pad, topOffset, deckW, deckH);
  }

  // Directional studio light gradient across chassis (top-left bright -> bottom-right soft)
  const sheenGrad = ctx.createLinearGradient(pad, topOffset, pad + deckW, topOffset + deckH);
  if (isDark) {
    sheenGrad.addColorStop(0, 'rgba(255,255,255,0.06)');
    sheenGrad.addColorStop(0.45, 'rgba(255,255,255,0.01)');
    sheenGrad.addColorStop(1, 'rgba(0,0,0,0.22)');
  } else {
    sheenGrad.addColorStop(0, 'rgba(255,255,255,0.52)');
    sheenGrad.addColorStop(0.48, 'rgba(255,255,255,0.08)');
    sheenGrad.addColorStop(1, 'rgba(165,176,198,0.20)');
  }
  ctx.fillStyle = sheenGrad;
  ctx.fillRect(pad, topOffset, deckW, deckH);

  // Subtle recessed inner deck border groove
  drawRoundedRect(ctx, pad + 3.5, topOffset + 3.5, deckW - 7, deckH - 7, rx * 0.82);
  ctx.strokeStyle = isDark ? 'rgba(255,255,255,0.05)' : 'rgba(255,255,255,0.82)';
  ctx.lineWidth = 1.2;
  ctx.stroke();

  drawRoundedRect(ctx, pad + 1.5, topOffset + 1.5, deckW - 3, deckH - 3, rx * 0.92);
  ctx.strokeStyle = isDark ? 'rgba(0,0,0,0.65)' : 'rgba(148,160,184,0.26)';
  ctx.lineWidth = 1;
  ctx.stroke();
  ctx.restore();

  // Outer chamfer highlight
  drawRoundedRect(ctx, pad, topOffset, deckW, deckH, rx);
  ctx.strokeStyle = isDark ? 'rgba(255,255,255,0.08)' : 'rgba(255,255,255,0.92)';
  ctx.lineWidth = 1;
  ctx.stroke();

  // 4. Precision micro corner fasteners + engraved LP-01 badge
  const screwInset = deckW * 0.048;
  const screws = [
    [pad + screwInset, topOffset + screwInset],
    [pad + deckW - screwInset, topOffset + screwInset],
    [pad + screwInset, topOffset + deckH - screwInset],
    [pad + deckW - screwInset, topOffset + deckH - screwInset],
  ];
  for (const [sx, sy] of screws) {
    ctx.beginPath();
    ctx.arc(sx, sy, 2.2, 0, Math.PI * 2);
    ctx.fillStyle = isDark ? '#0D0F14' : '#C6CCD8';
    ctx.fill();
    ctx.beginPath();
    ctx.arc(sx - 0.5, sy - 0.5, 1.5, 0, Math.PI * 2);
    ctx.fillStyle = isDark ? '#323846' : '#FAFBFD';
    ctx.fill();
  }

  // Subtle model mark top-left
  ctx.fillStyle = isDark ? 'rgba(255,255,255,0.22)' : 'rgba(110,120,140,0.38)';
  ctx.font = `600 ${Math.round(deckW * 0.026)}px "JetBrains Mono", monospace`;
  ctx.fillText(p.rpmMultiplier > 1.1 ? 'LP-01 · 45' : 'LP-01 · 33⅓', pad + deckW * 0.078, topOffset + deckH * 0.075);

  // 5. Recessed Platter Well
  const platterCx = pad + deckW * 0.44;
  const platterCy = topOffset + deckH * 0.51;
  const vinylR = deckH * 0.405;
  const platterR = vinylR * 1.045;

  // Platter recessed cavity shadow
  ctx.beginPath();
  ctx.arc(platterCx, platterCy, platterR, 0, Math.PI * 2);
  ctx.fillStyle = isDark ? '#101319' : '#DEE2EA';
  ctx.fill();

  const wellShadow = ctx.createRadialGradient(
    platterCx,
    platterCy,
    vinylR * 0.9,
    platterCx,
    platterCy,
    platterR
  );
  wellShadow.addColorStop(0, isDark ? 'rgba(0,0,0,0.85)' : 'rgba(130,142,168,0.32)');
  wellShadow.addColorStop(1, isDark ? 'rgba(255,255,255,0.06)' : 'rgba(255,255,255,0.8)');
  ctx.strokeStyle = wellShadow;
  ctx.lineWidth = 2.5;
  ctx.stroke();

  // Machined aluminum platter rim + subtle strobe ticks
  ctx.save();
  ctx.translate(platterCx, platterCy);
  ctx.rotate(p.discAngle);
  const strobeCount = 72;
  for (let i = 0; i < strobeCount; i++) {
    const a = (i / strobeCount) * Math.PI * 2;
    const r0 = vinylR * 1.012;
    const r1 = vinylR * 1.032;
    ctx.beginPath();
    ctx.moveTo(Math.cos(a) * r0, Math.sin(a) * r0);
    ctx.lineTo(Math.cos(a) * r1, Math.sin(a) * r1);
    ctx.strokeStyle = isDark ? 'rgba(210,220,240,0.16)' : 'rgba(115,126,148,0.28)';
    ctx.lineWidth = 1.1;
    ctx.stroke();
  }
  ctx.restore();

  // 6. Vinyl Record Disc (supports swap transition!)
  const drawVinylDisc = (
    angleRad: number,
    img: HTMLImageElement | null,
    alpha: number,
    offsetX: number,
    scaleFactor: number
  ) => {
    if (alpha <= 0.01) return;
    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.translate(platterCx + offsetX, platterCy);
    ctx.scale(scaleFactor, scaleFactor);

    // Disc contact drop shadow onto aluminum platter
    ctx.save();
    ctx.shadowColor = isDark ? 'rgba(0,0,0,0.92)' : 'rgba(18,22,32,0.34)';
    ctx.shadowBlur = vinylR * 0.14;
    ctx.shadowOffsetX = 3;
    ctx.shadowOffsetY = 6;
    ctx.beginPath();
    ctx.arc(0, 0, vinylR, 0, Math.PI * 2);
    ctx.fillStyle = '#090A0D';
    ctx.fill();
    ctx.restore();

    // Clip to vinyl outer circumference
    ctx.save();
    ctx.beginPath();
    ctx.arc(0, 0, vinylR, 0, Math.PI * 2);
    ctx.clip();

    // Base rich obsidian vinyl body
    const baseGrad = ctx.createRadialGradient(-vinylR * 0.25, -vinylR * 0.25, vinylR * 0.1, 0, 0, vinylR);
    baseGrad.addColorStop(0, '#1B1E26');
    baseGrad.addColorStop(0.5, '#0B0C10');
    baseGrad.addColorStop(1, '#060709');
    ctx.fillStyle = baseGrad;
    ctx.fillRect(-vinylR, -vinylR, vinylR * 2, vinylR * 2);

    // Fine concentric micro-grooves + track separation dead-bands
    const labelR = vinylR * 0.345;
    const grooveStart = vinylR * 0.39;
    const grooveEnd = vinylR * 0.965;
    const grooveSteps = 84;
    for (let i = 0; i < grooveSteps; i++) {
      const t = i / grooveSteps;
      const r = lerp(grooveStart, grooveEnd, t);
      const isBandGap = i === 24 || i === 52 || i === 74;
      ctx.beginPath();
      ctx.arc(0, 0, r, 0, Math.PI * 2);
      ctx.strokeStyle = isBandGap
        ? 'rgba(255,255,255,0.09)'
        : i % 3 === 0
        ? 'rgba(255,255,255,0.036)'
        : 'rgba(0,0,0,0.55)';
      ctx.lineWidth = isBandGap ? 1.4 : 0.65;
      ctx.stroke();
    }

    // Rotating radial groove shimmer (subtle angular micro-variations that spin with vinyl!)
    ctx.save();
    ctx.rotate(angleRad);
    for (let s = 0; s < 16; s++) {
      const a = (s / 16) * Math.PI * 2;
      const arcSpan = 0.08 + (s % 3) * 0.04;
      ctx.beginPath();
      ctx.arc(0, 0, vinylR * (0.52 + (s % 5) * 0.08), a, a + arcSpan);
      ctx.strokeStyle = 'rgba(255,255,255,0.045)';
      ctx.lineWidth = 1.2;
      ctx.stroke();
    }
    ctx.restore();

    // STATIONARY Fixed-Light Anisotropic Conical Specular Bow-Tie Sheen
    // (Light source stays fixed at top-left ~42deg regardless of disc rotation!)
    const lightAngles = [-Math.PI * 0.24, Math.PI * 0.76];
    for (const la of lightAngles) {
      ctx.save();
      ctx.rotate(la);
      const coneGrad = ctx.createLinearGradient(0, -vinylR * 0.42, vinylR, vinylR * 0.42);
      coneGrad.addColorStop(0, 'rgba(255,255,255,0)');
      coneGrad.addColorStop(0.42, isDark ? 'rgba(220,232,255,0.06)' : 'rgba(255,255,255,0.11)');
      coneGrad.addColorStop(0.5, isDark ? 'rgba(235,242,255,0.22)' : 'rgba(255,255,255,0.28)');
      coneGrad.addColorStop(0.58, isDark ? 'rgba(220,232,255,0.06)' : 'rgba(255,255,255,0.11)');
      coneGrad.addColorStop(1, 'rgba(255,255,255,0)');

      ctx.beginPath();
      ctx.moveTo(0, 0);
      ctx.arc(0, 0, vinylR * 0.99, -0.34, 0.34);
      ctx.closePath();
      ctx.fillStyle = coneGrad;
      ctx.fill();

      // Secondary crisp specular highlight ribbon
      ctx.beginPath();
      ctx.moveTo(0, 0);
      ctx.arc(0, 0, vinylR * 0.97, -0.09, 0.09);
      ctx.closePath();
      ctx.fillStyle = isDark ? 'rgba(255,255,255,0.09)' : 'rgba(255,255,255,0.14)';
      ctx.fill();
      ctx.restore();
    }

    // Outer vinyl rim edge specular ring
    ctx.beginPath();
    ctx.arc(0, 0, vinylR - 0.8, 0, Math.PI * 2);
    ctx.strokeStyle = 'rgba(255,255,255,0.16)';
    ctx.lineWidth = 1.2;
    ctx.stroke();

    // Rotating Center Label + Album Cover Artwork
    ctx.save();
    ctx.rotate(angleRad);

    // Paper ring border around cover art
    ctx.beginPath();
    ctx.arc(0, 0, labelR, 0, Math.PI * 2);
    ctx.fillStyle = '#EAECEF';
    ctx.fill();

    ctx.save();
    ctx.beginPath();
    ctx.arc(0, 0, labelR * 0.93, 0, Math.PI * 2);
    ctx.clip();
    if (img && img.complete && img.naturalWidth > 0) {
      ctx.drawImage(img, -labelR * 0.93, -labelR * 0.93, labelR * 1.86, labelR * 1.86);
    } else {
      ctx.fillStyle = '#E6E8EE';
      ctx.fillRect(-labelR, -labelR, labelR * 2, labelR * 2);
    }
    ctx.restore();

    // Subtle concentric press indentation ring on paper label
    ctx.beginPath();
    ctx.arc(0, 0, labelR * 0.42, 0, Math.PI * 2);
    ctx.strokeStyle = 'rgba(20, 24, 34, 0.14)';
    ctx.lineWidth = 1;
    ctx.stroke();

    ctx.restore(); // end label rotation

    // Fixed-light soft glaze over label
    const labelSheen = ctx.createLinearGradient(-labelR, -labelR, labelR, labelR);
    labelSheen.addColorStop(0, 'rgba(255,255,255,0.14)');
    labelSheen.addColorStop(0.5, 'rgba(255,255,255,0)');
    labelSheen.addColorStop(1, 'rgba(0,0,0,0.08)');
    ctx.beginPath();
    ctx.arc(0, 0, labelR, 0, Math.PI * 2);
    ctx.fillStyle = labelSheen;
    ctx.fill();

    // Machined brushed-steel center spindle pin + directional shadow
    const spindleR = vinylR * 0.052;
    ctx.beginPath();
    ctx.arc(1.5, 2, spindleR * 1.15, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(0,0,0,0.36)';
    ctx.fill();

    const spGrad = ctx.createRadialGradient(-spindleR * 0.35, -spindleR * 0.35, 0.5, 0, 0, spindleR);
    spGrad.addColorStop(0, '#FFFFFF');
    spGrad.addColorStop(0.55, '#B7BECB');
    spGrad.addColorStop(1, '#5B6270');
    ctx.beginPath();
    ctx.arc(0, 0, spindleR, 0, Math.PI * 2);
    ctx.fillStyle = spGrad;
    ctx.fill();

    ctx.restore(); // end vinyl clip
    ctx.restore(); // end alpha/transform
  };

  if (p.swapProgress < 1 && prevCoverImg) {
    const outEase = p.swapProgress;
    drawVinylDisc(
      p.discAngle - outEase * 0.4,
      prevCoverImg,
      1 - outEase,
      -outEase * deckW * 0.16,
      1 - outEase * 0.06
    );
    const inEase = 1 - Math.pow(1 - p.swapProgress, 3);
    drawVinylDisc(
      p.discAngle,
      coverImg,
      inEase,
      (1 - inEase) * deckW * 0.14,
      0.94 + inEase * 0.06
    );
  } else {
    drawVinylDisc(p.discAngle, coverImg, 1, 0, 1);
  }

  // 7. Bottom-Left Rotary Knob (with 3-spoke / Y selector matching reference)
  const knobCx = pad + deckW * 0.115;
  const knobCy = topOffset + deckH * 0.87;
  const knobR = deckW * 0.072 * (1 - p.knobPress * 0.05);

  ctx.save();
  ctx.shadowColor = isDark ? 'rgba(0,0,0,0.72)' : 'rgba(140,152,175,0.42)';
  ctx.shadowBlur = 10 - p.knobPress * 5;
  ctx.shadowOffsetX = 3;
  ctx.shadowOffsetY = 5 - p.knobPress * 3;
  ctx.beginPath();
  ctx.arc(knobCx, knobCy, knobR, 0, Math.PI * 2);
  const knobGrad = ctx.createLinearGradient(knobCx - knobR, knobCy - knobR, knobCx + knobR, knobCy + knobR);
  if (isDark) {
    knobGrad.addColorStop(0, '#2C313E');
    knobGrad.addColorStop(1, '#161922');
  } else {
    knobGrad.addColorStop(0, '#F7F8FB');
    knobGrad.addColorStop(1, '#DDE1EA');
  }
  ctx.fillStyle = knobGrad;
  ctx.fill();
  ctx.restore();

  ctx.beginPath();
  ctx.arc(knobCx, knobCy, knobR, 0, Math.PI * 2);
  ctx.strokeStyle = isDark ? 'rgba(255,255,255,0.10)' : 'rgba(255,255,255,0.92)';
  ctx.lineWidth = 1.2;
  ctx.stroke();

  // Inner concentric groove & Y-spoke selector lines matching reference knob
  ctx.beginPath();
  ctx.arc(knobCx, knobCy, knobR * 0.72, 0, Math.PI * 2);
  ctx.strokeStyle = isDark ? 'rgba(0,0,0,0.5)' : 'rgba(130,142,168,0.28)';
  ctx.lineWidth = 1;
  ctx.stroke();

  const knobRot = p.rpmMultiplier > 1.1 ? 0.45 : 0;
  ctx.save();
  ctx.translate(knobCx, knobCy);
  ctx.rotate(knobRot);
  for (const ang of [-Math.PI / 2, Math.PI / 6, (Math.PI * 5) / 6]) {
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(Math.cos(ang) * knobR * 0.72, Math.sin(ang) * knobR * 0.72);
    ctx.strokeStyle = isDark ? 'rgba(210,220,238,0.42)' : 'rgba(105,115,136,0.52)';
    ctx.lineWidth = 1.2;
    ctx.stroke();
  }
  ctx.restore();

  // 8. Bottom-Right Circular Start/Stop Tactile Button
  const btnCx = pad + deckW * 0.885;
  const btnCy = topOffset + deckH * 0.87;
  const btnR = deckW * 0.068 * (1 - p.startBtnPress * 0.06);

  ctx.save();
  ctx.shadowColor = isDark ? 'rgba(0,0,0,0.72)' : 'rgba(140,152,175,0.38)';
  ctx.shadowBlur = 9 - p.startBtnPress * 5;
  ctx.shadowOffsetX = 2.5;
  ctx.shadowOffsetY = 4 - p.startBtnPress * 2.5;
  ctx.beginPath();
  ctx.arc(btnCx, btnCy, btnR, 0, Math.PI * 2);
  const btnGrad = ctx.createLinearGradient(btnCx - btnR, btnCy - btnR, btnCx + btnR, btnCy + btnR);
  if (isDark) {
    btnGrad.addColorStop(0, '#292E3A');
    btnGrad.addColorStop(1, '#14171F');
  } else {
    btnGrad.addColorStop(0, '#F8F9FC');
    btnGrad.addColorStop(1, '#DFE3EC');
  }
  ctx.fillStyle = btnGrad;
  ctx.fill();
  ctx.restore();

  ctx.beginPath();
  ctx.arc(btnCx, btnCy, btnR * 0.84, 0, Math.PI * 2);
  ctx.strokeStyle =
    p.phase === 'playing' || p.phase === 'cueing_in'
      ? isDark
        ? 'rgba(210, 224, 245, 0.52)'
        : 'rgba(65, 76, 98, 0.42)'
      : isDark
      ? 'rgba(255,255,255,0.08)'
      : 'rgba(130,142,168,0.28)';
  ctx.lineWidth = 1.2;
  ctx.stroke();

  // 9. Independent Mechanical Tonearm & Gimbal Assembly (Top-Right)
  const pivotX = pad + deckW * 0.875;
  const pivotY = topOffset + deckH * 0.168;
  const armBaseR = deckW * 0.088;

  // Tonearm armrest clip positioned beside outer platter rim
  const restX = pad + deckW * 0.885;
  const restY = topOffset + deckH * 0.48;
  ctx.save();
  ctx.fillStyle = isDark ? '#2D323E' : '#8D95A5';
  drawRoundedRect(ctx, restX - 4, restY - 8, 8, 16, 3);
  ctx.fill();
  ctx.restore();

  // Recessed gimbal mounting well
  ctx.beginPath();
  ctx.arc(pivotX, pivotY, armBaseR, 0, Math.PI * 2);
  ctx.fillStyle = isDark ? '#12151C' : '#D9DDE7';
  ctx.fill();
  ctx.strokeStyle = isDark ? 'rgba(255,255,255,0.08)' : 'rgba(255,255,255,0.9)';
  ctx.lineWidth = 1.2;
  ctx.stroke();

  // Gimbal metallic ring
  const gimbalGrad = ctx.createRadialGradient(pivotX - armBaseR * 0.3, pivotY - armBaseR * 0.3, 2, pivotX, pivotY, armBaseR * 0.78);
  if (isDark) {
    gimbalGrad.addColorStop(0, '#4C5364');
    gimbalGrad.addColorStop(0.65, '#252A34');
    gimbalGrad.addColorStop(1, '#14171E');
  } else {
    gimbalGrad.addColorStop(0, '#FFFFFF');
    gimbalGrad.addColorStop(0.6, '#D6DBE5');
    gimbalGrad.addColorStop(1, '#A5AEBF');
  }
  ctx.beginPath();
  ctx.arc(pivotX, pivotY, armBaseR * 0.78, 0, Math.PI * 2);
  ctx.fillStyle = gimbalGrad;
  ctx.fill();

  // Rotating tonearm wand + counterweight + headshell + stylus + dynamic 3D elevation shadow
  const armLen = deckH * 0.56;
  const armRad = (p.armAngleDeg * Math.PI) / 180;
  const liftScale = 1 + p.cueZ * 0.032;
  const shadowDist = 5 + p.cueZ * 10;
  const shadowBlur = 6 + p.cueZ * 10;

  const drawTonearmGeometry = (isShadowPass: boolean) => {
    ctx.save();
    ctx.translate(
      pivotX + (isShadowPass ? shadowDist : 0),
      pivotY + (isShadowPass ? shadowDist * 1.15 : 0)
    );
    ctx.rotate(armRad);
    if (!isShadowPass) {
      ctx.scale(liftScale, liftScale);
    }

    const colorMain = isShadowPass
      ? isDark
        ? 'rgba(0,0,0,0.58)'
        : 'rgba(28,34,48,0.24)'
      : isDark
      ? '#AEB7C9'
      : '#262A34';

    // Counterweight barrel (extends upward behind pivot!)
    const cwW = deckW * 0.056;
    const cwH = deckH * 0.115;
    if (isShadowPass) {
      ctx.fillStyle = colorMain;
      drawRoundedRect(ctx, -cwW / 2, -cwH * 0.85, cwW, cwH, 3);
      ctx.fill();
    } else {
      const cwGrad = ctx.createLinearGradient(-cwW / 2, 0, cwW / 2, 0);
      cwGrad.addColorStop(0, '#4E5462');
      cwGrad.addColorStop(0.35, '#EDF0F6');
      cwGrad.addColorStop(0.7, '#7A8294');
      cwGrad.addColorStop(1, '#2D313B');
      ctx.fillStyle = cwGrad;
      drawRoundedRect(ctx, -cwW / 2, -cwH * 0.85, cwW, cwH, 3);
      ctx.fill();

      // Dark knurled top end-cap
      ctx.fillStyle = '#17191F';
      drawRoundedRect(ctx, -cwW * 0.44, -cwH * 0.88, cwW * 0.88, cwH * 0.2, 2);
      ctx.fill();
    }

    // Precision tonearm straight/gently-cranked metallic tube
    const tubeTopW = deckW * 0.018;
    const tubeTipY = armLen * 0.84;
    const headshellEndY = armLen;
    const headshellOffsetX = -deckW * 0.048; // Angled inward tracking offset (classic Baerwald geometry!)

    ctx.beginPath();
    ctx.moveTo(-tubeTopW / 2, 0);
    ctx.lineTo(tubeTopW / 2, 0);
    ctx.lineTo(tubeTopW * 0.42, tubeTipY);
    ctx.lineTo(headshellOffsetX + tubeTopW * 0.65, headshellEndY);
    ctx.lineTo(headshellOffsetX - tubeTopW * 0.65, headshellEndY);
    ctx.lineTo(-tubeTopW * 0.42, tubeTipY);
    ctx.closePath();

    if (isShadowPass) {
      ctx.fillStyle = colorMain;
      ctx.fill();
    } else {
      const tubeGrad = ctx.createLinearGradient(-tubeTopW, 0, tubeTopW, 0);
      if (isDark) {
        tubeGrad.addColorStop(0, '#6B7486');
        tubeGrad.addColorStop(0.4, '#DCE2EE');
        tubeGrad.addColorStop(1, '#3E4554');
      } else {
        tubeGrad.addColorStop(0, '#14171D');
        tubeGrad.addColorStop(0.35, '#596070');
        tubeGrad.addColorStop(1, '#0F1116');
      }
      ctx.fillStyle = tubeGrad;
      ctx.fill();
    }

    // Headshell & Phono Cartridge block
    ctx.save();
    ctx.translate(headshellOffsetX, headshellEndY - deckH * 0.02);
    ctx.rotate(0.24); // Headshell tracking offset angle

    const hsW = deckW * 0.036;
    const hsH = deckH * 0.088;
    ctx.fillStyle = isShadowPass ? colorMain : isDark ? '#2D323E' : '#181B22';
    drawRoundedRect(ctx, -hsW / 2, -hsH * 0.3, hsW, hsH, 2.5);
    ctx.fill();

    if (!isShadowPass) {
      // Finger-lift spur
      ctx.beginPath();
      ctx.moveTo(hsW / 2, hsH * 0.25);
      ctx.quadraticCurveTo(hsW * 1.4, hsH * 0.35, hsW * 1.25, hsH * 0.65);
      ctx.strokeStyle = isDark ? '#9BA5B8' : '#4C5362';
      ctx.lineWidth = 1.6;
      ctx.lineCap = 'round';
      ctx.stroke();

      // Stylus diamond needle tip + active contact micro-sparkle when seated on spinning vinyl
      ctx.beginPath();
      ctx.arc(0, hsH * 0.72, 1.9, 0, Math.PI * 2);
      ctx.fillStyle = p.phase === 'playing' ? '#E4ECFA' : '#7D8698';
      ctx.fill();
    }
    ctx.restore();

    // Gimbal center yoke cap
    if (!isShadowPass) {
      ctx.beginPath();
      ctx.arc(0, 0, armBaseR * 0.34, 0, Math.PI * 2);
      ctx.fillStyle = isDark ? '#20242E' : '#323743';
      ctx.fill();
      ctx.beginPath();
      ctx.arc(-1, -1, armBaseR * 0.14, 0, Math.PI * 2);
      ctx.fillStyle = isDark ? '#8C96AB' : '#A6AEBE';
      ctx.fill();
    }

    ctx.restore();
  };

  // Render shadow pass first with blur, then sharp tonearm pass
  ctx.save();
  ctx.filter = `blur(${Math.round(shadowBlur * 0.45)}px)`;
  drawTonearmGeometry(true);
  ctx.restore();

  drawTonearmGeometry(false);
}
