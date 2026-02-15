import { useTranslation } from 'react-i18next';
import type { Article, AiSearchResultItem } from '@violet-web/shared';
import { ArticleCard } from '../search/ArticleCard';
import { useAppStore } from '../../stores/app-store';
import styles from './AiArticleCard.module.css';

interface AiArticleCardProps {
  article: Article;
  result: AiSearchResultItem;
}

export function AiArticleCard({ article, result }: AiArticleCardProps) {
  const { t } = useTranslation();
  const viewMode = useAppStore((s) => s.viewMode);
  const scorePct = Math.round(result.score * 100);

  return (
    <div className={styles.wrapper}>
      <ArticleCard article={article} viewMode={viewMode} />
      <div className={styles.overlay}>
        <span className={styles.scoreBadge} title={t('aiSearch.score')}>
          {scorePct}%
        </span>
        {result.description && (
          <p className={styles.description}>{result.description}</p>
        )}
      </div>
    </div>
  );
}
