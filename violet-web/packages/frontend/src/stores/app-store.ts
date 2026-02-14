import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import i18n from '../i18n/config';

export type ContentLanguage = 'all' | 'korean' | 'english' | 'japanese' | 'chinese';
export type UILanguage = 'system' | 'en' | 'ko' | 'ja' | 'zh';

interface AppState {
  contentLanguage: ContentLanguage;
  uiLanguage: UILanguage;

  setContentLanguage: (lang: ContentLanguage) => void;
  setUILanguage: (lang: UILanguage) => void;
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

      setContentLanguage: (contentLanguage) => set({ contentLanguage }),
      setUILanguage: (uiLanguage) => {
        const actualLang = uiLanguage === 'system' ? getSystemLanguage() : uiLanguage;
        i18n.changeLanguage(actualLang);
        set({ uiLanguage });
      },
    }),
    { name: 'violet-app-settings' },
  ),
);
