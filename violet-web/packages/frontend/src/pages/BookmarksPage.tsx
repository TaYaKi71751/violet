import { useState, useEffect, useCallback, useRef } from 'react';
import { useNavigate, useLocation } from 'react-router';
import { useTranslation } from 'react-i18next';
import { useBookmarkGroups, useBookmarkArticles } from '../hooks/useBookmarks';
import { BookmarkGroupList } from '../components/bookmark/BookmarkGroupList';
import { LocalSearchSection } from '../components/search/LocalSearchSection';
import { SearchResultGrid } from '../components/search/SearchResultGrid';
import { LoadingSpinner } from '../components/common/LoadingSpinner';
import { InfiniteScroll } from '../components/common/InfiniteScroll';
import { useQueries } from '@tanstack/react-query';
import { getArticle } from '../api/content';
import { useArticleTagSummary } from '../hooks/useArticleTagSummary';
import { useLocalArticleSearch } from '../hooks/useLocalArticleSearch';
import { useLocalSearchState } from '../hooks/useLocalSearchState';
import { useIsMobile } from '../hooks/useMediaQuery';
import { useAppStore } from '../stores/app-store';
import styles from './BookmarksPage.module.css';

const PAGE_SIZE = 30;

export function BookmarksPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const location = useLocation();
  const isMobile = useIsMobile();
  const { scrollMode } = useAppStore();

  const [selectedGroupId, setSelectedGroupId] = useState<number | undefined>(() => {
    const saved = sessionStorage.getItem(`bookmarks:group:${location.key}`);
    return saved ? parseInt(saved) : undefined;
  });
  const [visibleCount, setVisibleCount] = useState(() => {
    const saved = sessionStorage.getItem(`bookmarks:visible:${location.key}`);
    return saved ? parseInt(saved) : PAGE_SIZE;
  });

  const { data: groups, isLoading: groupsLoading } = useBookmarkGroups();
  const { data: bookmarkArticles, isLoading: articlesLoading } =
    useBookmarkArticles(selectedGroupId);

  const articleQueries = useQueries({
    queries: (bookmarkArticles ?? []).map((ba) => ({
      queryKey: ['article', parseInt(ba.Article)],
      queryFn: () => getArticle(parseInt(ba.Article)),
      enabled: !!ba.Article,
    })),
  });

  const articles = articleQueries
    .map((q) => q.data)
    .filter((a): a is NonNullable<typeof a> => !!a);

  const isLoading = groupsLoading || articlesLoading || articleQueries.some((q) => q.isLoading);

  // Extract tag summary from all articles in current group
  const tagSummary = useArticleTagSummary(articles);

  // Filter articles based on URL query parameter
  const filteredArticles = useLocalArticleSearch(articles);

  // Memoize reset callback
  const handleReset = useCallback(() => {
    navigate('/bookmarks', { replace: true });
  }, [navigate]);

  // Local search state
  const { selectedTags, searchBarRef, getSuggestions, handleTagToggle, resetTags } =
    useLocalSearchState({
      basePath: '/bookmarks',
      tagSummary,
      onReset: handleReset,
    });

  // Persist selectedGroupId and visibleCount to sessionStorage for scroll restoration
  useEffect(() => {
    if (selectedGroupId !== undefined) {
      sessionStorage.setItem(`bookmarks:group:${location.key}`, String(selectedGroupId));
    } else {
      sessionStorage.removeItem(`bookmarks:group:${location.key}`);
    }
  }, [selectedGroupId, location.key]);

  useEffect(() => {
    sessionStorage.setItem(`bookmarks:visible:${location.key}`, String(visibleCount));
  }, [visibleCount, location.key]);

  // Reset selected tags and visible count when group changes
  // Use a ref to track the previous group so we only reset on actual user-initiated changes,
  // not on the initial mount where we restore from sessionStorage.
  const prevGroupRef = useRef(selectedGroupId);
  useEffect(() => {
    if (prevGroupRef.current !== selectedGroupId) {
      prevGroupRef.current = selectedGroupId;
      resetTags();
      setVisibleCount(PAGE_SIZE);
    }
  }, [selectedGroupId, resetTags]);

  const handleLoadMore = useCallback(() => {
    setVisibleCount((prev) => prev + PAGE_SIZE);
  }, []);

  const displayedArticles =
    scrollMode === 'infinite'
      ? filteredArticles.slice(0, visibleCount)
      : filteredArticles;

  const hasMore = scrollMode === 'infinite' && visibleCount < filteredArticles.length;

  return (
    <div>
      <h2 className={styles.heading}>{t('bookmarks.heading')}</h2>
      {groups && (
        <BookmarkGroupList
          groups={groups}
          selectedId={selectedGroupId}
          onSelect={setSelectedGroupId}
        />
      )}

      {!isMobile && (
        <LocalSearchSection
          basePath="/bookmarks"
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
      {!isLoading && scrollMode === 'infinite' ? (
        <InfiniteScroll
          hasMore={hasMore}
          loading={false}
          onLoadMore={handleLoadMore}
        >
          <SearchResultGrid articles={displayedArticles} />
        </InfiniteScroll>
      ) : (
        !isLoading && <SearchResultGrid articles={displayedArticles} />
      )}
    </div>
  );
}
