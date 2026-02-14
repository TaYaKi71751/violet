import type { Article } from '@violet-web/shared';
import { ArticleCard } from './ArticleCard';
import styles from './SearchResultGrid.module.css';

interface SearchResultGridProps {
  articles: Article[];
}

export function SearchResultGrid({ articles }: SearchResultGridProps) {
  if (articles.length === 0) {
    return <div className={styles.empty}>No results found.</div>;
  }

  return (
    <div className={styles.grid}>
      {articles.map((article) => (
        <ArticleCard key={article.Id} article={article} />
      ))}
    </div>
  );
}
