import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useBookmarkGroups, useBookmarkArticles } from '../hooks/useBookmarks';
import { useArticle } from '../hooks/useArticle';
import { BookmarkGroupList } from '../components/bookmark/BookmarkGroupList';
import { SearchResultGrid } from '../components/search/SearchResultGrid';
import { LoadingSpinner } from '../components/common/LoadingSpinner';
import { useQueries } from '@tanstack/react-query';
import { getArticle } from '../api/content';
import styles from './BookmarksPage.module.css';

export function BookmarksPage() {
  const { t } = useTranslation();
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
      {isLoading && <LoadingSpinner />}
      {!isLoading && <SearchResultGrid articles={articles} />}
    </div>
  );
}
