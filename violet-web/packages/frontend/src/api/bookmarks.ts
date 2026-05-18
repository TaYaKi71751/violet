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

function nextId(items: Array<{ Id: number }>) {
  return items.reduce((max, item) => Math.max(max, item.Id), 0) + 1;
}

function readGroups(): BookmarkGroup[] {
  const groups = readJson<BookmarkGroup[]>(GROUPS_KEY, []);
  if (groups.some((group) => group.Id === DEFAULT_GROUP.Id)) return groups;

  const nextGroups = [DEFAULT_GROUP, ...groups];
  writeJson(GROUPS_KEY, nextGroups);
  return nextGroups;
}

// Groups
export async function getGroups(): Promise<BookmarkGroup[]> {
  return readGroups().sort((a, b) => a.Gorder - b.Gorder);
}

export async function createGroup(req: CreateBookmarkGroupRequest): Promise<{ Id: number }> {
  const groups = readGroups();
  const id = nextId(groups);
  const group: BookmarkGroup = {
    Id: id,
    Name: req.Name,
    DateTime: new Date().toISOString(),
    Description: req.Description ?? null,
    Color: req.Color ?? null,
    Gorder: groups.reduce((max, item) => Math.max(max, item.Gorder), 0) + 1,
  };

  writeJson(GROUPS_KEY, [...groups, group]);
  return { Id: id };
}

export async function deleteGroup(id: number): Promise<void> {
  if (id === DEFAULT_GROUP.Id) return;

  writeJson(GROUPS_KEY, readGroups().filter((group) => group.Id !== id));
  writeJson(
    ARTICLES_KEY,
    readJson<BookmarkArticle[]>(ARTICLES_KEY, []).filter((item) => item.GroupId !== id),
  );
  writeJson(
    ARTISTS_KEY,
    readJson<BookmarkArtist[]>(ARTISTS_KEY, []).filter((item) => item.GroupId !== id),
  );
}

// Articles
export async function getBookmarkArticles(groupId?: number): Promise<BookmarkArticle[]> {
  const articles = readJson<BookmarkArticle[]>(ARTICLES_KEY, []);
  return articles
    .filter((item) => groupId === undefined || item.GroupId === groupId)
    .sort((a, b) => b.Id - a.Id);
}

export async function addBookmarkArticle(req: AddBookmarkArticleRequest): Promise<{ Id: number }> {
  const articles = readJson<BookmarkArticle[]>(ARTICLES_KEY, []);
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

  writeJson(ARTICLES_KEY, [article, ...articles]);
  return { Id: id };
}

export async function deleteBookmarkArticle(id: number): Promise<void> {
  writeJson(
    ARTICLES_KEY,
    readJson<BookmarkArticle[]>(ARTICLES_KEY, []).filter((item) => item.Id !== id),
  );
}

export async function checkBookmark(articleId: string): Promise<boolean> {
  return readJson<BookmarkArticle[]>(ARTICLES_KEY, []).some(
    (item) => item.Article === articleId,
  );
}

// Artists
export async function getBookmarkArtists(groupId?: number): Promise<BookmarkArtist[]> {
  const artists = readJson<BookmarkArtist[]>(ARTISTS_KEY, []);
  return artists
    .filter((item) => groupId === undefined || item.GroupId === groupId)
    .sort((a, b) => b.Id - a.Id);
}

export async function addBookmarkArtist(req: AddBookmarkArtistRequest): Promise<{ Id: number }> {
  const artists = readJson<BookmarkArtist[]>(ARTISTS_KEY, []);
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

  writeJson(ARTISTS_KEY, [artist, ...artists]);
  return { Id: id };
}

export async function deleteBookmarkArtist(id: number): Promise<void> {
  writeJson(
    ARTISTS_KEY,
    readJson<BookmarkArtist[]>(ARTISTS_KEY, []).filter((item) => item.Id !== id),
  );
}

// Crop Images
export async function getCropBookmarks(): Promise<BookmarkCropImage[]> {
  return readJson<BookmarkCropImage[]>(CROPS_KEY, []).sort((a, b) => b.Id - a.Id);
}

export async function addCropBookmark(req: AddBookmarkCropImageRequest): Promise<{ Id: number }> {
  const crops = readJson<BookmarkCropImage[]>(CROPS_KEY, []);
  const id = nextId(crops);
  const crop: BookmarkCropImage = {
    Id: id,
    Article: req.Article,
    Page: req.Page,
    Area: req.Area,
    AspectRatio: req.AspectRatio,
    DateTime: new Date().toISOString(),
  };

  writeJson(CROPS_KEY, [crop, ...crops]);
  return { Id: id };
}

export async function deleteCropBookmark(id: number): Promise<void> {
  writeJson(
    CROPS_KEY,
    readJson<BookmarkCropImage[]>(CROPS_KEY, []).filter((item) => item.Id !== id),
  );
}
