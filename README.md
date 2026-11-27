# 🎄 GoalAdvent 2026

A 25-day Christmas **Goal Hunt** advent for ManiaPlanet 4. Collect checkpoints on event maps, fight over a daily bounty, earn badges and compete on one free shared leaderboard (up to ~30 players).

> **Dev build** for ManiaPlanet 4 / Openplanet 1.29. It is **not** submitted to the official Openplanet plugin list. Install it from this repo or from the attached `goaladvent-dev.op` package only.

Everything (code, comments, UI strings, docs) is in English. Full technical reference: [DOCS.md](DOCS.md).

**Contents:** [Quick start](#-quick-start) · [How it works](#-how-it-works) · [Scoring](#-scoring) · [Features](#-features) · [Themes](#-themes) · [Settings](#️-settings) · [Map detection](#-map-detection) · [Sync modes](#-sync-modes) · [Admin & debugging](#-admin--debugging) · [QA](#-release-qa) · [Troubleshooting](#-troubleshooting) · [Source layout](#-source-layout) · [Notes](#-notes)

---

## 🚀 Quick start

**Requirements:** ManiaPlanet 4 with Openplanet 1.29.14 (all natives verified against `OpenplanetCore.json`). No account and no paid service; offline mode works with nothing configured.

1. Copy this folder to your Openplanet plugins directory, e.g.
   ```
   C:\Users\<you>\Openplanet4\Plugins\goaladvent-dev
   ```
2. Reload scripts in game (`F3 → Developer → Reload Scripts`) or restart the game.
3. Open **GoalAdvent 2026** from the Openplanet menu.

The dashboard opens automatically on start. Turn off `Show dashboard on start` if you prefer to open it manually.

The worker URL is baked in, so the plugin switches to online mode on its own. Players configure nothing. Set `Sync mode` to `0` to force offline.

---

## 🗓️ How it works

- **24 event days + a grand finale** on day 25.
- **Tuesdays (1, 8, 15, 22)** are Pursuit bonus nights on ManiaPlanet: no Goal Hunt race, and no lost streak.
- **Strict 1–25 December, UTC.** Days roll over at **02:00 UTC**, so a run at 01:59 UTC still belongs to the previous day. No future day is accepted, and the event closes at 02:00 UTC on 26 December. There is no January catch-up window.
- Past days stay playable while the event runs. The worker's day bucket is mirrored into `/state`, so tiles unlock on **server time**; changing your local clock cannot cheat.
- **Checkpoints accumulate across the whole event day**, not just one race. Later laps keep counting until the match ends.

---

## 🧮 Scoring

| What | Points |
|---|---|
| Complete day 1–24 (10 CP) | 100 |
| Complete day 1–24 on **premiere** (server UTC) | 200 |
| Complete the finale (day 25) | 300 |
| Take a day's bounty record | +150 (once per day per player) |

**Best 15 of 24 days count**, and the finale always counts on top. Missing days never destroy a run.

The server stores the best checkpoint count and earned points **per day** in D1. The leaderboard sorts days 1–24 by points, takes the top 15 and adds the finale. This is exactly the `TOTAL SCORE` shown in the finale tab, so the local view and the online ranking always agree.

### 🛡️ Bounty

The player with the most checkpoints on a day holds the record and earns +150 pts.

- Every day starts at **15 CP held by `GrinchBot`**.
- Equal CP is broken by the lower `timeMs` (the plugin sends 0 today).
- The record owner is stored as the account id, not the mutable nickname.
- The bonus is granted at most once per day per player, enforced by the D1 primary key.

### 🥇 Run tiers (visual only)

Tiers appear in the tile outline, day details, tooltip and HUD. **Points never change.**

| Tier | Checkpoints |
|---|---|
| Completed (emerald) | 10 |
| Silver | 15 |
| Gold | 30 |

### 📈 Milestones (cosmetic)

5 / 10 / 15 / 30 / 50 / 100 CP. The HUD shows the day total, the last milestone reached and the next one with "to go". Day details and tile tooltips show the same ladder. No extra points.

### 🎖️ Badges

`GOALMAS-2026`, `GOALMAS-PLAYER`, `BOUNTY-HUNTER`, `ELF-VETERAN`, `GOALMAS-24`, `FINALIST`, plus `PURSUIT` and `MP-GALAXY`.

Thresholds: 10 and 24 completed days; `FINALIST` requires all 25.

---

## ✨ Features

- 🖥️ **Dashboard**: compact tab bar, 5×5 calendar, day details, leaderboard, live feed, per-day bounty board, finale tab, HUD and banner. The window is movable and manually resizable; the grid and tables follow the content region. State is shown by tile icon, caption and border (no corner badges).
- 🎁 **Gift opening**: finishing a day or stealing a bounty plays a short animation with the points, checkpoints and current bounty holder.
- 💬 **Discord feed**: the worker mirrors bounty takeovers and first clears to a channel webhook, so `#goalmas-leaderboard` updates by itself.
- 🌗 **Two colour themes** sharing one layout (see [Themes](#-themes)).

---

## 🎨 Themes

Both themes use **the same layout**. Only colours, transparency and corner radius change. Switching is instant and saved in Openplanet settings (`Settings → Plugins → GoalAdvent 2026`).

| Theme | Look |
|---|---|
| 🪟 **Transparent Glass** (default) | Neutral black smoke over the game, white frosted cards, 0 px corners, white alpha borders. Enabled by the `Galaxy theme` switch |
| 🖤 **Obsidian Minimal** | Matte carbon, 4–6 px rounding. Turn the `Galaxy theme` switch off and pick `GoalAdvent` as the UI Theme |

The `Glass Opacity` slider (15–80%) adjusts the window tint live. Intermediate containers stay fully transparent so layers do not stack into a wall.

---

## ⚙️ Settings

All options live in Openplanet's plugin settings (there is no separate in-plugin settings window).

| Setting | Default | Meaning |
|---|---|---|
| `Show dashboard on start` | on | Open the window with the game |
| `Galaxy theme` | on | Use the transparent Glass look now |
| `UI Theme` | Classic | Colour scheme when `Galaxy theme` is off |
| `UI scale` | 1.25 | Font and card scale (1.0–2.0) |
| `Glass Opacity` | 0.55 | Window tint strength (Glass theme) |
| `Show moon phase percent` | on | Show illumination on tiles |
| `Show day details` | off | Side panel with details instead of the full-width grid |
| `Show in-game tips` | on | Short hint in the calendar tab |
| `Show notifications` | on | Banners for completed days and bounties |
| `Opening animation` | on | Gift card on day completion / bounty |
| `Auto sync` | on | Refresh results every 20 seconds |
| `Sync mode` | 0 (effective 2) | 0 offline, 1 shared folder, 2 HTTP worker |
| `Worker URL` | baked in | Cloudflare Worker base URL |
| `Event server keyword` | pursuit | Restrict detection to the event server |
| `Allowed titlepacks` | Pursuit,PursuitStadium | Title ids where detection may run |
| `Map UID to day` | empty | `UID=day` pairs for maps without `#N` |
| `Force current map as day` | 0 | 1–25 override for testing |
| `Debug overlay` | off | Admin diagnostics window |
| `QA preview` | 0 | Review the finished UI without saving or submitting anything: 0 off, 1 all 25 days done, 2 CP tier mix, 3 finale only |

---

## 🏁 Map detection

The plugin tries these in order:

1. 🛠️ `Force current map as day` (1–25), then a number in the map name (`#7 Goal Hunt`, `Goal Hunt Day 7`, `GH 7`). Format codes are stripped.
2. 🆔 **UID mapping**: the first submit sends `mapUid`; the worker stores `UID → day` in D1 and shares it through `/state`. A new map works for everyone after the first run.
3. 🗺️ **MapType** `TrackMania\GoalHuntArena` is authoritative and bypasses the server/titlepack gate.
4. 📅 **UTC bucket fallback**: during the event, a Goal Hunt map without a number is assigned to today's bucket.
5. 🛠️ **Manual fallbacks**: **Assign this map to day N** in the debug panel or the `Map UID to day` setting.

Set `Event server keyword` to part of the server name or login so editor and other servers are ignored. An empty value accepts everything (test mode). `Allowed titlepacks` compares the base title id before `@author`.

---

## 🔄 Sync modes

| Mode | Transport | What you need |
|---|---|---|
| `0` | Offline | Nothing. Progress is kept in `GoalmasAdvent.json` in plugin storage |
| `1` | Shared folder | SMB / OneDrive / Dropbox folder, one JSON per player |
| `2` | HTTP worker | Free Cloudflare Workers + D1 (already deployed) |

Redeployment steps: [backend/DEPLOY.md](backend/DEPLOY.md).

---

## 🗄️ Admin & debugging

### Live database

- 📊 Read-only admin page: `https://goalmas.tomekdot-goalmas.workers.dev/admin?token=<ADMIN_TOKEN>` (players, bounties, learned map UIDs, recent events). The token is a Worker secret and is deliberately **not** stored in this repo.
- 🧰 Raw D1 tables: Cloudflare dashboard → Workers & Pages → D1 → `goalmas`.
- ☁️ Worker health check: `https://goalmas.tomekdot-goalmas.workers.dev/`

The reset route is restricted to the owner account and the admin secret. A player cannot reset anyone's progress.

### Debug overlay

Enable `Debug overlay` in settings. A `Debug` item appears in the plugin menu with a live state window:

- ✅ `SERVER ONLINE` / ❌ `NOT CONFIRMED`, HTTP code, last-sync age, board rows
- 🎯 detected Goal Hunt day and playable state
- 📤 submit queue, CP counters, API URL, event-server check, map name/UID
- 🔘 buttons: **Test server**, **Run sync now**, **Copy log to clipboard**, **Clear errors**

A `[goaladvent][DBG]` line is written to `Openplanet.log` on load and on every map change. **Copy log to clipboard** packages state, status, test result and errors into one pasteable block.

---

## 🧪 Release QA

Node only, no dependencies:

```
node tests/qa_checks.js
node tests/qa_checks.js --live
```

It checks source hygiene, constants shared with the worker, rest days, CP tiers, server-clock gating, admin reset guards, the QA preview, the 02:00 UTC bucket and the worker syntax. With `--live` it also probes the deployed worker.

The result is written to `tests/qa-result.json`. With the debug overlay on, the log line shows `qa=passed` (or `failed`) next to `qaPreview=N`. Keep it green before a release.

---

## ❓ Troubleshooting

| Symptom | Fix |
|---|---|
| Plugin not in menu | Check `PluginsEnabled` in `Settings.ini` and reload scripts |
| `No Goal Hunt map detected` | The map has no `#N`: use the debug assign button or set a UID mapping |
| `submit: HTTP 403` | The server says that day is not open. Check the PC clock and the December date; a future day cannot be published |
| `Attempted to suspend...` | Fixed by running HTTP sync in a coroutine (`startnew`) |
| Raw `$fff` codes in feed | Fixed: notifications and feed rows use one sanitizer |
| Leaderboard disagrees with `TOTAL SCORE` | Updated worker scoring: submit once to migrate |
| `Script compilation failed` | Check `Openplanet.log`, then reload scripts |
| Test data left before the event | On the admin page (secret token required) use `Reset owner test data`; the next sync clears the local save too |

---

## 📁 Source layout

| File | Responsibility |
|---|---|
| `src/Config.as` | Settings, tuning constants, global state, storage paths |
| `src/Calendar.as` | Day titles/hints/fragments, dates, badges, scoring, JSON save |
| `src/GoalHunt.as` | Identity, map detection, checkpoint counting, rewards, upload |
| `src/Sync.as` | Banner/feed, HTTP/folder transports, `/state` parsing |
| `src/UI.as` | Dashboard layout, tabs, grid, HUD, feed |
| `src/Theme.as` | `ThemePalette`: colours, alpha and radii for both themes |
| `src/Debug.as` | Admin diagnostics and log line |
| `src/Main.as` | Entry points (`Main`, `Update`, `Render`, `RenderInterface`, `RenderMenu`) |
| `backend/worker.js` | Cloudflare Worker + D1: `/state`, `/submit`, `/admin`, `/admin/reset` |
| `backend/schema.sql` | D1 tables (`players`, `bounties`, `events`, `map_days`, `bounty_bonus`, `meta`, `day_cp`) |
| `backend/wrangler.toml` | Worker/D1 deployment config |
| `backend/DEPLOY.md` | Free-tier deployment guide |

---

## 📝 Notes

- The local JSON file is authoritative; the worker is a shared mirror.
- `Update(float dt)` receives milliseconds; timers use seconds.
- CP counting uses a monotonic per-run counter over `CTrackManiaPlayer.ScriptAPI.CurRace.Checkpoints`, with lap and trigger identity for later laps, accumulated for the whole 02:00 UTC bucket. Milestones are display-only.
- Cloudflare's free tier handles ~30 concurrent players with a large margin.
- Release notes and changelog are generated automatically on each `v*` tag: <https://github.com/tomekdot/goaladvent-dev/releases>
