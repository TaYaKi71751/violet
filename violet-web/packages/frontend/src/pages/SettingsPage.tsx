import { useState } from 'react';
import { ViewerSettings } from '../components/viewer/ViewerSettings';
import { useSearchStore } from '../stores/search-store';
import { useSyncStatus, useTriggerSync, useTriggerFullSync } from '../hooks/useSync';
import styles from './SettingsPage.module.css';

export function SettingsPage() {
  const { recentSearches, clearRecentSearches } = useSearchStore();
  const { data: syncStatus } = useSyncStatus();
  const triggerSync = useTriggerSync();
  const triggerFullSync = useTriggerFullSync();
  const [showFullSyncConfirm, setShowFullSyncConfirm] = useState(false);

  const handleSyncNow = () => {
    triggerSync.mutate();
  };

  const handleFullSync = () => {
    setShowFullSyncConfirm(true);
  };

  const confirmFullSync = () => {
    triggerFullSync.mutate();
    setShowFullSyncConfirm(false);
  };

  const formatDate = (dateStr: string | null) => {
    if (!dateStr) return 'Never';
    return new Date(dateStr).toLocaleString();
  };

  const getStatusText = () => {
    if (!syncStatus) return 'Loading...';
    switch (syncStatus.status) {
      case 'idle':
        return 'Idle';
      case 'checking':
        return 'Checking for updates...';
      case 'downloading_full':
        return 'Downloading full database...';
      case 'applying_chunks':
        return 'Applying updates...';
      case 'error':
        return 'Error';
      default:
        return syncStatus.status;
    }
  };

  const isSyncing = syncStatus?.status !== 'idle' && syncStatus?.status !== 'error';

  return (
    <div className={styles.page}>
      <h2 className={styles.heading}>Settings</h2>

      <div className={styles.section}>
        <h3 className={styles.subheading}>Database Sync</h3>

        <div className={styles.syncInfo}>
          <div className={styles.infoRow}>
            <span className={styles.label}>Database:</span>
            <span className={syncStatus?.dbExists ? styles.statusOk : styles.statusError}>
              {syncStatus?.dbExists ? 'Ready' : 'Not Found'}
            </span>
          </div>

          <div className={styles.infoRow}>
            <span className={styles.label}>Last Sync:</span>
            <span>{formatDate(syncStatus?.lastSync || null)}</span>
          </div>

          <div className={styles.infoRow}>
            <span className={styles.label}>Status:</span>
            <span className={isSyncing ? styles.statusSyncing : ''}>
              {getStatusText()}
            </span>
          </div>

          {syncStatus?.progress && (
            <div className={styles.progress}>
              <div className={styles.progressBar}>
                <div
                  className={styles.progressFill}
                  style={{
                    width: `${(syncStatus.progress.current / syncStatus.progress.total) * 100}%`
                  }}
                />
              </div>
              <div className={styles.progressText}>
                {syncStatus.progress.message} ({syncStatus.progress.current}/{syncStatus.progress.total})
              </div>
            </div>
          )}

          {syncStatus?.error && (
            <div className={styles.error}>
              Error: {syncStatus.error}
            </div>
          )}
        </div>

        <div className={styles.syncButtons}>
          <button
            className={styles.syncBtn}
            onClick={handleSyncNow}
            disabled={isSyncing || triggerSync.isPending}
          >
            {triggerSync.isPending ? 'Starting...' : 'Sync Now'}
          </button>

          <button
            className={styles.fullSyncBtn}
            onClick={handleFullSync}
            disabled={isSyncing || triggerFullSync.isPending}
          >
            {triggerFullSync.isPending ? 'Starting...' : 'Re-download DB'}
          </button>
        </div>

        {showFullSyncConfirm && (
          <div className={styles.confirmDialog}>
            <p>This will re-download the entire database. Continue?</p>
            <div className={styles.confirmButtons}>
              <button className={styles.confirmBtn} onClick={confirmFullSync}>
                Yes, Re-download
              </button>
              <button className={styles.cancelBtn} onClick={() => setShowFullSyncConfirm(false)}>
                Cancel
              </button>
            </div>
          </div>
        )}
      </div>

      <ViewerSettings />

      <div className={styles.section}>
        <h3 className={styles.subheading}>Recent Searches</h3>
        {recentSearches.length > 0 ? (
          <>
            <div className={styles.searches}>
              {recentSearches.map((q, i) => (
                <span key={i} className={styles.searchItem}>{q}</span>
              ))}
            </div>
            <button className={styles.clearBtn} onClick={clearRecentSearches}>
              Clear Search History
            </button>
          </>
        ) : (
          <p className={styles.empty}>No recent searches</p>
        )}
      </div>
    </div>
  );
}
