import express from 'express';
import cors from 'cors';
import { contentRouter } from './routes/content.js';
import { proxyRouter } from './routes/proxy.js';
import { bookmarksRouter } from './routes/bookmarks.js';
import { historyRouter } from './routes/history.js';
import { syncRouter } from './routes/sync.js';
import { downloadsRouter } from './routes/downloads.js';
import { aiSearchRouter } from './routes/ai-search.js';
import { errorHandler } from './middleware/error-handler.js';
import { requestLogger } from './middleware/request-logger.js';

export function createApp() {
  const app = express();

  app.use(cors());
  app.use(express.json());
  app.use(requestLogger);

  app.get('/api/health', (_req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
  });

  app.use('/api/content', contentRouter);
  app.use('/api/proxy', proxyRouter);
  app.use('/api/bookmarks', bookmarksRouter);
  app.use('/api/history', historyRouter);
  app.use('/api/sync', syncRouter);
  app.use('/api/downloads', downloadsRouter);
  app.use('/api/ai-search', aiSearchRouter);

  app.use(errorHandler);

  return app;
}
