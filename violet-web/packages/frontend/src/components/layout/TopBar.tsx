import { useNavigate } from 'react-router';
import { SearchBar } from '../search/SearchBar';
import styles from './TopBar.module.css';

export function TopBar() {
  const navigate = useNavigate();

  return (
    <header className={styles.topbar}>
      <div className={styles.brand} onClick={() => navigate('/')}>
        Violet
      </div>
      <div className={styles.searchWrapper}>
        <SearchBar />
      </div>
    </header>
  );
}
