import { useCallback } from 'react';
import { useCropBookmarks, useDeleteCropBookmark } from '../hooks/useBookmarks';
import { CropBookmarkGrid } from '../components/bookmark/CropBookmarkGrid';
import { LoadingSpinner } from '../components/common/LoadingSpinner';
import { useAppStore } from '../stores/app-store';
import styles from './CropBookmarksPage.module.css';

export function CropBookmarksPage() {
  const { data: cropBookmarks, isLoading } = useCropBookmarks();
  const deleteCropMutation = useDeleteCropBookmark();
  const cropColumnWidth = useAppStore((s) => s.cropColumnWidth);
  const setCropColumnWidth = useAppStore((s) => s.setCropColumnWidth);

  const handleDelete = useCallback(
    (id: number) => {
      deleteCropMutation.mutate(id);
    },
    [deleteCropMutation],
  );

  return (
    <div>
      <div className={styles.header}>
        <h2 className={styles.heading}>Crop Bookmarks</h2>
        <input
          type="range"
          className={styles.sizeSlider}
          min={120}
          max={400}
          step={10}
          value={cropColumnWidth}
          onChange={(e) => setCropColumnWidth(Number(e.target.value))}
        />
      </div>
      {isLoading && <LoadingSpinner />}
      {!isLoading && (
        <CropBookmarkGrid
          crops={cropBookmarks ?? []}
          columnWidth={cropColumnWidth}
          onDelete={handleDelete}
        />
      )}
    </div>
  );
}
