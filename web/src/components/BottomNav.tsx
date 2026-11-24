import React from 'react';
import { AppTheme, ScreenId } from '../types/music';
import { HomeIcon, LibraryBookmarkIcon, SaturnExploreIcon, SearchLensIcon } from './Icons';

interface BottomNavProps {
  activeScreen: ScreenId;
  theme: AppTheme;
  labels: {
    home: string;
    explore: string;
    library: string;
    search: string;
  };
  onNavigate: (screen: ScreenId) => void;
}

export const BottomNav: React.FC<BottomNavProps> = ({
  activeScreen,
  theme,
  labels,
  onNavigate,
}) => {
  const isDark = theme === 'dark';

  const isLibraryActive =
    activeScreen === 'library' ||
    activeScreen === 'albums' ||
    activeScreen === 'artists' ||
    activeScreen === 'playlists' ||
    activeScreen === 'favorites';

  const items: {
    id: ScreenId;
    label: string;
    active: boolean;
    renderIcon: (active: boolean) => React.ReactNode;
  }[] = [
    {
      id: 'home',
      label: labels.home,
      active: activeScreen === 'home',
      renderIcon: (active) => <HomeIcon size={21} active={active} />,
    },
    {
      id: 'explore',
      label: labels.explore,
      active: activeScreen === 'explore',
      renderIcon: (active) => <SaturnExploreIcon size={24} active={active} />,
    },
    {
      id: 'search',
      label: labels.search,
      active: activeScreen === 'search',
      renderIcon: (active) => <SearchLensIcon size={20} active={active} />,
    },
    {
      id: 'library',
      label: labels.library,
      active: isLibraryActive,
      renderIcon: (active) => <LibraryBookmarkIcon size={21} active={active} />,
    },
  ];

  return (
    <nav
      aria-label="Primary Navigation"
      style={{
        height: 'calc(62px + var(--safe-bottom))',
        paddingBottom: 'var(--safe-bottom)',
        background: 'var(--bg-nav)',
        backdropFilter: 'blur(20px)',
        WebkitBackdropFilter: 'blur(20px)',
        borderTop: `1px solid ${isDark ? 'rgba(255,255,255,0.06)' : 'rgba(255,255,255,0.92)'}`,
        boxShadow: isDark
          ? '0 -10px 26px rgba(0,0,0,0.45)'
          : '0 -10px 28px rgba(145, 158, 182, 0.14)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-around',
        paddingInline: 14,
        flexShrink: 0,
        zIndex: 35,
      }}
    >
      {items.map((item) => (
        <button
          key={item.id}
          type="button"
          onClick={() => onNavigate(item.id)}
          aria-label={item.label}
          aria-current={item.active ? 'page' : undefined}
          style={{
            background: 'none',
            border: 'none',
            padding: '6px 14px',
            borderRadius: 14,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: 3,
            color: item.active ? 'var(--text-primary)' : 'var(--text-muted)',
            cursor: 'pointer',
            transition: 'color 0.2s ease, transform 0.16s ease',
          }}
        >
          {item.renderIcon(item.active)}
          <span
            style={{
              width: item.active ? 14 : 0,
              height: 2,
              borderRadius: 99,
              background: 'var(--text-primary)',
              opacity: item.active ? 0.85 : 0,
              transition: 'all 0.22s ease',
            }}
          />
        </button>
      ))}
    </nav>
  );
};
