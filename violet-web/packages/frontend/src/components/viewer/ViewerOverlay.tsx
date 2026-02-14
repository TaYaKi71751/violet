import { useViewerStore } from '../../stores/viewer-store';
import { ViewerSettingsPanel } from './ViewerSettingsPanel';
import styles from './ViewerOverlay.module.css';

interface ViewerOverlayProps {
  currentPage: number;
  totalPages: number;
  onPageChange: (page: number) => void;
  onClose: () => void;
}

export function ViewerOverlay({
  currentPage,
  totalPages,
  onPageChange,
  onClose,
}: ViewerOverlayProps) {
  const { showOverlay, showSettings, toggleOverlay, toggleSettings } = useViewerStore();

  if (!showOverlay) {
    return (
      <>
        <div className={styles.tapZone} onClick={toggleOverlay} />
        {showSettings && <ViewerSettingsPanel />}
      </>
    );
  }

  return (
    <>
      <div className={styles.tapZone} onClick={toggleOverlay} />
      <div className={styles.top}>
        <button className={styles.closeBtn} onClick={onClose}>
          Back
        </button>
        <span className={styles.pageInfo}>
          {currentPage + 1} / {totalPages}
        </span>
        <button
          className={styles.settingsBtn}
          onClick={(e) => {
            e.stopPropagation();
            toggleSettings();
          }}
        >
          Settings
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
    </>
  );
}
