import { useState } from 'react';
import { useNavigate } from 'react-router';
import { useTranslation } from 'react-i18next';
import type { Article } from '@violet-web/shared';
import { parsePipeTags } from '@violet-web/shared';
import { LazyImage } from '../common/LazyImage';
import { useThumbnail } from '../../hooks/useThumbnail';
import { useBookmarkGroups, useIsBookmarked } from '../../hooks/useBookmarks';
import { AddBookmarkDialog } from '../bookmark/AddBookmarkDialog';
import styles from './ArticleCard.module.css';

interface ArticleCardProps {
  article: Article;
}

export function ArticleCard({ article }: ArticleCardProps) {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { data: thumbnailUrl } = useThumbnail(article.Id);
  const { data: isBookmarked } = useIsBookmarked(String(article.Id));
  const { data: groups } = useBookmarkGroups();
  const [showBookmarkDialog, setShowBookmarkDialog] = useState(false);

  const artists = parsePipeTags(article.Artists);
  const language = article.Language ?? '';

  const handleBookmarkClick = (e: React.MouseEvent) => {
    e.stopPropagation();
    setShowBookmarkDialog(true);
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
            aria-label={isBookmarked ? t('article.bookmarked') : t('article.bookmark')}
          >
            {isBookmarked ? '★' : '☆'}
          </button>
        </div>
        <div className={styles.info}>
          <div className={styles.title}>{article.Title}</div>
          <div className={styles.meta}>
            {artists.length > 0 && <span>{artists.join(', ')}</span>}
            {language && <span className={styles.lang}>{language}</span>}
          </div>
        </div>
      </div>

      {showBookmarkDialog && groups && (
        <AddBookmarkDialog
          articleId={String(article.Id)}
          groups={groups}
          onClose={() => setShowBookmarkDialog(false)}
        />
      )}
    </>
  );
}
