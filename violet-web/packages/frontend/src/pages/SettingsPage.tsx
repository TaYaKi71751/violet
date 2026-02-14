import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useSearchStore } from '../stores/search-store';
import { useAppStore } from '../stores/app-store';
import { useSyncStatus, useTriggerSync, useTriggerFullSync } from '../hooks/useSync';
import styles from './SettingsPage.module.css';

export function SettingsPage() {
  const { t } = useTranslation();
  const { recentSearches, clearRecentSearches } = useSearchStore();
  const { contentLanguage, uiLanguage, setContentLanguage, setUILanguage } = useAppStore();
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
    if (!dateStr) return t('settings.sync.never');
    return new Date(dateStr).toLocaleString();
  };

  const getStatusText = () => {
    if (!syncStatus) return t('viewer.loading');
    switch (syncStatus.status) {
      case 'idle':
        return t('settings.sync.idle');
      case 'checking':
        return t('settings.sync.checking');
      case 'downloading_full':
        return t('settings.sync.downloadingFull');
      case 'applying_chunks':
        return t('settings.sync.applyingChunks');
      case 'error':
        return t('settings.sync.error');
      default:
        return syncStatus.status;
    }
  };

  const isSyncing = syncStatus?.status !== 'idle' && syncStatus?.status !== 'error';

  return (
    <div className={styles.page}>
      <h2 className={styles.heading}>{t('settings.heading')}</h2>

      <div className={styles.section}>
        <h3 className={styles.subheading}>{t('settings.language.heading')}</h3>

        <div className={styles.settingGroup}>
          <label className={styles.settingLabel}>{t('settings.language.contentLanguage')}</label>
          <select
            className={styles.select}
            value={contentLanguage}
            onChange={(e) => setContentLanguage(e.target.value as any)}
          >
            <option value="all">{t('settings.language.all')}</option>
            <option value="korean">{t('settings.language.korean')}</option>
            <option value="english">{t('settings.language.english')}</option>
            <option value="japanese">{t('settings.language.japanese')}</option>
            <option value="chinese">{t('settings.language.chinese')}</option>
          </select>
        </div>

        <div className={styles.settingGroup}>
          <label className={styles.settingLabel}>{t('settings.language.uiLanguage')}</label>
          <select
            className={styles.select}
            value={uiLanguage}
            onChange={(e) => setUILanguage(e.target.value as any)}
          >
            <option value="system">{t('settings.language.system')}</option>
            <option value="en">{t('settings.language.en')}</option>
            <option value="ko">{t('settings.language.ko')}</option>
            <option value="ja">{t('settings.language.ja')}</option>
            <option value="zh">{t('settings.language.zh')}</option>
          </select>
        </div>
      </div>

      <div className={styles.section}>
        <h3 className={styles.subheading}>{t('settings.sync.heading')}</h3>

        <div className={styles.syncInfo}>
          <div className={styles.infoRow}>
            <span className={styles.label}>{t('settings.sync.database')}</span>
            <span className={syncStatus?.dbExists ? styles.statusOk : styles.statusError}>
              {syncStatus?.dbExists ? t('settings.sync.ready') : t('settings.sync.notFound')}
            </span>
          </div>

          <div className={styles.infoRow}>
            <span className={styles.label}>{t('settings.sync.lastSync')}</span>
            <span>{formatDate(syncStatus?.lastSync || null)}</span>
          </div>

          <div className={styles.infoRow}>
            <span className={styles.label}>{t('settings.sync.status')}</span>
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
              {t('settings.sync.error')}: {syncStatus.error}
            </div>
          )}
        </div>

        <div className={styles.syncButtons}>
          <button
            className={styles.syncBtn}
            onClick={handleSyncNow}
            disabled={isSyncing || triggerSync.isPending}
          >
            {triggerSync.isPending ? t('settings.sync.starting') : t('settings.sync.syncNow')}
          </button>

          <button
            className={styles.fullSyncBtn}
            onClick={handleFullSync}
            disabled={isSyncing || triggerFullSync.isPending}
          >
            {triggerFullSync.isPending ? t('settings.sync.starting') : t('settings.sync.redownloadDB')}
          </button>
        </div>

        {showFullSyncConfirm && (
          <div className={styles.confirmDialog}>
            <p>{t('settings.sync.confirmRedownload')}</p>
            <div className={styles.confirmButtons}>
              <button className={styles.confirmBtn} onClick={confirmFullSync}>
                {t('settings.sync.yes')}
              </button>
              <button className={styles.cancelBtn} onClick={() => setShowFullSyncConfirm(false)}>
                {t('settings.sync.cancel')}
              </button>
            </div>
          </div>
        )}
      </div>

      <div className={styles.section}>
        <h3 className={styles.subheading}>{t('settings.recentSearches.heading')}</h3>
        {recentSearches.length > 0 ? (
          <>
            <div className={styles.searches}>
              {recentSearches.map((q, i) => (
                <span key={i} className={styles.searchItem}>{q}</span>
              ))}
            </div>
            <button className={styles.clearBtn} onClick={clearRecentSearches}>
              {t('settings.recentSearches.clear')}
            </button>
          </>
        ) : (
          <p className={styles.empty}>{t('settings.recentSearches.empty')}</p>
        )}
      </div>
    </div>
  );
}
