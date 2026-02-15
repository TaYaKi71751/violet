import { useState, useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import { useViewerStore } from '../../stores/viewer-store';
import { useIsBookmarked, useToggleBookmark } from '../../hooks/useBookmarks';
import { ViewerSettingsPanel } from './ViewerSettingsPanel';
import { PageThumbnailDialog } from './PageThumbnailDialog';
import { CropDialog } from './CropDialog';
import styles from './ViewerOverlay.module.css';

interface ViewerOverlayProps {
  galleryId: number;
  currentPage: number;
  totalPages: number;
  onPageChange: (page: number) => void;
  onClose: () => void;
  thumbnailUrls: string[];
  imageUrls: string[];
}

export function ViewerOverlay({
  galleryId,
  currentPage,
  totalPages,
  onPageChange,
  onClose,
  thumbnailUrls,
  imageUrls,
}: ViewerOverlayProps) {
  const { t } = useTranslation();
  const { showOverlay, showSettings, readDirection, twoPageMode, coverPageMode, toggleOverlay, toggleSettings } = useViewerStore();
  const { data: isBookmarked } = useIsBookmarked(String(galleryId));
  const toggleBookmark = useToggleBookmark();
  const rtl = readDirection === 'rtl';
  const [showThumbnails, setShowThumbnails] = useState(false);
  const [showCropDialog, setShowCropDialog] = useState(false);

  const visiblePages = useMemo(() => {
    if (!twoPageMode) return [currentPage];

    const pages: number[] = [];
    if (coverPageMode === 'cover') {
      if (currentPage === 0) {
        pages.push(0);
      } else {
        if (currentPage < totalPages) pages.push(currentPage);
        if (currentPage + 1 < totalPages) pages.push(currentPage + 1);
      }
    } else {
      const pairStart = Math.floor(currentPage / 2) * 2;
      if (pairStart < totalPages) pages.push(pairStart);
      if (pairStart + 1 < totalPages) pages.push(pairStart + 1);
    }
    return pages;
  }, [currentPage, twoPageMode, coverPageMode, totalPages]);

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

      <div
        className={`${styles.pageIndicator} ${showOverlay ? styles.pageIndicatorAboveSlider : ''}`}
        onClick={(e) => {
          e.stopPropagation();
          setShowThumbnails(true);
        }}
      >
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
            <button
              className={styles.cropBtn}
              onClick={(e) => {
                e.stopPropagation();
                setShowCropDialog(true);
              }}
              aria-label="Crop"
            >
              ✂
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
      {showThumbnails && (
        <PageThumbnailDialog
          thumbnailUrls={thumbnailUrls}
          currentPage={currentPage}
          totalPages={totalPages}
          twoPageMode={twoPageMode}
          coverPageMode={coverPageMode}
          onPageSelect={onPageChange}
          onClose={() => setShowThumbnails(false)}
        />
      )}
      {showCropDialog && (
        <CropDialog
          galleryId={galleryId}
          imageUrls={imageUrls}
          visiblePages={visiblePages}
          onClose={() => setShowCropDialog(false)}
        />
      )}
    </>
  );
}
