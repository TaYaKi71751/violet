import type { TagChipData } from '../../hooks/useArticleTagSummary';
import styles from './TagChips.module.css';

interface TagChipsProps {
  tags: TagChipData[];
  selectedTags: Set<string>;
  onToggle: (display: string) => void;
}

export function TagChips({ tags, selectedTags, onToggle }: TagChipsProps) {
  if (tags.length === 0) {
    return null;
  }

  return (
    <div className={styles.container}>
      {tags.map((tag) => {
        const isSelected = selectedTags.has(tag.display);
        // Replace underscores with spaces for display
        const displayText = tag.display.replace(/_/g, ' ');
        return (
          <button
            key={tag.display}
            type="button"
            className={`${styles.chip} ${isSelected ? styles.active : ''}`}
            onClick={() => onToggle(tag.display)}
          >
            {displayText} ({tag.count})
          </button>
        );
      })}
    </div>
  );
}
