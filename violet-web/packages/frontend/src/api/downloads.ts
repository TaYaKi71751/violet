import type { DownloadRecord } from '@violet-web/shared';
import { getProxyImageUrl, resolveGallery } from './proxy';
import {
  deleteDownloadedArticleListItem,
  deleteDownloadedBase64Images,
  getDownloadedArticleListItem,
  getDownloadedBase64Image,
  putDownloadedArticleListItem,
  putDownloadedBase64Image,
} from '../services/image-cache';
import { createZip } from '../utils/zip';

const DOWNLOADS_KEY = 'violet-web:downloads';
const DOWNLOADED_KEY = 'violet-downloaded';

interface DownloadedArticle {
  id: string;
  page: number;
}

function base64ToBytes(base64: string): Uint8Array {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);

  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }

  return bytes;
}

function extensionFromContentType(contentType: string): string {
  if (contentType.includes('avif')) return 'avif';
  if (contentType.includes('webp')) return 'webp';
  if (contentType.includes('png')) return 'png';
  if (contentType.includes('gif')) return 'gif';
  return 'jpg';
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

function bytesToBase64(bytes: Uint8Array): string {
  let binary = '';
  const chunkSize = 0x8000;

  for (let index = 0; index < bytes.length; index += chunkSize) {
    const chunk = bytes.subarray(index, index + chunkSize);
    binary += String.fromCharCode(...chunk);
  }

  return btoa(binary);
}

function ascii(bytes: Uint8Array, start: number, length: number): string {
  let value = '';
  for (let index = start; index < start + length && index < bytes.length; index += 1) {
    value += String.fromCharCode(bytes[index]);
  }
  return value;
}

function contentTypeFromBuffer(bytes: Uint8Array): string | null {
  if (
    bytes.length >= 3 &&
    bytes[0] === 0xff &&
    bytes[1] === 0xd8 &&
    bytes[2] === 0xff
  ) {
    return 'image/jpeg';
  }

  if (
    bytes.length >= 8 &&
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4e &&
    bytes[3] === 0x47 &&
    bytes[4] === 0x0d &&
    bytes[5] === 0x0a &&
    bytes[6] === 0x1a &&
    bytes[7] === 0x0a
  ) {
    return 'image/png';
  }

  if (bytes.length >= 6) {
    const signature = ascii(bytes, 0, 6);
    if (signature === 'GIF87a' || signature === 'GIF89a') {
      return 'image/gif';
    }
  }

  if (
    bytes.length >= 12 &&
    ascii(bytes, 0, 4) === 'RIFF' &&
    ascii(bytes, 8, 4) === 'WEBP'
  ) {
    return 'image/webp';
  }

  if (bytes.length >= 12 && ascii(bytes, 4, 4) === 'ftyp') {
    const brands = ascii(bytes, 8, Math.min(bytes.length - 8, 64));
    if (brands.includes('avif') || brands.includes('avis')) {
      return 'image/avif';
    }
  }

  return null;
}

function contentTypeFromUrl(url: string): string | null {
  let target = url;

  try {
    const parsed = new URL(url, window.location.origin);
    target = parsed.searchParams.get('url') ?? parsed.href;
  } catch {
    // Fall through to string matching below.
  }

  const pathname = (() => {
    try {
      return new URL(target).pathname.toLowerCase();
    } catch {
      return target.toLowerCase().split('?')[0];
    }
  })();

  if (pathname.endsWith('.avif')) return 'image/avif';
  if (pathname.endsWith('.webp')) return 'image/webp';
  if (pathname.endsWith('.jpg') || pathname.endsWith('.jpeg')) return 'image/jpeg';
  if (pathname.endsWith('.png')) return 'image/png';
  return null;
}

function contentTypeFromResponse(response: Response): string | null {
  const contentType = response.headers.get('content-type')?.split(';')[0].trim().toLowerCase();
  if (!contentType || !contentType.startsWith('image/')) return null;
  return contentType;
}

async function responseToStoredImage(
  response: Response,
  sourceUrl: string,
): Promise<{ base64: string; contentType: string }> {
  const bytes = new Uint8Array(await response.arrayBuffer());
  return {
    base64: bytesToBase64(bytes),
    contentType:
      contentTypeFromBuffer(bytes) ||
      contentTypeFromUrl(sourceUrl) ||
      contentTypeFromResponse(response) ||
      'image/jpeg',
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

    const image = await responseToStoredImage(response, imageUrl);
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

      const image = await responseToStoredImage(response, imageUrl);
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

export async function exportDownloadedArticleZip(articleId: string): Promise<void> {
  const downloaded = await getDownloadedArticleListItem(articleId);
  const legacy = readDownloaded().find((item) => item.id === articleId);
  const pageCount = downloaded ? downloaded.page - 1 : legacy?.page;

  if (!pageCount || pageCount < 1) {
    throw new Error('Downloaded article not found');
  }

  const width = Math.max(3, String(pageCount).length);
  const entries = [];

  for (let page = 1; page <= pageCount; page += 1) {
    const image = await getDownloadedBase64Image(articleId, page);
    if (!image) {
      throw new Error(`Missing downloaded page ${page}`);
    }

    entries.push({
      name: `${String(page).padStart(width, '0')}.${extensionFromContentType(image.contentType)}`,
      data: base64ToBytes(image.base64),
    });
  }

  const blob = createZip(entries);
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = `${articleId}.zip`;
  anchor.click();
  URL.revokeObjectURL(url);
}
