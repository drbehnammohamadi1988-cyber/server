import React from 'react';
import { motion } from 'framer-motion';

interface IconProps {
  size?: number;
  active?: boolean;
  className?: string;
}

export const HomeIcon: React.FC<IconProps> = ({ size = 21, active = false, className }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" className={className}>
    <path
      d="M4.5 10.6L12 4.5L19.5 10.6V18.8C19.5 19.6 18.9 20.2 18.1 20.2H14.6V14.7C14.6 14.1 14.1 13.6 13.5 13.6H10.5C9.9 13.6 9.4 14.1 9.4 14.7V20.2H5.9C5.1 20.2 4.5 19.6 4.5 18.8V10.6Z"
      fill={active ? 'currentColor' : 'none'}
      stroke="currentColor"
      strokeWidth={active ? 1.8 : 1.7}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

export const SaturnExploreIcon: React.FC<IconProps> = ({ size = 24, active = false, className }) => (
  <svg width={size} height={size} viewBox="0 0 26 26" fill="none" className={className}>
    <circle
      cx="13"
      cy="13"
      r="5.6"
      fill={active ? 'currentColor' : 'none'}
      stroke="currentColor"
      strokeWidth={1.7}
    />
    <ellipse
      cx="13"
      cy="13"
      rx="10.8"
      ry="3.1"
      transform="rotate(-24 13 13)"
      stroke="currentColor"
      strokeWidth={active ? 2.1 : 1.7}
      strokeLinecap="round"
    />
  </svg>
);

export const LibraryBookmarkIcon: React.FC<IconProps> = ({ size = 21, active = false, className }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" className={className}>
    <path
      d="M6.8 4.6C6.8 3.9 7.4 3.4 8.1 3.4H15.9C16.6 3.4 17.2 3.9 17.2 4.6V20.3L12 16.9L6.8 20.3V4.6Z"
      fill={active ? 'currentColor' : 'none'}
      stroke="currentColor"
      strokeWidth={1.7}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

export const SearchLensIcon: React.FC<IconProps> = ({ size = 20, active = false, className }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" className={className}>
    <circle
      cx="11"
      cy="11"
      r="6.4"
      stroke="currentColor"
      strokeWidth={active ? 2.2 : 1.7}
    />
    <path
      d="M16 16L20 20"
      stroke="currentColor"
      strokeWidth={active ? 2.2 : 1.7}
      strokeLinecap="round"
    />
  </svg>
);

export const BackChevronIcon: React.FC<IconProps & { rtl?: boolean }> = ({
  size = 22,
  rtl = false,
  className,
}) => (
  <svg
    width={size}
    height={size}
    viewBox="0 0 24 24"
    fill="none"
    className={className}
    style={{ transform: rtl ? 'scaleX(-1)' : undefined }}
  >
    <path
      d="M14.8 6.4L9.2 12L14.8 17.6"
      stroke="currentColor"
      strokeWidth={1.9}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

export const MoreDotsIcon: React.FC<IconProps> = ({ size = 22, className }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" className={className}>
    <circle cx="6.2" cy="12" r="1.45" />
    <circle cx="12" cy="12" r="1.45" />
    <circle cx="17.8" cy="12" r="1.45" />
  </svg>
);

export const SkipPrevIcon: React.FC<IconProps & { rtl?: boolean }> = ({ size = 18, rtl = false }) => (
  <svg
    width={size}
    height={size}
    viewBox="0 0 24 24"
    fill="currentColor"
    style={{ transform: rtl ? 'scaleX(-1)' : undefined }}
  >
    <rect x="5" y="6.2" width="2.1" height="11.6" rx="1" />
    <path d="M18.2 6.8C18.2 6.1 17.4 5.7 16.8 6.1L9.3 11.2C8.8 11.6 8.8 12.4 9.3 12.8L16.8 17.9C17.4 18.3 18.2 17.9 18.2 17.2V6.8Z" />
  </svg>
);

export const SkipNextIcon: React.FC<IconProps & { rtl?: boolean }> = ({ size = 18, rtl = false }) => (
  <svg
    width={size}
    height={size}
    viewBox="0 0 24 24"
    fill="currentColor"
    style={{ transform: rtl ? 'scaleX(-1)' : undefined }}
  >
    <rect x="16.9" y="6.2" width="2.1" height="11.6" rx="1" />
    <path d="M5.8 6.8C5.8 6.1 6.6 5.7 7.2 6.1L14.7 11.2C15.2 11.6 15.2 12.4 14.7 12.8L7.2 17.9C6.6 18.3 5.8 17.9 5.8 17.2V6.8Z" />
  </svg>
);

/**
 * Play <-> Pause Morphing SVG matching tactile center dial aesthetics:
 * Smoothly morphs two vertical bars (Pause) into a crisp play triangle or single rotary indicator.
 */
export const MorphPlayPauseIcon: React.FC<{ isPlaying: boolean; size?: number }> = ({
  isPlaying,
  size = 24,
}) => {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
      <motion.path
        initial={false}
        animate={{
          d: isPlaying
            ? 'M7.5 6.2C7.5 5.6 8.0 5.2 8.6 5.2H9.8C10.4 5.2 10.9 5.6 10.9 6.2V17.8C10.9 18.4 10.4 18.8 9.8 18.8H8.6C8.0 18.8 7.5 18.4 7.5 17.8V6.2Z'
            : 'M7.8 5.9C7.8 5.2 8.6 4.8 9.2 5.2L13.6 8.1C14.1 8.4 14.1 9.0 14.1 9.6V14.4C14.1 15.0 14.1 15.6 13.6 15.9L9.2 18.8C8.6 19.2 7.8 18.8 7.8 18.1V5.9Z',
        }}
        transition={{ type: 'spring', stiffness: 420, damping: 28 }}
      />
      <motion.path
        initial={false}
        animate={{
          d: isPlaying
            ? 'M13.1 6.2C13.1 5.6 13.6 5.2 14.2 5.2H15.4C16.0 5.2 16.5 5.6 16.5 6.2V17.8C16.5 18.4 16.0 18.8 15.4 18.8H14.2C13.6 18.8 13.1 18.4 13.1 17.8V6.2Z'
            : 'M13.4 8.2C13.4 7.8 13.9 7.8 14.2 8.0L18.4 11.2C18.9 11.6 18.9 12.4 18.4 12.8L14.2 16.0C13.9 16.2 13.4 16.2 13.4 15.8V8.2Z',
        }}
        transition={{ type: 'spring', stiffness: 420, damping: 28 }}
      />
    </svg>
  );
};

export const ShuffleIcon: React.FC<IconProps> = ({ size = 18 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <path
      d="M16 5H20V9M20 5L14.5 10.5M4 19L9.5 13.5M16 19H20V15M20 19L4 5"
      stroke="currentColor"
      strokeWidth={1.75}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

export const RepeatIcon: React.FC<{ mode: 'off' | 'all' | 'one'; size?: number }> = ({
  mode,
  size = 18,
}) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <path
      d="M17 4L20 7L17 10M20 7H8C5.8 7 4 8.8 4 11V12M7 20L4 17L7 14M4 17H16C18.2 17 20 15.2 20 13V12"
      stroke="currentColor"
      strokeWidth={1.75}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
    {mode === 'one' && (
      <circle cx="12" cy="12" r="2.1" fill="currentColor" />
    )}
  </svg>
);

export const HeartIcon: React.FC<IconProps> = ({ size = 18, active = false }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <path
      d="M12 20.2C12 20.2 4.5 15.2 4.5 9.6C4.5 7.1 6.4 5.2 8.8 5.2C10.3 5.2 11.4 6.0 12 7.1C12.6 6.0 13.7 5.2 15.2 5.2C17.6 5.2 19.5 7.1 19.5 9.6C19.5 15.2 12 20.2 12 20.2Z"
      fill={active ? 'currentColor' : 'none'}
      stroke="currentColor"
      strokeWidth={1.75}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

export const QueueListIcon: React.FC<IconProps> = ({ size = 18 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <path
      d="M4.5 7H14.5M4.5 12H14.5M4.5 17H10.5M16 14.5V19.5L20 17L16 14.5Z"
      stroke="currentColor"
      strokeWidth={1.75}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

export const EqualizerIcon: React.FC<IconProps> = ({ size = 18 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <path
      d="M6 5V19M12 5V19M18 5V19"
      stroke="currentColor"
      strokeWidth={1.6}
      strokeLinecap="round"
    />
    <circle cx="6" cy="9.5" r="2.2" fill="currentColor" />
    <circle cx="12" cy="14.5" r="2.2" fill="currentColor" />
    <circle cx="18" cy="8.5" r="2.2" fill="currentColor" />
  </svg>
);

export const VolumeIcon: React.FC<{ muted?: boolean; size?: number }> = ({
  muted = false,
  size = 18,
}) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <path
      d="M5 9.8H8.4L13.2 5.8V18.2L8.4 14.2H5V9.8Z"
      stroke="currentColor"
      strokeWidth={1.75}
      strokeLinejoin="round"
    />
    {muted ? (
      <path d="M16.5 9.5L20.5 14.5M20.5 9.5L16.5 14.5" stroke="currentColor" strokeWidth={1.75} strokeLinecap="round" />
    ) : (
      <path
        d="M16.2 9.2C17.4 10.6 17.4 13.4 16.2 14.8M18.8 6.8C21.1 9.5 21.1 14.5 18.8 17.2"
        stroke="currentColor"
        strokeWidth={1.75}
        strokeLinecap="round"
      />
    )}
  </svg>
);

export const DiscIcon: React.FC<IconProps> = ({ size = 18 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <circle cx="12" cy="12" r="8.5" stroke="currentColor" strokeWidth={1.7} />
    <circle cx="12" cy="12" r="2.4" stroke="currentColor" strokeWidth={1.7} />
  </svg>
);

export const PlusIcon: React.FC<IconProps> = ({ size = 18 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <path d="M12 5.5V18.5M5.5 12H18.5" stroke="currentColor" strokeWidth={1.9} strokeLinecap="round" />
  </svg>
);

export const UploadWaveIcon: React.FC<IconProps> = ({ size = 18 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <path
      d="M12 15.5V5.5M12 5.5L8.2 9.3M12 5.5L15.8 9.3M4.8 15.8V17.6C4.8 18.5 5.5 19.2 6.4 19.2H17.6C18.5 19.2 19.2 18.5 19.2 17.6V15.8"
      stroke="currentColor"
      strokeWidth={1.75}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

export const SettingsGearIcon: React.FC<IconProps> = ({ size = 18 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <circle cx="12" cy="12" r="3.2" stroke="currentColor" strokeWidth={1.7} />
    <path
      d="M12 3.5V5.7M12 18.3V20.5M3.5 12H5.7M18.3 12H20.5M6.1 6.1L7.6 7.6M16.4 16.4L17.9 17.9M17.9 6.1L16.4 7.6M7.6 16.4L6.1 17.9"
      stroke="currentColor"
      strokeWidth={1.7}
      strokeLinecap="round"
    />
  </svg>
);

export const MoonSunIcon: React.FC<{ isDark: boolean; size?: number }> = ({ isDark, size = 18 }) =>
  isDark ? (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <circle cx="12" cy="12" r="4.2" stroke="currentColor" strokeWidth={1.7} />
      <path
        d="M12 3V5M12 19V21M3 12H5M19 12H21M5.6 5.6L7.1 7.1M16.9 16.9L18.4 18.4M18.4 5.6L16.9 7.1M7.1 16.4L5.6 17.9"
        stroke="currentColor"
        strokeWidth={1.7}
        strokeLinecap="round"
      />
    </svg>
  ) : (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <path
        d="M19.4 14.2A7.6 7.6 0 0 1 9.8 4.6A7.8 7.8 0 1 0 19.4 14.2Z"
        stroke="currentColor"
        strokeWidth={1.7}
        strokeLinejoin="round"
      />
    </svg>
  );
