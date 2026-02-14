import type { Article, ArticleSearchResult } from '@violet-web/shared';
import { api } from './client';

export async function searchArticles(
  query: string,
  page = 0,
  pageSize = 30,
): Promise<ArticleSearchResult> {
  const { data } = await api.get<ArticleSearchResult>('/content/search', {
    params: { q: query, page, pageSize },
  });
  return data;
}

export async function getArticle(id: number): Promise<Article> {
  const { data } = await api.get<Article>(`/content/${id}`);
  return data;
}
