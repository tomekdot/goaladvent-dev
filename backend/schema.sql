-- goalmas - D1 schema (Cloudflare SQLite).
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
  cp     INTEGER NOT NULL DEFAULT 0,  -- best checkpoint count
  ms     INTEGER NOT NULL DEFAULT 0,  -- optional time, tie-breaker only
  holder TEXT NOT NULL           -- nickname of the record holder
);

CREATE TABLE IF NOT EXISTS events (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  msg        TEXT NOT NULL,
  created_at INTEGER NOT NULL
);

-- Learned from real submits: a new map UID is bound to the day it was played
-- on, then shared with every player through /state.
CREATE TABLE IF NOT EXISTS map_days (
  uid        TEXT PRIMARY KEY,
  day        INTEGER NOT NULL,
  first_seen INTEGER NOT NULL
);

-- One bounty bonus per player per day. The primary key makes the grant
-- race-free: of two simultaneous submits exactly one row is inserted.
CREATE TABLE IF NOT EXISTS bounty_bonus (
  day        INTEGER NOT NULL,
  account_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (day, account_id)
);

-- Unix seconds of the last admin reset (key = 'reset_epoch'). Clients compare
-- it with their saved value and drop local test progress once when it changes.
CREATE TABLE IF NOT EXISTS meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
