import { useNavigate } from 'react-router';
import { useTranslation } from 'react-i18next';
import type { Article } from '@violet-web/shared';
import { parsePipeTags, parseTagTuples, ticksToDate } from '@violet-web/shared';
import { LazyImage } from '../common/LazyImage';
import { useThumbnail } from '../../hooks/useThumbnail';
import { useIsBookmarked, useToggleBookmark } from '../../hooks/useBookmarks';
import { useTagTranslation } from '../../hooks/useTagTranslation';
import type { ViewMode } from '../../stores/app-store';
import styles from './ArticleCard.module.css';

interface ArticleCardProps {
  article: Article;
  viewMode?: ViewMode;
}

const TAG_ORDER: Record<string, number> = { female: 0, male: 1, tag: 2, '': 2 };

function getTagOrder(ns: string): number {
  return TAG_ORDER[ns] ?? 3;
}

export function ArticleCard({ article, viewMode = 'grid' }: ArticleCardProps) {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { data: thumbnailUrl } = useThumbnail(article.Id);
  const { data: isBookmarked } = useIsBookmarked(String(article.Id));
  const toggleBookmark = useToggleBookmark();
  const { translateTag } = useTagTranslation();

  const artists = parsePipeTags(article.Artists);
  const language = article.Language ?? '';

  const handleBookmarkClick = (e: React.MouseEvent) => {
    e.stopPropagation();
    toggleBookmark.mutate({ articleId: String(article.Id), isBookmarked: !!isBookmarked });
  };

  const handleSearchClick = (category: string, value: string) => (e: React.MouseEvent) => {
    e.stopPropagation();
    const encoded = value.replace(/ /g, '_');
    const url = `/?q=${category}:${encoded}`;
    if (e.ctrlKey || e.metaKey) {
      window.open(url, '_blank');
    } else {
      navigate(url);
    }
  };

  const isDetail = viewMode === 'detail';

  const groups = isDetail ? parsePipeTags(article.Groups) : [];
  const series = isDetail ? parsePipeTags(article.Series) : [];
  const tags = isDetail
    ? parseTagTuples(article.Tags)
        .filter((t) => ['female', 'male', 'tag', ''].includes(t.namespace))
        .sort((a, b) => {
          const orderDiff = getTagOrder(a.namespace) - getTagOrder(b.namespace);
          if (orderDiff !== 0) return orderDiff;
          return a.tag.localeCompare(b.tag);
        })
    : [];

  return (
    <>
      <div
        className={`${styles.card} ${isDetail ? styles.detailCard : ''}`}
        onClick={() => navigate(`/viewer/${article.Id}`)}
      >
        <div className={styles.imageWrapper}>
          {thumbnailUrl ? (
            <LazyImage src={thumbnailUrl} alt={article.Title} className={styles.image} />
          ) : (
            <div className={styles.noImage}>{t('article.noImage')}</div>
          )}
          <button
            className={`${styles.bookmarkBtn} ${isBookmarked ? styles.bookmarked : ''}`}
            onClick={handleBookmarkClick}
            disabled={toggleBookmark.isPending}
            aria-label={isBookmarked ? t('article.bookmarked') : t('article.bookmark')}
          >
            {isBookmarked ? '★' : '☆'}
          </button>
          {article.Files != null && (
            <span className={styles.pageCount}>{article.Files}P</span>
          )}
        </div>
        <div className={styles.info}>
          <div className={styles.title}>{article.Title}</div>
          <div className={styles.meta}>
            {artists.length > 0 && (
              <span>
                {isDetail && <span className={styles.detailLabel}>Artist</span>}
                {artists.map((a, i) => (
                  <span key={a}>
                    {i > 0 && ', '}
                    <span className={styles.clickable} onClick={handleSearchClick('artist', a)}>{a}</span>
                  </span>
                ))}
              </span>
            )}
            {language && (
              <span className={styles.lang}>{isDetail && <span className={styles.detailLabel}>Lang</span>}{language}</span>
            )}
          </div>

          {isDetail && (
            <div className={styles.detailInfo}>
              {groups.length > 0 && (
                <div className={styles.detailRow}>
                  <span className={styles.detailLabel}>Group</span>
                  <span>{groups.map((g, i) => (
                    <span key={g}>
                      {i > 0 && ', '}
                      <span className={styles.clickable} onClick={handleSearchClick('group', g)}>{g}</span>
                    </span>
                  ))}</span>
                </div>
              )}
              {series.length > 0 && (
                <div className={styles.detailRow}>
                  <span className={styles.detailLabel}>Series</span>
                  <span>{series.map((s, i) => (
                    <span key={s}>
                      {i > 0 && ', '}
                      <span className={styles.clickable} onClick={handleSearchClick('series', s)}>{s}</span>
                    </span>
                  ))}</span>
                </div>
              )}
              {article.Published != null && (
                <div className={styles.detailRow}>
                  <span className={styles.detailLabel}>Date</span>
                  <span>{(typeof article.Published === 'number'
                    ? ticksToDate(article.Published)
                    : new Date(article.Published)
                  ).toLocaleDateString()}</span>
                </div>
              )}
              {tags.length > 0 && (
                <div className={styles.tagList}>
                  {tags.map((tag) => {
                    const koTag = translateTag(tag.namespace, tag.tag.replace(/_/g, ' '));
                    return (
                      <span
                        key={`${tag.namespace}:${tag.tag}`}
                        className={`${styles.tagChip} ${
                          tag.namespace === 'female'
                            ? styles.tagFemale
                            : tag.namespace === 'male'
                              ? styles.tagMale
                              : styles.tagGeneral
                        }`}
                      >
                        {koTag ?? tag.tag.replace(/_/g, ' ')}
                      </span>
                    );
                  })}
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </>
  );
}
