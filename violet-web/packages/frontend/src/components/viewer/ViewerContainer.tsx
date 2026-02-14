import { useViewerStore } from '../../stores/viewer-store';
import { VerticalReader } from './VerticalReader';
import { HorizontalReader } from './HorizontalReader';
import { PagedReader } from './PagedReader';
import { ViewerOverlay } from './ViewerOverlay';
import styles from './ViewerContainer.module.css';

interface ViewerContainerProps {
  imageUrls: string[];
  currentPage: number;
  totalPages: number;
  onPageChange: (page: number) => void;
  onClose: () => void;
}

export function ViewerContainer({
  imageUrls,
  currentPage,
  totalPages,
  onPageChange,
  onClose,
}: ViewerContainerProps) {
  const { viewMode, pageMode, readDirection, padding, twoPageMode, coverPageMode } =
    useViewerStore();

  const rtl = readDirection === 'rtl';

  return (
    <div className={styles.container}>
      {pageMode === 'paged' ? (
        <PagedReader
          imageUrls={imageUrls}
          currentPage={currentPage}
          onPageChange={onPageChange}
          rtl={rtl}
          twoPageMode={twoPageMode}
          coverPageMode={coverPageMode}
        />
      ) : viewMode === 'vertical' ? (
        <VerticalReader
          imageUrls={imageUrls}
          currentPage={currentPage}
          onPageChange={onPageChange}
          padding={padding}
        />
      ) : (
        <HorizontalReader
          imageUrls={imageUrls}
          currentPage={currentPage}
          onPageChange={onPageChange}
          rtl={rtl}
        />
      )}
      <ViewerOverlay
        currentPage={currentPage}
        totalPages={totalPages}
        onPageChange={onPageChange}
        onClose={onClose}
      />
    </div>
  );
}
