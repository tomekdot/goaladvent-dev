# 🎄 GoalAdvent 2026 (dev build)

Development build for ManiaPlanet 4 / Openplanet 1.29. It is **not** submitted
to the official Openplanet plugin list - install it from this repo or from the
attached `goaladvent-dev.op` package only.

A 25-day Christmas **Goal Hunt** advent: collect checkpoints on event maps,
fight over a daily bounty, earn badges, and share one free leaderboard with up
to ~30 players. All code, comments, UI strings and docs are in English. For the complete
technical reference see [DOCS.md](DOCS.md).

---

## ✨ Features

- 🎁 **24 event days + grand finale** (day 25). Tuesdays (1, 8, 15, 22) are
  Pursuit bonus nights on ManiaPlanet - no Goal Hunt race, no lost streak.
- 🚩 **Checkpoint scoring**: 10 CP in one run completes a day (100 pts;
  300 pts for the finale). Premiere day pays x2 - the **server UTC** clock
  decides, so changing the local clock cannot cheat.
- 🛡️ **Bounty**: most checkpoints on a day wins the record and +150 pts.
  Starts at 15 CP held by `GrinchBot`. Optional `timeMs` is a tie-breaker.
  The bounty bonus is granted at most once per day per player.
- 🔁 **Catch-up**: past days stay playable until the event ends. The finale
  stays open until 5 January; the raffle is drawn afterwards.
- 🏆 **Best 15 of 24 count**. The finale always counts on top. Missing days
  never destroy a run.
- 🎖️ **Badges**: `GOALMAS-2026`, `GOALMAS-PLAYER`, `BOUNTY-HUNTER`,
  `ELF-VETERAN`, `GOALMAS-24`, `FINALIST`, plus `PURSUIT` and `MP-GALAXY`.
- 🖥️ **Dashboard**: left sidebar, 5x5 colour-coded calendar, day details,
  leaderboard, live feed, finale tab, HUD and banner.
- 🌗 **Two colour themes** with one shared layout (see below).

---

## 🧮 Scoring in detail

| What | Points |
|---|---|
| Complete day 1-24 | 100 |
| Complete day 1-24 on premiere (server UTC) | 200 |
| Complete finale (day 25) | 300 |
| Take a day's bounty record | +150 (once per day) |

The server stores the best checkpoint count and the earned points **per day**
in D1. The leaderboard sorts days 1-24 by points, takes the top 15 and adds the
finale. This is exactly the number shown as `BEST 15` in the footer, so the
local view and the online ranking always agree. Badge thresholds are 10 and 24
completed days, and FINALIST for all 25.

---

## 📋 Requirements

- ManiaPlanet 4 with Openplanet 1.29.14 (all natives verified against
  `OpenplanetCore.json`).
- No account, no paid service. Offline mode works with nothing configured.

---

## 📦 Install

1. Copy this folder to:
   ```
   C:\Users\tomekdot\Openplanet4\Plugins\goaladvent-dev
   ```
2. Reload scripts in game (`F3 -> Developer -> Reload Scripts`) or restart.
3. Open the plugin from the Openplanet menu: **GoalAdvent**.

The dashboard opens automatically on start (`Show dashboard on start = true`).
Turn that setting off if you want to open it manually from the menu.

---

## 🎨 Themes

Both themes use **the same layout** - only colours, transparency and corner
radius change. Switching is instant and is saved in Openplanet settings.

- 🖤 **Obsidian Minimal** (default): matte carbon, 4-6 px rounding.
- 🪟 **Transparent Glass**: neutral black smoke over the game (45% by default),
  white frosted cards, 0 px corners and white alpha borders. The
  `Glass Opacity` slider (15-80%) adjusts the window tint live; intermediate
  containers stay fully transparent so layers do not stack into a wall.

Switch with `UI Theme` in Openplanet -> Settings -> Plugins -> GoalAdvent.

---

## ⚙️ Settings

All options live in Openplanet's own plugin settings (no in-plugin settings
window).

| Setting | Default | Meaning |
|---|---|---|
| `Show dashboard on start` | on | Open the window with the game |
| `UI Theme` | Obsidian Minimal | Colour scheme |
| `Glass Opacity` | 0.55 | Window tint strength (Glass theme) |
| `Show moon phase percent` | on | Show illumination on tiles |
| `Show in-game tips` | on | Short hint in the calendar tab |
| `Show notifications` | on | Banners for completed days and bounties |
| `Auto sync` | on | Refresh results every 20 seconds |
| `Sync mode` | 0 (effective 2) | 0 offline, 1 shared folder, 2 HTTP worker |
| `Worker URL` | baked in | Cloudflare Worker base URL |
| `Event server keyword` | empty | Restrict results to the event server |
| `Map UID to day` | empty | `UID=day` pairs for maps without `#N` |
| `Force current map as day` | 0 | 1-25 override for testing |
| `Debug overlay` | off | Admin diagnostics window |

---

## 🗄️ Live database

- 📊 Read-only admin page:
  `https://goalmas.tomekdot-goalmas.workers.dev/admin?token=<ADMIN_TOKEN>`
  (players, bounties, learned map UIDs, recent events). The token is a Worker
  secret and is deliberately not stored in this repo.
- 🧰 Raw D1 tables: Cloudflare dashboard -> Workers & Pages -> D1 -> `goalmas`.
- ☁️ Worker root health check:
  `https://goalmas.tomekdot-goalmas.workers.dev/`

---

## 🔄 Sync modes

| Mode | Transport | What you need |
|---|---|---|
| `0` | Offline | Nothing. Progress in `GoalmasAdvent.json` in plugin storage |
| `1` | Shared folder | SMB / OneDrive / Dropbox folder, one JSON per player |
| `2` | HTTP worker | Free Cloudflare Workers + D1 (already deployed) |

The worker URL is baked into `DEFAULT_API_URL`, so the plugin switches to mode
`2` automatically on load. Players configure nothing. Set mode `0` to force
offline. See [DEPLOY.md](backend/DEPLOY.md) for redeployment steps.

---

## 🏁 Map detection

1. 🗺️ **Name first**: `#7 Goal Hunt`, `Goal Hunt Day 7`, `GH 7`,
   `Goal Hunt - Minesweeper`, `goalhuntarena` - format codes are stripped.
2. 🆔 **UID mapping**: the first submit sends `mapUid`; the worker stores
   `UID -> day` in D1 and shares it through `/state`. New maps work for
   everyone after the first run.
3. 📅 **UTC date fallback**: during the event (1-25 December UTC, finale until
   5 January) a Goal Hunt map without a number is assigned to today's day.
4. 🛠️ Manual fallbacks: **Assign this map to day N** in the debug panel,
   `Map UID to day` setting, or `Force current map as day`.

Set `Event server keyword` to part of the server name/login so editor or other
servers are ignored. Empty accepts everything (test mode).

---

## 🐛 Debugging (admin)

Enable `Debug overlay` in settings. A `Debug` item appears in the plugin menu
with a live state window:

- ✅ `SERVER ONLINE` / ❌ `NOT CONFIRMED`, HTTP code, last-sync age, board rows
- 🎯 detected Goal Hunt day and playable state
- 📤 submit queue, CP counters, API URL, event-server check, map name/UID
- 🔘 buttons: **Test server**, **Run sync now**, **Copy log to clipboard**,
  **Clear errors**

The `[goaladvent][DBG]` line is written to `Openplanet.log` on load and on
every map change; **Copy log to clipboard** packages the state, status, test
result and errors into one pasteable block.

---

## 📁 Source layout

| File | Responsibility |
|---|---|
| `src/Config.as` | Settings, tuning constants, global state, storage paths |
| `src/Calendar.as` | Day titles/hints/fragments, dates, badges, scoring, JSON save |
| `src/GoalHunt.as` | Identity, map detection, checkpoint counting, rewards, upload |
| `src/Sync.as` | Banner/feed, HTTP/folder transports, `/state` parsing |
| `src/UI.as` | Dashboard layout, tabs, grid, HUD, feed, footer |
| `src/Theme.as` | `ThemePalette` - colours, alpha and radii for both themes |
| `src/Debug.as` | Admin diagnostics and log line |
| `src/Main.as` | Entry points (`Main`, `Update`, `Render`, `RenderInterface`, `RenderMenu`) |
| `backend/worker.js` | Cloudflare Worker + D1: `/state`, `/submit`, `/admin` |
| `backend/schema.sql` | D1 tables (`players`, `bounties`, `events`, `map_days`) |
| `backend/wrangler.toml` | Worker/D1 deployment config |
| `backend/DEPLOY.md` | Free-tier deployment guide |

---

## ❓ Troubleshooting

| Symptom | Fix |
|---|---|
| Plugin not in menu | Check `PluginsEnabled` in `Settings.ini` and reload scripts |
| `No Goal Hunt map detected` | Map has no `#N` - use the debug assign button or set a UID mapping |
| `submit: HTTP 403` | Old worker - redeploy with `wrangler deploy` (all days now accepted) |
| `Attempted to suspend...` | Fixed by running HTTP sync in a coroutine (`startnew`) |
| Raw `$fff` codes in feed | Fixed - feed uses the ManiaPlanet colour parser |
| Leaderboard disagrees with `BEST 15` | Updated worker scoring - submit once to migrate |
| `Script compilation failed` | Check `Openplanet.log`, then reload scripts |

---

## 📝 Notes

- The local JSON file is authoritative; the worker is a shared mirror.
- `Update(float dt)` receives milliseconds; timers use seconds.
- CP counting uses `CTrackManiaPlayer.ScriptAPI.CurRace.Checkpoints.Length`.
- Cloudflare's free tier handles ~30 concurrent players with a large margin.
- Release notes and full changelog links are generated automatically on each
  `v*` tag: https://github.com/tomekdot/goaladvent-dev/releases
