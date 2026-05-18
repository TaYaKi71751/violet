import type { ArticleReadLog, InsertReadLogRequest, UpdateReadLogRequest } from '@violet-web/shared';
import {
  USER_STORES,
  getAllUserItems,
  putUserItem,
  putUserItems,
  deleteUserItem,
} from '../services/user-database';

const HISTORY_KEY = 'violet-web:read-history';

export interface HistoryResponse {
  logs: ArticleReadLog[];
  totalCount: number;
  page: number;
  pageSize: number;
}

let migrationPromise: Promise<void> | null = null;

function readLegacyHistory(): ArticleReadLog[] {
  if (typeof window === 'undefined') return [];

  try {
    const raw = window.localStorage.getItem(HISTORY_KEY);
    return raw ? (JSON.parse(raw) as ArticleReadLog[]) : [];
  } catch {
    return [];
  }
}

async function ensureMigrated() {
  if (migrationPromise) return migrationPromise;

  migrationPromise = (async () => {
    const logs = await getAllUserItems<ArticleReadLog>(USER_STORES.readHistory);
    if (logs.length === 0) {
      await putUserItems(USER_STORES.readHistory, readLegacyHistory());
    }
  })();

  return migrationPromise;
}

async function readHistory(): Promise<ArticleReadLog[]> {
  await ensureMigrated();
  return getAllUserItems<ArticleReadLog>(USER_STORES.readHistory);
}

async function getLatestLogsByArticle() {
  const latest = new Map<string, ArticleReadLog>();

  for (const log of (await readHistory()).sort((a, b) => b.Id - a.Id)) {
    if (!latest.has(log.Article)) {
      latest.set(log.Article, log);
    }
  }

  return Array.from(latest.values()).sort((a, b) => b.Id - a.Id);
}

function nextId(logs: ArticleReadLog[]) {
  return logs.reduce((max, log) => Math.max(max, log.Id), 0) + 1;
}

export async function getHistory(page = 0, pageSize = 30): Promise<HistoryResponse> {
  const logs = await getLatestLogsByArticle();
  const start = page * pageSize;

  return {
    logs: logs.slice(start, start + pageSize),
    totalCount: logs.length,
    page,
    pageSize,
  };
}

export async function getHistoryIds(): Promise<string[]> {
  return (await getLatestLogsByArticle()).map((log) => log.Article);
}

export async function insertReadLog(req: InsertReadLogRequest): Promise<{ Id: number }> {
  const logs = await readHistory();
  const id = nextId(logs);
  const log: ArticleReadLog = {
    Id: id,
    Article: req.Article,
    DateTimeStart: new Date().toISOString(),
    DateTimeEnd: null,
    LastPage: 0,
    Type: req.Type ?? 0,
  };

  await putUserItem(USER_STORES.readHistory, log);
  return { Id: id };
}

export async function updateReadLog(id: number, req: UpdateReadLogRequest): Promise<void> {
  const logs = await readHistory();
  const log = logs.find((item) => item.Id === id);
  if (!log) return;

  await putUserItem(USER_STORES.readHistory, {
    ...log,
    LastPage: req.LastPage,
    DateTimeEnd: req.DateTimeEnd ?? new Date().toISOString(),
  });
}

export async function deleteReadLog(id: number): Promise<void> {
  await ensureMigrated();
  await deleteUserItem(USER_STORES.readHistory, id);
}
