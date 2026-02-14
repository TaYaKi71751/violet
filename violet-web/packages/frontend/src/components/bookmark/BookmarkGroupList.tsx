import type { BookmarkGroup } from '@violet-web/shared';
import styles from './BookmarkGroupList.module.css';

interface BookmarkGroupListProps {
  groups: BookmarkGroup[];
  selectedId: number | undefined;
  onSelect: (id: number | undefined) => void;
}

export function BookmarkGroupList({ groups, selectedId, onSelect }: BookmarkGroupListProps) {
  return (
    <div className={styles.list}>
      <button
        className={`${styles.item} ${selectedId === undefined ? styles.active : ''}`}
        onClick={() => onSelect(undefined)}
      >
        All
      </button>
      {groups.map((g) => (
        <button
          key={g.Id}
          className={`${styles.item} ${selectedId === g.Id ? styles.active : ''}`}
          onClick={() => onSelect(g.Id)}
        >
          {g.Name}
        </button>
      ))}
    </div>
  );
}
