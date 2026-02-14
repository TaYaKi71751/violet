import { useRef } from 'react';
import { useSearchParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { useSearch } from '../hooks/useSearch';
import { useAppStore } from '../stores/app-store';
import { SearchResultGrid } from '../components/search/SearchResultGrid';
import { LoadingSpinner } from '../components/common/LoadingSpinner';
import styles from './HomePage.module.css';

export function HomePage() {
  const { t } = useTranslation();
  const [searchParams, setSearchParams] = useSearchParams();
  const query = searchParams.get('q') || '';
  const page = parseInt(searchParams.get('p') || '0');
  const { contentLanguage } = useAppStore();

  const setPage = (updater: number | ((prev: number) => number)) => {
    const newPage = typeof updater === 'function' ? updater(page) : updater;
    const newParams = new URLSearchParams(searchParams);
    if (newPage === 0) {
      newParams.delete('p');
    } else {
      newParams.set('p', String(newPage));
    }
    setSearchParams(newParams);
  };

  const fullQuery =
    contentLanguage !== 'all' ? `${query} lang:${contentLanguage}` : query;
  const { data, isLoading } = useSearch(fullQuery || ' ', page);

  const totalPages = data ? Math.ceil(data.totalCount / data.pageSize) : 0;
  const lastTotalPagesRef = useRef(0);
  if (totalPages > 0) lastTotalPagesRef.current = totalPages;
  const displayTotalPages = totalPages || lastTotalPagesRef.current;

  return (
    <div className={styles.page}>
      {isLoading && <LoadingSpinner />}
      {data && <SearchResultGrid articles={data.articles} />}
      {displayTotalPages > 1 && (
        <div className={styles.pagination}>
          <button
            disabled={page === 0}
            onClick={() => setPage((p) => p - 1)}
          >
            {t('home.prev')}
          </button>
          <span>
            {page + 1} / {displayTotalPages}
          </span>
          <button
            disabled={page >= displayTotalPages - 1}
            onClick={() => setPage((p) => p + 1)}
          >
            {t('home.next')}
          </button>
        </div>
      )}
    </div>
  );
}
