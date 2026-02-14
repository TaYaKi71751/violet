import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useReadHistory } from '../hooks/useReadHistory';
import { useQueries } from '@tanstack/react-query';
import { getArticle } from '../api/content';
import { SearchResultGrid } from '../components/search/SearchResultGrid';
import { LoadingSpinner } from '../components/common/LoadingSpinner';
import styles from './HistoryPage.module.css';

export function HistoryPage() {
  const { t } = useTranslation();
  const [page, setPage] = useState(0);
  const { data, isLoading } = useReadHistory(page);

  const articleQueries = useQueries({
    queries: (data?.logs ?? []).map((log) => ({
      queryKey: ['article', parseInt(log.Article)],
      queryFn: () => getArticle(parseInt(log.Article)),
      enabled: !!log.Article,
    })),
  });

  const articles = articleQueries
    .map((q) => q.data)
    .filter((a): a is NonNullable<typeof a> => !!a);

  const totalPages = data ? Math.ceil(data.totalCount / data.pageSize) : 0;

  return (
    <div>
      <h2 className={styles.heading}>{t('history.heading')}</h2>
      {isLoading && <LoadingSpinner />}
      {!isLoading && <SearchResultGrid articles={articles} />}
      {totalPages > 1 && (
        <div className={styles.pagination}>
          <button disabled={page === 0} onClick={() => setPage((p) => p - 1)}>
            {t('home.prev')}
          </button>
          <span>
            {page + 1} / {totalPages}
          </span>
          <button
            disabled={page >= totalPages - 1}
            onClick={() => setPage((p) => p + 1)}
          >
            {t('home.next')}
          </button>
        </div>
      )}
    </div>
  );
}
