import { useCallback } from 'react';
import { useCropBookmarks, useDeleteCropBookmark } from '../hooks/useBookmarks';
import { CropBookmarkGrid } from '../components/bookmark/CropBookmarkGrid';
import { LoadingSpinner } from '../components/common/LoadingSpinner';
import styles from './CropBookmarksPage.module.css';

export function CropBookmarksPage() {
  const { data: cropBookmarks, isLoading } = useCropBookmarks();
  const deleteCropMutation = useDeleteCropBookmark();

  const handleDelete = useCallback(
    (id: number) => {
      deleteCropMutation.mutate(id);
    },
    [deleteCropMutation],
  );

  return (
    <div>
      <h2 className={styles.heading}>Crop Bookmarks</h2>
      {isLoading && <LoadingSpinner />}
      {!isLoading && (
        <CropBookmarkGrid
          crops={cropBookmarks ?? []}
          onDelete={handleDelete}
        />
      )}
    </div>
  );
}
