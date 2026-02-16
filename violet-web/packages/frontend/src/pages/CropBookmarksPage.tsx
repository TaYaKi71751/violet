import { useCallback, useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router';
import { useTranslation } from 'react-i18next';
import { useCropBookmarks, useDeleteCropBookmark } from '../hooks/useBookmarks';
import { useUserCropBookmarks } from '../hooks/useUserCropBookmarks';
import { CropBookmarkGrid } from '../components/bookmark/CropBookmarkGrid';
import { LoadingSpinner } from '../components/common/LoadingSpinner';
import { LocalSearchSection } from '../components/search/LocalSearchSection';
import { useQueries } from '@tanstack/react-query';
import { getArticle } from '../api/content';
import { useArticleTagSummary } from '../hooks/useArticleTagSummary';
import { useLocalSearchState } from '../hooks/useLocalSearchState';
import { useIsMobile } from '../hooks/useMediaQuery';
import { useAppStore } from '../stores/app-store';
import type { Article } from '@violet-web/shared';
import styles from './CropBookmarksPage.module.css';

export function CropBookmarksPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const isMobile = useIsMobile();

  const { data: cropBookmarks, isLoading } = useCropBookmarks();
  const deleteCropMutation = useDeleteCropBookmark();
  const cropColumnWidth = useAppStore((s) => s.cropColumnWidth);
  const setCropColumnWidth = useAppStore((s) => s.setCropColumnWidth);

  const [showUserBookmarks, setShowUserBookmarks] = useState(false);
  const { data: userCropBookmarks, isLoading: isUserLoading } =
    useUserCropBookmarks(showUserBookmarks);

  const handleDelete = useCallback(
    (id: number) => {
      if (id < 0) return; // user bookmarks are read-only
      deleteCropMutation.mutate(id);
    },
    [deleteCropMutation],
  );

  const displayCrops = showUserBookmarks
    ? (userCropBookmarks ?? [])
    : (cropBookmarks ?? []);
  const loading = showUserBookmarks ? isUserLoading : isLoading;

  // Fetch articles for tag summary
  const articleQueries = useQueries({
    queries: displayCrops.map((crop) => ({
      queryKey: ['article', crop.Article],
      queryFn: () => getArticle(crop.Article),
      enabled: !!crop.Article,
    })),
  });

  const articles = articleQueries
    .map((q) => q.data)
    .filter((a): a is NonNullable<typeof a> => !!a);

  const tagSummary = useArticleTagSummary(articles);

  const handleReset = useCallback(() => {
    navigate('/crop-bookmarks', { replace: true });
  }, [navigate]);

  const { selectedTags, searchBarRef, getSuggestions, handleTagToggle, resetTags } =
    useLocalSearchState({
      basePath: '/crop-bookmarks',
      tagSummary,
      onReset: handleReset,
    });

  // Reset tags when showUserBookmarks changes
  const prevShowUserRef = useRef(showUserBookmarks);
  useEffect(() => {
    if (prevShowUserRef.current !== showUserBookmarks) {
      prevShowUserRef.current = showUserBookmarks;
      resetTags();
    }
  }, [showUserBookmarks, resetTags]);

  // Filter crops based on selected tags
  const filteredCrops = selectedTags.size === 0
    ? displayCrops
    : displayCrops.filter((crop) => {
        const article = articles.find((a) => a.Id === crop.Article);
        if (!article) return false;

        // Check if article has ALL selected tags
        const articleTags = new Set<string>();
        if (article.Artists) articleTags.add(`artist:${article.Artists}`);
        if (article.Series) articleTags.add(`series:${article.Series}`);
        if (article.Type) articleTags.add(`type:${article.Type}`);
        if (article.Language) articleTags.add(`lang:${article.Language}`);
        if (article.Tags) {
          article.Tags.split('|').forEach((tag) => {
            const [category, name] = tag.split(':');
            if (category && name) articleTags.add(`${category}:${name}`);
          });
        }
        if (article.Characters) {
          article.Characters.split('|').forEach((char) => {
            articleTags.add(`character:${char}`);
          });
        }

        return Array.from(selectedTags).every((selectedTag) =>
          articleTags.has(selectedTag),
        );
      });

  return (
    <div>
      <div className={styles.header}>
        <h2 className={styles.heading}>Crop Bookmarks</h2>
        <label className={styles.toggleRow}>
          <span className={styles.toggleLabel}>{t('crop.userBookmarks')}</span>
          <span className={styles.toggle}>
            <input
              type="checkbox"
              checked={showUserBookmarks}
              onChange={(e) => setShowUserBookmarks(e.target.checked)}
            />
            <span className={styles.toggleTrack} />
          </span>
        </label>
        <input
          type="range"
          className={styles.sizeSlider}
          min={120}
          max={400}
          step={10}
          value={cropColumnWidth}
          onChange={(e) => setCropColumnWidth(Number(e.target.value))}
        />
      </div>

      {!isMobile && (
        <LocalSearchSection
          basePath="/crop-bookmarks"
          searchBarRef={searchBarRef}
          getSuggestions={getSuggestions}
          tagSummary={tagSummary}
          selectedTags={selectedTags}
          onTagToggle={handleTagToggle}
          resultCount={filteredCrops.length}
          isLoading={loading}
        />
      )}

      {loading && <LoadingSpinner />}
      {!loading && (
        <CropBookmarkGrid
          crops={filteredCrops}
          columnWidth={cropColumnWidth}
          onDelete={handleDelete}
        />
      )}
    </div>
  );
}
