import { NavLink } from 'react-router';
import { useTranslation } from 'react-i18next';
import { useAppStore } from '../../stores/app-store';
import styles from './BottomNav.module.css';

const navItems = [
  { to: '/', labelKey: 'nav.home' },
  { to: '/history', labelKey: 'nav.history' },
  { to: '/bookmarks', labelKey: 'nav.bookmarks' },
  { to: '/crop-bookmarks', labelKey: 'nav.cropBookmarks' },
  { to: '/downloads', labelKey: 'nav.downloads' },
  { to: '/ai-search', labelKey: 'nav.aiSearch' },
  { to: '/settings', labelKey: 'nav.settings' },
];

export function BottomNav() {
  const { t } = useTranslation();
  const { aiSearchEnabled } = useAppStore();

  return (
    <nav className={styles.nav}>
      {navItems.filter((item) => item.to !== '/ai-search' || aiSearchEnabled).map((item) => (
        <NavLink
          key={item.to}
          to={item.to}
          className={({ isActive }) =>
            `${styles.link} ${isActive ? styles.active : ''}`
          }
        >
          {t(item.labelKey)}
        </NavLink>
      ))}
    </nav>
  );
}
