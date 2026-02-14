import { NavLink } from 'react-router';
import styles from './Sidebar.module.css';

const navItems = [
  { to: '/', label: 'Home' },
  { to: '/search', label: 'Search' },
  { to: '/bookmarks', label: 'Bookmarks' },
  { to: '/history', label: 'History' },
  { to: '/settings', label: 'Settings' },
];

export function Sidebar() {
  return (
    <nav className={styles.sidebar}>
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
