import { NavLink } from 'react-router';
import { useTranslation } from 'react-i18next';
import { Bookmark, Crop, Download, History, Home, Settings, Sparkles } from 'lucide-react';
import { useAppStore } from '../../stores/app-store';
import styles from './BottomNav.module.css';

const navItems = [
  { to: '/', labelKey: 'nav.home', icon: Home },
  { to: '/history', labelKey: 'nav.history', icon: History },
  { to: '/bookmarks', labelKey: 'nav.bookmarks', icon: Bookmark },
  { to: '/crop-bookmarks', labelKey: 'nav.cropBookmarks', icon: Crop },
  { to: '/downloads', labelKey: 'nav.downloads', icon: Download },
  { to: '/ai-search', labelKey: 'nav.aiSearch', icon: Sparkles },
  { to: '/settings', labelKey: 'nav.settings', icon: Settings },
];

export function BottomNav() {
  const { t } = useTranslation();
  const { aiSearchEnabled } = useAppStore();

  return (
    <nav className={styles.nav}>
      {navItems.filter((item) => item.to !== '/ai-search' || aiSearchEnabled).map((item) => {
        const Icon = item.icon;
        const label = t(item.labelKey);

        return (
          <NavLink
            key={item.to}
            to={item.to}
            className={({ isActive }) =>
              `${styles.link} ${isActive ? styles.active : ''}`
            }
            aria-label={label}
            title={label}
          >
            <Icon size={22} strokeWidth={2.2} aria-hidden="true" />
          </NavLink>
        );
      })}
    </nav>
  );
}
