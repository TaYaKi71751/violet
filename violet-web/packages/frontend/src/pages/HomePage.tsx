import { useState } from 'react';
import { useSearchParams } from 'react-router';
import { useSearch } from '../hooks/useSearch';
import { useAppStore } from '../stores/app-store';
import { SearchResultGrid } from '../components/search/SearchResultGrid';
import { LoadingSpinner } from '../components/common/LoadingSpinner';
import styles from './HomePage.module.css';

export function HomePage() {
  const [searchParams] = useSearchParams();
  const query = searchParams.get('q') || '';
  const [page, setPage] = useState(0);
  const { contentLanguage } = useAppStore();

  const fullQuery =
    contentLanguage !== 'all' ? `${query} lang:${contentLanguage}` : query;
  const { data, isLoading } = useSearch(fullQuery || ' ', page);

  const totalPages = data ? Math.ceil(data.totalCount / data.pageSize) : 0;

  return (
    <div>
      <h2 className={styles.heading}>
        {query ? `Search: ${query}` : 'Browse'}
      </h2>
      {isLoading && <LoadingSpinner />}
      {data && (
        <>
          <p className={styles.count}>{data.totalCount} results</p>
          <SearchResultGrid articles={data.articles} />
          {totalPages > 1 && (
            <div className={styles.pagination}>
              <button
                disabled={page === 0}
                onClick={() => setPage((p) => p - 1)}
              >
                Prev
              </button>
              <span>
                {page + 1} / {totalPages}
              </span>
              <button
                disabled={page >= totalPages - 1}
                onClick={() => setPage((p) => p + 1)}
              >
                Next
              </button>
            </div>
          )}
        </>
      )}
    </div>
  );
}
