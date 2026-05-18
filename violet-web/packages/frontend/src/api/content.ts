import type {
  Article,
  ArticleSearchResult,
  SuggestionResult,
  SuggestionCacheStatus,
} from '@violet-web/shared';
import { api } from './client';

const ARTICLE_CACHE_KEY = 'violet-web:article-cache';
const DOWNLOADS_KEY = 'violet-web:downloads';
const DOWNLOADED_KEY = 'violet-downloaded';

interface StoredDownload {
  Article: string;
  Status: string;
}

interface StoredDownloadedArticle {
  id: string;
  page: number;
}

function readJson<T>(key: string, fallback: T): T {
  if (typeof window === 'undefined') return fallback;

  try {
    const raw = window.localStorage.getItem(key);
    return raw ? (JSON.parse(raw) as T) : fallback;
  } catch {
    return fallback;
  }
}

function writeJson<T>(key: string, value: T) {
  window.localStorage.setItem(key, JSON.stringify(value));
}

function readArticleCache(): Record<string, Article> {
  return readJson<Record<string, Article>>(ARTICLE_CACHE_KEY, {});
}

export function writeArticleCache(articles: Article[]) {
  if (typeof window === 'undefined' || articles.length === 0) return;

  const cache = readArticleCache();
  for (const article of articles) {
    cache[String(article.Id)] = article;
  }
  writeJson(ARTICLE_CACHE_KEY, cache);
}

function getDownloadedArticleIds() {
  const ids = new Set(
    readJson<StoredDownloadedArticle[]>(DOWNLOADED_KEY, []).map((download) =>
      String(download.id),
    ),
  );

  for (const download of readJson<StoredDownload[]>(DOWNLOADS_KEY, [])) {
    if (download.Status === 'completed') {
      ids.add(String(download.Article));
    }
  }

  return ids;
}

function filterCachedArticles(query: string): Article[] {
  const terms = query
    .toLowerCase()
    .split(/\s+/)
    .map((term) => term.trim())
    .filter(Boolean);

  const articles = Object.values(readArticleCache());
  if (terms.length === 0) return articles;

  return articles.filter((article) => {
    const haystack = [
      article.Id,
      article.Title,
      article.Artists,
      article.Characters,
      article.Groups,
      article.Language,
      article.Series,
      article.Tags,
      article.Type,
      article.Class,
    ]
      .filter((value) => value != null)
      .join(' ')
      .toLowerCase();

    return terms.every((term) => {
      const normalized = term.replace(/_/g, ' ');
      const [, value = normalized] = normalized.split(':');
      return haystack.includes(normalized) || haystack.includes(value);
    });
  });
}

export async function searchArticles(
  query: string,
  page = 0,
  pageSize = 30,
): Promise<ArticleSearchResult> {
  try {
    const { data } = await api.get<ArticleSearchResult>('/content/search', {
      params: { q: query, page, pageSize },
    });
    writeArticleCache(data.articles);
    return data;
  } catch (error) {
    const cached = filterCachedArticles(query);
    if (cached.length === 0) throw error;

    const start = page * pageSize;
    return {
      articles: cached.slice(start, start + pageSize),
      totalCount: cached.length,
      page,
      pageSize,
    };
  }
}

export async function getArticle(id: number): Promise<Article> {
  const articleId = String(id);
  const cached = readArticleCache()[articleId];
  if (cached && getDownloadedArticleIds().has(articleId)) return cached;

  try {
    const { data } = await api.get<Article>(`/content/${id}`);
    writeArticleCache([data]);
    return data;
  } catch (error) {
    if (cached) return cached;
    throw error;
  }
}

export async function getArticlesBatch(ids: number[]): Promise<Article[]> {
  const cache = readArticleCache();
  const downloadedIds = getDownloadedArticleIds();
  const cachedById = new Map<number, Article>();

  for (const id of ids) {
    const article = cache[String(id)];
    if (article && downloadedIds.has(String(id))) {
      cachedById.set(id, article);
    }
  }

  const missingIds = ids.filter((id) => !cachedById.has(id));
  if (missingIds.length === 0) {
    return ids.map((id) => cachedById.get(id)!);
  }

  try {
    const { data } = await api.post<{ articles: Article[] }>('/content/batch', {
      ids: missingIds,
    });
    writeArticleCache(data.articles);

    const fetchedById = new Map(data.articles.map((article) => [article.Id, article]));
    return ids
      .map((id) => cachedById.get(id) ?? fetchedById.get(id))
      .filter((article): article is Article => !!article);
  } catch (error) {
    const cachedArticles = ids
      .map((id) => cachedById.get(id))
      .filter((article): article is Article => !!article);
    if (cachedArticles.length > 0) return cachedArticles;
    throw error;
  }
}

export async function fetchSuggestions(
  q: string,
  limit = 20
): Promise<SuggestionResult> {
  const { data } = await api.get<SuggestionResult>('/content/suggest', {
    params: { q, limit },
  });
  return data;
}

export async function rebuildSuggestionCache(): Promise<{ success: boolean }> {
  const { data } = await api.post<{ success: boolean }>('/content/suggest/rebuild');
  return data;
}

export async function getSuggestionCacheStatus(): Promise<SuggestionCacheStatus> {
  const { data } = await api.get<SuggestionCacheStatus>('/content/suggest/status');
  return data;
}

export async function fetchTagCounts(): Promise<Record<string, number>> {
  const { data } = await api.get<Record<string, number>>('/content/suggest/tag-counts');
  return data;
}
