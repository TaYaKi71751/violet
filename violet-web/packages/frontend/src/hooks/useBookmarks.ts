import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  getGroups,
  getBookmarkArticles,
  addBookmarkArticle,
  deleteBookmarkArticle,
  checkBookmark,
  getCropBookmarks,
  deleteCropBookmark,
} from '../api/bookmarks';
import { useToastStore } from '../stores/toast-store';

export function useBookmarkGroups() {
  return useQuery({
    queryKey: ['bookmarkGroups'],
    queryFn: getGroups,
  });
}

export function useBookmarkArticles(groupId?: number) {
  return useQuery({
    queryKey: ['bookmarkArticles', groupId],
    queryFn: () => getBookmarkArticles(groupId),
  });
}

export function useIsBookmarked(articleId: string) {
  return useQuery({
    queryKey: ['isBookmarked', articleId],
    queryFn: () => checkBookmark(articleId),
    enabled: !!articleId,
  });
}

export function useAddBookmark() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: addBookmarkArticle,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['bookmarkArticles'] });
      qc.invalidateQueries({ queryKey: ['isBookmarked'] });
    },
  });
}

export function useRemoveBookmark() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: deleteBookmarkArticle,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['bookmarkArticles'] });
      qc.invalidateQueries({ queryKey: ['isBookmarked'] });
    },
  });
}

export function useCropBookmarks() {
  return useQuery({
    queryKey: ['cropBookmarks'],
    queryFn: getCropBookmarks,
  });
}

export function useDeleteCropBookmark() {
  const qc = useQueryClient();
  const addToast = useToastStore((state) => state.addToast);
  return useMutation({
    mutationFn: deleteCropBookmark,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['cropBookmarks'] });
      addToast('크롭 북마크가 삭제되었습니다', 'info');
    },
    onError: () => {
      addToast('크롭 북마크 삭제 중 오류가 발생했습니다', 'error');
    },
  });
}

const VIOLET_DEFAULT_GROUP_ID = 1;

export function useToggleBookmark() {
  const qc = useQueryClient();
  const addToast = useToastStore((state) => state.addToast);

  return useMutation({
    mutationFn: async ({ articleId, isBookmarked }: { articleId: string; isBookmarked: boolean }) => {
      if (isBookmarked) {
        // Find bookmark ID from the bookmarks list
        const bookmarks = await getBookmarkArticles();
        const bookmark = bookmarks.find((b) => b.Article === articleId);
        if (bookmark) {
          await deleteBookmarkArticle(bookmark.Id);
          return { action: 'removed' as const };
        }
        throw new Error('Bookmark not found');
      } else {
        await addBookmarkArticle({ Article: articleId, GroupId: VIOLET_DEFAULT_GROUP_ID });
        return { action: 'added' as const };
      }
    },
    onSuccess: (data) => {
      qc.invalidateQueries({ queryKey: ['bookmarkArticles'] });
      qc.invalidateQueries({ queryKey: ['isBookmarked'] });

      if (data.action === 'added') {
        addToast('북마크에 추가되었습니다', 'success');
      } else {
        addToast('북마크가 해제되었습니다', 'info');
      }
    },
    onError: () => {
      addToast('북마크 처리 중 오류가 발생했습니다', 'error');
    },
  });
}
