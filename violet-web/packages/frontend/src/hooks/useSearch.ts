import { useQuery } from '@tanstack/react-query';
import { searchArticles } from '../api/content';

export function useSearch(query: string, page: number, pageSize = 30) {
  return useQuery({
    queryKey: ['search', query, page, pageSize],
    queryFn: () => searchArticles(query, page, pageSize),
    enabled: query.length > 0,
    placeholderData: (prev) => prev,
  });
}
