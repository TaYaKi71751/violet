import { useMemo, useEffect, useRef, useState } from 'react';
import type { BookmarkCropImage } from '@violet-web/shared';
import { CropImageCard } from './CropImageCard';
import { useColumnCount } from '../../hooks/useColumnCount';
import { useAppStore } from '../../stores/app-store';
import { getCachedImage } from '../../services/image-cache';
import styles from './CropBookmarkGrid.module.css';

interface CropBookmarkGridProps {
  crops: BookmarkCropImage[];
  columnWidth: number;
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

/**
 * Crop a full image blob to just the visible crop region.
 * Returns a small blob (~300x400px) instead of the full image (~2000x3000px).
 * This reduces browser painting cost from ~500% oversized to exact display size.
 */
async function cropImageBlob(
  blob: Blob,
  area: string,
): Promise<Blob> {
  const { left, top, right, bottom } = parseCropArea(area);
  const bitmap = await createImageBitmap(blob);
  const sx = Math.round(left * bitmap.width);
  const sy = Math.round(top * bitmap.height);
  const sw = Math.round((right - left) * bitmap.width);
  const sh = Math.round((bottom - top) * bitmap.height);

  const canvas = new OffscreenCanvas(sw, sh);
  const ctx = canvas.getContext('2d')!;
  ctx.drawImage(bitmap, sx, sy, sw, sh, 0, 0, sw, sh);
  bitmap.close();

  return canvas.convertToBlob({ type: 'image/jpeg', quality: 0.92 });
}

/**
 * Pre-fetch all cached images at the grid level and crop them
 * so individual cards never do async work during scroll.
 * Cropped images are exact display size → minimal painting cost.
 */
function usePrefetchedCache(crops: BookmarkCropImage[]) {
  const imageCacheEnabled = useAppStore((s) => s.imageCacheEnabled);
  const [cachedUrls, setCachedUrls] = useState<Map<string, string>>(new Map);
  const blobUrlsRef = useRef<string[]>([]);

  useEffect(() => {
    if (!imageCacheEnabled || crops.length === 0) {
      setCachedUrls(new Map());
      return;
    }

    let cancelled = false;

    // Read all cache entries and crop them to display size
    Promise.all(
      crops.map(async (c) => {
        const cached = await getCachedImage(c.Article, c.Page);
        if (!cached) return null;
        const cropped = await cropImageBlob(cached.blob, c.Area);
        return { key: `${c.Article}:${c.Page}`, blob: cropped };
      }),
    )
      .then((results) => {
        if (cancelled) return;
        // Revoke previous blob URLs
        for (const url of blobUrlsRef.current) URL.revokeObjectURL(url);

        const map = new Map<string, string>();
        const urls: string[] = [];
        for (const r of results) {
          if (r) {
            const url = URL.createObjectURL(r.blob);
            urls.push(url);
            map.set(r.key, url);
          }
        }
        blobUrlsRef.current = urls;
        setCachedUrls(map);
      })
      .catch(() => {
        if (!cancelled) setCachedUrls(new Map());
      });

    return () => {
      cancelled = true;
    };
  }, [crops, imageCacheEnabled]);

  // Cleanup blob URLs on unmount
  useEffect(
    () => () => {
      for (const url of blobUrlsRef.current) URL.revokeObjectURL(url);
    },
    [],
  );

  return cachedUrls;
}

export function CropBookmarkGrid({ crops, columnWidth, onDelete }: CropBookmarkGridProps) {
  const columnCount = useColumnCount(columnWidth);
  const gridRef = useRef<HTMLDivElement>(null);
  const scrollTimer = useRef<ReturnType<typeof setTimeout>>(undefined);
  const cachedUrls = usePrefetchedCache(crops);

  useEffect(() => {
    const handleScroll = () => {
      gridRef.current?.classList.add(styles.scrolling);
      clearTimeout(scrollTimer.current);
      scrollTimer.current = setTimeout(() => {
        gridRef.current?.classList.remove(styles.scrolling);
      }, 150);
    };
    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => {
      window.removeEventListener('scroll', handleScroll);
      clearTimeout(scrollTimer.current);
    };
  }, []);

  const columns = useMemo(
    () => distributeToColumns(crops, columnCount),
    [crops, columnCount],
  );

  if (crops.length === 0) {
    return <div className={styles.empty}>No crop bookmarks</div>;
  }

  return (
    <div ref={gridRef} className={styles.grid}>
      {columns.map((col, colIdx) => (
        <div key={colIdx} className={styles.column}>
          {col.map((crop) => (
            <CropImageCard
              key={crop.Id}
              crop={crop}
              cachedUrl={cachedUrls.get(`${crop.Article}:${crop.Page}`)}
              onDelete={onDelete}
            />
          ))}
        </div>
      ))}
    </div>
  );
}
