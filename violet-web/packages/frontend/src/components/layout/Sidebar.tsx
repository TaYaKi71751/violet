import { NavLink, useNavigate } from 'react-router';
import { useTranslation } from 'react-i18next';
import { Home, Bookmark, History, Settings, ChevronLeft, ChevronRight } from 'lucide-react';
import { useAppStore } from '../../stores/app-store';
import styles from './Sidebar.module.css';

const navItems = [
  { to: '/', labelKey: 'nav.home', icon: Home },
  { to: '/bookmarks', labelKey: 'nav.bookmarks', icon: Bookmark },
  { to: '/history', labelKey: 'nav.history', icon: History },
  { to: '/settings', labelKey: 'nav.settings', icon: Settings },
];

export function Sidebar() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { themeColor, sidebarCollapsed, toggleSidebar } = useAppStore();

  const logoSrc = themeColor === 'purple'
    ? '/logos/logo.png'
    : `/logos/logo-${themeColor}.png`;

  return (
    <nav className={`${styles.sidebar} ${sidebarCollapsed ? styles.collapsed : ''}`}>
      <div className={styles.logoContainer} onClick={() => navigate('/')}>
        <img src={logoSrc} alt="Violet" className={styles.logo} />
      </div>

      <div className={styles.navLinks}>
        {navItems.map((item) => {
          const Icon = item.icon;
          return (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                `${styles.link} ${isActive ? styles.active : ''}`
              }
              title={sidebarCollapsed ? t(item.labelKey) : undefined}
            >
              <Icon size={20} className={styles.icon} />
              {!sidebarCollapsed && <span>{t(item.labelKey)}</span>}
            </NavLink>
          );
        })}
      </div>

      <button className={styles.toggleBtn} onClick={toggleSidebar}>
        {sidebarCollapsed ? <ChevronRight size={20} /> : <ChevronLeft size={20} />}
      </button>
    </nav>
  );
}
