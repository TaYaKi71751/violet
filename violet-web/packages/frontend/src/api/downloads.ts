import type { DownloadRecord } from '@violet-web/shared';
import { getProxyImageUrl, resolveGallery } from './proxy';
import {
  deleteDownloadedArticleListItem,
  deleteDownloadedBase64Images,
  putDownloadedArticleListItem,
  putDownloadedBase64Image,
} from '../services/image-cache';

const DOWNLOADS_KEY = 'violet-web:downloads';
const DOWNLOADED_KEY = 'violet-downloaded';

interface DownloadedArticle {
  id: string;
  page: number;
}

export interface DownloadsResponse {
  downloads: DownloadRecord[];
  totalCount: number;
  page: number;
  pageSize: number;
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

function readDownloads(): DownloadRecord[] {
  return readJson<DownloadRecord[]>(DOWNLOADS_KEY, []);
}

function writeDownloads(downloads: DownloadRecord[]) {
  writeJson(DOWNLOADS_KEY, downloads);
}

function nextId(downloads: DownloadRecord[]) {
  return downloads.reduce((max, download) => Math.max(max, download.Id), 0) + 1;
}

function updateDownloadRecord(id: number, patch: Partial<DownloadRecord>) {
  const downloads = readDownloads();
  writeDownloads(
    downloads.map((download) =>
      download.Id === id ? { ...download, ...patch } : download,
    ),
  );
}

function blobToBase64(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onerror = () => reject(reader.error);
    reader.onload = () => {
      const result = String(reader.result);
      resolve(result.includes(',') ? result.split(',')[1] : result);
    };
    reader.readAsDataURL(blob);
  });
}

function dataUrlToBase64(dataUrl: string): string {
  return dataUrl.includes(',') ? dataUrl.split(',')[1] : dataUrl;
}

async function blobToStoredImage(blob: Blob): Promise<{ base64: string; contentType: string }> {
  const bitmap = await createImageBitmap(blob);
  const attempts = [
    { maxWidth: 1280, quality: 0.72 },
    { maxWidth: 960, quality: 0.62 },
    { maxWidth: 720, quality: 0.52 },
  ];

  try {
    for (const attempt of attempts) {
      const scale = Math.min(1, attempt.maxWidth / bitmap.width);
      const width = Math.max(1, Math.round(bitmap.width * scale));
      const height = Math.max(1, Math.round(bitmap.height * scale));
      const canvas = document.createElement('canvas');
      canvas.width = width;
      canvas.height = height;
      const context = canvas.getContext('2d');
      if (!context) continue;

      context.drawImage(bitmap, 0, 0, width, height);
      const dataUrl = canvas.toDataURL('image/jpeg', attempt.quality);
      const base64 = dataUrlToBase64(dataUrl);
      if (base64.length > 0) return { base64, contentType: 'image/jpeg' };
    }
  } finally {
    bitmap.close();
  }

  return {
    base64: await blobToBase64(blob),
    contentType: blob.type || 'image/jpeg',
  };
}

async function markDownloaded(articleId: string, pageCount: number) {
  const downloaded = readJson<DownloadedArticle[]>(DOWNLOADED_KEY, []);
  const next = downloaded.filter((item) => item.id !== articleId);
  next.unshift({ id: articleId, page: pageCount });
  writeJson(DOWNLOADED_KEY, next);
  await putDownloadedArticleListItem(articleId, pageCount + 1);
}

function readDownloaded() {
  return readJson<DownloadedArticle[]>(DOWNLOADED_KEY, []);
}

function removeArticleImages(articleId: string, pageCount: number) {
  for (let page = 1; page <= pageCount; page += 1) {
    window.localStorage.removeItem(`article-${articleId}-${page}`);
  }
}

async function removeDownloaded(record: DownloadRecord) {
  const downloaded = readDownloaded();
  const item = downloaded.find((entry) => entry.id === record.Article);
  const pageCount = item?.page ?? record.TotalPages;

  removeArticleImages(record.Article, pageCount);
  await deleteDownloadedBase64Images(record.Article);
  await deleteDownloadedArticleListItem(record.Article);

  writeJson(
    DOWNLOADED_KEY,
    downloaded.filter((entry) => entry.id !== record.Article),
  );
}

function isQuotaError(error: unknown) {
  return (
    error instanceof DOMException &&
    (error.name === 'QuotaExceededError' ||
      error.name === 'NS_ERROR_DOM_QUOTA_REACHED')
  );
}

async function evictOldestDownloadedExcept(articleId: string): Promise<boolean> {
  const downloaded = readDownloaded();
  const victim = [...downloaded].reverse().find((entry) => entry.id !== articleId);
  if (!victim) return false;

  removeArticleImages(victim.id, victim.page);
  await deleteDownloadedBase64Images(victim.id);
  await deleteDownloadedArticleListItem(victim.id);
  writeJson(
    DOWNLOADED_KEY,
    downloaded.filter((entry) => entry.id !== victim.id),
  );
  writeDownloads(readDownloads().filter((download) => download.Article !== victim.id));
  return true;
}

async function setPageImage(
  articleId: string,
  page: number,
  image: { base64: string; contentType: string },
) {
  const key = `article-${articleId}-${page}`;

  try {
    window.localStorage.removeItem(key);
    await putDownloadedBase64Image(articleId, page, image.base64, image.contentType);
  } catch (error) {
    if (!isQuotaError(error) || !(await evictOldestDownloadedExcept(articleId))) {
      throw error;
    }
    await putDownloadedBase64Image(articleId, page, image.base64, image.contentType);
  }
}

async function setThumbnailImage(
  articleId: string,
  image: { base64: string; contentType: string },
) {
  try {
    await putDownloadedBase64Image(articleId, 'thumbnail', image.base64, image.contentType);
  } catch (error) {
    if (!isQuotaError(error) || !(await evictOldestDownloadedExcept(articleId))) {
      throw error;
    }
    await putDownloadedBase64Image(articleId, 'thumbnail', image.base64, image.contentType);
  }
}

async function storeThumbnail(articleId: string, thumbnailUrl: string | undefined, referer: string) {
  if (!thumbnailUrl) return;

  try {
    const imageUrl = getProxyImageUrl(thumbnailUrl, referer);
    const response = await fetch(imageUrl);
    if (!response.ok) return;

    const image = await blobToStoredImage(await response.blob());
    await setThumbnailImage(articleId, image);
  } catch {
    // Thumbnail cache is best-effort; page downloads should continue.
  }
}

async function storeArticleImages(record: DownloadRecord) {
  const articleId = record.Article;

  try {
    const gallery = await resolveGallery(Number(articleId));
    const referer = `https://hitomi.la/reader/${articleId}.html`;
    updateDownloadRecord(record.Id, {
      Status: 'downloading',
      TotalPages: gallery.urls.length,
      DownloadedPages: 0,
      ErrorMessage: null,
    });

    await storeThumbnail(
      articleId,
      gallery.bigThumbnails?.[0],
      referer,
    );

    for (let index = 0; index < gallery.urls.length; index += 1) {
      const imageUrl = getProxyImageUrl(gallery.urls[index], referer);
      const response = await fetch(imageUrl);
      if (!response.ok) {
        throw new Error(`Failed to fetch page ${index + 1}: HTTP ${response.status}`);
      }

      const image = await blobToStoredImage(await response.blob());
      await setPageImage(articleId, index + 1, image);
      updateDownloadRecord(record.Id, { DownloadedPages: index + 1 });
    }

    await markDownloaded(articleId, gallery.urls.length);
    updateDownloadRecord(record.Id, {
      Status: 'completed',
      TotalPages: gallery.urls.length,
      DownloadedPages: gallery.urls.length,
      ErrorMessage: null,
    });
  } catch (error) {
    updateDownloadRecord(record.Id, {
      Status: 'failed',
      ErrorMessage: error instanceof Error ? error.message : String(error),
    });
  }
}

export async function getDownloads(page = 0, pageSize = 30): Promise<DownloadsResponse> {
  const downloads = readDownloads().sort((a, b) => b.Id - a.Id);
  const start = page * pageSize;

  return {
    downloads: downloads.slice(start, start + pageSize),
    totalCount: downloads.length,
    page,
    pageSize,
  };
}

export async function getDownloadIds(): Promise<string[]> {
  return readDownloads()
    .sort((a, b) => b.Id - a.Id)
    .map((download) => download.Article);
}

export async function getDownload(id: number): Promise<DownloadRecord> {
  const record = readDownloads().find((download) => download.Id === id);
  if (!record) throw new Error('Download not found');
  return record;
}

export async function createDownload(articleId: string): Promise<DownloadRecord> {
  const downloads = readDownloads();
  const existing = downloads.find(
    (download) => download.Article === articleId && download.Status === 'completed',
  );
  if (existing) return existing;

  const record: DownloadRecord = {
    Id: nextId(downloads),
    Article: articleId,
    Status: 'downloading',
    TotalPages: 0,
    DownloadedPages: 0,
    DateTime: new Date().toISOString(),
    ErrorMessage: null,
  };

  writeDownloads([record, ...downloads]);
  storeArticleImages(record);
  return record;
}

export async function retryDownload(id: number): Promise<DownloadRecord> {
  const downloads = readDownloads();
  const record = downloads.find((download) => download.Id === id);
  if (!record) throw new Error('Download not found');

  const nextRecord: DownloadRecord = {
    ...record,
    Status: 'downloading',
    TotalPages: 0,
    DownloadedPages: 0,
    ErrorMessage: null,
  };

  writeDownloads(downloads.map((download) => (download.Id === id ? nextRecord : download)));
  storeArticleImages(nextRecord);
  return nextRecord;
}

export async function deleteDownload(id: number): Promise<void> {
  const downloads = readDownloads();
  const record = downloads.find((download) => download.Id === id);
  if (record) await removeDownloaded(record);
  writeDownloads(downloads.filter((download) => download.Id !== id));
}

export async function checkDownloaded(articleId: string): Promise<boolean> {
  return (
    readDownloaded().some((download) => download.id === articleId) ||
    readDownloads().some(
      (download) => download.Article === articleId && download.Status === 'completed',
    )
  );
}
