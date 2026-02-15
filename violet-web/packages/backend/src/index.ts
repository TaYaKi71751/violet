import { createApp } from './app.js';
import { SyncManager } from './services/sync-manager.js';
import { recoverInterruptedDownloads } from './services/download-service.js';

const PORT = process.env.PORT ? parseInt(process.env.PORT) : 3001;

const app = createApp();

app.listen(PORT, async () => {
  console.log(`[violet-web] Backend running on http://localhost:${PORT}`);

  // Recover downloads interrupted by previous shutdown
  recoverInterruptedDownloads();

  // Initialize sync manager
  try {
    const syncManager = SyncManager.getInstance();
    await syncManager.initialize();
  } catch (error) {
    console.error('[violet-web] Failed to initialize SyncManager:', error);
  }
});
