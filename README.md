# goalmas 2026 (dev build)

Development build for this ManiaPlanet 4 / Openplanet 1.29 setup. It is not
submitted to the official Openplanet plugin list - install it from this repo or
from the attached `goalmas-dev.op` package only.

A 25-day Christmas **Goal Hunt** advent event for **ManiaPlanet 4** (Openplanet 1.29).
Players collect checkpoints on maps named `#N Goal Hunt`, fight over a daily checkpoint
bounty, earn badges and a raffle ticket, and share one free leaderboard.

English is used for all code, comments, UI strings and documentation.

## Features

- **24 event days + grand finale** (day 25), with Tuesdays (1, 8, 15, 22) reserved for
  Pursuit on ManiaPlanet - no Goal Hunt, no lost streak.
- **Checkpoint scoring**: reaching 10 CP in one run completes a day (100 pts;
  300 pts for the finale). The map premiere day pays x2 - the server's UTC clock
  decides, so clients cannot cheat by changing their local time.
- **Bounty = most checkpoints**: start at 15 CP held by GrinchBot; beat it to take
  the record and 150 bonus points. Optional `timeMs` is kept as a tie-breaker.
- **Catch-up**: every past day stays playable until the event ends, so nobody loses
  a day. The finale stays open until 5 January and the raffle is drawn afterwards.
- **Best 15 of 24** days count toward the final score - no burnout penalty.
- **Badges**: `GOALMAS-2026`, `GOALMAS-PLAYER`, `BOUNTY-HUNTER`, `ELF-VETERAN`,
  `GOALMAS-24`, `FINALIST`, plus community badges (`PURSUIT`, `MP-GALAXY`).
- **Modern dashboard UI**: header card with progress and badges, four tabs
  (calendar / leaderboard / live feed / finale), colour-coded 5x5 tile grid and
  a separate detail card for the selected day.
- **Live HUD, banner and notifications** while driving a Goal Hunt map.

## Requirements

- ManiaPlanet 4 with Openplanet 1.29.14 (the reflection DB used to verify every native).
- The plugin runs entirely offline by default - no account, no server, no cost.

## Install

Copy this folder to:

```
C:\Users\tomekdot\Openplanet4\Plugins\goalmas-dev
```

Reload scripts in game (`F3 -> Developer -> Reload Scripts`) or restart the game.
Open it from the Openplanet plugin menu: **goalmas**.

Nothing is visible at startup; the calendar only opens when you select it.

## Themes

Two visual styles share the same data and switch live, with no game restart:

- **Obsidian Minimal** (default): compact carbon dashboard with a left sidebar,
  round stat cards and a 5x5 tile grid.
- **Pursuit Native**: translucent scoreboard inspired by the Pursuit mode in
  ManiaPlanet - sharp 0 px corners, white column headers, alternating rows,
  gold stars and a bottom `TOTAL POINTS` bar.

Switch with the cog button in the plugin window, the `Settings` item in the
plugin menu, or the `UI Theme` setting in Openplanet -> Settings -> Plugins.
The choice is saved between game sessions. Settings also expose `Show moon
phase percent`, `Show in-game tips` and `Auto sync`.

## Sync modes

| Mode | Transport | What you need |
|---|---|---|
| `0` | Offline | Nothing. Progress is saved in `GoalmasAdvent.json` in plugin storage. |
| `1` | Shared folder | A folder shared by everyone (SMB, OneDrive, Dropbox). One JSON per player, local leaderboard. |
| `2` | HTTP worker | Free Cloudflare Workers + D1. See [DEPLOY.md](DEPLOY.md). |

Set `Sync mode` in the plugin settings. If a Worker URL is configured, the plugin
switches to HTTP mode automatically - players do not have to configure anything.

## Event server

Maps are detected by name only: `#1 Goal Hunt` ... `#25 Goal Hunt` (also accepts
`GoalHunt` and `Goal-Hunt`, with or without format codes). Set `Event server keyword`
to part of the event server name/login so results from the editor or other servers
are ignored.

## Source layout

| File | Responsibility |
|---|---|
| `src/Config.as` | Settings, palette of constants, global state |
| `src/Calendar.as` | 25 day titles/hints/fragments, dates, badges, scoring, JSON save |
| `src/GoalHunt.as` | Player identity, map detection, checkpoint counting, rewards, upload |
| `src/Sync.as` | Banner/feed, shared-folder and HTTP transports, `/state` parsing |
| `src/UI.as` | Obsidian dashboard, tabs, calendar grid, HUD, banner, settings window |
| `src/UI_Pursuit.as` | Pursuit Native scoreboard theme and its style helper |
| `src/Main.as` | Entry points (`Main`, `Update`, `Render`, `RenderInterface`, `RenderMenu`) |
| `backend/worker.js` | Cloudflare Worker + D1 backend: `/state` and `/submit` |
| `backend/schema.sql` | D1 tables |
| `backend/wrangler.toml` | Worker/D1 deployment config (fill in `database_id`) |
| `backend/DEPLOY.md` | Step-by-step free deployment guide |

## Notes

- The local JSON file is always authoritative; the worker is a shared mirror.
- `Update(float dt)` receives milliseconds; the banner and submit debounce use seconds.
- Checkpoint counting uses `CTrackManiaPlayer.ScriptAPI.CurRace.Checkpoints.Length`,
  the same native path as the working chase-mode overlay.
- No paid service is required. Cloudflare's free tier handles ~30 concurrent players
  with a very large margin.
