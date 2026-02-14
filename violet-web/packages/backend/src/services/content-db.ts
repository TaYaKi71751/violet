import Database from 'better-sqlite3';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

let db: Database.Database | null = null;

export function getDbPath(): string {
  return process.env.DATA_DB_PATH || path.resolve(__dirname, '../../data/data.db');
}

export function isContentDbReady(): boolean {
  return fs.existsSync(getDbPath());
}

export function getContentDb(): Database.Database {
  if (db) return db;

  const dbPath = getDbPath();
  db = new Database(dbPath, { readonly: true });
  // WAL mode is set by writable connections, readonly connections inherit it
  return db;
}

export function closeContentDb(): void {
  if (db) {
    db.close();
    db = null;
  }
}

export function reopenContentDb(): Database.Database {
  closeContentDb();
  return getContentDb();
}
