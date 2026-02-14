import { useParams, useNavigate } from 'react-router';
import { useImageList } from '../hooks/useImageList';
import { useViewer } from '../hooks/useViewer';
import { useInsertReadLog, useUpdateReadLog } from '../hooks/useReadHistory';
import { ViewerContainer } from '../components/viewer/ViewerContainer';
import { LoadingSpinner } from '../components/common/LoadingSpinner';
import { getProxyImageUrl } from '../api/proxy';
import { useEffect, useRef } from 'react';

export function ViewerPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const galleryId = parseInt(id!);
  const { data: imageList, isLoading } = useImageList(galleryId);

  const totalPages = imageList?.urls.length ?? 0;
  const { currentPage, goToPage } = useViewer(totalPages);

  const insertLog = useInsertReadLog();
  const updateLog = useUpdateReadLog();
  const logIdRef = useRef<number | null>(null);

  // Insert read log on mount
  useEffect(() => {
    if (!galleryId) return;
    insertLog.mutate(
      { Article: String(galleryId), Type: 0 },
      {
        onSuccess: (data) => {
          logIdRef.current = Number(data.Id);
        },
      },
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [galleryId]);

  // Update read log on page change
  useEffect(() => {
    if (logIdRef.current == null) return;
    updateLog.mutate({ id: logIdRef.current, LastPage: currentPage });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentPage]);

  if (isLoading) return <LoadingSpinner />;
  if (!imageList || imageList.urls.length === 0) {
    return <div style={{ padding: 20 }}>No images found for this gallery.</div>;
  }

  const proxyUrls = imageList.urls.map((url) =>
    getProxyImageUrl(url, `https://hitomi.la/reader/${galleryId}.html`),
  );

  return (
    <ViewerContainer
      imageUrls={proxyUrls}
      currentPage={currentPage}
      totalPages={totalPages}
      onPageChange={goToPage}
      onClose={() => navigate(`/article/${galleryId}`)}
    />
  );
}
