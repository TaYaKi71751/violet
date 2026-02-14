import { useQuery, useInfiniteQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { getDownloads, createDownload } from '../api/downloads';
import { useToastStore } from '../stores/toast-store';

export function useDownloadHistory(page = 0, pageSize = 30, enabled = true) {
  return useQuery({
    queryKey: ['downloads', page, pageSize],
    queryFn: () => getDownloads(page, pageSize),
    enabled,
  });
}

export function useInfiniteDownloadHistory(pageSize = 30, enabled = true) {
  return useInfiniteQuery({
    queryKey: ['downloads-infinite', pageSize],
    queryFn: ({ pageParam = 0 }) => getDownloads(pageParam, pageSize),
    initialPageParam: 0,
    getNextPageParam: (lastPage, allPages) => {
      const totalPages = Math.ceil(lastPage.totalCount / pageSize);
      return allPages.length < totalPages ? allPages.length : undefined;
    },
    enabled,
  });
}

export function useStartDownload() {
  const qc = useQueryClient();
  const { t } = useTranslation();
  const addToast = useToastStore((s) => s.addToast);

  return useMutation({
    mutationFn: (articleId: string) => createDownload(articleId),
    onSuccess: () => {
      addToast(t('downloads.startToast'), 'info');
      qc.invalidateQueries({ queryKey: ['downloads'] });
      qc.invalidateQueries({ queryKey: ['downloads-infinite'] });
    },
    onError: () => {
      addToast(t('downloads.errorToast'), 'error');
    },
  });
}
