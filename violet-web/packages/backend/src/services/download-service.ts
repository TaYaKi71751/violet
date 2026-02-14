import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { getUserDb } from './user-db.js';
import { resolveGallery, getGalleryHeaders } from './gallery-resolver.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ARTICLES_DIR = path.resolve(__dirname, '../../data/articles');

const USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

function getExtFromUrl(url: string): string {
  const pathname = new URL(url).pathname;
  const ext = path.extname(pathname);
  return ext || '.jpg';
}

export async function startDownload(articleId: string): Promise<number> {
  const db = getUserDb();

  const result = db
    .prepare(
      'INSERT INTO Download (Article, Status, TotalPages, DownloadedPages, DateTime) VALUES (?, ?, 0, 0, ?)',
    )
    .run(articleId, 'downloading', new Date().toISOString());

  const downloadId = Number(result.lastInsertRowid);

  // Fire-and-forget: run the actual download in the background
  processDownload(downloadId, articleId).catch(() => {});

  return downloadId;
}

async function processDownload(downloadId: number, articleId: string): Promise<void> {
  const db = getUserDb();

  try {
    const gallery = await resolveGallery(Number(articleId));
    const urls = gallery.urls;

    db.prepare('UPDATE Download SET TotalPages = ? WHERE Id = ?').run(urls.length, downloadId);

    const articleDir = path.join(ARTICLES_DIR, articleId);
    fs.mkdirSync(articleDir, { recursive: true });

    const headers = await getGalleryHeaders(articleId);
    headers['User-Agent'] = USER_AGENT;

    for (let i = 0; i < urls.length; i++) {
      const url = urls[i];
      const ext = getExtFromUrl(url);
      const filePath = path.join(articleDir, `${i}${ext}`);

      const res = await fetch(url, { headers });
      if (!res.ok) {
        throw new Error(`Failed to fetch page ${i}: HTTP ${res.status}`);
      }

      const buffer = Buffer.from(await res.arrayBuffer());
      fs.writeFileSync(filePath, buffer);

      db.prepare('UPDATE Download SET DownloadedPages = ? WHERE Id = ?').run(i + 1, downloadId);
    }

    db.prepare('UPDATE Download SET Status = ? WHERE Id = ?').run('completed', downloadId);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    db.prepare('UPDATE Download SET Status = ?, ErrorMessage = ? WHERE Id = ?').run(
      'failed',
      message,
      downloadId,
    );
  }
}
