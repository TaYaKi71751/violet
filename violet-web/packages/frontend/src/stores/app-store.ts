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

export type ViewMode = 'grid' | 'detail';
export type ScrollMode = 'pagination' | 'infinite';

interface AppState {
  contentLanguage: ContentLanguage;
  uiLanguage: UILanguage;
  themeColor: ThemeColor;
  sidebarCollapsed: boolean;
  viewMode: ViewMode;
  cardMinWidth: number;
  cropColumnWidth: number;
  scrollMode: ScrollMode;
  tagTranslation: boolean;
  aiSearchEnabled: boolean;
  excludedTags: string[];

  setContentLanguage: (lang: ContentLanguage) => void;
  setUILanguage: (lang: UILanguage) => void;
  setThemeColor: (color: ThemeColor) => void;
  toggleSidebar: () => void;
  setViewMode: (mode: ViewMode) => void;
  setCardMinWidth: (width: number) => void;
  setCropColumnWidth: (width: number) => void;
  setScrollMode: (mode: ScrollMode) => void;
  setTagTranslation: (enabled: boolean) => void;
  setAiSearchEnabled: (enabled: boolean) => void;
  addExcludedTag: (tag: string) => void;
  removeExcludedTag: (tag: string) => void;
}

// Helper to get system language
const getSystemLanguage = (): string => {
  const browserLang = navigator.language.toLowerCase();
  if (browserLang.startsWith('ko')) return 'ko';
  if (browserLang.startsWith('ja')) return 'ja';
  if (browserLang.startsWith('zh')) return 'zh';
  return 'en';
};

export const useAppStore = create<AppState>()(
  persist(
    (set) => ({
      contentLanguage: 'all',
      uiLanguage: 'system',
      themeColor: 'purple',
      sidebarCollapsed: false,
      viewMode: 'grid',
      cardMinWidth: 200,
      cropColumnWidth: 240,
      scrollMode: 'infinite',
      tagTranslation: true,
      aiSearchEnabled: false,
      excludedTags: ['female:snuff', 'female:gore'],

      setContentLanguage: (contentLanguage) => set({ contentLanguage }),
      setUILanguage: (uiLanguage) => {
        const actualLang = uiLanguage === 'system' ? getSystemLanguage() : uiLanguage;
        i18n.changeLanguage(actualLang);
        set({ uiLanguage });
      },
      setThemeColor: (themeColor) => set({ themeColor }),
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
    }),
    { name: 'violet-app-settings' },
  ),
);
