import { Router } from 'express';
import { getUserDb } from '../services/user-db.js';

export const historyRouter = Router();

historyRouter.get('/', (req, res) => {
  const page = parseInt(req.query.page as string) || 0;
  const pageSize = Math.min(parseInt(req.query.pageSize as string) || 30, 100);
  const db = getUserDb();
  const logs = db
    .prepare(
      'SELECT * FROM ArticleReadLog ORDER BY Id DESC LIMIT ? OFFSET ?',
    )
    .all(pageSize, page * pageSize);
  const countRow = db
    .prepare('SELECT COUNT(*) as cnt FROM ArticleReadLog')
    .get() as { cnt: number };
  res.json({ logs, totalCount: countRow.cnt, page, pageSize });
});

historyRouter.post('/', (req, res) => {
  const { Article, Type } = req.body;
  const db = getUserDb();
  const result = db
    .prepare(
      'INSERT INTO ArticleReadLog (Article, DateTimeStart, DateTimeEnd, LastPage, Type) VALUES (?, ?, NULL, 0, ?)',
    )
    .run(Article, new Date().toISOString(), Type ?? 0);
  res.json({ Id: result.lastInsertRowid });
});

historyRouter.patch('/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const { LastPage, DateTimeEnd } = req.body;
  const db = getUserDb();
  const end = DateTimeEnd ?? new Date().toISOString();
  db.prepare(
    'UPDATE ArticleReadLog SET LastPage = ?, DateTimeEnd = ? WHERE Id = ?',
  ).run(LastPage, end, id);
  res.json({ ok: true });
});

historyRouter.delete('/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const db = getUserDb();
  db.prepare('DELETE FROM ArticleReadLog WHERE Id = ?').run(id);
  res.json({ ok: true });
});
