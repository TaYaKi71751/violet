import { useCallback, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useCropBookmarks, useDeleteCropBookmark } from '../hooks/useBookmarks';
import { useUserCropBookmarks } from '../hooks/useUserCropBookmarks';
import { CropBookmarkGrid } from '../components/bookmark/CropBookmarkGrid';
import { LoadingSpinner } from '../components/common/LoadingSpinner';
import { useAppStore } from '../stores/app-store';
import styles from './CropBookmarksPage.module.css';

export function CropBookmarksPage() {
  const { data: cropBookmarks, isLoading } = useCropBookmarks();
  const deleteCropMutation = useDeleteCropBookmark();
  const cropColumnWidth = useAppStore((s) => s.cropColumnWidth);
  const setCropColumnWidth = useAppStore((s) => s.setCropColumnWidth);

  const { t } = useTranslation();
  const [showUserBookmarks, setShowUserBookmarks] = useState(false);
  const { data: userCropBookmarks, isLoading: isUserLoading } =
    useUserCropBookmarks(showUserBookmarks);

  const handleDelete = useCallback(
    (id: number) => {
      if (id < 0) return; // user bookmarks are read-only
      deleteCropMutation.mutate(id);
    },
    [deleteCropMutation],
  );

  const displayCrops = showUserBookmarks
    ? (userCropBookmarks ?? [])
    : (cropBookmarks ?? []);
  const loading = showUserBookmarks ? isUserLoading : isLoading;

  return (
    <div>
      <div className={styles.header}>
        <h2 className={styles.heading}>Crop Bookmarks</h2>
        <label className={styles.toggleRow}>
          <span className={styles.toggleLabel}>{t('crop.userBookmarks')}</span>
          <span className={styles.toggle}>
            <input
              type="checkbox"
              checked={showUserBookmarks}
              onChange={(e) => setShowUserBookmarks(e.target.checked)}
            />
            <span className={styles.toggleTrack} />
          </span>
        </label>
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
      {loading && <LoadingSpinner />}
      {!loading && (
        <CropBookmarkGrid
          crops={displayCrops}
          columnWidth={cropColumnWidth}
          onDelete={handleDelete}
        />
      )}
    </div>
  );
}
