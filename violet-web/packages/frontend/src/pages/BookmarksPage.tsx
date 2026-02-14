import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router';
import { useTranslation } from 'react-i18next';
import { useBookmarkGroups, useBookmarkArticles } from '../hooks/useBookmarks';
import { BookmarkGroupList } from '../components/bookmark/BookmarkGroupList';
import { LocalSearchSection } from '../components/search/LocalSearchSection';
import { SearchResultGrid } from '../components/search/SearchResultGrid';
import { LoadingSpinner } from '../components/common/LoadingSpinner';
import { useQueries } from '@tanstack/react-query';
import { getArticle } from '../api/content';
import { useArticleTagSummary } from '../hooks/useArticleTagSummary';
import { useLocalArticleSearch } from '../hooks/useLocalArticleSearch';
import { useLocalSearchState } from '../hooks/useLocalSearchState';
import { useIsMobile } from '../hooks/useMediaQuery';
import styles from './BookmarksPage.module.css';

export function BookmarksPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const isMobile = useIsMobile();

  const [selectedGroupId, setSelectedGroupId] = useState<number | undefined>(undefined);

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

  // Reset selected tags when group changes
  useEffect(() => {
    resetTags();
  }, [selectedGroupId, resetTags]);

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
      {!isLoading && <SearchResultGrid articles={filteredArticles} />}
    </div>
  );
}
