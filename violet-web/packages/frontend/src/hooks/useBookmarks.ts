import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  getGroups,
  getBookmarkArticles,
  addBookmarkArticle,
  deleteBookmarkArticle,
  checkBookmark,
} from '../api/bookmarks';

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
