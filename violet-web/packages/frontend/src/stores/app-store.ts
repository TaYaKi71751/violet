import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import i18n from '../i18n/config';

export type ContentLanguage = 'all' | 'korean' | 'english' | 'japanese' | 'chinese';
export type UILanguage = 'system' | 'en' | 'ko' | 'ja' | 'zh';
export type ThemeColor =
  | 'purple' | 'amber' | 'black' | 'blue' | 'blueGrey' | 'brown'
  | 'cyan' | 'deepOrange' | 'deepPurple' | 'green' | 'grey'
  | 'indigo' | 'lightBlue' | 'lightGreen' | 'lime' | 'orange'
  | 'pink' | 'red' | 'teal' | 'yellow';
export type ThemeMode = 'dark' | 'light' | 'system';

export type ViewMode = 'grid' | 'detail';
export type ScrollMode = 'pagination' | 'infinite';

interface AppState {
  contentLanguage: ContentLanguage;
  uiLanguage: UILanguage;
  themeColor: ThemeColor;
  themeMode: ThemeMode;
  sidebarCollapsed: boolean;
  viewMode: ViewMode;
  cardMinWidth: number;
  cropColumnWidth: number;
  scrollMode: ScrollMode;
  tagTranslation: boolean;
  aiSearchEnabled: boolean;
  excludedTags: string[];
  imageCacheEnabled: boolean;
  imageCacheMaxSizeMB: number;
  imageCacheExpireDays: number;

  setContentLanguage: (lang: ContentLanguage) => void;
  setUILanguage: (lang: UILanguage) => void;
  setThemeColor: (color: ThemeColor) => void;
  setThemeMode: (mode: ThemeMode) => void;
  toggleSidebar: () => void;
  setViewMode: (mode: ViewMode) => void;
  setCardMinWidth: (width: number) => void;
  setCropColumnWidth: (width: number) => void;
  setScrollMode: (mode: ScrollMode) => void;
  setTagTranslation: (enabled: boolean) => void;
  setAiSearchEnabled: (enabled: boolean) => void;
  addExcludedTag: (tag: string) => void;
  removeExcludedTag: (tag: string) => void;
  setImageCacheEnabled: (enabled: boolean) => void;
  setImageCacheMaxSizeMB: (size: number) => void;
  setImageCacheExpireDays: (days: number) => void;
}

// Helper to get system language
const getSystemLanguage = (): string => {
  const browserLang = navigator.language.toLowerCase();
  if (browserLang.startsWith('ko')) return 'ko';
  if (browserLang.startsWith('ja')) return 'ja';
  if (browserLang.startsWith('zh')) return 'zh';
  return 'en';
};

const getDefaultContentLanguage = (): ContentLanguage => {
  const lang = getSystemLanguage();
  const map: Record<string, ContentLanguage> = {
    ko: 'korean',
    ja: 'japanese',
    zh: 'chinese',
    en: 'english',
  };
  return map[lang] || 'all';
};

const getDefaultTagTranslation = (): boolean => {
  return getSystemLanguage() === 'ko';
};

export const useAppStore = create<AppState>()(
  persist(
    (set) => ({
      contentLanguage: getDefaultContentLanguage(),
      uiLanguage: 'system',
      themeColor: 'purple',
      themeMode: 'dark',
      sidebarCollapsed: false,
      viewMode: 'grid',
      cardMinWidth: 200,
      cropColumnWidth: 240,
      scrollMode: 'pagination',
      tagTranslation: getDefaultTagTranslation(),
      aiSearchEnabled: false,
      excludedTags: ['female:snuff', 'female:gore'],
      imageCacheEnabled: true,
      imageCacheMaxSizeMB: 500,
      imageCacheExpireDays: 7,

      setContentLanguage: (contentLanguage) => set({ contentLanguage }),
      setUILanguage: (uiLanguage) => {
        const actualLang = uiLanguage === 'system' ? getSystemLanguage() : uiLanguage;
        i18n.changeLanguage(actualLang);
        set({ uiLanguage });
      },
      setThemeColor: (themeColor) => set({ themeColor }),
      setThemeMode: (themeMode) => set({ themeMode }),
      toggleSidebar: () => set((state) => ({ sidebarCollapsed: !state.sidebarCollapsed })),
      setViewMode: (viewMode) => set({ viewMode }),
      setCardMinWidth: (cardMinWidth) => set({ cardMinWidth }),
      setCropColumnWidth: (cropColumnWidth) => set({ cropColumnWidth }),
      setScrollMode: (scrollMode) => set({ scrollMode }),
      setTagTranslation: (tagTranslation) => set({ tagTranslation }),
      setAiSearchEnabled: (aiSearchEnabled) => set({ aiSearchEnabled }),
      addExcludedTag: (tag) =>
        set((state) => ({
          excludedTags: state.excludedTags.includes(tag)
            ? state.excludedTags
            : [...state.excludedTags, tag],
        })),
      removeExcludedTag: (tag) =>
        set((state) => ({
          excludedTags: state.excludedTags.filter((t) => t !== tag),
        })),
      setImageCacheEnabled: (imageCacheEnabled) => set({ imageCacheEnabled }),
      setImageCacheMaxSizeMB: (imageCacheMaxSizeMB) => set({ imageCacheMaxSizeMB }),
      setImageCacheExpireDays: (imageCacheExpireDays) => set({ imageCacheExpireDays }),
    }),
    { name: 'violet-app-settings' },
  ),
);
