import { NavLink } from 'react-router';
import styles from './BottomNav.module.css';

const navItems = [
  { to: '/', label: 'Home' },
  { to: '/search', label: 'Search' },
  { to: '/bookmarks', label: 'Bookmarks' },
  { to: '/history', label: 'History' },
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
