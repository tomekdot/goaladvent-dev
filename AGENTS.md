# GoalAdvent dev - agent instructions

Source of truth for any AI agent working in this repository. Read it before
editing code. The broader workspace rules also apply:
`C:\Users\tomekdot\Openplanet4\AGENTS.md`.

## 1. Project identity

- **GoalAdvent 2026** - a 25-day Goal Hunt advent event for **ManiaPlanet 4** with
  **Openplanet 1.29.14**. Dev-only build; never submit to the official
  Openplanet plugin list.
- Folder / repo / package: `goaladvent-dev`.
  Remote: `https://github.com/tomekdot/goaladvent-dev`, default branch `main`,
  active feature branch `ui-layout-fixes`.
- Version: `info.toml` is the single source of truth and is bumped with every
  release tag - never hardcode the current version number in this file.
  Every build here is a dev build: tags and `info.toml` use the `-dev` suffix
  (`v0.6.0-dev`, not `v0.6.0`). The tag must equal `info.toml` exactly; keep the
  debug-only `PLUGIN_VERSION` in `Config.as` in sync with it. Each release
  bumps the patch by one (`0.6.0-dev` -> `0.6.1-dev` -> `0.6.2-dev`); only a
  deliberate milestone changes the minor number.
- Leaderboard points come from `scoreFromBests(bests)`: best 15 of days 1-24
  plus finale. Each day stores `pts` and a one-time bounty flag `b` in `bests`.
  Verified with 3x100 CP submits -> 300 points in `/state`.
- Renamed: folder / repo / package are `goaladvent-dev`, display name is
  `GoalAdvent 2026`. Deliberately unchanged: Cloudflare worker + D1 name `goalmas`,
  API URL, save file `GoalmasAdvent.json` and badge codes `GOALMAS-*` - changing
  those would break live data and saved progress.
- AngelScript 1.29 rejects `&inout` on primitives (e.g. `bool`); use plain
  `bool&` for an in/out reference parameter. This broke the whole compile in
  `DrawMpSpan()` once.
- Top bar uses 16 px title / 13 px tagline; footer uses 14 px text. Footer
  reserve is 30 px (`vec2(..., -30)`) so it sits low without a tall empty band.
- New maps are learned automatically: the plugin sends `mapUid` with every
  submit, the worker stores it in D1 `map_days` and returns it as `mapDays` in
  `/state`. Detection order: override -> server mapDays -> local UID setting ->
  name parser (#N / Day N / GH N / goalhuntarena) -> UTC date during the event.
- `/submit` must accept runs on every day. The old Tuesday 403 check was
  removed from `backend/worker.js` after a real Goal Hunt map mapped to day 1
  was rejected; redeploy with `wrangler deploy` from `backend/` after edits.
- Detection order: `S_MapDayOverride` -> `S_MapUidDays` (UID=day pairs) ->
  `#N Goal Hunt` name parser. Maps like "Goal Hunt - Minesweeper" have no
  number, so they need a UID mapping; the debug button adds the current map to
  the selected day immediately.
- Debug panel has `Copy log to clipboard` (`IO::SetClipboard`), which pastes
  the full state line, status, server-test result and all collected errors as
  one block. Keep `DebugStateLine()` as the single source for log and clipboard.
- The optional day-details strip (`S_ShowDayDetails`, default off) is split:
  a non-scrolling body child plus a fixed 46 px action row (`RenderDayAction`)
  so the button is always visible. The default view is the full-width grid
  with a thin day bar (`RenderDayBar`) below it. Never pin the button with
  `SetCursorPosY()` on the whole panel again.
- Readiness at a glance: debug panel starts with SERVER ONLINE / NOT CONFIRMED,
  HTTP code, last-sync age, board row count and Goal Hunt map detection. The
  `Test server` button runs `SelfTestServer()` (a coroutine) and prints OK/FAIL.
  The footer shows the same live health plus player count.
- `SyncState()` yields on HTTP and **must** be launched with `startnew()` from
  any UI path (`SyncNow()`, buttons). Direct calls are only valid inside
  coroutines (`AutoSyncLoop`, `Coroutine_SubmitCp`). Calling it from `Render()`
  throws `Attempted to suspend in script context that does not support suspension`.
- Backend is live at `https://goalmas.tomekdot-goalmas.workers.dev` and baked
  into `DEFAULT_API_URL` in `Config.as`, so sync mode 2 is automatic for every
  player. D1 `goalmas` ID is in `backend/wrangler.toml`; redeploy with
  `wrangler deploy` from `backend/`.
- Map detection order: `S_MapDayOverride` -> server `mapDays` (UID) -> local
  `S_MapUidDays` -> name parser (`#N`, `Day N`, `GH N`, `goalhuntarena`) ->
  MapType `TrackMania\GoalHuntArena` -> UTC event day. A MapType containing
  `GoalHuntArena` is authoritative and **bypasses** `OnEventServer()` (the
  titlepack/keyword gate); without it the gate still applies. When there is no
  day in the name or UID mapping and we are outside the event window, a real
  Goal Hunt map maps to `g_selectedDay` (usually 1) so QA is not stuck at 0.
  `CurrentTitleId()` returns an id with an author suffix in MP4 (observed
  `Pursuit@domino54`); `TitleIdBase()` strips everything from `@` and allowed
  entries are matched by prefix, so `Pursuit` accepts both `Pursuit@domino54`
  and `PursuitStadium@author`. `CurrentMapName()` and the live `detected day`
  are shown in the debug panel with `title` / `titleRaw`; a
  `[goaladvent][DBG] Map ... -> day ...` line is logged on every map change
  when `S_Debug` is on.
- Header card is a single row: tagline on the left, sync/save/reset/theme
  icon buttons on the right. Progress numbers live only in the footer
  (points | gifts | badges, with icon anchors); no header progress strip.
  Navigation is a compact five-tab bar (Calendar / Leaderboard / Live feed /
  Bounties / Finale), not a sidebar. The footer shows connection status.
- Admin debug: `S_Debug` (Settings -> Advanced -> Debug overlay) adds a `Debug`
  menu item and writes one `[goaladvent][DBG]` line on load. `LogDebugState()` is
  the single place to extend when adding a new diagnostic field.
- There is NO in-plugin settings window. All options are `[Setting]` globals in
  `Config.as`, edited only in Openplanet -> Settings -> Plugins -> GoalAdvent 2026.
  `Glass Opacity` uses min/max there; changing it updates the palette next frame.
- `S_QaPreview` (Advanced, 0 off / 1 all days / 2 CP tiers / 3 finale only)
  fills the in-memory arrays with a mock 25-day season for release review.
  `ApplyQaPreview()` runs after `LoadProgress()` and after every `ApplyState()`;
  while it is on, `SaveProgress()`, `TrackGoalHunt()` and the submit path are
  disabled so the real save and D1 are untouched. Openplanet caches newly
  added settings until a full restart - to test a variant before that, change
  the default in `Config.as` and reload. Restore it to 0 afterwards.
  To force a clean local slate, create `.qa-clean-slate` in the plugin folder
  and reload: `LoadProgress()` deletes it, sets `S_QaPreview = 0`, resets the
  arrays and writes a fresh save; `SaveProgress()` skips writes while the
  marker exists so an unload cannot restore preview data.
- QA gate: `node tests/qa_checks.js` (add `--live` for worker checks). It writes
  `tests/qa-result.json` with `status: passed|failed`; the debug panel shows
  it as `qa=passed` through `QaResultText()` in `Debug.as`. Keep it green
  before tagging a release.
- `S_ShowOnStart` defaults to `true` - the dashboard opens by itself. There is
  deliberately no startup banner; banners are only for in-game Goal Hunt events.
- Reward feedback: `StartOpenAnimation()` / `RenderOpenAnimation()` in `UI.as`
  draw a gift-opening card on the foreground draw list (no window, no input,
  4.2 s). `CompleteDay()` and `ClaimBounty()` call it instead of `ShowBanner()`
  when `S_OpenAnimation` is on; a run that both completes the day and steals the
  bounty merges into one card. Never make this overlay take mouse input.
- Discord mirror: worker secret `DISCORD_WEBHOOK_URL` posts an embed for every
  bounty takeover (holder change) and first day completion. Repeated +0 submits
  stay silent. `/admin` shows `Discord webhook: configured / not set`.
- The worker has a read-only `/admin?token=<ADMIN_TOKEN>` HTML page (secret is
  never committed) and D1 can be browsed in the Cloudflare dashboard.
- Admin reset: `POST /admin/reset?token=<ADMIN_TOKEN>` with JSON
  `{ "accountId": "tomek_k.", "confirm": "RESET" }`. It requires the secret
  **and** the fixed `OWNER_ACCOUNT_ID`, so only the owner's test data can be
  wiped; no token in the request means 404, any other account or confirm value
  means 403. The route deletes that player's row and bounty bonuses, resets any
  bounty they hold to GrinchBot and bumps `meta.reset_epoch` (Unix seconds,
  must fit an AngelScript int). `/state` returns `resetEpoch`; the plugin
  clears its local save once when the value changes. The admin page has a
  button that calls this route after a confirmation. Use it to clean test
  data before the event starts.
- `[Setting]` entries carry user-facing `description` (and `min`/`max` for
  numbers), following the style of `event-calendar-dev`.
- Stat-card icons are centred with a borderless `Button` + `ButtonTextAlign`;
  do not go back to manual `MeasureString()` offsets for icon glyphs.
- Progress bars thinner than ~20 px must not carry overlay text; put the label
  on its own line.
- Calendar tile height is derived from available column height (60-84 px);
  moon percentage sits on its own centred line below the status, never in the
  top-right corner where it collided with the tile icon.
- `TextMuted()` is deliberately 40% brighter than the raw palette value so
  labels, hints and footer text stay readable. Adjust there, not in `Theme.as`.
- `Transparent Glass` uses neutral backgrounds (R == G == B). Intermediate
  containers must stay `alpha = 0` (`containerBg`) or transparency stacks into
  an opaque wall. The window tint is `S_GlassOpacity` (0.15-0.80, default 0.55).
- Two themes share the **same layout**. `UiTheme` + `g_Theme` are persisted
  `[Setting]`s in `Config.as`; `Theme.as` holds `ThemePalette` and
  `RefreshPalette()`. UI code reads colours only through `Gold()`, `TextMain()`,
  `g_palette.*` wrappers - never hard-code a colour in a layout function.
  `Render()` and `RenderDashboard()` call `RefreshPalette()` before drawing.
  The default glass look keeps the original grey tiles (`S_GalaxyOn = true`);
  the grey active-tab look is unchanged. Tabs read their
  colours from `g_palette.tab*`; there are no white hardcoded tab colours.
  Calendar tiles carry **no corner checkmarks or tier dots** - the centre
  icon, the `DONE` caption and the border colour carry that state.
- Release workflow pins `ubuntu-24.04` and `actions/checkout@v6` (Node 24).
  Do not revert to `ubuntu-latest` or `checkout@v4` - GitHub warns about both.
- `main` is the default branch and the source of releases. Merge feature work
  there first, then push a `v*` tag from `main`.
- Display name is `GoalAdvent 2026` in the README and UI; folder/repo/package id is
  lowercase `goaladvent-dev`. Keep uppercase data identifiers unchanged:
  `GoalmasAdvent.json` (save file, would reset progress) and badge codes such as
  `GOALMAS-2026`.
- Pushing a `v*` tag runs `.github/workflows/release.yml`, which zips
  `info.toml`, `README.md` and `src/` into `goaladvent-dev.op` and publishes a
  GitHub release automatically. Do not upload the asset by hand. Release notes
  are a short human-readable list of commit subjects since the previous tag,
  not just the auto-generated Full Changelog.
- **Everything in English**: code, comments, identifiers, UI strings, docs.
  Chat with the user may be Polish. Source files (`src/*.as`, `backend/*`) must
  contain no non-ASCII text; `README.md` may use emojis for readability.

## 2. Layout

| Path | Responsibility |
|---|---|
| `src/Config.as` | Settings, tuning constants, global state, storage paths |
| `src/Calendar.as` | Day titles/hints/fragments, `g_offDays`, dates, scoring, save/load |
| `src/GoalHunt.as` | Identity, `#N Goal Hunt` detection, checkpoint counting, submission |
| `src/Sync.as` | Banner/feed, shared-folder + HTTP transports, `/state` parsing |
| `src/UI.as` | Single dashboard layout, tabs, tile grid, HUD, banner, settings |
| `src/Theme.as` | `ThemePalette` - colours, alpha and radii for both themes |
| `src/Debug.as` | Admin diagnostics window + `[goaladvent][DBG]` log line |
| `src/Main.as` | Entry points: `Main`, `Update`, `Render`, `RenderInterface`, `RenderMenu` |
| `backend/worker.js` | Cloudflare Worker + D1: `/state`, `/submit`, `/admin` |
| `backend/schema.sql` | D1 tables (`players`, `bounties`, `events`) |
| `backend/wrangler.toml` | Worker/D1 config (fill in `database_id`) |
| `backend/DEPLOY.md` | Free-tier deployment guide |
| `README.md` | Player-facing overview and install steps |
| `tests/qa_checks.js` | Dependency-free release QA gate, writes `tests/qa-result.json` |
| `DOCS.md` | Full technical reference (rules, architecture, troubleshooting) |
| `goaladvent-dev.op` | Built package - **not** tracked in git; rebuild after changes |

Openplanet compiles `.as` recursively from `src/`; there is no manifest listing.

## 3. Rules that must not be broken

### Event logic (single source of truth)

- `g_offDays = { 1, 8, 15, 22 }` in `Calendar.as` **must** match
  `TUESDAY_OFF_DAYS` in `backend/worker.js`. Rest-day titles and hints are indexed
  by those exact day numbers - never shift them by hand.
- `DAY_COUNT = 25`, `GOAL_CP = 10`; days 1-24 score 100, finale 300, bounty 150.
- Finale grace period is `FINALE_GRACE_DAYS = 5` (5 January). Do not hardcode
  "5 January" in UI text - read the constant.
- Local JSON (`GoalmasAdvent.json`) is authoritative; the worker is a mirror.
- Map detection uses UID mappings learned by the worker first, then the name
  parser (`#N Goal Hunt`, `Goal Hunt Day N`, `GH N`, `goalhuntarena`), then the
  UTC event day. The old "name only" rule is obsolete.
- Premiere x2, day unlock and the finale window are decided by the **server
  UTC** clock. `/state` returns `serverMonth`, `serverDate`, `serverDay` and
  `serverCatchUp`; `Config.as` keeps a `SERVER_CLOCK_TTL_SEC = 180` mirror and
  `Calendar.as` only falls back to the local clock when offline or stale.
  `/submit` re-checks the day against server UTC and answers HTTP 403
  `day-not-open` for a future day. Never let the client clock decide a day.
- Run tiers are cosmetic: `SILVER_CP` (15) and `GOLD_CP` (30) in `Config.as`
  colour the tile border/dot, the day details, tooltip and HUD. Points stay
  100 / 300 / 150. `ClampCp()` in `Calendar.as` keeps every display inside
  0..`MAX_CP` (250), the same limit the worker accepts.
- Bounty record: higher CP wins, equal CP goes to the lower `timeMs`. The D1
  `bounty_bonus(day, account_id)` primary key grants the +150 only once per
  player per day; two simultaneous submits cannot double-grant it.
- Optional anti-cheat gate: `S_EventServerKeyword` matches part of the server
  name/login; empty accepts every server (test mode).

### Sync

- Modes: `0` offline, `1` shared folder, `2` HTTP worker. If `ApiUrl()` is
  non-empty (setting or `DEFAULT_API_URL`), `Main()` switches from 0 to 2
  automatically - zero setup for players.
- `SyncNow()` must never start a second request while `g_syncing` is true.
  Refresh buttons additionally use `UI::BeginDisabled(g_syncing)`.
- HTTP requests are coroutines: `Net::HttpRequest@ req` (handle), `yield()`
  until `Finished()`. Never pass a request by value or start parallel submits.

### ImGui / AngelScript (compile-killers verified on MP4 1.29)

Ground truth for any native: `C:\Users\tomekdot\Openplanet4\OpenplanetCore.json`.
Grep it before using a new API. Absent in this build: `I2S`, `UI::TextColored`,
`UI::CalcTextSize`, `GetItemRectMin/Max`, `UI::InputInt3`, `mp.ManiaApp`,
`UI::BeginTable(id, flags)` two-arg form.

- `tostring(uint)` is ambiguous -> cast to `int` or use `Text::Format`.
- No `char()` or char literals; no `out` as an identifier (reserved keyword).
- `AddRectFilled(const vec4&in rect, ...)` takes **(x, y, width, height)**,
  not end coordinates. Passing `x2, y2` paints giant rectangles.
- `DrawList::AddText(const vec2&in pos, ...)` takes a **position**.
- `UI::MeasureString(str, null, size, 0.0f)` returns text size in `vec2`; use it
  for pill widths and right-aligned footer text.
- `UI::GetCursorPos()` exists; `UI::GetCursorPosX()` does **not** in this build.
- Every `SetCursorPos()` that moves the cursor past current content must be
  followed by an item (`UI::Dummy(vec2(0, 1))`) or `EndChild()` throws
  `UI assertion failed ... Please submit an item e.g. Dummy() afterwards`.
- Centring: `UI::StyleVar::ButtonTextAlign = vec2(0.5, 0.5)`. Do **not** call
  `SetCursorScreenPos()` inside `BeginChild` - it triggers
  `UI assertion failed ... Please submit an item e.g. Dummy() afterwards`.
- Child cards that must not scroll:
  `UI::WindowFlags::NoScrollbar | UI::WindowFlags::NoScrollWithMouse` plus
  `UI::StyleVar::ScrollbarSize = 0.0f`.
- Every `PushStyleColor` / `PushStyleVar` needs a matching pop in the same
  function. `PushDashboardStyle()` = 15 colours + 12 vars,
  `PopDashboardStyle()` pops exactly those counts.
- Json enum member is `Json::Type::Boolean` (not `Bool`). `goaladvent_check.js`
  and `goalmas_check.js` verify all `Json::Type::*` members against the
  whitelist; a wrong one fails compile with `No matching symbol`.
- The dashboard is manually resizable: `SetNextWindowSize(..., FirstUseEver)`
  seeds the layout (820x620 with day details, 650x620 without, times `UiK()`)
  and `SetNextWindowSizeConstraints()` sets a 700/560 px minimum (460/400 px
  high). No `NoResize`. The tab row drops its icons when the measured row does
  not fit, so a narrow window clips nothing.
- `ApplyState()` treats `/state` as hostile: every leaf goes through
  `JsonIntOr()` / `JsonStrOr()` / `JsonBoolOr()` with a type check and a CP
  clamp. A malformed response must never throw a script exception.
- `UI::BeginDisabled(bool)` / `UI::EndDisabled()` are available.
- `UI::BeginTabBar(id)` takes only the id. `UI::ListBox(label, int& item,
  string[] items)` exists (value array).
- UI strings stay English. Palette functions live at the top of `UI.as`.
- Keep cards text-wrapped; stat card = 64 px, icon box 36x36 centred vertically,
  label and value on separate rows with a 14 px gap after the box.
- Calendar tiles use absolute column positions derived from
  `GetContentRegionAvail()`; do not use `SameLine()` for the 5x5 grid (it leaves
  an unused strip after column five). Draw the icon and status with `AddText()`
  at the measured centre so a short glyph stays aligned with a wider label.
- Panel refresh buttons are centred (`CenteredButton`, FS_BODY); day action
  buttons size to their measured label (`FitLabel` / `FitLabel3`, which has a
  third stub fallback for narrow windows). The day bar keeps the title on the
  left and reserves up to 70% of the row for the button, with a 6 px inset at
  the right border. The button is lifted 8 px so its label lines up with the
  title text, and the grid reserve grows by 10 px to make room. Rest days show no "Pursuit night" line under the title -
  the tile says REST and the details card carries the bonus info.
  The footer alone shows connection status and totals.

### UI text and typography

- Font scale: 13 px for labels and the footer, 15 px for body text and values,
  18 px for the day title and the app name. Nothing below 13 px; do not add
  extra sizes.
- Section headers and card labels are UPPERCASE; navigation, values and
  sentences are sentence case.
- Separators are ` | ` or `:` - never ` - `. Source files stay ASCII, so no
  middle dots or other non-ASCII punctuation.
- Stat card = muted 13 px label above a 15 px value in the main text colour.
- Spell out units: `Last quarter | 56% lit`, `TOTAL 240 pts`.
- Times carry UTC next to local time: `Bonus 20:00 CET (19:00 UTC)`.
- Tone: short, factual, plain English, no exclamation marks. It should read
  like a tool, not a gadget.

### Runtime integration

- `Update(float dt)` receives **milliseconds** (timers are in seconds).
- The dashboard opens on start (`S_ShowOnStart = true`); the only menu entry
  is `Icons::Calendar + " GoalAdvent 2026"` in `RenderMenu()`. Do not add top-bar menus.
- Checkpoint count path (same as working chase-mode overlay):
  `app.CurrentPlayground.Players[i]` -> `cast<CTrackManiaPlayer>` ->
  `player.ScriptAPI.CurRace.Checkpoints.Length`.
- Login: `CurrentProfile.AccountSettings.OnlineLogin` -> `GetLocalLogin()` ->
  `S_Nickname` fallback.
- Never kill `ManiaPlanet.exe`. Edit `.as`, ask the user to reload scripts
  (`F3 -> Developer -> Reload Scripts`) or restart the game.

## 4. Verification workflow

1. Edit only what the task needs; keep changes consistent with surrounding code.
2. Run the static checker:
   ```
   node C:\Users\tomekdot\AppData\Local\Temp\opencode\goaladvent_check.js
   ```
   It verifies braces, UI API names/enums against `OpenplanetCore.json`,
   reserved keywords, duplicate function signatures, icons, worker syntax and
   stale names. Expect `ALL CHECKS OK`.
3. For layout work also run `ui_balance.js`, `ui_style_stack.js` and
   `calendar_check.js` from the same temp folder (brace balance, style-stack
   balance, rest-day alignment).
4. After the user reloads the plugin, grep `C:\Users\tomekdot\Openplanet4\Openplanet.log`:
   ```
   Get-Content ...\Openplanet.log -Tail 400 | Select-String 'goaladvent|ERR :|Script compilation failed'
   ```
   Success = `Loaded plugin 'goaladvent-dev'` + `[goaladvent] Loaded: 25 days...`
   with no `ERR :`.
5. Do not declare a task done on static checks alone if a game reload is
   possible - say what still needs visual confirmation.

## 5. Git workflow

- One clean commit per change. Conventional Commits **with scope**:
  `feat(goaladvent): ...`, `fix(goaladvent): ...`, `style(goaladvent): ...`.
- Author identity: `tomekdot <73403480+tomekdot@users.noreply.github.com>`
  (the GitHub ID + noreply address, identical to the global git config and all
  other repos). Never use the plain `tomekdot@users.noreply.github.com` form.
- Iterate with `git commit --amend` + `git push --force-with-lease` on the
  personal feature branch; do not stack fixup commits.
- Another agent may rebase/rewrite this branch concurrently. If a push is
  rejected, `git fetch` + inspect `git log --graph --all` and `.git/rebase-merge`
  **before** force-pushing. Never clobber a rebase in progress.
- After code changes, rebuild `goaladvent-dev.op` (`info.toml` + `README.md` at
  root, code in `src/`) and refresh the latest `v*` release only when asked.
