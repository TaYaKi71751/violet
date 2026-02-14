import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export type ViewMode = 'vertical' | 'horizontal';
export type ReadDirection = 'ltr' | 'rtl';

interface ViewerState {
  viewMode: ViewMode;
  readDirection: ReadDirection;
  padding: number;
  showOverlay: boolean;
  twoPageMode: boolean;

  setViewMode: (mode: ViewMode) => void;
  setReadDirection: (dir: ReadDirection) => void;
  setPadding: (padding: number) => void;
  toggleOverlay: () => void;
  setTwoPageMode: (enabled: boolean) => void;
}

export const useViewerStore = create<ViewerState>()(
  persist(
    (set) => ({
      viewMode: 'vertical',
      readDirection: 'ltr',
      padding: 0,
      showOverlay: true,
      twoPageMode: false,

      setViewMode: (viewMode) => set({ viewMode }),
      setReadDirection: (readDirection) => set({ readDirection }),
      setPadding: (padding) => set({ padding }),
      toggleOverlay: () => set((s) => ({ showOverlay: !s.showOverlay })),
      setTwoPageMode: (twoPageMode) => set({ twoPageMode }),
    }),
    { name: 'violet-viewer-settings' },
  ),
);
