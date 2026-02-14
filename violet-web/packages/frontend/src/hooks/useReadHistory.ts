import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getHistory, insertReadLog, updateReadLog } from '../api/history';

export function useReadHistory(page = 0, pageSize = 30) {
  return useQuery({
    queryKey: ['readHistory', page, pageSize],
    queryFn: () => getHistory(page, pageSize),
  });
}

export function useInsertReadLog() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: insertReadLog,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['readHistory'] });
    },
  });
}

export function useUpdateReadLog() {
  return useMutation({
    mutationFn: ({ id, ...req }: { id: number; LastPage: number; DateTimeEnd?: string }) =>
      updateReadLog(id, req),
  });
}
