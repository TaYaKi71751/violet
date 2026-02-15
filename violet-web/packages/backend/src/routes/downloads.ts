import { Router } from 'express';
import { getUserDb } from '../services/user-db.js';
import { startDownload, retryDownload } from '../services/download-service.js';

export const downloadsRouter = Router();

downloadsRouter.post('/', async (req, res) => {
  const { articleId } = req.body;
  if (!articleId) {
    res.status(400).json({ error: 'articleId is required' });
    return;
  }

  try {
    const downloadId = await startDownload(String(articleId));
    const db = getUserDb();
    const record = db.prepare('SELECT * FROM Download WHERE Id = ?').get(downloadId);
    res.json(record);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    res.status(500).json({ error: message });
  }
});

downloadsRouter.get('/', (req, res) => {
  const page = parseInt(req.query.page as string) || 0;
  const pageSize = Math.min(parseInt(req.query.pageSize as string) || 30, 100);
  const db = getUserDb();

  const downloads = db
    .prepare('SELECT * FROM Download ORDER BY Id DESC LIMIT ? OFFSET ?')
    .all(pageSize, page * pageSize);

  const countRow = db.prepare('SELECT COUNT(*) as cnt FROM Download').get() as { cnt: number };

  res.json({ downloads, totalCount: countRow.cnt, page, pageSize });
});

downloadsRouter.get('/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const db = getUserDb();
  const record = db.prepare('SELECT * FROM Download WHERE Id = ?').get(id);

  if (!record) {
    res.status(404).json({ error: 'Download not found' });
    return;
  }

  res.json(record);
});

downloadsRouter.post('/:id/retry', async (req, res) => {
  const id = parseInt(req.params.id);
  try {
    await retryDownload(id);
    const db = getUserDb();
    const record = db.prepare('SELECT * FROM Download WHERE Id = ?').get(id);
    res.json(record);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    res.status(400).json({ error: message });
  }
});

downloadsRouter.delete('/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const db = getUserDb();
  db.prepare('DELETE FROM Download WHERE Id = ?').run(id);
  res.json({ ok: true });
});
