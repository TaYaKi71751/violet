import type { RefObject } from 'react';
import { useTranslation } from 'react-i18next';
import { SearchBar, type SearchBarRef } from './SearchBar';
import { TagChips } from './TagChips';
import type { TagChipData } from '../../hooks/useArticleTagSummary';
import type { TagEntry } from '@violet-web/shared';
import styles from './LocalSearchSection.module.css';

interface LocalSearchSectionProps {
  basePath: string;
  searchBarRef: RefObject<SearchBarRef | null>;
  getSuggestions: (input: string) => TagEntry[];
  tagSummary: TagChipData[];
  selectedTags: Set<string>;
  onTagToggle: (display: string) => void;
  resultCount?: number;
  isLoading?: boolean;
}

export function LocalSearchSection({
  basePath,
  searchBarRef,
  getSuggestions,
  tagSummary,
  selectedTags,
  onTagToggle,
  resultCount,
  isLoading,
}: LocalSearchSectionProps) {
  const { t } = useTranslation();

  return (
    <div className={styles.container}>
      <div className={styles.searchBar}>
        <SearchBar
          ref={searchBarRef}
          getSuggestions={getSuggestions}
          basePath={basePath}
        />
        {!isLoading && resultCount !== undefined && resultCount > 0 && (
          <div className={styles.resultCount}>
            {t('home.results', { count: resultCount })}
          </div>
        )}
      </div>

      {!isLoading && tagSummary.length > 0 && (
        <TagChips
          tags={tagSummary}
          selectedTags={selectedTags}
          onToggle={onTagToggle}
        />
      )}
    </div>
  );
}
