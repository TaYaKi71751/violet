import { useState } from 'react';
import { useParams, useNavigate } from 'react-router';
import { parsePipeTags, parseTagTuples } from '@violet-web/shared';
import { useArticle } from '../hooks/useArticle';
import { useBookmarkGroups, useIsBookmarked } from '../hooks/useBookmarks';
import { AddBookmarkDialog } from '../components/bookmark/AddBookmarkDialog';
import { LazyImage } from '../components/common/LazyImage';
import { LoadingSpinner } from '../components/common/LoadingSpinner';
import { getProxyImageUrl } from '../api/proxy';
import styles from './ArticlePage.module.css';

export function ArticlePage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const articleId = parseInt(id!);
  const { data: article, isLoading } = useArticle(articleId);
  const { data: isBookmarked } = useIsBookmarked(id!);
  const { data: groups } = useBookmarkGroups();
  const [showBookmarkDialog, setShowBookmarkDialog] = useState(false);

  if (isLoading) return <LoadingSpinner />;
  if (!article) return <div>Article not found</div>;

  const artists = parsePipeTags(article.Artists);
  const tags = parseTagTuples(article.Tags);
  const series = parsePipeTags(article.Series);
  const characters = parsePipeTags(article.Characters);
  const thumbnailUrl = article.Thumbnail
    ? getProxyImageUrl(article.Thumbnail)
    : undefined;

  return (
    <div className={styles.page}>
      <div className={styles.header}>
        {thumbnailUrl && (
          <div className={styles.coverWrapper}>
            <LazyImage src={thumbnailUrl} alt={article.Title} className={styles.cover} />
          </div>
        )}
        <div className={styles.details}>
          <h1 className={styles.title}>{article.Title}</h1>
          <div className={styles.meta}>
            {artists.length > 0 && (
              <div className={styles.field}>
                <span className={styles.label}>Artist</span>
                <span>{artists.join(', ')}</span>
              </div>
            )}
            {article.Language && (
              <div className={styles.field}>
                <span className={styles.label}>Language</span>
                <span>{article.Language}</span>
              </div>
            )}
            {article.Type && (
              <div className={styles.field}>
                <span className={styles.label}>Type</span>
                <span>{article.Type}</span>
              </div>
            )}
            {article.Files && (
              <div className={styles.field}>
                <span className={styles.label}>Pages</span>
                <span>{article.Files}</span>
              </div>
            )}
            {series.length > 0 && (
              <div className={styles.field}>
                <span className={styles.label}>Series</span>
                <span>{series.join(', ')}</span>
              </div>
            )}
            {characters.length > 0 && (
              <div className={styles.field}>
                <span className={styles.label}>Characters</span>
                <span>{characters.join(', ')}</span>
              </div>
            )}
          </div>

          <div className={styles.actions}>
            <button
              className={styles.readBtn}
              onClick={() => navigate(`/viewer/${article.Id}`)}
            >
              Read
            </button>
            <button
              className={styles.bookmarkBtn}
              onClick={() => setShowBookmarkDialog(true)}
            >
              {isBookmarked ? 'Bookmarked' : 'Bookmark'}
            </button>
          </div>
        </div>
      </div>

      {tags.length > 0 && (
        <div className={styles.tags}>
          {tags.map((t, i) => (
            <span key={i} className={styles.tag}>
              {t.namespace ? `${t.namespace}:` : ''}
              {t.tag}
            </span>
          ))}
        </div>
      )}

      {showBookmarkDialog && groups && (
        <AddBookmarkDialog
          articleId={String(article.Id)}
          groups={groups}
          onClose={() => setShowBookmarkDialog(false)}
        />
      )}
    </div>
  );
}
