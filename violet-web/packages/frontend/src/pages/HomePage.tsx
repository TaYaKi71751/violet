import { useSearch } from '../hooks/useSearch';
import { SearchResultGrid } from '../components/search/SearchResultGrid';
import { LoadingSpinner } from '../components/common/LoadingSpinner';
import styles from './HomePage.module.css';

export function HomePage() {
  const { data, isLoading } = useSearch(' ', 0, 30);

  return (
    <div>
      <h2 className={styles.heading}>Recent</h2>
      {isLoading && <LoadingSpinner />}
      {data && <SearchResultGrid articles={data.articles} />}
    </div>
  );
}
