/**
 * Ported from violet/lib/script/script_manager.dart
 *
 * Resolves a hitomi gallery ID into image URLs by:
 * 1. Evaluating gg.js routing data
 * 2. Fetching gallery metadata
 * 3. Building image and thumbnail URLs
 */

import type { ImageList } from '@violet-web/shared';

const BASE_DOMAIN = 'gold-usergeneratedcontent.net';
const GG_JS_URL = `https://ltn.${BASE_DOMAIN}/gg.js`;

const USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

interface GalleryFile {
  hash?: string;
}

interface GalleryInfo {
  files?: GalleryFile[];
}

interface GgRouting {
  b: string;
  mList: Set<string>;
  o1: number;
  o2: number;
}

let routingCache: GgRouting | null = null;
let latestUpdate = 0;

async function fetchText(url: string, headers?: Record<string, string>): Promise<string> {
  const res = await fetch(url, {
    headers: { 'User-Agent': USER_AGENT, ...headers },
  });
  if (!res.ok) throw new Error(`Failed to fetch ${url}: ${res.status}`);
  return res.text();
}

async function tryRefreshV4(): Promise<boolean> {
  try {
    const ggText = await fetchText(GG_JS_URL);
    const b = ggText.match(/b:\s*'([^']+)'/)?.[1] ?? '';
    const mList = new Set([...ggText.matchAll(/case (\d+):/g)].map((m) => m[1]));
    const oMatches = [...ggText.matchAll(/o = (\d+)/g)].map((m) => Number(m[1]));

    routingCache = {
      b,
      mList,
      o1: oMatches[0] ?? 0,
      o2: oMatches[oMatches.length - 1] ?? 1,
    };
    latestUpdate = Date.now();
    return true;
  } catch {
    return false;
  }
}

async function ensureScript(): Promise<void> {
  // Refresh if cache is empty or older than 30 minutes
  if (routingCache && Date.now() - latestUpdate < 30 * 60 * 1000) {
    return;
  }

  if (!(await tryRefreshV4())) {
    throw new Error('Failed to refresh Hitomi routing data');
  }
}

async function getGalleryInfo(id: number): Promise<GalleryInfo> {
  const body = await fetchText(
    `https://ltn.${BASE_DOMAIN}/galleries/${id}.js`,
    getGalleryHeadersSync(),
  );
  const json = body
    .replace(/^var galleryinfo\s*=\s*/, '')
    .replace(/;\s*$/, '');

  return JSON.parse(json) as GalleryInfo;
}

function getHashShard(hash: string): string {
  const part = hash[hash.length - 1] + hash[hash.length - 3] + hash[hash.length - 2];
  return parseInt(part, 16).toString();
}

function getServerNum(hashShard: string, routing: GgRouting): number {
  const node = routing.mList.has(hashShard) ? routing.o2 : routing.o1;
  return node + 1;
}

function buildImageUrls(files: GalleryFile[], routing: GgRouting, useAvif = false): string[] {
  const domain = useAvif ? 'a' : 'w';
  const ext = useAvif ? 'avif' : 'webp';

  return files.flatMap((file) => {
    const hash = file.hash;
    if (!hash) return [];

    const shard = getHashShard(hash);
    const serverNum = getServerNum(shard, routing);
    return [`https://${domain}${serverNum}.${BASE_DOMAIN}/${routing.b}${shard}/${hash}.${ext}`];
  });
}

function buildThumbnailUrls(files: GalleryFile[], routing: GgRouting, size: 'big' | 'small', useAvif = false): string[] {
  const firstPath = useAvif
    ? size === 'big' ? 'avifbigtn' : 'avifsmallsmalltn'
    : size === 'big' ? 'webpbigtn' : 'webpsmalltn';
  const ext = useAvif ? 'avif' : 'webp';

  return files.flatMap((file) => {
    const hash = file.hash;
    if (!hash) return [];

    const shard = getHashShard(hash);
    const serverNum = getServerNum(shard, routing);
    const domain = serverNum === 1 ? 'atn' : 'btn';
    const secondPath = hash.substring(hash.length - 1);
    const thirdPath = hash.substring(hash.length - 3, hash.length - 1);

    return [`https://${domain}.${BASE_DOMAIN}/${firstPath}/${secondPath}/${thirdPath}/${hash}.${ext}`];
  });
}

function getGalleryHeadersSync(): Record<string, string> {
  return {
    'User-Agent': USER_AGENT,
    Accept: 'image/avif,image/webp,image/png,image/svg+xml,image/*;q=0.8,*/*;q=0.5',
    'Accept-Language': 'en-US',
    Referer: 'https://hitomi.la/',
    'Sec-Fetch-Dest': 'image',
    'Sec-Fetch-Mode': 'no-cors',
    'Sec-Fetch-Site': 'cross-site',
    Priority: 'u=4, i',
  };
}

export async function resolveGallery(id: number): Promise<ImageList> {
  await ensureScript();
  if (!routingCache) throw new Error('Hitomi routing data not available');

  const galleryInfo = await getGalleryInfo(id);
  const files = galleryInfo.files ?? [];
  return {
    urls: buildImageUrls(files, routingCache),
    bigThumbnails: buildThumbnailUrls(files, routingCache, 'big'),
    smallThumbnails: buildThumbnailUrls(files, routingCache, 'small'),
  };
}

/**
 * Get headers required for fetching images from a gallery.
 */
export async function getGalleryHeaders(
  _id: string,
): Promise<Record<string, string>> {
  return getGalleryHeadersSync();
}
