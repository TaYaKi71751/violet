import { useViewerStore } from '../../stores/viewer-store';
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
  const { showOverlay, toggleOverlay } = useViewerStore();

  if (!showOverlay) {
    return (
      <div className={styles.tapZone} onClick={toggleOverlay} />
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
  );
}
