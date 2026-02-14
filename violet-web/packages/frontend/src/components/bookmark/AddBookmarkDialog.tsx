import { useState } from 'react';
import type { BookmarkGroup } from '@violet-web/shared';
import { useAddBookmark } from '../../hooks/useBookmarks';
import styles from './AddBookmarkDialog.module.css';

interface AddBookmarkDialogProps {
  articleId: string;
  groups: BookmarkGroup[];
  onClose: () => void;
}

export function AddBookmarkDialog({ articleId, groups, onClose }: AddBookmarkDialogProps) {
  const [selectedGroup, setSelectedGroup] = useState(1);
  const addBookmark = useAddBookmark();

  const handleAdd = () => {
    addBookmark.mutate(
      { Article: articleId, GroupId: selectedGroup },
      { onSuccess: onClose },
    );
  };

  return (
    <div className={styles.overlay} onClick={onClose}>
      <div className={styles.dialog} onClick={(e) => e.stopPropagation()}>
        <h3>Add Bookmark</h3>
        <select
          className={styles.select}
          value={selectedGroup}
          onChange={(e) => setSelectedGroup(Number(e.target.value))}
        >
          {groups.map((g) => (
            <option key={g.Id} value={g.Id}>
              {g.Name}
            </option>
          ))}
        </select>
        <div className={styles.actions}>
          <button className={styles.cancelBtn} onClick={onClose}>
            Cancel
          </button>
          <button
            className={styles.addBtn}
            onClick={handleAdd}
            disabled={addBookmark.isPending}
          >
            Add
          </button>
        </div>
      </div>
    </div>
  );
}
