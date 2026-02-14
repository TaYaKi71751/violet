import { Router } from 'express';
import { getContentDb, isContentDbReady } from '../services/content-db.js';
import { translateQuery } from '../services/query-engine.js';
import {
  buildSuggestionCache,
  loadSuggestionCacheFromFile,
  searchSuggestions,
  getCacheStatus,
} from '../services/suggestion-engine.js';

// Load cache from file on startup, or build from DB if file not available
if (!loadSuggestionCacheFromFile() && isContentDbReady()) {
  console.log('No suggestion cache file found, building from DB...');
  buildSuggestionCache(getContentDb());
}

export const contentRouter = Router();

contentRouter.get('/search', (req, res) => {
  if (!isContentDbReady()) {
    res.status(503).json({ error: 'Database syncing, please wait.' });
    return;
  }

  const query = (req.query.q as string) || '';
  const page = parseInt(req.query.page as string) || 0;
  const pageSize = Math.min(parseInt(req.query.pageSize as string) || 30, 100);

  const db = getContentDb();
  const { sql, countSql } = translateQuery(query, page, pageSize);

  const articles = db.prepare(sql).all();
  const countRow = db.prepare(countSql).get() as { cnt: number } | undefined;
  const totalCount = countRow?.cnt ?? 0;

  res.json({ articles, totalCount, page, pageSize });
});

// Suggestion endpoints (must be before /:id route)
contentRouter.get('/suggest', (req, res) => {
  if (!isContentDbReady()) {
    res.status(503).json({ error: 'Database syncing, please wait.' });
    return;
  }

  const q = (req.query.q as string) || '';
  const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);

  const suggestions = searchSuggestions(q, limit);
  res.json({ suggestions });
});

contentRouter.post('/suggest/rebuild', (req, res) => {
  if (!isContentDbReady()) {
    res.status(503).json({ error: 'Database syncing, please wait.' });
    return;
  }

  try {
    const db = getContentDb();
    buildSuggestionCache(db);
    res.json({ success: true });
  } catch (error) {
    console.error('Failed to build suggestion cache:', error);
    res.status(500).json({ error: 'Failed to build cache' });
  }
});

contentRouter.get('/suggest/status', (req, res) => {
  const status = getCacheStatus();
  res.json(status);
});

contentRouter.get('/:id', (req, res) => {
  if (!isContentDbReady()) {
    res.status(503).json({ error: 'Database syncing, please wait.' });
    return;
  }

  const id = parseInt(req.params.id);
  if (isNaN(id)) {
    res.status(400).json({ error: 'Invalid id' });
    return;
  }

  const db = getContentDb();
  const article = db
    .prepare('SELECT * FROM HitomiColumnModel WHERE Id = ?')
    .get(id);

  if (!article) {
    res.status(404).json({ error: 'Not found' });
    return;
  }

  res.json(article);
});
