import { useQuery } from '@tanstack/react-query';
import { getThumbnailUrl, getProxyImageUrl } from '../api/proxy';
import { getDownloadedBase64Image } from '../services/image-cache';

export function useThumbnail(galleryId: number) {
  return useQuery({
    queryKey: ['thumbnail', galleryId],
    queryFn: async () => {
      const downloaded = await getDownloadedBase64Image(String(galleryId), 'thumbnail');
      if (downloaded) {
        return `data:${downloaded.contentType};base64,${downloaded.base64}`;
      }

      const url = await getThumbnailUrl(galleryId);
      // Return proxied URL with referer
      return getProxyImageUrl(url, `https://hitomi.la/reader/${galleryId}.html`);
    },
    enabled: galleryId > 0,
    staleTime: 30 * 60 * 1000, // 30 minutes (matches backend cache)
  });
}
