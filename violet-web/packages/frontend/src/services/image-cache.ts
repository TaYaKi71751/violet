const DB_NAME = 'violet-image-cache';
const DB_VERSION = 1;
const STORE_NAME = 'images';

interface CachedImage {
  articleId: number;
  page: number;
  blob: Blob;
  contentType: string;
  size: number;
  lastAccessed: number;
  createdAt: number;
}

let dbInstance: IDBDatabase | null = null;

function openDB(): Promise<IDBDatabase> {
  if (dbInstance) return Promise.resolve(dbInstance);

  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);

    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        const store = db.createObjectStore(STORE_NAME, { keyPath: ['articleId', 'page'] });
        store.createIndex('lastAccessed', 'lastAccessed', { unique: false });
        store.createIndex('articleId', 'articleId', { unique: false });
      }
    };

    request.onsuccess = () => {
      dbInstance = request.result;
      dbInstance.onclose = () => { dbInstance = null; };
      resolve(dbInstance);
    };

    request.onerror = () => reject(request.error);
  });
}

export async function getCachedImage(
  articleId: number,
  page: number,
): Promise<{ blob: Blob; contentType: string } | null> {
  try {
    const db = await openDB();
    return new Promise((resolve) => {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      const store = tx.objectStore(STORE_NAME);
      const request = store.get([articleId, page]);

      request.onsuccess = () => {
        const result = request.result as CachedImage | undefined;
        if (result) {
          // Update lastAccessed
          result.lastAccessed = Date.now();
          store.put(result);
          resolve({ blob: result.blob, contentType: result.contentType });
        } else {
          resolve(null);
        }
      };

      request.onerror = () => resolve(null);
    });
  } catch {
    return null;
  }
}

export async function putCachedImage(
  articleId: number,
  page: number,
  blob: Blob,
  contentType: string,
  maxSizeBytes: number,
): Promise<void> {
  try {
    const db = await openDB();
    const now = Date.now();
    const entry: CachedImage = {
      articleId,
      page,
      blob,
      contentType,
      size: blob.size,
      lastAccessed: now,
      createdAt: now,
    };

    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      const store = tx.objectStore(STORE_NAME);
      const request = store.put(entry);
      request.onsuccess = () => resolve();
      request.onerror = () => reject(request.error);
    });

    await evictIfNeeded(maxSizeBytes);
  } catch {
    // best-effort
  }
}

export async function getCacheStats(): Promise<{ totalSizeBytes: number; itemCount: number }> {
  try {
    const db = await openDB();
    return new Promise((resolve) => {
      const tx = db.transaction(STORE_NAME, 'readonly');
      const store = tx.objectStore(STORE_NAME);
      const request = store.getAll();

      request.onsuccess = () => {
        const items = request.result as CachedImage[];
        const totalSizeBytes = items.reduce((sum, item) => sum + item.size, 0);
        resolve({ totalSizeBytes, itemCount: items.length });
      };

      request.onerror = () => resolve({ totalSizeBytes: 0, itemCount: 0 });
    });
  } catch {
    return { totalSizeBytes: 0, itemCount: 0 };
  }
}

export async function cleanupExpired(days: number): Promise<void> {
  try {
    const db = await openDB();
    const cutoff = Date.now() - days * 24 * 60 * 60 * 1000;

    const items = await new Promise<CachedImage[]>((resolve) => {
      const tx = db.transaction(STORE_NAME, 'readonly');
      const store = tx.objectStore(STORE_NAME);
      const index = store.index('lastAccessed');
      const range = IDBKeyRange.upperBound(cutoff);
      const request = index.getAll(range);

      request.onsuccess = () => resolve(request.result as CachedImage[]);
      request.onerror = () => resolve([]);
    });

    if (items.length === 0) return;

    const tx = db.transaction(STORE_NAME, 'readwrite');
    const store = tx.objectStore(STORE_NAME);
    for (const item of items) {
      store.delete([item.articleId, item.page]);
    }
  } catch {
    // best-effort
  }
}

export async function clearAllCache(): Promise<void> {
  try {
    const db = await openDB();
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      const store = tx.objectStore(STORE_NAME);
      const request = store.clear();
      request.onsuccess = () => resolve();
      request.onerror = () => reject(request.error);
    });
  } catch {
    // best-effort
  }
}

async function evictIfNeeded(maxSizeBytes: number): Promise<void> {
  try {
    const db = await openDB();
    const items = await new Promise<CachedImage[]>((resolve) => {
      const tx = db.transaction(STORE_NAME, 'readonly');
      const store = tx.objectStore(STORE_NAME);
      const request = store.getAll();

      request.onsuccess = () => resolve(request.result as CachedImage[]);
      request.onerror = () => resolve([]);
    });

    let totalSize = items.reduce((sum, item) => sum + item.size, 0);
    if (totalSize <= maxSizeBytes) return;

    // Sort by lastAccessed ascending (oldest first) for LRU eviction
    items.sort((a, b) => a.lastAccessed - b.lastAccessed);

    const tx = db.transaction(STORE_NAME, 'readwrite');
    const store = tx.objectStore(STORE_NAME);

    for (const item of items) {
      if (totalSize <= maxSizeBytes) break;
      store.delete([item.articleId, item.page]);
      totalSize -= item.size;
    }
  } catch {
    // best-effort
  }
}
