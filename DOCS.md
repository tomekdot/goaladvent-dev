# GoalAdvent 2026 - full technical documentation

This file is the complete reference for the project. For the player-facing
overview see [README.md](README.md); for deployment commands see
[backend/DEPLOY.md](backend/DEPLOY.md); for agent rules see [AGENTS.md](AGENTS.md).

---

## 1. Identity and scope

| Item | Value |
|---|---|
| Display name | GoalAdvent |
| Folder / repo / package id | `goaladvent-dev` |
| GitHub | https://github.com/tomekdot/goaladvent-dev |
| Default branch | `main` |
| Release tag pattern | `v*` (for example `v0.5.4-dev`) |
| Version source | `info.toml` and `PLUGIN_VERSION` in `src/Config.as` |
| Target game | ManiaPlanet 4 (MP4), Openplanet 1.29.14 |
| Language | AngelScript + ImGui; all code, comments, UI strings and docs in English |
| Distribution | Dev-only; not submitted to the official Openplanet plugin list |

Deliberately unchanged after the rename, because changing them would break live
data: Cloudflare worker and D1 name `goalmas`, the API URL, the save file
`GoalmasAdvent.json`, and badge codes starting with `GOALMAS-`.

Live endpoints:

```
Worker root:   https://goalmas.tomekdot-goalmas.workers.dev/
State:         https://goalmas.tomekdot-goalmas.workers.dev/state?accountId=<id>
Submit:        POST https://goalmas.tomekdot-goalmas.workers.dev/submit
Admin page:    https://goalmas.tomekdot-goalmas.workers.dev/admin?token=<ADMIN_TOKEN>
D1 account:    https://dash.cloudflare.com/2975602b6ae7dc883884858d1b5ce4bf/database/d1
D1 database:   goalmas  (id in backend/wrangler.toml)
```

The `ADMIN_TOKEN` is a Worker secret and is intentionally not stored in git.
Create it with `wrangler secret put ADMIN_TOKEN` from `backend/`.

---

## 2. Quick start

1. Copy the folder to `C:\Users\tomekdot\Openplanet4\Plugins\goaladvent-dev`.
2. Start ManiaPlanet with Openplanet developer mode (omit unsigned-plugin
   warnings only if `Settings.ini` has `DeveloperMode=true`).
3. Reload scripts with `F3 -> Developer -> Reload Scripts`, or restart the game
   after a folder move so stale load errors clear.
4. The dashboard opens on start (`S_ShowOnStart = true`). It can also be opened
   from the Openplanet menu item `GoalAdvent`.
5. Settings are edited in `Openplanet -> Settings -> Plugins -> GoalAdvent`.
   There is no in-plugin settings window.
6. Verify the log:
   ```
   Get-Content ...\Openplanet.log -Tail 400 |
     Select-String 'goaladvent|ERR :|Script compilation failed'
   ```
   Expected: `Loaded plugin 'goaladvent-dev' (version ...)` and
   `[goaladvent] Loaded: 25 days, goal 10 CP, sync mode 2.` with no `ERR :`.

Never kill `ManiaPlanet.exe` from an agent; ask the user to reload.

---

## 3. Source layout

| File | Responsibility |
|---|---|
| `src/Config.as` | Settings, constants (`PLUGIN_VERSION`, scoring, timings), global state |
| `src/Calendar.as` | Day titles/hints/fragments, `g_offDays`, dates, badges, `ScoreDays()`, save/load |
| `src/GoalHunt.as` | Identity, map detection, checkpoint counting, rewards, submit coroutines |
| `src/Sync.as` | Banner/feed, folder + HTTP transports, `/state` parsing, self-test |
| `src/Theme.as` | `ThemePalette` with colours, alpha and corner radii for both themes |
| `src/UI.as` | Single dashboard layout, tabs, grid, HUD, banner, footer, MP colour parser |
| `src/Debug.as` | Admin overlay, `DebugStateLine()`, clipboard log export, error history |
| `src/Main.as` | Entry points: `Main`, `Update`, `Render`, `RenderInterface`, `RenderMenu` |
| `backend/worker.js` | Cloudflare Worker: `/`, `/state`, `/submit`, `/admin` |
| `backend/schema.sql` | D1 tables: `players`, `bounties`, `events`, `map_days` |
| `backend/wrangler.toml` | Worker/D1 binding and deployed database id |
| `backend/DEPLOY.md` | Free-tier deployment guide |
| `.github/workflows/release.yml` | Build `goaladvent-dev.op` and publish releases on `v*` tags |

Openplanet compiles `src/*.as` recursively; no explicit manifest lists them.

---

## 4. Event rules

### 4.1 Days

- 25 days: 1-24 regular, 25 = grand finale.
- `g_offDays = { 1, 8, 15, 22 }` in `Calendar.as`; must match
  `TUESDAY_OFF_DAYS` in `backend/worker.js`. Those are Pursuit bonus nights in
  the calendar UI. The worker now accepts submissions on every day, because a
  Goal Hunt map can be played on any of them.
- Day 25 finale stays open until 5 January (`FINALE_GRACE_DAYS = 5`).
- All past days remain playable for catch-up.

### 4.2 Checkpoints and points

| Action | Points |
|---|---|
| Complete day 1-24 (10 CP in one run) | `BASE_POINTS = 100` |
| Complete on premiere day (server UTC) | x2 |
| Complete finale | `FINALE_POINTS = 300` |
| Take a day bounty record | `BOUNTY_POINTS = 150` (once per day per player) |

Checkpoint count comes from
`CTrackManiaPlayer.ScriptAPI.CurRace.Checkpoints.Length` over
`app.CurrentPlayground.Players`, matched by local login.

### 4.3 Final score

`ScoreDays()` sorts completed days 1-24 by earned points, takes the top 15 and
sums them. `TotalPoints()` adds the finale. The worker does the same in
`scoreFromBests(bests)` so `TOTAL` in the footer equals the leaderboard.

Each day stores `{ cp, ms, pts, b }` in the player's `bests` JSON:
`pts` is the earned day score, `b` marks that the bounty bonus was already
granted. Legacy records without `pts` are reconstructed on read.

### 4.4 Badges

`GOALMAS-2026` (starter), `GOALMAS-PLAYER` (first completion),
`BOUNTY-HUNTER`, `ELF-VETERAN` (10 completed days), `GOALMAS-24`,
`FINALIST` (all 25), plus community badges `PURSUIT` and `MP-GALAXY` derived
from server name/login keywords.

---

## 5. Map detection

Detection order in `DetectGoalHuntDay()`:

1. **Explicit override**: `S_MapDayOverride` (1-25, for testing).
2. **UID mapping from server**: `mapDays` returned by `/state`, learned from
   completed submits of all players.
3. **Local UID mapping**: `S_MapUidDays`, a comma-separated `UID=day` list.
   The debug button *Assign this map to day N* adds the current map.
4. **Name parser** `ParseDayFromMapName()`: accepts `#7 Goal Hunt`,
   `Goal Hunt Day 7`, `GH 7`, `Goal Hunt - Minesweeper`, `goalhuntarena`.
   ManiaPlanet format codes (`$fff`, `$z`, ...) are stripped first.
5. **Map type metadata** `CGameCtnChallenge.MapType`: values containing
   `GoalHuntArena` are recognised even when the name has no number. This is
   how maps such as `Goal Hunt - Complex` (MapType `GoalHuntArena`,
   Titlepack `Pursuit`) are detected.
6. **UTC date fallback** `CurrentEventDayUtc()`: during 1-25 December (and the
   January finale window) a recognised Goal Hunt map with no number is
   assigned to today's UTC day.

All of the above is gated by `OnEventServer()`: if `S_EventServerKeyword` is
set, the server name or login must contain it. Empty keyword accepts all
servers (test mode).

When the first completed run on an unknown map is submitted, its UID is stored
in D1 `map_days` and shared through `/state`, so every player recognises the
map afterwards without manual configuration.

---

## 6. Sync and coroutines

Modes (`S_SyncMode`):

| Mode | Transport | Notes |
|---|---|---|
| `0` | Offline | Save file `GoalmasAdvent.json` in plugin storage |
| `1` | Shared folder | One JSON per player; local leaderboard |
| `2` | HTTP worker | Cloudflare; default effective mode because `DEFAULT_API_URL` is baked in |

`DEFAULT_API_URL` is non-empty, so `Main()` promotes mode 0 to 2 on load.
The stored `[Setting]` default remains `0`; the effective mode is `2`.

**Coroutine rule:** any function containing `yield()` or `sleep()` must run in
a coroutine. `SyncState()` and `Coroutine_SubmitCp()` yield on HTTP, so UI
callers use `startnew(...)` via `SyncNow()` / `SubmitWhenFree()`. Direct calls
are only valid from existing coroutines (`AutoSyncLoop`, `Coroutine_SubmitCp`).

Submit flow:

1. `TrackGoalHunt()` detects a new CP maximum and sets `g_submitPending`.
2. After `SUBMIT_DEBOUNCE_SEC` (6 s), `RequestCpSubmit()` queues `g_pendingDay`
   and `g_pendingCp`. `g_lastSentCp` is NOT advanced yet.
3. `SubmitWhenFree()` waits while `g_syncing`, then calls `Coroutine_SubmitCp()`.
4. Only HTTP 200 advances `g_lastSentCp`. A failed or busy submit is retried.

`/state` response fields: `points`, `bounties`, `badges`, `days` (25 entries),
`leaderboard` (top 20), `mapDays` (UID to day), `events` (last 15).

---

## 7. Cloudflare backend

`worker.js` runs `ensureSchema(env)` once per isolate (cached promise), then
routes:

- `GET /` - health JSON `{ ok: true, service: "goalmas", goalCp: 10, days: 25 }`.
- `GET /state?accountId=...` - player state, leaderboard, map bindings, feed.
- `POST /submit` - body `{ accountId, name, day, cpCount, timeMs, mapUid }`.
  Validates day 1-25 and cpCount 1-250, records bounty/UID, recomputes points.
- `GET /admin?token=...` - read-only HTML dashboard. Returns 404 when
  `ADMIN_TOKEN` is unset or does not match.

D1 tables (`schema.sql`):

```
players(account_id PK, name, points, bounties, badges, bests)
bounties(day PK, cp DEFAULT 0, ms, holder)
events(id PK AUTOINCREMENT, msg, created_at)
map_days(uid PK, day, first_seen)
```

Redeploy after any backend change:

```
cd backend
wrangler d1 execute goalmas --remote --file=schema.sql
wrangler deploy
```

### Discord announcements

The worker can mirror the live feed into Discord. Set one secret and every
bounty takeover and first day completion is posted as an embed:

```
cd backend
wrangler secret put DISCORD_WEBHOOK_URL
```

Paste a channel webhook URL (Discord: Channel Settings -> Integrations ->
Webhooks -> New Webhook -> Copy URL). Without the secret the worker simply
skips Discord, so nothing breaks; the `/admin` page shows
`Discord webhook: configured / not set` so you can confirm it after deploying.

Announcement rules:

- bounty takeover (holder changes) -> gold embed "Bounty taken - day N" with
  player, checkpoints and the bonus points;
- first completion of a day -> blue embed "Day N completed";
- repeated submits with no new points stay silent, so the channel is not
  flooded.

The same lines are stored in `events` and appear in the plugin's Live feed tab.

---

## 8. UI and themes

One layout, two palettes (`Theme.as`). `RefreshPalette()` is called from
`Render()` and `RenderDashboard()`; UI code reads colours only through
`Gold()`, `TextMain()`, `g_palette.*` wrappers.

- **Obsidian Minimal** (default): matte carbon, 4-6 px rounding.
- **Transparent Glass**: neutral black smoke (`rgba(3%,3%,3%,S_GlassOpacity)`),
  white frosted cards (`rgba(255,255,255,0.07)`), 0 px corners, white alpha
  borders. Intermediate containers use `containerBg` with alpha 0 so layers
  do not stack. Default opacity `0.55`, slider range 0.15-0.80.

Font scale: title 16 px, tagline 13 px, section headers 15 px, calendar tip
14 px, tile icon 18 px, tile label 16 px, tile moon 13 px, footer 14 px.

Panels: sidebar (tabs + progress + day status field), workspace (calendar,
leaderboard, live feed, finale), fixed footer with live health, admin debug
window, HUD and banner overlays.

Completing a day (or stealing a bounty) plays a short gift-opening card drawn
on the foreground draw list: the box pops in, the lid lifts, a gold ring
expands and the result line shows points, checkpoints and the current bounty
holder. It takes no input, so it cannot block driving, and it fades out after
`OPEN_ANIM_SEC` (4.2 s). `S_OpenAnimation` turns it off; when it is off the
plain text banner is used instead.

The leaderboard and feed use a ManiaPlanet format-code parser (`MpColour`,
`DrawMpSpan`, `DrawMpName`) so `$fff`, `$f04`, `$z` etc. render as colours
instead of raw text.

Debug panel shows at the top: server online/not confirmed, HTTP code, last
sync age, board row count, detected Goal Hunt day, map name, map type, UID,
playable state. Buttons: Test server, Assign this map to day N, Copy log to
clipboard, Log state to Openplanet.log, Run sync now, Clear errors.

---

## 9. Settings reference

| Setting | Default | Meaning |
|---|---|---|
| Show dashboard on start | on | Open the window with the game |
| UI Theme | Obsidian Minimal | Colour scheme |
| Glass Opacity | 0.55 | Window tint strength |
| Show moon phase percent | on | Illumination on tiles |
| Show in-game tips | on | Hint in calendar tab |
| Show notifications | on | Event banners |
| Opening animation | on | Gift card on day completion / bounty |
| Auto sync | on | Refresh every 20 s |
| Sync mode | 0 stored / 2 effective | Offline / folder / worker |
| Worker URL | baked in | Cloudflare base URL |
| Event server keyword | pursuit | Anti-cheat server filter |
| Map UID to day | empty | `UID=day` pairs |
| Force current map as day | 0 | 1-25 override for testing |
| Debug overlay | off | Admin diagnostics |

---

## 10. Verification and troubleshooting

Static checks (temp folder):

```
node C:\Users\tomekdot\AppData\Local\Temp\opencode\goalmas_check.js
node ...\ui_balance.js
node ...\ui_style_stack_all.js
node ...\calendar_check.js
node ...\ascii_check.js
```

`goalmas_check.js` validates braces, UI API names/enums against
`OpenplanetCore.json`, reserved keywords, duplicate signatures, icons, worker
syntax and stale names. Expect `ALL CHECKS OK`.

Runtime verification:

```
Get-Content C:\Users\tomekdot\Openplanet4\Openplanet.log -Tail 400 |
  Select-String 'goaladvent|ERR :|Script compilation failed'
```

| Symptom | Cause / fix |
|---|---|
| Plugin missing from menu | `PluginsEnabled` entry in `Settings.ini`; reload scripts |
| `Script compilation failed` | Check exact line in log; common cause was `&inout` on `bool` (fixed) |
| `Attempted to suspend...` | HTTP called from UI; use `startnew()` |
| `No Goal Hunt map detected` | Check map name/type; assign UID or set override |
| `submit: HTTP 403` | Old worker; redeploy (all days accepted now) |
| CP not submitted | Fixed by `SubmitWhenFree()` queue and `g_lastSentCp` on success |
| Raw `$fff` in feed | Fixed by MP colour parser |
| Footer shows huge `syncAge` | Fixed: prints `never` when no sync yet |
| Leaderboard differs from TOTAL | Fixed by `scoreFromBests()` and legacy migration |

---

## 11. AngelScript / ImGui gotchas (MP4 1.29)

Ground truth for any native: `C:\Users\tomekdot\Openplanet4\OpenplanetCore.json`
and the reflection DB `Openplanet4.json`.

Absent or trap-prone: `I2S`, `UI::TextColored`, `UI::CalcTextSize`,
`GetItemRectMin/Max`, `UI::InputInt3`, `UI::BeginTable(id, flags)` two-arg form,
`mp.ManiaApp`, `UI::GetCursorPosX()`.

- `tostring(uint)` is ambiguous - cast to `int`.
- No `char()` or char literals; `out` is a reserved word.
- `bool &inout` is invalid - use `bool&`.
- `AddRectFilled(vec4)` takes `(x, y, width, height)`, not end coordinates.
- `DrawList::AddText` takes a position.
- `SetCursorPos()` past current content must be followed by an item (for
  example `UI::Dummy(vec2(0, 1))`) or `EndChild()` asserts.
- Never call `SetCursorScreenPos()` inside `BeginChild`.
- Every `PushStyleColor` / `PushStyleVar` needs a matching pop in the same
  function; `PushDashboardStyle()` = 13 colours + 10 vars.
- Child cards without scrolling: `NoScrollbar | NoScrollWithMouse` and
  `ScrollbarSize = 0`.
- `UI::BeginTabBar(id)` takes only the id; `UI::ListBox` uses a value array.

---

## 12. Git and release workflow

- One clean commit per change, Conventional Commits with scope:
  `feat(goaladvent): ...`, `fix(goaladvent): ...`, `style(goaladvent): ...`.
- Author: `tomekdot <73403480+tomekdot@users.noreply.github.com>`.
- Iterate with amend + `git push --force-with-lease` on personal branches;
  do not stack fixup commits.
- `main` is the default branch and source of releases. Merge feature work
  there, then push a `v*` tag from `main`.
- The Actions workflow builds `goaladvent-dev.op` (`info.toml`, `README.md`,
  `src/`) and publishes a release with a Markdown compare link.
- Before force-pushing, check `git fetch`, `git log --graph --all` and
  `.git/rebase-merge` - another agent may be rewriting the branch.

---

## 13. Pre-1-December checklist

- [x] Clean compile confirmed in `Openplanet.log`
- [x] Worker + D1 deployed, `/state` and `/submit` verified with real requests
- [x] Best-15 scoring verified (3 x 100 CP -> 300 points)
- [x] Admin page token-protected, raw D1 dashboard link documented
- [x] Map detection by name, UID (server + local), MapType and UTC date
- [x] Submit queue no longer drops CP during a sync
- [x] Readable fonts and colours on all tiles and headers
- [x] README, DOCS, DEPLOY and AGENTS up to date
- [ ] Live 25-day event with ~30 players (starts 1 December UTC)
- [ ] Final visual check after the last reload (user action)

---

## 14. Quick reference

```
Game folder:   C:\Users\tomekdot\Openplanet4\Plugins\goaladvent-dev
Log:           C:\Users\tomekdot\Openplanet4\Openplanet.log
Checker:       C:\Users\tomekdot\AppData\Local\Temp\opencode\goalmas_check.js
Repo:          https://github.com/tomekdot/goaladvent-dev
Releases:      https://github.com/tomekdot/goaladvent-dev/releases
Worker:        https://goalmas.tomekdot-goalmas.workers.dev
D1 database:   goalmas
Event dates:   1-25 December 2026, finale until 5 January 2027
```
