import { useRef, useEffect } from 'react';
import { Outlet, useSearchParams, useLocation } from 'react-router';
import { useTranslation } from 'react-i18next';
import { Sidebar } from './Sidebar';
import { BottomNav } from './BottomNav';
import { SearchBar, type SearchBarRef } from '../search/SearchBar';
import { Toast } from '../common/Toast';
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
  const searchBarRef = useRef<SearchBarRef>(null);

  const fullQuery = contentLanguage !== 'all' ? `${query} lang:${contentLanguage}` : query;
  const { data } = useSearch(fullQuery || ' ', 0);

  const showSearchBar = location.pathname === '/' || location.pathname === '/bookmarks' || location.pathname === '/history';

  // Handle "/" key to focus search bar on home, bookmarks, and history pages
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement;
      // Ignore if user is typing in an input or textarea
      if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA') {
        return;
      }

      // Only trigger on home, bookmarks, or history pages
      const validPaths = ['/', '/bookmarks', '/history'];
      if (e.key === '/' && validPaths.includes(location.pathname)) {
        e.preventDefault();
        searchBarRef.current?.focus();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [location.pathname]);

  return (
    <div className={styles.shell}>
      {isDesktop && <Sidebar />}
      <div className={styles.mainArea}>
        {isDesktop && showSearchBar && (
          <div className={styles.searchBar}>
            <SearchBar ref={searchBarRef} />
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
      <Toast />
    </div>
  );
}
