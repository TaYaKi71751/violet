import { Router } from 'express';
import { getUserDb } from '../services/user-db.js';

export const bookmarksRouter = Router();

// --- Groups ---

bookmarksRouter.get('/groups', (_req, res) => {
  const db = getUserDb();
  const groups = db.prepare('SELECT * FROM BookmarkGroup ORDER BY Gorder ASC').all();
  res.json(groups);
});

bookmarksRouter.post('/groups', (req, res) => {
  const { Name, Description, Color } = req.body;
  const db = getUserDb();
  const maxOrder = db
    .prepare('SELECT COALESCE(MAX(Gorder), 0) as m FROM BookmarkGroup')
    .get() as { m: number };
  const result = db
    .prepare(
      'INSERT INTO BookmarkGroup (Name, DateTime, Description, Color, Gorder) VALUES (?, ?, ?, ?, ?)',
    )
    .run(Name, new Date().toISOString(), Description ?? null, Color ?? null, maxOrder.m + 1);
  res.json({ Id: result.lastInsertRowid });
});

bookmarksRouter.delete('/groups/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const db = getUserDb();
  db.prepare('DELETE FROM BookmarkArticle WHERE GroupId = ?').run(id);
  db.prepare('DELETE FROM BookmarkArtist WHERE GroupId = ?').run(id);
  db.prepare('DELETE FROM BookmarkGroup WHERE Id = ?').run(id);
  res.json({ ok: true });
});

// --- Articles ---

bookmarksRouter.get('/articles', (req, res) => {
  const groupId = req.query.groupId ? parseInt(req.query.groupId as string) : undefined;
  const db = getUserDb();
  const sql = groupId !== undefined
    ? 'SELECT * FROM BookmarkArticle WHERE GroupId = ? ORDER BY Id DESC'
    : 'SELECT * FROM BookmarkArticle ORDER BY Id DESC';
  const articles = groupId !== undefined
    ? db.prepare(sql).all(groupId)
    : db.prepare(sql).all();
  res.json(articles);
});

bookmarksRouter.post('/articles', (req, res) => {
  const { Article, GroupId } = req.body;
  const gid = GroupId ?? 1;
  const db = getUserDb();
  const result = db
    .prepare('INSERT INTO BookmarkArticle (Article, DateTime, GroupId) VALUES (?, ?, ?)')
    .run(Article, new Date().toISOString(), gid);
  res.json({ Id: result.lastInsertRowid });
});

bookmarksRouter.delete('/articles/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const db = getUserDb();
  db.prepare('DELETE FROM BookmarkArticle WHERE Id = ?').run(id);
  res.json({ ok: true });
});

bookmarksRouter.get('/articles/check/:articleId', (req, res) => {
  const articleId = req.params.articleId;
  const db = getUserDb();
  const row = db
    .prepare('SELECT Id FROM BookmarkArticle WHERE Article = ? LIMIT 1')
    .get(articleId);
  res.json({ bookmarked: !!row });
});

// --- Artists ---

bookmarksRouter.get('/artists', (req, res) => {
  const groupId = req.query.groupId ? parseInt(req.query.groupId as string) : undefined;
  const db = getUserDb();
  const sql = groupId !== undefined
    ? 'SELECT * FROM BookmarkArtist WHERE GroupId = ? ORDER BY Id DESC'
    : 'SELECT * FROM BookmarkArtist ORDER BY Id DESC';
  const artists = groupId !== undefined
    ? db.prepare(sql).all(groupId)
    : db.prepare(sql).all();
  res.json(artists);
});

bookmarksRouter.post('/artists', (req, res) => {
  const { Artist, IsGroup, GroupId } = req.body;
  const gid = GroupId ?? 1;
  const db = getUserDb();
  const result = db
    .prepare('INSERT INTO BookmarkArtist (Artist, IsGroup, DateTime, GroupId) VALUES (?, ?, ?, ?)')
    .run(Artist, IsGroup ?? 0, new Date().toISOString(), gid);
  res.json({ Id: result.lastInsertRowid });
});

bookmarksRouter.delete('/artists/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const db = getUserDb();
  db.prepare('DELETE FROM BookmarkArtist WHERE Id = ?').run(id);
  res.json({ ok: true });
});

// --- Crop Images ---

bookmarksRouter.get('/crops', (_req, res) => {
  const db = getUserDb();
  const crops = db.prepare('SELECT * FROM BookmarkCropImage ORDER BY Id DESC').all();
  res.json(crops);
});

bookmarksRouter.delete('/crops/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const db = getUserDb();
  db.prepare('DELETE FROM BookmarkCropImage WHERE Id = ?').run(id);
  res.json({ ok: true });
});
