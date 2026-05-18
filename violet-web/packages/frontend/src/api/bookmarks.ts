import type {
  BookmarkGroup,
  BookmarkArticle,
  BookmarkArtist,
  BookmarkCropImage,
  AddBookmarkArticleRequest,
  AddBookmarkArtistRequest,
  AddBookmarkCropImageRequest,
  CreateBookmarkGroupRequest,
} from '@violet-web/shared';
import {
  USER_STORES,
  getAllUserItems,
  putUserItem,
  putUserItems,
  replaceUserItems,
  deleteUserItem,
} from '../services/user-database';

const GROUPS_KEY = 'violet-web:bookmark-groups';
const ARTICLES_KEY = 'violet-web:bookmark-articles';
const ARTISTS_KEY = 'violet-web:bookmark-artists';
const CROPS_KEY = 'violet-web:bookmark-crops';

const DEFAULT_GROUP: BookmarkGroup = {
  Id: 1,
  Name: 'violet_default',
  DateTime: new Date(0).toISOString(),
  Description: null,
  Color: null,
  Gorder: 0,
};

let migrationPromise: Promise<void> | null = null;

function readLegacyJson<T>(key: string, fallback: T): T {
  if (typeof window === 'undefined') return fallback;

  try {
    const raw = window.localStorage.getItem(key);
    return raw ? (JSON.parse(raw) as T) : fallback;
  } catch {
    return fallback;
  }
}

function nextId(items: Array<{ Id: number }>) {
  return items.reduce((max, item) => Math.max(max, item.Id), 0) + 1;
}

async function ensureMigrated() {
  if (migrationPromise) return migrationPromise;

  migrationPromise = (async () => {
    const [groups, articles, artists, crops] = await Promise.all([
      getAllUserItems<BookmarkGroup>(USER_STORES.bookmarkGroups),
      getAllUserItems<BookmarkArticle>(USER_STORES.bookmarkArticles),
      getAllUserItems<BookmarkArtist>(USER_STORES.bookmarkArtists),
      getAllUserItems<BookmarkCropImage>(USER_STORES.bookmarkCrops),
    ]);

    if (groups.length === 0) {
      const legacyGroups = readLegacyJson<BookmarkGroup[]>(GROUPS_KEY, []);
      await putUserItems(USER_STORES.bookmarkGroups, [
        DEFAULT_GROUP,
        ...legacyGroups.filter((group) => group.Id !== DEFAULT_GROUP.Id),
      ]);
    }

    if (articles.length === 0) {
      await putUserItems(
        USER_STORES.bookmarkArticles,
        readLegacyJson<BookmarkArticle[]>(ARTICLES_KEY, []),
      );
    }

    if (artists.length === 0) {
      await putUserItems(
        USER_STORES.bookmarkArtists,
        readLegacyJson<BookmarkArtist[]>(ARTISTS_KEY, []),
      );
    }

    if (crops.length === 0) {
      await putUserItems(
        USER_STORES.bookmarkCrops,
        readLegacyJson<BookmarkCropImage[]>(CROPS_KEY, []),
      );
    }
  })();

  return migrationPromise;
}

async function readGroups(): Promise<BookmarkGroup[]> {
  await ensureMigrated();
  const groups = await getAllUserItems<BookmarkGroup>(USER_STORES.bookmarkGroups);
  if (groups.some((group) => group.Id === DEFAULT_GROUP.Id)) return groups;

  await putUserItem(USER_STORES.bookmarkGroups, DEFAULT_GROUP);
  return [DEFAULT_GROUP, ...groups];
}

// Groups
export async function getGroups(): Promise<BookmarkGroup[]> {
  return (await readGroups()).sort((a, b) => a.Gorder - b.Gorder);
}

export async function createGroup(req: CreateBookmarkGroupRequest): Promise<{ Id: number }> {
  const groups = await readGroups();
  const id = nextId(groups);
  const group: BookmarkGroup = {
    Id: id,
    Name: req.Name,
    DateTime: new Date().toISOString(),
    Description: req.Description ?? null,
    Color: req.Color ?? null,
    Gorder: groups.reduce((max, item) => Math.max(max, item.Gorder), 0) + 1,
  };

  await putUserItem(USER_STORES.bookmarkGroups, group);
  return { Id: id };
}

export async function deleteGroup(id: number): Promise<void> {
  if (id === DEFAULT_GROUP.Id) return;

  await ensureMigrated();
  await deleteUserItem(USER_STORES.bookmarkGroups, id);

  const [articles, artists] = await Promise.all([
    getAllUserItems<BookmarkArticle>(USER_STORES.bookmarkArticles),
    getAllUserItems<BookmarkArtist>(USER_STORES.bookmarkArtists),
  ]);

  await Promise.all([
    replaceUserItems(
      USER_STORES.bookmarkArticles,
      articles.filter((item) => item.GroupId !== id),
    ),
    replaceUserItems(
      USER_STORES.bookmarkArtists,
      artists.filter((item) => item.GroupId !== id),
    ),
  ]);
}

// Articles
export async function getBookmarkArticles(groupId?: number): Promise<BookmarkArticle[]> {
  await ensureMigrated();
  const articles = await getAllUserItems<BookmarkArticle>(USER_STORES.bookmarkArticles);
  return articles
    .filter((item) => groupId === undefined || item.GroupId === groupId)
    .sort((a, b) => b.Id - a.Id);
}

export async function addBookmarkArticle(req: AddBookmarkArticleRequest): Promise<{ Id: number }> {
  const articles = await getBookmarkArticles();
  const groupId = req.GroupId ?? DEFAULT_GROUP.Id;
  const existing = articles.find(
    (item) => item.Article === req.Article && item.GroupId === groupId,
  );
  if (existing) return { Id: existing.Id };

  const id = nextId(articles);
  const article: BookmarkArticle = {
    Id: id,
    Article: req.Article,
    DateTime: new Date().toISOString(),
    GroupId: groupId,
  };

  await readGroups();
  await putUserItem(USER_STORES.bookmarkArticles, article);
  return { Id: id };
}

export async function deleteBookmarkArticle(id: number): Promise<void> {
  await ensureMigrated();
  await deleteUserItem(USER_STORES.bookmarkArticles, id);
}

export async function checkBookmark(articleId: string): Promise<boolean> {
  const articles = await getBookmarkArticles();
  return articles.some((item) => item.Article === articleId);
}

export async function exportBookmarkArticles(): Promise<string[]> {
  const seen = new Set<string>();
  const entries: string[] = [];

  for (const bookmark of await getBookmarkArticles()) {
    const articleId = String(bookmark.Article);
    if (seen.has(articleId)) continue;

    seen.add(articleId);
    entries.push(articleId);
  }

  return entries;
}

export async function importBookmarkArticles(
  articleIds: unknown,
): Promise<{ added: number; skipped: number }> {
  if (!Array.isArray(articleIds)) {
    throw new Error('Bookmark import data must be an array');
  }

  const articles = await getBookmarkArticles();
  const existing = new Set(articles.map((item) => String(item.Article)));
  const imported: BookmarkArticle[] = [];
  let nextArticleId = nextId(articles);
  let skipped = 0;

  for (const value of articleIds) {
    if (typeof value !== 'string' && typeof value !== 'number') {
      skipped += 1;
      continue;
    }

    const articleId = String(value).trim();
    if (!/^\d+$/.test(articleId) || existing.has(articleId)) {
      skipped += 1;
      continue;
    }

    existing.add(articleId);
    imported.push({
      Id: nextArticleId,
      Article: articleId,
      DateTime: new Date().toISOString(),
      GroupId: DEFAULT_GROUP.Id,
    });
    nextArticleId += 1;
  }

  if (imported.length > 0) {
    await readGroups();
    await putUserItems(USER_STORES.bookmarkArticles, imported);
  }

  return { added: imported.length, skipped };
}

// Artists
export async function getBookmarkArtists(groupId?: number): Promise<BookmarkArtist[]> {
  await ensureMigrated();
  const artists = await getAllUserItems<BookmarkArtist>(USER_STORES.bookmarkArtists);
  return artists
    .filter((item) => groupId === undefined || item.GroupId === groupId)
    .sort((a, b) => b.Id - a.Id);
}

export async function addBookmarkArtist(req: AddBookmarkArtistRequest): Promise<{ Id: number }> {
  const artists = await getBookmarkArtists();
  const groupId = req.GroupId ?? DEFAULT_GROUP.Id;
  const existing = artists.find(
    (item) =>
      item.Artist === req.Artist &&
      item.IsGroup === req.IsGroup &&
      item.GroupId === groupId,
  );
  if (existing) return { Id: existing.Id };

  const id = nextId(artists);
  const artist: BookmarkArtist = {
    Id: id,
    Artist: req.Artist,
    IsGroup: req.IsGroup,
    DateTime: new Date().toISOString(),
    GroupId: groupId,
  };

  await readGroups();
  await putUserItem(USER_STORES.bookmarkArtists, artist);
  return { Id: id };
}

export async function deleteBookmarkArtist(id: number): Promise<void> {
  await ensureMigrated();
  await deleteUserItem(USER_STORES.bookmarkArtists, id);
}

// Crop Images
export async function getCropBookmarks(): Promise<BookmarkCropImage[]> {
  await ensureMigrated();
  return (await getAllUserItems<BookmarkCropImage>(USER_STORES.bookmarkCrops)).sort(
    (a, b) => b.Id - a.Id,
  );
}

export async function addCropBookmark(req: AddBookmarkCropImageRequest): Promise<{ Id: number }> {
  const crops = await getCropBookmarks();
  const id = nextId(crops);
  const crop: BookmarkCropImage = {
    Id: id,
    Article: req.Article,
    Page: req.Page,
    Area: req.Area,
    AspectRatio: req.AspectRatio,
    DateTime: new Date().toISOString(),
  };

  await putUserItem(USER_STORES.bookmarkCrops, crop);
  return { Id: id };
}

export async function deleteCropBookmark(id: number): Promise<void> {
  await ensureMigrated();
  await deleteUserItem(USER_STORES.bookmarkCrops, id);
}
