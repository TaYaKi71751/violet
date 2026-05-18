import { useQuery } from '@tanstack/react-query';
import type { ImageList } from '@violet-web/shared';
import { resolveGallery } from '../api/proxy';
import { getDownloadedArticleListItem } from '../services/image-cache';

function createDownloadedImageList(galleryId: number, pageMarker: number): ImageList {
  const pageCount = Math.max(0, pageMarker - 1);
  const urls = Array.from(
    { length: pageCount },
    (_, index) => `indexeddb://downloaded/${galleryId}/${index + 1}`,
  );

  return {
    urls,
    bigThumbnails: [],
    smallThumbnails: [],
  };
}

async function resolveImageList(galleryId: number): Promise<ImageList> {
  const downloaded = await getDownloadedArticleListItem(String(galleryId));
  if (downloaded) {
    return createDownloadedImageList(galleryId, downloaded.page);
  }

  return resolveGallery(galleryId);
}

export function useImageList(galleryId: number) {
  return useQuery({
    queryKey: ['imageList', galleryId],
    queryFn: () => resolveImageList(galleryId),
    enabled: galleryId > 0,
    staleTime: 30 * 60 * 1000,
  });
}
