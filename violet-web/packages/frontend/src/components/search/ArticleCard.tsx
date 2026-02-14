import { useNavigate } from 'react-router';
import type { Article } from '@violet-web/shared';
import { parsePipeTags } from '@violet-web/shared';
import { LazyImage } from '../common/LazyImage';
import { useThumbnail } from '../../hooks/useThumbnail';
import styles from './ArticleCard.module.css';

interface ArticleCardProps {
  article: Article;
}

export function ArticleCard({ article }: ArticleCardProps) {
  const navigate = useNavigate();
  const { data: thumbnailUrl } = useThumbnail(article.Id);

  const artists = parsePipeTags(article.Artists);
  const language = article.Language ?? '';

  return (
    <div
      className={styles.card}
      onClick={() => navigate(`/article/${article.Id}`)}
    >
      <div className={styles.imageWrapper}>
        {thumbnailUrl ? (
          <LazyImage src={thumbnailUrl} alt={article.Title} className={styles.image} />
        ) : (
          <div className={styles.noImage}>No Image</div>
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
  );
}
