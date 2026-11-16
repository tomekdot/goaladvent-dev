-- Goalmas - D1 schema (Cloudflare SQLite).
-- Run once:  npx wrangler d1 execute goalmas --remote --file=schema.sql

CREATE TABLE IF NOT EXISTS players (
  account_id TEXT PRIMARY KEY,   -- MP4 login (OnlineLogin), no passwords
  name       TEXT NOT NULL,      -- in-game nickname
  points     INTEGER NOT NULL DEFAULT 0,
  bounties   INTEGER NOT NULL DEFAULT 0,
  badges     TEXT NOT NULL DEFAULT '[]',  -- JSON array of badge names
  bests      TEXT NOT NULL DEFAULT '{}'   -- JSON: { "7": { "cp": 18, "ms": 0 } }
);

CREATE TABLE IF NOT EXISTS bounties (
  day    INTEGER PRIMARY KEY,    -- 1..25
  cp     INTEGER NOT NULL,       -- best checkpoint count
  ms     INTEGER NOT NULL DEFAULT 0,  -- optional time, tie-breaker only
  holder TEXT NOT NULL           -- nickname of the record holder
);

CREATE TABLE IF NOT EXISTS events (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  msg        TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
