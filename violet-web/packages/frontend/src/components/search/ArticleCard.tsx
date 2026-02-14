import { useNavigate } from 'react-router';
import { useTranslation } from 'react-i18next';
import type { Article } from '@violet-web/shared';
import { parsePipeTags } from '@violet-web/shared';
import { LazyImage } from '../common/LazyImage';
import { useThumbnail } from '../../hooks/useThumbnail';
import { useIsBookmarked, useToggleBookmark } from '../../hooks/useBookmarks';
import styles from './ArticleCard.module.css';

interface ArticleCardProps {
  article: Article;
}

export function ArticleCard({ article }: ArticleCardProps) {
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

  return (
    <>
      <div
        className={styles.card}
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
            {artists.length > 0 && <span>{artists.join(', ')}</span>}
            {language && <span className={styles.lang}>{language}</span>}
          </div>
        </div>
      </div>
    </>
  );
}
