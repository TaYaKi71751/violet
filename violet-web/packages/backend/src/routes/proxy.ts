import { Router } from 'express';
import { proxyImage } from '../services/image-proxy.js';
import { resolveGallery } from '../services/gallery-resolver.js';

export const proxyRouter = Router();

proxyRouter.get('/image', async (req, res, next) => {
  try {
    const url = req.query.url as string;
    const referer = req.query.referer as string | undefined;

    if (!url) {
      res.status(400).json({ error: 'url parameter required' });
      return;
    }

    await proxyImage(url, referer, res);
  } catch (err) {
    next(err);
  }
});

proxyRouter.get('/gallery/:id', async (req, res, next) => {
  try {
    const id = parseInt(req.params.id);
    if (isNaN(id)) {
      res.status(400).json({ error: 'Invalid gallery id' });
      return;
    }

    const result = await resolveGallery(id);
    res.json(result);
  } catch (err) {
    next(err);
  }
});
