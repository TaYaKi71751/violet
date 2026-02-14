import type { ArticleReadLog, InsertReadLogRequest, UpdateReadLogRequest } from '@violet-web/shared';
import { api } from './client';

export interface HistoryResponse {
  logs: ArticleReadLog[];
  totalCount: number;
  page: number;
  pageSize: number;
}

export async function getHistory(page = 0, pageSize = 30): Promise<HistoryResponse> {
  const { data } = await api.get<HistoryResponse>('/history', {
    params: { page, pageSize },
  });
  return data;
}

export async function insertReadLog(req: InsertReadLogRequest): Promise<{ Id: number }> {
  const { data } = await api.post<{ Id: number }>('/history', req);
  return data;
}

export async function updateReadLog(id: number, req: UpdateReadLogRequest): Promise<void> {
  await api.patch(`/history/${id}`, req);
}

export async function deleteReadLog(id: number): Promise<void> {
  await api.delete(`/history/${id}`);
}
