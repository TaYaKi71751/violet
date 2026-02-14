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
  const { contentLanguage, viewMode, setViewMode, cardMinWidth, setCardMinWidth } = useAppStore();
  const searchBarRef = useRef<SearchBarRef>(null);
  const contentRef = useRef<HTMLElement>(null);

  // Scroll content to top on navigation (pathname or query param change)
  useEffect(() => {
    contentRef.current?.scrollTo(0, 0);
  }, [location.pathname, location.search]);

  const fullQuery = contentLanguage !== 'all' ? `${query} lang:${contentLanguage}` : query;
  const { data } = useSearch(fullQuery || ' ', 0);

  const showSearchBar = location.pathname === '/';

  // Handle "/" key to focus search bar on home page
  // Note: bookmarks and history pages will handle "/" key themselves
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement;
      // Ignore if user is typing in an input or textarea
      if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA') {
        return;
      }

      // Only trigger on home page (bookmarks/history have their own search bars)
      if (e.key === '/' && location.pathname === '/') {
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
            <input
              type="range"
              className={styles.cardSizeSlider}
              min={120}
              max={350}
              step={10}
              value={cardMinWidth}
              onChange={(e) => setCardMinWidth(Number(e.target.value))}
              title={`Card width: ${cardMinWidth}px`}
            />
            <label className={styles.viewSwitch} title={viewMode === 'grid' ? 'Detail view' : 'Grid view'}>
              <span className={styles.switchLabel}>▦</span>
              <input
                type="checkbox"
                className={styles.switchInput}
                checked={viewMode === 'detail'}
                onChange={() => setViewMode(viewMode === 'grid' ? 'detail' : 'grid')}
              />
              <span className={styles.switchTrack}>
                <span className={styles.switchThumb} />
              </span>
              <span className={styles.switchLabel}>☰</span>
            </label>
          </div>
        )}
        <main ref={contentRef} className={styles.content}>
          <Outlet />
        </main>
      </div>
      {isMobile && <BottomNav />}
      <Toast />
    </div>
  );
}
