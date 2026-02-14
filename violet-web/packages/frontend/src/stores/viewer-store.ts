import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import i18n from '../i18n/config';

export type ViewMode = 'vertical' | 'horizontal';
export type PageMode = 'scroll' | 'paged';
export type ReadDirection = 'ltr' | 'rtl';
export type CoverPageMode = 'cover' | 'normal';
export type Language = 'system' | 'en' | 'ko' | 'ja' | 'zh';

interface ViewerState {
  viewMode: ViewMode;
  pageMode: PageMode;
  readDirection: ReadDirection;
  padding: number;
  showOverlay: boolean;
  twoPageMode: boolean;
  coverPageMode: CoverPageMode;
  showSettings: boolean;
  language: Language;

  setViewMode: (mode: ViewMode) => void;
  setPageMode: (mode: PageMode) => void;
  setReadDirection: (dir: ReadDirection) => void;
  setPadding: (padding: number) => void;
  toggleOverlay: () => void;
  setTwoPageMode: (enabled: boolean) => void;
  setCoverPageMode: (mode: CoverPageMode) => void;
  toggleSettings: () => void;
  setLanguage: (lang: Language) => void;
}

// Helper to get system language
const getSystemLanguage = (): string => {
  const browserLang = navigator.language.toLowerCase();
  if (browserLang.startsWith('ko')) return 'ko';
  if (browserLang.startsWith('ja')) return 'ja';
  if (browserLang.startsWith('zh')) return 'zh';
  return 'en';
};

export const useViewerStore = create<ViewerState>()(
  persist(
    (set) => ({
      viewMode: 'vertical',
      pageMode: 'scroll',
      readDirection: 'rtl',
      padding: 0,
      showOverlay: true,
      twoPageMode: false,
      coverPageMode: 'cover',
      showSettings: false,
      language: 'system',

      setViewMode: (viewMode) => set({ viewMode }),
      setPageMode: (pageMode) => set({ pageMode }),
      setReadDirection: (readDirection) => set({ readDirection }),
      setPadding: (padding) => set({ padding }),
      toggleOverlay: () => set((s) => ({ showOverlay: !s.showOverlay })),
      setTwoPageMode: (twoPageMode) => set({ twoPageMode }),
      setCoverPageMode: (coverPageMode) => set({ coverPageMode }),
      toggleSettings: () => set((s) => ({ showSettings: !s.showSettings })),
      setLanguage: (language) => {
        const actualLang = language === 'system' ? getSystemLanguage() : language;
        i18n.changeLanguage(actualLang);
        set({ language });
      },
    }),
    { name: 'violet-viewer-settings' },
  ),
);
