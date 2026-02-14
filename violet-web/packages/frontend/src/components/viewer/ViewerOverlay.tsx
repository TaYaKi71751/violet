import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useViewerStore } from '../../stores/viewer-store';
import { useBookmarkGroups, useIsBookmarked } from '../../hooks/useBookmarks';
import { AddBookmarkDialog } from '../bookmark/AddBookmarkDialog';
import { ViewerSettingsPanel } from './ViewerSettingsPanel';
import styles from './ViewerOverlay.module.css';

interface ViewerOverlayProps {
  galleryId: number;
  currentPage: number;
  totalPages: number;
  onPageChange: (page: number) => void;
  onClose: () => void;
}

export function ViewerOverlay({
  galleryId,
  currentPage,
  totalPages,
  onPageChange,
  onClose,
}: ViewerOverlayProps) {
  const { t } = useTranslation();
  const { showOverlay, showSettings, toggleOverlay, toggleSettings } = useViewerStore();
  const { data: isBookmarked } = useIsBookmarked(String(galleryId));
  const { data: groups } = useBookmarkGroups();
  const [showBookmarkDialog, setShowBookmarkDialog] = useState(false);

  const handleLeftTap = () => {
    // Left third - could be used for previous page in paged mode
    if (currentPage > 0) {
      onPageChange(currentPage - 1);
    }
  };

  const handleRightTap = () => {
    // Right third - could be used for next page in paged mode
    if (currentPage < totalPages - 1) {
      onPageChange(currentPage + 1);
    }
  };

  if (!showOverlay) {
    return (
      <>
        <div className={styles.tapZoneLeft} onClick={handleLeftTap} />
        <div className={styles.tapZoneCenter} onClick={toggleOverlay} />
        <div className={styles.tapZoneRight} onClick={handleRightTap} />
        <div className={styles.pageIndicator}>
          {t('viewer.pageInfo', { current: currentPage + 1, total: totalPages })}
        </div>
        {showSettings && <ViewerSettingsPanel />}
      </>
    );
  }

  return (
    <>
      <div className={styles.tapZoneLeft} onClick={handleLeftTap} />
      <div className={styles.tapZoneCenter} onClick={toggleOverlay} />
      <div className={styles.tapZoneRight} onClick={handleRightTap} />
      <div className={styles.top}>
        <button className={styles.closeBtn} onClick={onClose}>
          {t('viewer.back')}
        </button>
        <button
          className={`${styles.bookmarkBtn} ${isBookmarked ? styles.bookmarked : ''}`}
          onClick={(e) => {
            e.stopPropagation();
            setShowBookmarkDialog(true);
          }}
          aria-label={isBookmarked ? t('article.bookmarked') : t('article.bookmark')}
        >
          {isBookmarked ? '★' : '☆'}
        </button>
        <span className={styles.pageInfo}>
          {t('viewer.pageInfo', { current: currentPage + 1, total: totalPages })}
        </span>
        <button
          className={styles.settingsBtn}
          onClick={(e) => {
            e.stopPropagation();
            toggleSettings();
          }}
        >
          {t('viewer.settings')}
        </button>
      </div>
      <div className={styles.bottom}>
        <input
          type="range"
          className={styles.slider}
          min={0}
          max={totalPages - 1}
          value={currentPage}
          onChange={(e) => onPageChange(Number(e.target.value))}
        />
      </div>
      {showSettings && <ViewerSettingsPanel />}
      {showBookmarkDialog && groups && (
        <AddBookmarkDialog
          articleId={String(galleryId)}
          groups={groups}
          onClose={() => setShowBookmarkDialog(false)}
        />
      )}
    </>
  );
}
