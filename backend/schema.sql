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
  holder TEXT NOT NULL,          -- display nickname (mutable, display only)
  holder_id TEXT NOT NULL DEFAULT ''  -- canonical account id of the record owner
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

-- Whole-day checkpoint totals, keyed by the 02:00 UTC bucket. A new bucket
-- starts with no row, so the previous day's total can never leak into it.
CREATE TABLE IF NOT EXISTS day_cp (
  bucket_date TEXT NOT NULL,   -- YYYY-MM-DD of the event bucket
  account_id TEXT NOT NULL,
  day        INTEGER NOT NULL, -- event day the total belongs to
  cp         INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (bucket_date, account_id, day)
);

-- Unix seconds of the last admin reset (key = 'reset_epoch'). Clients compare
-- it with their saved value and drop local test progress once when it changes.
CREATE TABLE IF NOT EXISTS meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

-- First 15 CP submit on a day locks that day's colour index (1..25).
CREATE TABLE IF NOT EXISTS day_colours (
  day          INTEGER PRIMARY KEY,
  colour_index INTEGER NOT NULL,
  holder_id    TEXT NOT NULL,
  set_at       INTEGER NOT NULL
);
