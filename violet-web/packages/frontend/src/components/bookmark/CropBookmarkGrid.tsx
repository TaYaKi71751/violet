import { useMemo } from 'react';
import type { BookmarkCropImage } from '@violet-web/shared';
import { CropImageCard } from './CropImageCard';
import { useColumnCount } from '../../hooks/useColumnCount';
import styles from './CropBookmarkGrid.module.css';

interface CropBookmarkGridProps {
  crops: BookmarkCropImage[];
  onDelete: (id: number) => void;
}

function parseCropArea(area: string) {
  const [left, top, right, bottom] = area.split(',').map(Number);
  return { left, top, right, bottom };
}

function getCropAspectRatio(crop: BookmarkCropImage): number {
  const { left, top, right, bottom } = parseCropArea(crop.Area);
  const cropWidth = right - left;
  const cropHeight = bottom - top;
  return (cropWidth * crop.AspectRatio) / cropHeight;
}

/**
 * Distribute crops into columns by always placing the next item
 * into the shortest column (by estimated height). This preserves
 * visual left-to-right, top-to-bottom order.
 */
function distributeToColumns(crops: BookmarkCropImage[], columnCount: number) {
  const columns: BookmarkCropImage[][] = Array.from({ length: columnCount }, () => []);
  const heights = new Array(columnCount).fill(0);

  for (const crop of crops) {
    // Find the shortest column
    let minIdx = 0;
    for (let i = 1; i < columnCount; i++) {
      if (heights[i] < heights[minIdx]) minIdx = i;
    }
    columns[minIdx].push(crop);
    // Estimate height contribution (1 / aspectRatio, since width is equal across columns)
    const ar = getCropAspectRatio(crop);
    heights[minIdx] += ar > 0 ? 1 / ar : 1;
  }

  return columns;
}

export function CropBookmarkGrid({ crops, onDelete }: CropBookmarkGridProps) {
  const columnCount = useColumnCount(240);

  const columns = useMemo(
    () => distributeToColumns(crops, columnCount),
    [crops, columnCount],
  );

  if (crops.length === 0) {
    return <div className={styles.empty}>No crop bookmarks</div>;
  }

  return (
    <div className={styles.grid}>
      {columns.map((col, colIdx) => (
        <div key={colIdx} className={styles.column}>
          {col.map((crop) => (
            <CropImageCard key={crop.Id} crop={crop} onDelete={onDelete} />
          ))}
        </div>
      ))}
    </div>
  );
}
