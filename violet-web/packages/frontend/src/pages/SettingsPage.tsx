import { useState, useRef, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { HelpCircle } from 'lucide-react';

import { useAppStore } from '../stores/app-store';
import { useSyncStatus, useTriggerSync, useTriggerFullSync } from '../hooks/useSync';
import { useSuggestionCacheStatus, useRebuildSuggestionCache } from '../hooks/useSuggestionCache';
import { useSuggestions } from '../hooks/useSuggestions';
import { useTagTranslation } from '../hooks/useTagTranslation';
import { getCacheStats, clearAllCache } from '../services/image-cache';
import styles from './SettingsPage.module.css';

const themeColors = [
  'purple', 'amber', 'black', 'blue', 'blueGrey', 'brown',
  'cyan', 'deepOrange', 'deepPurple', 'green', 'grey',
  'indigo', 'lightBlue', 'lightGreen', 'lime', 'orange',
  'pink', 'red', 'teal', 'yellow'
] as const;

export function SettingsPage() {
  const { t } = useTranslation();
  const { contentLanguage, uiLanguage, themeColor, scrollMode, tagTranslation, aiSearchEnabled, excludedTags, imageCacheEnabled, imageCacheMaxSizeMB, imageCacheExpireDays, setContentLanguage, setUILanguage, setThemeColor, setScrollMode, setTagTranslation, setAiSearchEnabled, addExcludedTag, removeExcludedTag, setImageCacheEnabled, setImageCacheMaxSizeMB, setImageCacheExpireDays } = useAppStore();
  const [showAiSearchHelp, setShowAiSearchHelp] = useState(false);
  const [showImageCacheHelp, setShowImageCacheHelp] = useState(false);
  const helpRef = useRef<HTMLDivElement>(null);
  const imageCacheHelpRef = useRef<HTMLDivElement>(null);
  const { data: syncStatus } = useSyncStatus();
  const triggerSync = useTriggerSync();
  const triggerFullSync = useTriggerFullSync();
  const [showFullSyncConfirm, setShowFullSyncConfirm] = useState(false);
  const { data: cacheStatus } = useSuggestionCacheStatus();
  const rebuildCache = useRebuildSuggestionCache();

  const [cacheStats, setCacheStats] = useState<{ totalSizeBytes: number; itemCount: number }>({ totalSizeBytes: 0, itemCount: 0 });
  const [isClearing, setIsClearing] = useState(false);

  useEffect(() => {
    getCacheStats().then(setCacheStats);
  }, []);

  const handleClearCache = async () => {
    setIsClearing(true);
    await clearAllCache();
    setCacheStats({ totalSizeBytes: 0, itemCount: 0 });
    setIsClearing(false);
  };

  const formatCacheSize = (bytes: number) => {
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  };

  const [tagInput, setTagInput] = useState('');
  const [tagDropdownOpen, setTagDropdownOpen] = useState(false);
  const [tagHighlightedIndex, setTagHighlightedIndex] = useState(0);
  const tagInputRef = useRef<HTMLInputElement>(null);
  const tagWrapperRef = useRef<HTMLDivElement>(null);
  const { data: tagSuggestions } = useSuggestions(tagInput);
  const { translateTag } = useTagTranslation();

  const filteredSuggestions = (tagSuggestions?.suggestions ?? []).filter(
    (s) => !excludedTags.includes(s.display),
  );

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
      case 'building_cache':
        return t('settings.sync.buildingCache');
      case 'error':
        return t('settings.sync.error');
      default:
        return syncStatus.status;
    }
  };

  const isSyncing = syncStatus?.status !== 'idle' && syncStatus?.status !== 'error';

  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (helpRef.current && !helpRef.current.contains(e.target as Node)) {
        setShowAiSearchHelp(false);
      }
    };
    if (showAiSearchHelp) {
      document.addEventListener('mousedown', handleClickOutside);
    }
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [showAiSearchHelp]);

  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (imageCacheHelpRef.current && !imageCacheHelpRef.current.contains(e.target as Node)) {
        setShowImageCacheHelp(false);
      }
    };
    if (showImageCacheHelp) {
      document.addEventListener('mousedown', handleClickOutside);
    }
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [showImageCacheHelp]);

  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (tagWrapperRef.current && !tagWrapperRef.current.contains(e.target as Node)) {
        setTagDropdownOpen(false);
      }
    };
    if (tagDropdownOpen) {
      document.addEventListener('mousedown', handleClickOutside);
    }
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [tagDropdownOpen]);

  useEffect(() => {
    setTagHighlightedIndex(0);
  }, [filteredSuggestions.length]);

  const handleTagSelect = (display: string) => {
    addExcludedTag(display);
    setTagInput('');
    setTagDropdownOpen(false);
    tagInputRef.current?.focus();
  };

  const handleTagKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (!tagDropdownOpen || filteredSuggestions.length === 0) {
      if (e.key === 'Enter' && tagInput.trim()) {
        e.preventDefault();
        handleTagSelect(tagInput.trim());
      }
      return;
    }
    switch (e.key) {
      case 'Escape':
        setTagDropdownOpen(false);
        e.preventDefault();
        break;
      case 'ArrowDown':
        setTagHighlightedIndex((prev) =>
          prev < filteredSuggestions.length - 1 ? prev + 1 : prev,
        );
        e.preventDefault();
        break;
      case 'ArrowUp':
        setTagHighlightedIndex((prev) => (prev > 0 ? prev - 1 : 0));
        e.preventDefault();
        break;
      case 'Enter':
        e.preventDefault();
        if (tagHighlightedIndex < filteredSuggestions.length) {
          handleTagSelect(filteredSuggestions[tagHighlightedIndex].display);
        }
        break;
    }
  };

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
            <option value="eo">{t('settings.language.eo')}</option>
            <option value="it">{t('settings.language.it')}</option>
            <option value="pt">{t('settings.language.pt')}</option>
          </select>
        </div>
      </div>

      <div className={styles.section}>
        <h3 className={styles.subheading}>{t('settings.theme.heading')}</h3>
        <p className={styles.themeDesc}>{t('settings.theme.description')}</p>
        <div className={styles.colorGrid}>
          {themeColors.map((color) => {
            const logoSrc = color === 'purple' ? '/logos/logo.png' : `/logos/logo-${color}.png`;
            return (
              <div
                key={color}
                className={`${styles.colorOption} ${themeColor === color ? styles.colorActive : ''}`}
                onClick={() => setThemeColor(color)}
              >
                <img src={logoSrc} alt={color} className={styles.colorLogo} />
              </div>
            );
          })}
        </div>
      </div>

      <div className={styles.section}>
        <h3 className={styles.subheading}>{t('settings.display.heading')}</h3>

        <div className={styles.settingGroup}>
          <label className={styles.settingLabel}>{t('settings.display.scrollMode')}</label>
          <select
            className={styles.select}
            value={scrollMode}
            onChange={(e) => setScrollMode(e.target.value as any)}
          >
            <option value="pagination">{t('settings.display.pagination')}</option>
            <option value="infinite">{t('settings.display.infinite')}</option>
          </select>
        </div>

      </div>

      <div className={styles.section}>
        <h3 className={styles.subheading}>{t('settings.tagTranslation.heading')}</h3>

        <div className={styles.toggleRow}>
          <div className={styles.toggleInfo}>
            <span className={styles.toggleLabel}>{t('settings.tagTranslation.korean')}</span>
            <span className={styles.toggleDesc}>{t('settings.tagTranslation.koreanDesc')}</span>
          </div>
          <label className={styles.toggle}>
            <input
              type="checkbox"
              checked={tagTranslation}
              onChange={(e) => setTagTranslation(e.target.checked)}
            />
            <span className={styles.toggleTrack} />
          </label>
        </div>
      </div>

      <div className={styles.section}>
        <h3 className={styles.subheading}>{t('settings.excludedTags.heading')}</h3>
        <p className={styles.excludedTagsDesc}>{t('settings.excludedTags.description')}</p>

        <div className={styles.excludedTagChips}>
          {excludedTags.map((tag) => (
            <span key={tag} className={styles.excludedTagChip}>
              {tag}
              <button
                type="button"
                className={styles.excludedTagRemove}
                onClick={() => removeExcludedTag(tag)}
                aria-label={`Remove ${tag}`}
              >
                &times;
              </button>
            </span>
          ))}
        </div>

        <div className={styles.tagInputWrapper} ref={tagWrapperRef}>
          <input
            ref={tagInputRef}
            type="text"
            className={styles.tagInput}
            placeholder={t('settings.excludedTags.placeholder')}
            value={tagInput}
            onChange={(e) => {
              setTagInput(e.target.value);
              setTagDropdownOpen(e.target.value.trim().length > 0);
            }}
            onFocus={() => {
              if (tagInput.trim().length > 0) setTagDropdownOpen(true);
            }}
            onKeyDown={handleTagKeyDown}
          />
          {tagDropdownOpen && filteredSuggestions.length > 0 && (
            <div className={styles.tagDropdown}>
              {filteredSuggestions.map((item, index) => (
                <button
                  key={item.display}
                  type="button"
                  className={`${styles.tagDropdownItem} ${index === tagHighlightedIndex ? styles.highlighted : ''}`}
                  onClick={() => handleTagSelect(item.display)}
                  onMouseEnter={() => setTagHighlightedIndex(index)}
                >
                  <span>
                    {item.display}
                    {(() => {
                      const parts = item.display.split(':');
                      if (parts.length === 2) {
                        const ko = translateTag(parts[0], parts[1]);
                        if (ko) return ` (${ko})`;
                      }
                      return null;
                    })()}
                  </span>
                  <span className={styles.tagDropdownItemCount}>{item.count.toLocaleString()}</span>
                </button>
              ))}
            </div>
          )}
        </div>

        <p className={styles.excludedTagsDesc} style={{ marginTop: '8px' }}>
          {t('settings.excludedTags.defaultNote')}
        </p>
      </div>

      <div className={styles.section}>
        <div className={styles.sectionHeader}>
          <h3 className={styles.subheading}>{t('settings.aiSearch.heading')}</h3>
          <div className={styles.helpWrapper} ref={helpRef}>
            <button
              className={styles.helpBtn}
              onClick={() => setShowAiSearchHelp((v) => !v)}
              aria-label="Help"
            >
              <HelpCircle size={16} />
            </button>
            {showAiSearchHelp && (
              <div className={styles.helpPopover}>
                <p>{t('settings.aiSearch.helpText')}</p>
                <a
                  href="https://github.com/project-violet/violet/tree/dev/violet-search"
                  target="_blank"
                  rel="noopener noreferrer"
                  className={styles.helpLink}
                >
                  violet-search GitHub
                </a>
              </div>
            )}
          </div>
        </div>

        <div className={styles.toggleRow}>
          <div className={styles.toggleInfo}>
            <span className={styles.toggleLabel}>{t('settings.aiSearch.enable')}</span>
            <span className={styles.toggleDesc}>{t('settings.aiSearch.enableDesc')}</span>
          </div>
          <label className={styles.toggle}>
            <input
              type="checkbox"
              checked={aiSearchEnabled}
              onChange={(e) => setAiSearchEnabled(e.target.checked)}
            />
            <span className={styles.toggleTrack} />
          </label>
        </div>
      </div>

      <div className={styles.section}>
        <div className={styles.sectionHeader}>
          <h3 className={styles.subheading}>{t('settings.imageCache.heading')}</h3>
          <div className={styles.helpWrapper} ref={imageCacheHelpRef}>
            <button
              className={styles.helpBtn}
              onClick={() => setShowImageCacheHelp((v) => !v)}
              aria-label="Help"
            >
              <HelpCircle size={16} />
            </button>
            {showImageCacheHelp && (
              <div className={styles.helpPopover}>
                <p>{t('settings.imageCache.helpText')}</p>
              </div>
            )}
          </div>
        </div>

        <div className={styles.toggleRow}>
          <div className={styles.toggleInfo}>
            <span className={styles.toggleLabel}>{t('settings.imageCache.enable')}</span>
            <span className={styles.toggleDesc}>{t('settings.imageCache.enableDesc')}</span>
          </div>
          <label className={styles.toggle}>
            <input
              type="checkbox"
              checked={imageCacheEnabled}
              onChange={(e) => setImageCacheEnabled(e.target.checked)}
            />
            <span className={styles.toggleTrack} />
          </label>
        </div>

        {imageCacheEnabled && (
          <>
            <div className={styles.settingGroup}>
              <label className={styles.settingLabel}>{t('settings.imageCache.maxSize')}</label>
              <select
                className={styles.select}
                value={imageCacheMaxSizeMB}
                onChange={(e) => setImageCacheMaxSizeMB(Number(e.target.value))}
              >
                <option value={100}>100 MB</option>
                <option value={250}>250 MB</option>
                <option value={500}>500 MB</option>
                <option value={1024}>1 GB</option>
                <option value={2048}>2 GB</option>
              </select>
            </div>

            <div className={styles.settingGroup}>
              <label className={styles.settingLabel}>{t('settings.imageCache.expireDays')}</label>
              <select
                className={styles.select}
                value={imageCacheExpireDays}
                onChange={(e) => setImageCacheExpireDays(Number(e.target.value))}
              >
                <option value={1}>{t('settings.imageCache.expireDaysDesc', { days: 1 })}</option>
                <option value={3}>{t('settings.imageCache.expireDaysDesc', { days: 3 })}</option>
                <option value={7}>{t('settings.imageCache.expireDaysDesc', { days: 7 })}</option>
                <option value={14}>{t('settings.imageCache.expireDaysDesc', { days: 14 })}</option>
                <option value={30}>{t('settings.imageCache.expireDaysDesc', { days: 30 })}</option>
              </select>
            </div>

            <div className={styles.syncInfo}>
              <div className={styles.infoRow}>
                <span className={styles.label}>{t('settings.imageCache.cacheSize')}</span>
                <span>{formatCacheSize(cacheStats.totalSizeBytes)}</span>
              </div>
              <div className={styles.infoRow}>
                <span className={styles.label}>{t('settings.imageCache.itemCount')}</span>
                <span>{t('settings.imageCache.items', { count: cacheStats.itemCount })}</span>
              </div>
            </div>

            <div className={styles.syncButtons}>
              <button
                className={styles.syncBtn}
                onClick={handleClearCache}
                disabled={isClearing || cacheStats.itemCount === 0}
              >
                {isClearing ? t('settings.imageCache.clearing') : t('settings.imageCache.clearCache')}
              </button>
            </div>
          </>
        )}
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
            <span className={styles.label}>{t('settings.sync.lastSyncDb')}</span>
            <span>{formatDate(syncStatus?.lastSyncDb || null)}</span>
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
        <h3 className={styles.subheading}>{t('settings.suggestions.heading')}</h3>

        <div className={styles.syncInfo}>
          <div className={styles.infoRow}>
            <span className={styles.label}>{t('settings.suggestions.status')}</span>
            <span className={cacheStatus?.built ? styles.statusOk : styles.statusError}>
              {cacheStatus?.built ? t('settings.suggestions.built') : t('settings.suggestions.notBuilt')}
            </span>
          </div>

          {cacheStatus?.built && cacheStatus.counts && (
            <div className={styles.infoRow}>
              <span className={styles.label}>{t('settings.suggestions.totalTags')}</span>
              <span>{Object.values(cacheStatus.counts).reduce((sum, c) => sum + (c as number), 0).toLocaleString()}</span>
            </div>
          )}
        </div>

        <div className={styles.syncButtons}>
          <button
            className={styles.syncBtn}
            onClick={() => rebuildCache.mutate()}
            disabled={rebuildCache.isPending}
          >
            {rebuildCache.isPending
              ? t('settings.suggestions.building')
              : cacheStatus?.built
              ? t('settings.suggestions.rebuild')
              : t('settings.suggestions.build')}
          </button>
        </div>
      </div>

    </div>
  );
}
