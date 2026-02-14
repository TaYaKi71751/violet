import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export type ViewMode = 'vertical' | 'horizontal';
export type PageMode = 'scroll' | 'paged';
export type ReadDirection = 'ltr' | 'rtl';
export type CoverPageMode = 'cover' | 'normal';

interface ViewerState {
  viewMode: ViewMode;
  pageMode: PageMode;
  readDirection: ReadDirection;
  padding: number;
  showOverlay: boolean;
  twoPageMode: boolean;
  coverPageMode: CoverPageMode;
  showSettings: boolean;

  setViewMode: (mode: ViewMode) => void;
  setPageMode: (mode: PageMode) => void;
  setReadDirection: (dir: ReadDirection) => void;
  setPadding: (padding: number) => void;
  toggleOverlay: () => void;
  setTwoPageMode: (enabled: boolean) => void;
  setCoverPageMode: (mode: CoverPageMode) => void;
  toggleSettings: () => void;
}

export const useViewerStore = create<ViewerState>()(
  persist(
    (set) => ({
      viewMode: 'vertical',
      pageMode: 'scroll',
      readDirection: 'rtl',
      padding: 0,
      showOverlay: false,
      twoPageMode: false,
      coverPageMode: 'cover',
      showSettings: false,

      setViewMode: (viewMode) => set({ viewMode }),
      setPageMode: (pageMode) => set({ pageMode }),
      setReadDirection: (readDirection) => set({ readDirection }),
      setPadding: (padding) => set({ padding }),
      toggleOverlay: () => set((s) => ({ showOverlay: !s.showOverlay })),
      setTwoPageMode: (twoPageMode) => set({ twoPageMode }),
      setCoverPageMode: (coverPageMode) => set({ coverPageMode }),
      toggleSettings: () => set((s) => ({ showSettings: !s.showSettings })),
    }),
    { name: 'violet-viewer-settings' },
  ),
);
