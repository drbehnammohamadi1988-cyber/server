import React from 'react';
import { EQ_BANDS_META, EQ_PRESETS } from '../data/catalog';
import { TranslationDict } from '../i18n/translations';
import { formatClock } from '../components/AudioVisualizer';
import { BackChevronIcon } from '../components/Icons';
import { AppSettings, Track } from '../types/music';

const ConsoleHeader: React.FC<{
  title: string;
  isRtl: boolean;
  backLabel: string;
  onBack: () => void;
  rightEl?: React.ReactNode;
}> = ({ title, isRtl, backLabel, onBack, rightEl }) => (
  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 18 }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
      <button
        type="button"
        onClick={onBack}
        className="tactile-btn"
        aria-label={backLabel}
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
      <h1 style={{ margin: 0, fontSize: 20, fontWeight: 800, letterSpacing: '-0.02em' }}>{title}</h1>
    </div>
    {rightEl}
  </div>
);

export const QueueScreen: React.FC<{
  tracks: Track[];
  queueIds: string[];
  currentTrackId: string;
  isRtl: boolean;
  t: TranslationDict;
  onBack: () => void;
  onPlayTrack: (track: Track) => void;
  onMoveItem: (index: number, delta: -1 | 1) => void;
  onRemoveItem: (index: number) => void;
  onClearUpcoming: () => void;
}> = ({
  tracks,
  queueIds,
  currentTrackId,
  isRtl,
  t,
  onBack,
  onPlayTrack,
  onMoveItem,
  onRemoveItem,
  onClearUpcoming,
}) => {
  const map = new Map(tracks.map((trk) => [trk.id, trk]));
  const items = queueIds.map((id, index) => ({ track: map.get(id), index })).filter((x) => Boolean(x.track)) as {
    track: Track;
    index: number;
  }[];

  return (
    <div className="scroll-clean" style={{ flex: 1, padding: 'calc(18px + var(--safe-top)) 20px 24px' }}>
      <ConsoleHeader
        title={t.queue.title}
        isRtl={isRtl}
        backLabel={t.common.back}
        onBack={onBack}
        rightEl={
          <button
            type="button"
            onClick={onClearUpcoming}
            className="tactile-pill"
            style={{ padding: '6px 12px', borderRadius: 999, fontSize: 11, fontWeight: 600, color: 'var(--text-secondary)' }}
          >
            {t.queue.clearUpcoming}
          </button>
        }
      />

      {items.length === 0 ? (
        <div className="recessed-well" style={{ borderRadius: 20, padding: 24, textAlign: 'center', color: 'var(--text-secondary)' }}>
          {t.queue.empty}
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 9 }}>
          {items.map(({ track, index }) => {
            const isCurrent = track.id === currentTrackId;
            return (
              <div
                key={`${track.id}-${index}`}
                className="tactile-pill"
                style={{
                  borderRadius: 20,
                  padding: '8px 12px',
                  display: 'flex',
                  alignItems: 'center',
                  gap: 10,
                  borderColor: isCurrent ? 'var(--text-primary)' : undefined,
                }}
              >
                <img
                  src={track.coverUrl}
                  alt={track.title}
                  onClick={() => onPlayTrack(track)}
                  style={{ width: 40, height: 40, borderRadius: '50%', objectFit: 'cover', cursor: 'pointer' }}
                />
                <div onClick={() => onPlayTrack(track)} style={{ flex: 1, minWidth: 0, cursor: 'pointer' }}>
                  <div style={{ fontSize: 13.5, fontWeight: 700, color: 'var(--text-primary)' }}>
                    {track.title} {isCurrent ? '· ●' : ''}
                  </div>
                  <div style={{ fontSize: 11.5, color: 'var(--text-secondary)' }}>
                    {track.artist} · {formatClock(track.durationSec)}
                  </div>
                </div>
                <div style={{ display: 'flex', gap: 4 }}>
                  <button
                    type="button"
                    disabled={index === 0}
                    onClick={() => onMoveItem(index, -1)}
                    aria-label={t.queue.moveUp}
                    style={{ border: 'none', background: 'transparent', color: 'var(--text-secondary)', cursor: 'pointer', padding: 4 }}
                  >
                    ↑
                  </button>
                  <button
                    type="button"
                    disabled={index === items.length - 1}
                    onClick={() => onMoveItem(index, 1)}
                    aria-label={t.queue.moveDown}
                    style={{ border: 'none', background: 'transparent', color: 'var(--text-secondary)', cursor: 'pointer', padding: 4 }}
                  >
                    ↓
                  </button>
                  {!isCurrent && (
                    <button
                      type="button"
                      onClick={() => onRemoveItem(index)}
                      aria-label={t.queue.remove}
                      style={{ border: 'none', background: 'transparent', color: 'var(--text-muted)', cursor: 'pointer', padding: 4 }}
                    >
                      ×
                    </button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

export const EqualizerScreen: React.FC<{
  enabled: boolean;
  gains: number[];
  presetId: string;
  isRtl: boolean;
  isFa: boolean;
  t: TranslationDict;
  onBack: () => void;
  onToggleEnabled: () => void;
  onSelectPreset: (presetId: string, gains: number[]) => void;
  onBandChange: (bandIdx: number, db: number) => void;
}> = ({
  enabled,
  gains,
  presetId,
  isRtl,
  isFa,
  t,
  onBack,
  onToggleEnabled,
  onSelectPreset,
  onBandChange,
}) => {
  return (
    <div className="scroll-clean" style={{ flex: 1, padding: 'calc(18px + var(--safe-top)) 20px 24px' }}>
      <ConsoleHeader
        title={t.equalizer.title}
        isRtl={isRtl}
        backLabel={t.common.back}
        onBack={onBack}
        rightEl={
          <button
            type="button"
            onClick={onToggleEnabled}
            className={enabled ? 'tactile-btn' : 'tactile-pill'}
            style={{
              padding: '7px 14px',
              borderRadius: 999,
              fontSize: 12,
              fontWeight: 700,
              color: enabled ? 'var(--text-primary)' : 'var(--text-muted)',
            }}
          >
            {enabled ? t.equalizer.enabled : t.equalizer.bypass}
          </button>
        }
      />

      <p style={{ margin: '0 0 18px', fontSize: 12, color: 'var(--text-secondary)' }}>{t.equalizer.preampNote}</p>

      {/* Hardware Faders Console */}
      <div
        className="tactile-pill"
        style={{
          borderRadius: 26,
          padding: '22px 16px',
          display: 'grid',
          gridTemplateColumns: 'repeat(5, 1fr)',
          gap: 8,
          marginBottom: 20,
          opacity: enabled ? 1 : 0.52,
        }}
      >
        {EQ_BANDS_META.map((band, idx) => {
          const val = gains[idx] ?? 0;
          return (
            <div key={band.id} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10 }}>
              <span className="tabular-mono" style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-primary)' }}>
                {val > 0 ? `+${val.toFixed(1)}` : val.toFixed(1)}
              </span>

              <div
                className="recessed-well"
                style={{
                  height: 152,
                  width: 34,
                  borderRadius: 999,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  position: 'relative',
                }}
              >
                <input
                  type="range"
                  min={-12}
                  max={12}
                  step={0.5}
                  value={val}
                  disabled={!enabled}
                  onChange={(e) => onBandChange(idx, parseFloat(e.target.value))}
                  aria-label={`${band.label} EQ gain`}
                  style={{
                    width: 132,
                    transform: 'rotate(-90deg)',
                    accentColor: 'var(--text-primary)',
                    cursor: enabled ? 'pointer' : 'not-allowed',
                  }}
                />
              </div>

              <span className="tabular-mono" style={{ fontSize: 11, color: 'var(--text-secondary)' }}>
                {band.label}
              </span>
            </div>
          );
        })}
      </div>

      <h2 style={{ margin: '0 0 10px', fontSize: 13.5, fontWeight: 700, color: 'var(--text-secondary)' }}>
        {t.equalizer.presets}
      </h2>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
        {EQ_PRESETS.map((preset) => {
          const active = preset.id === presetId;
          return (
            <button
              key={preset.id}
              type="button"
              onClick={() => onSelectPreset(preset.id, preset.gains)}
              className={active ? 'tactile-btn is-pressed' : 'tactile-pill'}
              style={{
                padding: '9px 14px',
                borderRadius: 999,
                fontSize: 12.5,
                fontWeight: 600,
                color: active ? 'var(--text-primary)' : 'var(--text-secondary)',
              }}
            >
              {isFa ? preset.nameFa : preset.nameEn}
            </button>
          );
        })}
      </div>
    </div>
  );
};

export const SettingsScreen: React.FC<{
  settings: AppSettings;
  sleepRemainingSec: number | null;
  t: TranslationDict;
  onBack: () => void;
  onUpdateSettings: (patch: Partial<AppSettings>) => void;
  onSetSleepTimer: (minutes: number | null) => void;
}> = ({ settings, sleepRemainingSec, t, onBack, onUpdateSettings, onSetSleepTimer }) => {
  const isRtl = settings.language === 'fa';
  const timerOptions: (number | null)[] = [null, 15, 30, 45, 60];

  const capabilities = [
    { label: t.settings.capWebFileImport, supported: true },
    { label: t.settings.capWebAudioFft, supported: true },
    { label: t.settings.capWebOfflineIdb, supported: true },
    { label: t.settings.capNativeMediaStore, supported: false },
    { label: t.settings.capNativeLockscreen, supported: false },
    { label: t.settings.capNativeBackground, supported: false },
  ];

  return (
    <div className="scroll-clean" style={{ flex: 1, padding: 'calc(18px + var(--safe-top)) 20px 28px' }}>
      <ConsoleHeader title={t.settings.title} isRtl={isRtl} backLabel={t.common.back} onBack={onBack} />

      {/* Theme & Language */}
      <h2 style={{ margin: '0 0 10px', fontSize: 13, fontWeight: 700, color: 'var(--text-secondary)' }}>
        {t.settings.appearance}
      </h2>
      <div className="tactile-pill" style={{ borderRadius: 22, padding: 14, display: 'flex', flexDirection: 'column', gap: 12, marginBottom: 18 }}>
        <div>
          <div style={{ fontSize: 12, color: 'var(--text-muted)', marginBottom: 8 }}>{t.settings.themeMode}</div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
            <button
              type="button"
              onClick={() => onUpdateSettings({ theme: 'light' })}
              className={settings.theme === 'light' ? 'tactile-btn is-pressed' : 'tactile-pill'}
              style={{ padding: '10px 10px', borderRadius: 14, fontSize: 12, fontWeight: 700, color: 'var(--text-primary)' }}
            >
              {t.settings.lightMode}
            </button>
            <button
              type="button"
              onClick={() => onUpdateSettings({ theme: 'dark' })}
              className={settings.theme === 'dark' ? 'tactile-btn is-pressed' : 'tactile-pill'}
              style={{ padding: '10px 10px', borderRadius: 14, fontSize: 12, fontWeight: 700, color: 'var(--text-primary)' }}
            >
              {t.settings.darkMode}
            </button>
          </div>
        </div>

        <div>
          <div style={{ fontSize: 12, color: 'var(--text-muted)', marginBottom: 8 }}>{t.settings.language}</div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
            <button
              type="button"
              onClick={() => onUpdateSettings({ language: 'en' })}
              className={settings.language === 'en' ? 'tactile-btn is-pressed' : 'tactile-pill'}
              style={{ padding: '10px 10px', borderRadius: 14, fontSize: 12, fontWeight: 700, color: 'var(--text-primary)' }}
            >
              {t.settings.english}
            </button>
            <button
              type="button"
              onClick={() => onUpdateSettings({ language: 'fa' })}
              className={settings.language === 'fa' ? 'tactile-btn is-pressed' : 'tactile-pill'}
              style={{ padding: '10px 10px', borderRadius: 14, fontSize: 12, fontWeight: 700, color: 'var(--text-primary)' }}
            >
              {t.settings.persian}
            </button>
          </div>
        </div>
      </div>

      {/* Playback Hardware & Sleep Timer */}
      <h2 style={{ margin: '0 0 10px', fontSize: 13, fontWeight: 700, color: 'var(--text-secondary)' }}>
        {t.settings.playbackHardware}
      </h2>
      <div className="tactile-pill" style={{ borderRadius: 22, padding: 14, display: 'flex', flexDirection: 'column', gap: 14, marginBottom: 18 }}>
        <div>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
            <span style={{ fontSize: 13, fontWeight: 600 }}>{t.settings.sleepTimer}</span>
            {sleepRemainingSec !== null && sleepRemainingSec > 0 && (
              <span className="tabular-mono" style={{ fontSize: 12, color: 'var(--text-secondary)' }}>
                {formatClock(sleepRemainingSec)}
              </span>
            )}
          </div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 7 }}>
            {timerOptions.map((mins) => {
              const active = settings.sleepTimerMinutes === mins;
              return (
                <button
                  key={String(mins)}
                  type="button"
                  onClick={() => onSetSleepTimer(mins)}
                  className={active ? 'tactile-btn is-pressed' : 'tactile-pill'}
                  style={{ padding: '7px 12px', borderRadius: 999, fontSize: 12, fontWeight: 600, color: 'var(--text-primary)' }}
                >
                  {mins === null ? t.settings.off : `${mins} ${t.settings.minutes}`}
                </button>
              );
            })}
          </div>
        </div>

        {(
          [
            ['hapticsEnabled', t.settings.haptics],
            ['reduceMotion', t.settings.reduceMotion],
            ['vinylWarmthCrackle', t.settings.vinylSurface],
          ] as const
        ).map(([key, label]) => (
          <div
            key={key}
            onClick={() => onUpdateSettings({ [key]: !settings[key] })}
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              cursor: 'pointer',
            }}
          >
            <span style={{ fontSize: 13, fontWeight: 600 }}>{label}</span>
            <span
              className="recessed-well"
              style={{
                width: 44,
                height: 24,
                borderRadius: 999,
                padding: 3,
                display: 'inline-flex',
                alignItems: 'center',
                justifyContent: settings[key] ? 'flex-end' : 'flex-start',
              }}
            >
              <span
                style={{
                  width: 18,
                  height: 18,
                  borderRadius: '50%',
                  background: settings[key] ? 'var(--text-primary)' : 'var(--text-muted)',
                  boxShadow: 'var(--shadow-btn-float)',
                }}
              />
            </span>
          </div>
        ))}
      </div>

      {/* Honest Runtime & Native Android Capability Matrix (Section 14) */}
      <h2 style={{ margin: '0 0 8px', fontSize: 13, fontWeight: 700, color: 'var(--text-secondary)' }}>
        {t.settings.nativeStatusTitle}
      </h2>
      <div className="recessed-well" style={{ borderRadius: 22, padding: 14, display: 'flex', flexDirection: 'column', gap: 10 }}>
        <p style={{ margin: 0, fontSize: 11.5, color: 'var(--text-secondary)', lineHeight: 1.5 }}>
          {t.settings.nativeStatusSubtitle}
        </p>
        {capabilities.map((cap) => (
          <div
            key={cap.label}
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              gap: 10,
              fontSize: 12,
              paddingTop: 6,
              borderTop: '1px solid var(--border-hairline)',
            }}
          >
            <span style={{ color: 'var(--text-primary)', fontWeight: 500 }}>{cap.label}</span>
            <span
              style={{
                fontSize: 10.5,
                fontWeight: 700,
                padding: '3px 8px',
                borderRadius: 999,
                whiteSpace: 'nowrap',
                background: cap.supported ? 'var(--bg-surface)' : 'transparent',
                border: '1px solid var(--border-subtle)',
                color: cap.supported ? 'var(--text-primary)' : 'var(--text-muted)',
              }}
            >
              {cap.supported ? t.settings.statusSupported : t.settings.statusNativeOnly}
            </span>
          </div>
        ))}
        <p style={{ margin: '4px 0 0', fontSize: 11, color: 'var(--text-muted)' }}>
          {t.settings.androidApkNote}
        </p>
      </div>
    </div>
  );
};
