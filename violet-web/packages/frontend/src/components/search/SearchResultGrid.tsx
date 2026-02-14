import { useTranslation } from 'react-i18next';
import type { Article } from '@violet-web/shared';
import { ArticleCard } from './ArticleCard';
import { useAppStore } from '../../stores/app-store';
import styles from './SearchResultGrid.module.css';

interface SearchResultGridProps {
  articles: Article[];
}

export function SearchResultGrid({ articles }: SearchResultGridProps) {
  const { t } = useTranslation();
  const viewMode = useAppStore((s) => s.viewMode);

  if (articles.length === 0) {
    return <div className={styles.empty}>{t('search.noResults')}</div>;
  }

  return (
    <div className={styles.grid}>
      {articles.map((article) => (
        <ArticleCard key={article.Id} article={article} viewMode={viewMode} />
      ))}
    </div>
  );
}
