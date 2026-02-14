import { NavLink } from 'react-router';
import styles from './BottomNav.module.css';

const navItems = [
  { to: '/', label: 'Home' },
  { to: '/bookmarks', label: 'Bookmarks' },
  { to: '/history', label: 'History' },
  { to: '/settings', label: 'Settings' },
];

export function BottomNav() {
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
          {item.label}
        </NavLink>
      ))}
    </nav>
  );
}
