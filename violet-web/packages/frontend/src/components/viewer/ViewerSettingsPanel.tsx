import { useViewerStore } from '../../stores/viewer-store';
import styles from './ViewerSettingsPanel.module.css';

export function ViewerSettingsPanel() {
  const {
    viewMode,
    pageMode,
    readDirection,
    twoPageMode,
    coverPageMode,
    padding,
    setViewMode,
    setPageMode,
    setReadDirection,
    setTwoPageMode,
    setCoverPageMode,
    setPadding,
    toggleSettings,
  } = useViewerStore();

  return (
    <div className={styles.overlay} onClick={toggleSettings}>
      <div className={styles.panel} onClick={(e) => e.stopPropagation()}>
        <div className={styles.header}>
          <h3>Viewer Settings</h3>
          <button className={styles.closeBtn} onClick={toggleSettings}>
            ×
          </button>
        </div>

        <div className={styles.content}>
          {/* Page Mode */}
          <div className={styles.section}>
            <label className={styles.label}>Reading Mode</label>
            <div className={styles.buttons}>
              <button
                className={`${styles.btn} ${pageMode === 'scroll' ? styles.active : ''}`}
                onClick={() => setPageMode('scroll')}
              >
                Scroll
              </button>
              <button
                className={`${styles.btn} ${pageMode === 'paged' ? styles.active : ''}`}
                onClick={() => setPageMode('paged')}
              >
                Paged
              </button>
            </div>
          </div>

          {/* View Mode (for scroll mode) */}
          {pageMode === 'scroll' && (
            <div className={styles.section}>
              <label className={styles.label}>Scroll Direction</label>
              <div className={styles.buttons}>
                <button
                  className={`${styles.btn} ${viewMode === 'vertical' ? styles.active : ''}`}
                  onClick={() => setViewMode('vertical')}
                >
                  Vertical
                </button>
                <button
                  className={`${styles.btn} ${viewMode === 'horizontal' ? styles.active : ''}`}
                  onClick={() => setViewMode('horizontal')}
                >
                  Horizontal
                </button>
              </div>
            </div>
          )}

          {/* Page Layout */}
          <div className={styles.section}>
            <label className={styles.label}>Page Layout</label>
            <div className={styles.buttons}>
              <button
                className={`${styles.btn} ${!twoPageMode ? styles.active : ''}`}
                onClick={() => setTwoPageMode(false)}
              >
                Single Page
              </button>
              <button
                className={`${styles.btn} ${twoPageMode ? styles.active : ''}`}
                onClick={() => setTwoPageMode(true)}
              >
                Two Pages
              </button>
            </div>
          </div>

          {/* Read Direction */}
          <div className={styles.section}>
            <label className={styles.label}>Reading Direction</label>
            <div className={styles.buttons}>
              <button
                className={`${styles.btn} ${readDirection === 'ltr' ? styles.active : ''}`}
                onClick={() => setReadDirection('ltr')}
              >
                Left to Right
              </button>
              <button
                className={`${styles.btn} ${readDirection === 'rtl' ? styles.active : ''}`}
                onClick={() => setReadDirection('rtl')}
              >
                Right to Left
              </button>
            </div>
          </div>

          {/* Cover Page Mode (only for two-page mode) */}
          {twoPageMode && (
            <div className={styles.section}>
              <label className={styles.label}>First Page</label>
              <div className={styles.buttons}>
                <button
                  className={`${styles.btn} ${coverPageMode === 'cover' ? styles.active : ''}`}
                  onClick={() => setCoverPageMode('cover')}
                >
                  Cover (Alone)
                </button>
                <button
                  className={`${styles.btn} ${coverPageMode === 'normal' ? styles.active : ''}`}
                  onClick={() => setCoverPageMode('normal')}
                >
                  Normal (Pair)
                </button>
              </div>
            </div>
          )}

          {/* Padding (for vertical scroll) */}
          {pageMode === 'scroll' && viewMode === 'vertical' && (
            <div className={styles.section}>
              <label className={styles.label}>Padding: {padding}px</label>
              <input
                type="range"
                min={0}
                max={50}
                value={padding}
                onChange={(e) => setPadding(Number(e.target.value))}
                className={styles.slider}
              />
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
