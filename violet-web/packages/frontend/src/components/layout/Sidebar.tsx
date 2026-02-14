import { NavLink, useNavigate } from 'react-router';
import { useTranslation } from 'react-i18next';
import { useAppStore } from '../../stores/app-store';
import styles from './Sidebar.module.css';

const navItems = [
  { to: '/', labelKey: 'nav.home' },
  { to: '/bookmarks', labelKey: 'nav.bookmarks' },
  { to: '/history', labelKey: 'nav.history' },
  { to: '/settings', labelKey: 'nav.settings' },
];

export function Sidebar() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { themeColor } = useAppStore();

  const logoSrc = themeColor === 'purple'
    ? '/logos/logo.png'
    : `/logos/logo-${themeColor}.png`;

  return (
    <nav className={styles.sidebar}>
      <div className={styles.logoContainer} onClick={() => navigate('/')}>
        <img src={logoSrc} alt="Violet" className={styles.logo} />
      </div>
      <div className={styles.navLinks}>
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
      </div>
    </nav>
  );
}
