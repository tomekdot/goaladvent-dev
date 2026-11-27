# GoalAdvent 2026 - Discord campaign plan

All player-facing text is in English, matching the plugin UI and the event.
Important: **1 December 2026 is a Tuesday**, which is a Pursuit bonus night
with no Goal Hunt. The first playable map is `#2 Goal Hunt` on 2 December.
The 1 December post is therefore installation and hype only.

---

## Before 1 December

| Task | Status / note |
|---|---|
| Deploy the Cloudflare worker | Done - `https://goalmas.tomekdot-goalmas.workers.dev` |
| Bake the URL into `DEFAULT_API_URL` | Done in `src/Config.as`; all players get online sync with no setup |
| Set `S_EventServerKeyword` to the event server | Set to `pursuit` - change in Openplanet settings if the server uses a different name |
| Push a `v*` tag so Actions builds the package | Done - releases publish `goaladvent-dev.op` |
| Find 3-5 testers and refine the FAQ | Not done - user action |
| Record a 10-15 s GIF (tiles, moon %, bounty) | Not done - use the in-game UI |

Installation instructions for testers:

1. Download `goaladvent-dev.op` from
   https://github.com/tomekdot/goaladvent-dev/releases
2. Copy the folder into `C:\Users\tomekdot\Openplanet4\Plugins\goaladvent-dev`
   (or install the `.op` through Openplanet).
3. `F3 -> Developer -> Reload Scripts` (or restart the game).
4. Open **GoalAdvent 2026** from the Openplanet menu. Requires Openplanet 1.29.14.

---

## Channels and roles

| Channel | Purpose |
|---|---|
| `#goalmas-news` | Admin-only announcements and the daily post |
| `#goalmas-help` | Installation help and bug reports |
| `#goalmas-leaderboard` | Scores and bounty takeovers |
| `#goalmas-chat` | General conversation |

| Role | How it is granted |
|---|---|
| `goalmas player` | Reaction to the pinned installation post |
| `bounty hunter` | Current daily record holder; changes every day |

`GrinchBot` is the mascot and the starting bounty holder (15 CP).

---

## Schedule

| Date | Post |
|---|---|
| 21 Nov | Teaser (slogan + GIF) |
| 24 Nov | Full announcement + pinned installation guide |
| 28 Nov | "Check your install" day + FAQ |
| 30 Nov | Reminder: start tomorrow |
| 1 Dec | Start - Pursuit night, last chance to install |
| 2-24 Dec | Daily map post |
| 25 Dec | Finale, event closes at 02:00 UTC on 26 Dec |
| After 25 Dec | Results and raffle draw |

---

## Post templates

### Teaser - 21 Nov

> ❄️ 25 maps. 25 days. One bounty nobody has beaten yet.
> GoalAdvent 2026 lands December 1. Start warming up.

### Announcement - 24 Nov (pin this)

> **GoalAdvent 2026 - a 25-day Goal Hunt advent for ManiaPlanet 4**
> Collect checkpoints on the daily `#N Goal Hunt` map. 10 CP in one run completes a day.
> • Beat GrinchBot's 15 CP record and steal the bounty (+150 pts)
> • Premiere day pays x2 (server UTC decides)
> • Best 15 of 24 days count - miss a day, keep the run
> • Pursuit Tuesdays (1, 8, 15, 22): no Goal Hunt, your streak is safe
> • 25/25 gifts = raffle ticket. The event closes 26 December, 02:00 UTC.
> Install: [release link] → `Reload Scripts` → open **GoalAdvent 2026** from the Openplanet menu. Needs Openplanet 1.29.14.
> React with 🎁 to get the player role.

### Daily post - 2-24 Dec

> 🎁 **Day {N} - {title}** - map `#{N} Goal Hunt` is live on {server}.
> Goal: 10 CP. Bounty: {X} CP by {holder}.
> Catch-up stays open - nobody loses a day.

Titles and hints are in `src/Calendar.as` (`g_titles`, `g_hints`).

### Bounty takeover - optional extra post

> 🎯 {player} just stole the day {N} bounty with {X} CP. GrinchBot is not amused.

### Install-check day - 28 Nov

> 🔧 GoalAdvent 2026 install check: open the dashboard, confirm `SERVER ONLINE` in the debug panel, and make sure the map `#2 Goal Hunt` is detected on 2 December. Questions in #goalmas-help.

### Reminder - 30 Nov

> ⏰ Tomorrow GoalAdvent 2026 starts. December 1 is a Pursuit night - no race, just install and get ready. First map: `#2 Goal Hunt` on 2 December.

### Start - 1 Dec

> ❄️ GoalAdvent 2026 is live. Tonight is Pursuit (day 1), so your streak is safe. Install, get the player role, and we race from day 2 tomorrow.

### Finale - 25 Dec

> 🏆 Day 25 finale is live. All 24 fragments, all bounties, one raffle ticket. The event closes at 02:00 UTC on 26 December.

### Results - after 25 Dec

> 🎉 GoalAdvent 2026 results are in. Top 3, bounty leaders and the raffle winner will be posted in #goalmas-leaderboard.

---

## Rhythm and engagement

- Weekly recap every Sunday: top 3 of the leaderboard, most bounties.
- One small weekly contest (for example best screenshot of the day). Only
  announce a prize if one actually exists - put it in `[prize]`.
- The worker already mirrors bounty takeovers and first day clears to a
  Discord webhook (`DISCORD_WEBHOOK_URL` secret). Set it once and
  `#goalmas-leaderboard` fills itself; the `/admin` page confirms
  `Discord webhook: configured`.
- Every completed day plays a short gift-opening animation in game, so the
  daily post can simply say "open today's gift".

---

## Helpful links

- Releases: https://github.com/tomekdot/goaladvent-dev/releases
- Full technical docs: `DOCS.md` in this repository
- Worker health: https://goalmas.tomekdot-goalmas.workers.dev/
