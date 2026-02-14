import { NavLink } from 'react-router';
import { useTranslation } from 'react-i18next';
import styles from './BottomNav.module.css';

const navItems = [
  { to: '/', labelKey: 'nav.home' },
  { to: '/bookmarks', labelKey: 'nav.bookmarks' },
  { to: '/history', labelKey: 'nav.history' },
  { to: '/settings', labelKey: 'nav.settings' },
];

export function BottomNav() {
  const { t } = useTranslation();

  return (
    <nav className={styles.nav}>
      {navItems.map((item) => (
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
