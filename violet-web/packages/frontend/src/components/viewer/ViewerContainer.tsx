import { useViewerStore } from '../../stores/viewer-store';
import { VerticalReader } from './VerticalReader';
import { HorizontalReader } from './HorizontalReader';
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
  const { viewMode, readDirection, padding } = useViewerStore();

  return (
    <div className={styles.container}>
      {viewMode === 'vertical' ? (
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
          rtl={readDirection === 'rtl'}
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
