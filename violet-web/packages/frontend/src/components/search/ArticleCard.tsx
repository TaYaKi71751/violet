import { useNavigate } from 'react-router';
import { useTranslation } from 'react-i18next';
import type { Article } from '@violet-web/shared';
import { parsePipeTags, parseTagTuples } from '@violet-web/shared';
import { LazyImage } from '../common/LazyImage';
import { useThumbnail } from '../../hooks/useThumbnail';
import { useIsBookmarked, useToggleBookmark } from '../../hooks/useBookmarks';
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

  const artists = parsePipeTags(article.Artists);
  const language = article.Language ?? '';

  const handleBookmarkClick = (e: React.MouseEvent) => {
    e.stopPropagation();
    toggleBookmark.mutate({ articleId: String(article.Id), isBookmarked: !!isBookmarked });
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
              <span>{isDetail && <span className={styles.detailLabel}>Artist</span>}{artists.join(', ')}</span>
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
                  <span>{groups.join(', ')}</span>
                </div>
              )}
              {series.length > 0 && (
                <div className={styles.detailRow}>
                  <span className={styles.detailLabel}>Series</span>
                  <span>{series.join(', ')}</span>
                </div>
              )}
              {tags.length > 0 && (
                <div className={styles.tagList}>
                  {tags.map((tag) => (
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
                      {tag.tag.replace(/_/g, ' ')}
                    </span>
                  ))}
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </>
  );
}
