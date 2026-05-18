import type { ArticleReadLog, InsertReadLogRequest, UpdateReadLogRequest } from '@violet-web/shared';

const HISTORY_KEY = 'violet-web:read-history';

export interface HistoryResponse {
  logs: ArticleReadLog[];
  totalCount: number;
  page: number;
  pageSize: number;
}

function readHistory(): ArticleReadLog[] {
  if (typeof window === 'undefined') return [];

  try {
    const raw = window.localStorage.getItem(HISTORY_KEY);
    return raw ? (JSON.parse(raw) as ArticleReadLog[]) : [];
  } catch {
    return [];
  }
}

function writeHistory(logs: ArticleReadLog[]) {
  window.localStorage.setItem(HISTORY_KEY, JSON.stringify(logs));
}

function getLatestLogsByArticle() {
  const latest = new Map<string, ArticleReadLog>();

  for (const log of readHistory().sort((a, b) => b.Id - a.Id)) {
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
  const logs = getLatestLogsByArticle();
  const start = page * pageSize;

  return {
    logs: logs.slice(start, start + pageSize),
    totalCount: logs.length,
    page,
    pageSize,
  };
}

export async function getHistoryIds(): Promise<string[]> {
  return getLatestLogsByArticle().map((log) => log.Article);
}

export async function insertReadLog(req: InsertReadLogRequest): Promise<{ Id: number }> {
  const logs = readHistory();
  const id = nextId(logs);
  const log: ArticleReadLog = {
    Id: id,
    Article: req.Article,
    DateTimeStart: new Date().toISOString(),
    DateTimeEnd: null,
    LastPage: 0,
    Type: req.Type ?? 0,
  };

  writeHistory([log, ...logs]);
  return { Id: id };
}

export async function updateReadLog(id: number, req: UpdateReadLogRequest): Promise<void> {
  const logs = readHistory();
  writeHistory(
    logs.map((log) =>
      log.Id === id
        ? {
            ...log,
            LastPage: req.LastPage,
            DateTimeEnd: req.DateTimeEnd ?? new Date().toISOString(),
          }
        : log,
    ),
  );
}

export async function deleteReadLog(id: number): Promise<void> {
  writeHistory(readHistory().filter((log) => log.Id !== id));
}
