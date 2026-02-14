import { Router } from 'express';
import { getContentDb, isContentDbReady } from '../services/content-db.js';
import { translateQuery } from '../services/query-engine.js';

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
