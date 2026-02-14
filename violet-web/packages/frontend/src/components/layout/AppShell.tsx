import { Outlet, useSearchParams, useLocation } from 'react-router';
import { useTranslation } from 'react-i18next';
import { Sidebar } from './Sidebar';
import { BottomNav } from './BottomNav';
import { SearchBar } from '../search/SearchBar';
import { useIsMobile, useIsDesktop } from '../../hooks/useMediaQuery';
import { useSearch } from '../../hooks/useSearch';
import { useAppStore } from '../../stores/app-store';
import styles from './AppShell.module.css';

export function AppShell() {
  const isMobile = useIsMobile();
  const isDesktop = useIsDesktop();
  const { t } = useTranslation();
  const location = useLocation();
  const [searchParams] = useSearchParams();
  const query = searchParams.get('q') || '';
  const { contentLanguage } = useAppStore();

  const fullQuery = contentLanguage !== 'all' ? `${query} lang:${contentLanguage}` : query;
  const { data } = useSearch(fullQuery || ' ', 0);

  const showSearchBar = location.pathname === '/' || location.pathname === '/bookmarks';

  return (
    <div className={styles.shell}>
      {isDesktop && <Sidebar />}
      <div className={styles.mainArea}>
        {isDesktop && showSearchBar && (
          <div className={styles.searchBar}>
            <SearchBar />
            {data && (
              <div className={styles.results}>
                <span className={styles.count}>{t('home.results', { count: data.totalCount })}</span>
              </div>
            )}
          </div>
        )}
        <main className={styles.content}>
          <Outlet />
        </main>
      </div>
      {isMobile && <BottomNav />}
    </div>
  );
}
