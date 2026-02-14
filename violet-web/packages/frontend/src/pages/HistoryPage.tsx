import { useState, useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { useReadHistory } from '../hooks/useReadHistory';
import { useQueries } from '@tanstack/react-query';
import { getArticle } from '../api/content';
import { LocalSearchSection } from '../components/search/LocalSearchSection';
import { SearchResultGrid } from '../components/search/SearchResultGrid';
import { LoadingSpinner } from '../components/common/LoadingSpinner';
import { useArticleTagSummary } from '../hooks/useArticleTagSummary';
import { useLocalArticleSearch } from '../hooks/useLocalArticleSearch';
import { useLocalSearchState } from '../hooks/useLocalSearchState';
import { useIsMobile } from '../hooks/useMediaQuery';
import styles from './HistoryPage.module.css';

export function HistoryPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const isMobile = useIsMobile();
  const [searchParams, setSearchParams] = useSearchParams();
  const page = parseInt(searchParams.get('p') || '0');

  const { data, isLoading } = useReadHistory(page);

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

  // Extract tag summary from all articles in current page
  const tagSummary = useArticleTagSummary(articles);

  // Filter articles based on URL query parameter
  const filteredArticles = useLocalArticleSearch(articles);

  // Local search state
  const { selectedTags, searchBarRef, getSuggestions, handleTagToggle, resetTags } =
    useLocalSearchState({
      basePath: '/history',
      tagSummary,
      onReset: () => {
        const newParams = new URLSearchParams(searchParams);
        newParams.delete('q');
        const newSearch = newParams.toString();
        navigate('/history' + (newSearch ? `?${newSearch}` : ''), { replace: true });
      },
    });

  const totalPages = data ? Math.ceil(data.totalCount / data.pageSize) : 0;

  // Reset selected tags when page changes
  useEffect(() => {
    resetTags();
  }, [page, resetTags]);

  return (
    <div className={styles.page}>
      <h2 className={styles.heading}>{t('history.heading')}</h2>

      {!isMobile && (
        <LocalSearchSection
          basePath="/history"
          searchBarRef={searchBarRef}
          getSuggestions={getSuggestions}
          tagSummary={tagSummary}
          selectedTags={selectedTags}
          onTagToggle={handleTagToggle}
          resultCount={filteredArticles.length}
          isLoading={isLoading}
        />
      )}

      {isLoading && <LoadingSpinner />}
      {!isLoading && <SearchResultGrid articles={filteredArticles} />}

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
