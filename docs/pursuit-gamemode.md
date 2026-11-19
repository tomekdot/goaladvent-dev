# Pursuit gamemode - architecture, code mechanics and role detection

Reference for how the TrackMania **Pursuit** mode (cops and robbers) is built,
how its code runs in ManiaScript, and how an Openplanet plugin reads the live
game state to detect **who is a hunter (police) and who is the hunted (thief)**.
Written for the GoalAdvent role-detection feature; reuse for any Pursuit tooling.

Everything here is grounded in verified sources: the ManiaScript engine model
(`trackmania-maniascript-expert` skill), the live API definition
(`C:\Users\tomekdot\Openplanet4\Openplanet4.json`), the Node Explorer object tree,
and the GoalAdvent role probe. Pursuit-specific script internals that cannot be
read from the closed titlepack are marked **unverified - confirm in-game**.

---

## 1. What Pursuit is

- A community **cops-and-robbers** TrackMania gamemode shipped in the titlepack
  `PursuitStadium@domino54` (author domino54). Confirmed loaded via Node Explorer:
  `CTrackMania.LoadedManiaTitle = "PursuitStadium@domino54"`.
- Two roles: **Hunter** (police, chases) and **Hunted** (thief, flees). One or a
  few players are hunted; the rest hunt. Rounds reset roles.
- Related variants in the same ecosystem: **GoalHunt** (checkpoint hunting, the
  GoalAdvent event mode) and **Pursuit rest nights** (the cop-robbers mode).
  Map types seen in the wild: `PursuitArena`, `GoalHuntArena`.

## 2. Where the code lives - and what you can read

| Artifact | Location | Readable? |
|---|---|---|
| Titlepack container | `Documents\ManiaPlanet\Packs\PursuitStadium@domino54.Title.Pack.gbx` | Header only |
| Gamemode + UI scripts | Inside the pack: ManiaScript `.Script.txt` + ManiaLink `.ML.txt` | **No** (closed pack) |
| Game config | `Documents\ManiaPlanet\Config\` (`User.FidCache.Gbx`, `<login>.ScriptCache.Gbx`) | Partial (hashed fids) |
| Openplanet settings | `Openplanet4\Settings.ini`, `PluginStorage\<plugin>\` | Yes |
| Live object tree | Openplanet **Node Explorer** | Yes (live values) |

**Container format.** `.Title.Pack.gbx` is a **NadeoPak**: magic `NadeoPak`, a
readable XML ident header (`uid`, `author`, `creationdate`, `GameVersion`), then
a compressed/encrypted body (LZO/Blowfish). The file table itself is compressed,
so scripts are **not** recoverable with a text editor or an ASCII strings scan.
Do not burn cycles grepping the raw pack for `.Script.txt` paths.

**Extraction restriction.** Openplanet menu -> System -> **Packs** (Pack Explorer,
developer mode) browses a pack's tree and extracts files, but extraction is
**intentionally limited to Nadeo official packs and your own titlepacks**. A
third-party pack (domino54) can be browsed, not extracted. Filenames inside packs
are often hashed and resolve only after the game loads them (`FileHashes.txt`).
System -> **Drives/Folders** (Fid Explorer) shows currently mounted files; a
loaded titlepack's scripts are mounted there. The `Fids::Extract` AngelScript
handle classes (`CSystemFidFile`, `CSystemFidsFolder`) are **not** exposed in
`OpenplanetCore.json`, so scripted extraction is not possible either.

**Consequence:** the literal Pursuit ManiaScript source is unavailable without
the author. This document describes the **engine architecture Pursuit builds on**
plus the **verified live API surface**, not fabricated script contents. For the
actual source: ask domino54, or use the in-game titlepack editor with authoring
access.

## 3. ManiaScript gamemode architecture (the engine Pursuit runs on)

Custom TrackMania gamemodes are ManiaScript scripts with `#RequireContext CSmMode`
(ShootMania-style mode, which Pursuit's cop-robbers logic uses), typically
`#Extends "Modes/Nadeo/Trackmania/Base/TrackmaniaBase.Script.txt"`.

**Lifecycle (server tick = 10 ms / 100 Hz):**

```
InitServer -> StartServer
  -> InitMatch -> StartMatch
    -> InitMap -> StartMap
      -> InitRound -> StartRound
        -> InitTurn -> StartTurn
          -> PlayLoop        (every 10 ms; role logic, events, scoring)
        -> EndTurn
      -> EndRound
    -> EndMap
  -> EndMatch
-> EndServer
```

Roles are assigned in mode logic (often `Match_InitRound` / `StartRound` or on
`OnPlayerAdded`), then enforced each `PlayLoop` tick. **Unverified - confirm
in-game:** whether Pursuit encodes the role as a team number, a custom player
property, or a ManiaScript `UserStore`/metadata flag.

**Manager scope (important):**

| Manager | Gamemode (`CSmMode`) | Manialink UI (`CMlScript`) |
|---|---|---|
| `GhostMgr` | available | null |
| `ScoreMgr` | available | often null |
| Chat read | no | server plugin (XML-RPC) yes |

UI cannot drive engine instances directly; it sends `SendCustomEvent(Type, Data)`
to the mode, which handles it in `PendingEvents`. UI is rendered as `CUILayer`
(`UIManager.UILayerCreate()`); MediaTracker FX (not Manialink layers) survive the
hide-UI key.

**Parser pitfall:** with global declarations at the top, the file must end with a
function (`Void DoNothing() {}`) or the compiler reports `Unexpected EOF`.

## 4. How Openplanet reads the live game state (VERIFIED API)

Game classes are defined in **`Openplanet4.json`**, NOT `OpenplanetCore.json`
(the latter is UI/core only). Verified member surface:

```
GetApp()
  -> cast<CGameManiaPlanet>          // parent CGameCtnApp
     .CurrentPlayground              // CGamePlayground@ (null in the lobby!)
        .Players                     // MwFastBuffer<CGamePlayer@>
           [i] -> cast<CTrackManiaPlayer>   // parent CGamePlayer
```

`CTrackManiaPlayer` fields relevant to roles (verified in `Openplanet4.json`):

| Field | Type | Use |
|---|---|---|
| `Score` | `CTrackManiaScore@` | scoring + team |
| `Score.TeamNum` | `uint` (inherited from `CTmRaceRulesScore`) | **primary role hypothesis** |
| `Score.Points` | `int` | score |
| `Score.LapsNbCheckpoint` | `uint` | checkpoint count (GoalHunt) |
| `ScriptAPI` | `CTrackManiaScriptPlayer@` | ManiaScript player bridge |
| `ScriptAPI.CurrentClan` | `int` | backup role signal |
| `ScriptAPI.CurRace.Checkpoints` | array | checkpoint path (GoalHunt) |
| `RaceState` | `CTrackManiaPlayer::ERaceState` | racing / spectating |
| `IsSpawned` | `bool` | in play vs waiting |
| `Position` / `Speed` / `Distance` | `vec3` / `float` | tactical tracking |
| `User` | `CGamePlayerInfo@` | `User.Login` = player login |

**Critical:** `CSmPlayer` is **ABSENT** in this API build. Any
`cast<CSmPlayer@>(...)` returns null. The archived `pursuit-suite-dev` plugin
built its `DeterminePlayerRole()` on `CSmPlayer`, so it was a **dead stub**
(always returned `Spectator`). Use `CTrackManiaPlayer` + `Score.TeamNum` instead.

`CurrentPlayground` is **null in the Online Play lobby** - there are no player
objects until you join a server round. The probe correctly logs
`ROLE no playground` there.

## 5. Role detection - mechanism and validation

**Hypothesis:** `Score.TeamNum` separates hunters (police) from the hunted
(thief) - Pursuit likely places them on different teams. Backups:
`ScriptAPI.CurrentClan`, `RaceState`. **The mapping is unverified; confirm it in
a live Pursuit round before relying on it.** Do not fabricate which team value
means police vs thief.

**Probe (implemented in GoalAdvent `src/Debug.as`):**

- `PURSUIT ROLE PROBE` section in the debug window: per player
  `login | team N | clan N | race N | spawned Y/N`.
- `DumpPursuitRoles()` prints the same to `Openplanet.log` as
  `[goaladvent][DBG] ROLE <login> team=<n> clan=<n> race=<n> spawned=<Y/N>`,
  called from `LogDebugState()` (on load when `S_Debug`, and via the
  "Log state to Openplanet.log" button). File-based reading needs no UI clicks.

**Validation procedure:**

1. Join a **Pursuit** server and wait for a cop-robbers round with a role split.
2. Open the GoalAdvent debug window (Settings -> Advanced -> Debug overlay) or
   click "Log state to Openplanet.log".
3. Read the `ROLE` lines: identify which field (`team` or `clan`) takes distinct
   values for the police vs the thief. Cross-check against the in-game role UI
   and the Node Explorer (`...Players[i].Score.TeamNum`, R/W flags show live
   values).
4. Implement `DetermineRole(CTrackManiaPlayer@)` from the confirmed signal, then
   a role indicator in GoalAdvent (icon/badge per player, hunter count, who is
   hunted). Optionally mirror the role to the worker for the event feed.

## 6. Pitfalls / what matters

- **`CSmPlayer` missing** -> use `CTrackManiaPlayer` + `Score.TeamNum`.
- **`pursuit-suite-dev` archived** to `Openplanet4\_quarantine\pursuit-suite-dev`
  (all stubs: `DeterminePlayerRole`, `IsInPursuitMode`, `CalculateTimeGap`). Do
  not reuse its logic; it never worked.
- **Lobby = no playground**; an active round is required for any player data.
- `tostring(uint)` is ambiguous in AngelScript 1.29 -> cast to `int`.
- Third-party pack extraction is blocked; browse only (Pack/Fid/Node Explorer).
- Game API lives in `Openplanet4.json`; UI API in `OpenplanetCore.json`. Grep the
  right file before using a native.
- The Node Explorer is the fastest way to inspect a live field value
  (`CTrackMania -> CurrentPlayground -> Players -> [i] -> Score -> TeamNum`).

## 7. Next steps

1. Validate `TeamNum` / `CurrentClan` in a live Pursuit round (probe + log).
2. Implement real `DetermineRole()` in GoalAdvent from the confirmed signal.
3. Add a role indicator (per-player icon/badge, hunter count, hunted highlight).
4. Optionally sync roles to the Cloudflare worker for the live feed.
5. If the literal gamemode source is ever needed, request it from domino54 -
   it cannot be extracted from the closed titlepack.