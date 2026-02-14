import { useTranslation } from 'react-i18next';
import { useViewerStore } from '../../stores/viewer-store';
import { useIsBookmarked, useToggleBookmark } from '../../hooks/useBookmarks';
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
  const { showOverlay, showSettings, readDirection, toggleOverlay, toggleSettings } = useViewerStore();
  const { data: isBookmarked } = useIsBookmarked(String(galleryId));
  const toggleBookmark = useToggleBookmark();
  const rtl = readDirection === 'rtl';

  const handleLeftTap = () => {
    if (rtl) {
      if (currentPage < totalPages - 1) onPageChange(currentPage + 1);
    } else {
      if (currentPage > 0) onPageChange(currentPage - 1);
    }
  };

  const handleRightTap = () => {
    if (rtl) {
      if (currentPage > 0) onPageChange(currentPage - 1);
    } else {
      if (currentPage < totalPages - 1) onPageChange(currentPage + 1);
    }
  };

  return (
    <>
      <div className={styles.tapZoneLeft} onClick={handleLeftTap} />
      <div className={styles.tapZoneCenter} onClick={toggleOverlay} />
      <div className={styles.tapZoneRight} onClick={handleRightTap} />

      <div className={`${styles.pageIndicator} ${showOverlay ? styles.pageIndicatorAboveSlider : ''}`}>
        {t('viewer.pageInfo', { current: currentPage + 1, total: totalPages })}
      </div>

      {showOverlay && (
        <>
          <div className={styles.top}>
            <button className={styles.closeBtn} onClick={onClose}>
              {t('viewer.back')}
            </button>
            <button
              className={`${styles.bookmarkBtn} ${isBookmarked ? styles.bookmarked : ''}`}
              onClick={(e) => {
                e.stopPropagation();
                toggleBookmark.mutate({ articleId: String(galleryId), isBookmarked: !!isBookmarked });
              }}
              disabled={toggleBookmark.isPending}
              aria-label={isBookmarked ? t('article.bookmarked') : t('article.bookmark')}
            >
              {isBookmarked ? '★' : '☆'}
            </button>
            <div style={{ flex: 1 }} />
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
        </>
      )}
      {showSettings && <ViewerSettingsPanel />}
    </>
  );
}
