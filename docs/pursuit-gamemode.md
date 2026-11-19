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
loaded titlepack's scripts are mounted there.

**Live extraction test (verified):** the Fids AngelScript API *is* accessible -
`CSystemFidsFolder` / `CSystemFidFile` are defined in `Openplanet4.json` (not
`OpenplanetCore.json`) and callable, with `CSystemFids.Trees` (subfolders) /
`.Leaves` (files) enumeration, `Fids::GetGameFolder/GetUserFolder`,
`Fids::GetFullPath`, `Fids::Extract(fid)` and `CSystemFidFile.CopyToFileRelative`.
A probe walking the Game and User drives found **no loose `.Script.txt` files**
(the scripts live inside the compressed pack containers, not as extractable
loose fids), and `Fids::Extract` on a pack path returned **BLOCKED/FAIL**. So
scripted extraction of a third-party titlepack does not work in practice: the
engine restricts extraction to own/official packs and the code is not exposed as
loose files. (Note: AngelScript 1.29 rejects `&inout` on primitives - use a
global counter, not an `int&` recursion parameter.)

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

## 6. Catching and assist mechanic

How police catch the thief, and how a plugin detects it.

**Mechanic (engine model; exact thresholds unverified - confirm in-game):**
Pursuit is proximity-based. The gamemode's `PlayLoop` (10 ms tick) measures the
distance between each hunter and the hunted; when a hunter comes within the
catch radius, the thief is caught (tagged), the round ends or roles reset, and
the caught player typically respawns / changes `RaceState`. An **assist** is
credited to hunters close enough to the catch at that moment (assist radius >=
catch radius). The literal catch/assist radii and rules live in the closed
gamemode script - observe them in a live round, do not assume values.

**Openplanet detection (verified API):**
- Positions: `CTrackManiaPlayer.Position` (vec3).
- Distance: `Math::Distance(const vec3&in a, const vec3&in b)` -> float (vec3
  overload verified in `OpenplanetCore.json`; `Distance2` = squared, cheaper for
  radius comparisons).
- Distance to hunted: `Math::Distance(hunter.Position, hunted.Position)` once
  the hunted is identified via role detection (section 5).
- Catch signal: distance to hunted drops below the catch radius; corroborate
  with `RaceState` / `IsSpawned` / `NbRespawns` changes on the hunted.
- Time gap: from checkpoint race times (`ScriptAPI.CurCheckpointRaceTime`,
  `CurCheckpointLapTime`), NOT `CSmPlayer` (absent). The archived
  `pursuit-suite` `CalculateTimeGap` used `CSmPlayer` and was a stub.
- Assist: at the catch instant, hunters within the assist radius of the hunted
  get assist credit; snapshot all hunter distances when the catch fires.

**Probe support:** `DumpPursuitRoles()` logs `near=<dist>m` per player - the
distance to the nearest other spawned player. In a live Pursuit round, watch
`near` collapse toward zero at a catch to read the catch radius; combine with
the role split (team/clan) to attribute the catch and assists.

**Detection plugin sketch:**
1. Each tick (or throttled), read all players' roles + positions.
2. Identify the hunted; compute every hunter's distance to it.
3. Detect a catch when min distance < catch radius AND the hunted's state
   changes (respawn / race state). Log the catch + nearby hunters (assists).
4. Surface in GoalAdvent: catch feed event, assist badges, hunter proximity HUD.

## 7. Pitfalls / what matters

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

## 8. Next steps

1. Validate `TeamNum` / `CurrentClan` in a live Pursuit round (probe + log).
2. Implement real `DetermineRole()` in GoalAdvent from the confirmed signal.
3. Add a role indicator (per-player icon/badge, hunter count, hunted highlight).
4. Optionally sync roles to the Cloudflare worker for the live feed.
5. The literal gamemode source IS obtainable: ManiaPlanet's in-game script
   editor (Ctrl+G) opens the running gamemode script. Fids extraction of a
   third-party pack is blocked, but the editor route works. See section 9.

## 9. Verified mechanics (from Pursuit.Script.txt, domino54, 2018-06-22)

Source obtained via the in-game script editor (Ctrl+G), not Fids extraction.
Extends `Modes/TrackMania/ModePursuit.Script.txt`; compatible map types:
`PursuitArena`, `GoalHuntArena`, `HuntersArena`, `PursuitProArena`. This section
supersedes the TeamNum hypothesis in sections 4-6: the role signal is the CLAN.

### 9.1 Roles = clans (not teams)

- `UseClans = True`, `PUR_CurEscapingClan = 2`. Thieves = the escaping clan
  (default **2**), Police = `3 - PUR_CurEscapingClan` (default **1**). Clan 0 =
  spectator / unassigned.
- The role field is `Player.CurrentClan`, exposed to Openplanet as
  `CTrackManiaPlayer.ScriptAPI.CurrentClan` (int). **This is the role signal,
  not `Score.TeamNum`.**
- Swap mode flips the escaping clan (1 <-> 2); detect it dynamically (the
  minority clan at round start is police, or read the clan labels). Default
  mapping: CurrentClan 2 = thief (Hunted), 1 = police (Hunter), 0 = spectator.
- Round start: everyone is a thief, one random policeman is tossed. A caught
  thief becomes police (Survival mode). Round ends when all thieves are caught
  or the time limit is reached.

### 9.2 Catching

- Primary: `PUR_AreTouching(Thief, Policeman)` -> `CatchThief(Thief, Policeman)`
  (reason `C_CaptureReason_Policeman = 0`). A TOUCH / collision test, not a fixed
  radius - approximate client-side with a small distance threshold.
- Environmental catches (thief, after the safe phase): OffZone(1), Boundary(2),
  Void(3), Command(4), Water(5), Ceiling(6), DangerZone(7), PoliceZone(8),
  ThiefZone(9), Speedbomb(10), GoalTimeout(11), Spectator(12).
- On catch: thief respawns (`TM::WaitRace`), `Captured.wav` plays, killfeed
  `Killfeed::SendNotice(thiefName, policemanName, icon, assistantLogin)`.
- Safe phase: `S_SafePhaseDuration` (default 15 s, max 60) before police pursue.
- Respawn: thieves respawn after capture (5000 ms min -> 15000 ms max as thieves
  dwindle; GoalHunt 5000 ms); cancel by driving > 8 m at > 10 speed.

### 9.3 Assists ("asysta")

`C_PointsForAssist = 1` (+1 Lagoon-car bonus). Two mechanisms build
`PotentialCaptureAssistants` on catch:

1. **Scare-off** (highest priority), `ThiefScaredOffByPolicemanId`:
   - Camping: thief speed <= 15 (`C_ScareDetectionRunningSpeed`) for >= 3000 ms
     (`C_ScareDetectionCampingDuration`) while a police is within 48 m horizontal
     (`C_ScareDetectionCampingDistMax`) and 7 m vertical
     (`C_ScareDetectionCampingHeightMax`); when the thief runs again, the nearest
     such police is credited with scaring them.
   - Fall: thief drops >= 2 m from an altitude peak with a police above within
     48 m horizontal -> nearest police credited.
   - Credit expires after 15000 ms (`C_ScareDetectionFallTimeout`).
2. **Chase**, `ThiefChasedByPolicemen*`: a police is chasing when
   - both speeds >= 25 km/h (`C_ChaseDetectionSpeedMin` / 3.6),
   - slower speed >= 0.5 x faster (`C_ChaseDetectionSpeedDiffPercMax`),
   - aim yaw difference <= 60 deg (`C_ChaseDetectionAimAngleDiffMax`),
   - distance <= 96 m (`C_ChaseDetectionDistanceMax`),
   - sustained >= 1000 ms (`C_ChaseDetectionStartingDelay`); status kept 15000 ms
     (`C_ChaseDetectionStatusKeepTime`).
   - Chasing assistants are sorted by nearest distance to the thief.

On catch: assistants = [scare-off police] + [chasing police by distance]; the
catching police is removed; the first assistant shows in the killfeed; each
assistant gets 1 point. If no police caught (environmental) but an assist exists,
the first assistant gets the capture credit.

### 9.4 Points

- Thief survival: +1 per other thief caught (streak max 3, `C_MaxSurvivalStreak`).
- Police capture: base = remaining-thief survival points; last thief up to 5
  (`C_PointsForLastCapMax`); capture streak up to 5 (`C_MaxCaptureStreak`);
  Lagoon-car bonus +1 (`C_PointsForLagoonCar`).
- Assist: 1 (+1 Lagoon). First police: 5 (`C_PointsForFirstPolice`). Last thief:
  5 (`C_PointsForLastThief`). Thief surviving to end: up to 5
  (`C_PointsForThiefEndMax`).
- TopScores categories: `Pursuit_Survival` (best survivor), `Pursuit_Capture`
  (most captures), `Pursuit_Stunts` (most stunts).

### 9.5 Client-side detection (Openplanet)

- Role: `ScriptAPI.CurrentClan` (2 thief / 1 police / 0 spec, default escaping=2).
- Position / speed / aim: `ScriptAPI.Position`, `.Speed`, aim yaw for chase math.
- Catch: watch a thief's clan flip to police (Survival) or respawn with a police
  within touching distance; environmental catches via respawn + zone state.
- Assist: replicate the scare / chase thresholds above from live positions/speeds.
- Killfeed / points notices are ManiaScript UI events in the client app
  (`PursuitClientApp.Script.txt`); reading them needs the UI layer / custom events.

## 10. ManiaLink client UI architecture (pause menu / map info script)

The titlepack UI is ManiaLink (`CMlScript`), separate from the gamemode
(`CSmMode`). The in-game menu script shows the standard structure.

### 10.1 Layers

- **LibManialink** - animation library. Per-control anim queues (`declare ... for
  Control`), `LibManialink_SetTarget{Position,Size,Scale,Rotation,Opacity,Colorize,
  BgColor,TextColor,Ratio,GaugeColor}`, `PresetAnim`/`AnimChain`/`AnimInsert`, and
  `LibManialink_AnimLoop()` easing via `AL::Ease(easing, t, start, diff, duration)`.
  Styles: -1 = new anim, 0 = chain, 1 = insert. Active flags per property (0..9).
- **DesignManialinks** - button/design system. Control classes `MainButton`,
  `SecondaryButton`, `ScrollFrame`, `FloatingButtonFrame`, `EntryEntry`,
  `ExpandingButton`; MouseOver/MouseOut/MouseClick handlers; platform-aware pad
  glyphs (PC/PS4/XB1) chosen from `Input.PendingEvents` pad type.
- **SoloMapInfosBase** - medal + best-time + mode/map-info panel.

### 10.2 Event loop

```
main() {
  Init();
  while (True) {
    yield;
    if (PageIsVisible) { ShowPage(); } else { HidePage(); continue; }
    DesignManialinks_Loop();
    LibManialink_AnimLoop();
    foreach (Event in PendingEvents) { MouseClick / MouseOver / MenuNavigation / KeyPress }
    foreach (Event in Input.PendingEvents) { pad buttons }
  }
}
```

- `PageIsVisible` drives ShowPage/HidePage; `SetUIHidden` toggles `ClientUI`
  score table / chat / alt menu.
- In-game menu buttons: Resume / Help / Spectator / Advanced options / Manage
  server / Quit via `CloseInGameMenu(CMlScriptIngame::EInGameMenuResult::*)`;
  `G_ButtonFocus` navigation (Up/Down/Select), mouse click selects a button.

### 10.3 Server -> client state: netread / netwrite (KEY for detection)

- The gamemode publishes state with `declare netwrite T X for Teams[0]` / `for UI`
  (e.g. `Net_Pursuit_OvertimeIsTicking`, `Net_Pursuit_GameOvertimeStart`,
  `Net_Pursuit_GameOvertimeDuration`).
- The UI reads it with `declare netread T X for UI` (e.g. `BestTimePlayer`,
  `Net_BestMedal`, `Net_ModeName`).
- This is the authoritative server -> client channel. The Pursuit client app
  (`PursuitClientApp.Script.txt`) reads Pursuit-specific net vars (thief/police
  counts, overtime, start time). Openplanet reads the exposed player fields
  (`CurrentClan`, `Position`, `Score`) directly; reading ManiaScript net vars
  themselves needs the UI layer / custom events, not the player API.

### 10.4 Medals / times

- `GetMedalForTime`: 0 Author (`<= Map.TMObjective_AuthorTime`), 1 Gold, 2 Silver,
  3 Bronze, 4 none; colors `C_QuadMedalImgColor`.
- `InputPlayer.Score.PrevRace.Time` / `BestRace.Time` for last/best time.
- `GetModeName() = Playground.ServerInfo.ModeName`; `ServerInfo.ServerName` for the
  header; `Map.MapInfo.MapUid` detects map changes.

## 11. Map selection / voting UI (LibMapSelection2)

The map-vote screen module. Confirms the bidirectional net channel and persistent
per-user storage.

### 11.1 Data

- `SMapCard` struct: `UID`, `Name`, `AuthorName`, `ThumbnailURL`.
- Map collection `Net_LibMapSelection2_MapsCollectionName`; voteable maps list +
  `SMapCard[Text]` data dictionary.

### 11.2 Net channel (bidirectional)

- **Server -> client** (`netread for Teams[0]`): `VotingScreenCurState` (0 hidden /
  1 voting / 2 results), `VotingEndTime`, `ResultsEndTime`, `VoteableMapsList`,
  `VoteableMapsData`, `CurMapsNbVotes` (`Integer[Text]`), `CurWinningMapUID`,
  `TotalNbPlayers`, `TotalNbVotes`, `LastUIUpdate`, `VotingUniqueID`.
- **Client -> server** (`netwrite for UI`): `CurSelectedMapUID` (the vote),
  `LastVotingUniqueID`, `RecentlyPlayedMaps`.
- **Per-player** (`netread for InputPlayer`): `IsSpectatorServer`,
  `LastRegisterMapRequest`, `NewMapUIDToRegister`.
- So `netwrite` is bidirectional: the server publishes state `for Teams[0]`, the
  client publishes actions `for UI`. A vote is just the client setting
  `Net_LibMapSelection2_CurSelectedMapUID`.

### 11.3 Persistent storage

- `declare persistent Integer / Text[][Text] ... for LocalUser`: recently-played
  maps per collection, capped at 15 (oldest removed), survives sessions and is
  sent back via `Net_LibMapSelection2_RecentlyPlayedMaps`.

### 11.4 Voting logic / UI

- Shown when `!IsInGameMenuDisplayed && state > 0 && GameTime <= voting/results
  end`; `SendCustomEvent("VisibilityChange", Text[])` notifies other layers.
- Map cards in a 2-row grid (80 + 2 px spacing); the current map is shifted to the
  front and rendered as a "Replay current map" card.
- Vote: MouseClick / MenuNavigation Select on `Quad_MapCardButton` sets
  `CurSelectedMapUID` (blocked for spectators or after `VotingEndTime`); arrow
  navigation walks a 2-row `DisplayedMapsNavigationGrid`.
- Results (state 2): per-map vote counts, winning map green; win reason
  "Selected at random" (0 votes) / "Selected by everyone" (all votes) /
  "Selected first" (draw) / "Selected by majority".
- Native `AnimMgr.Add(control, "<manialink xml>", duration, Easing)` animations
  (e.g. `SineOut`) alongside LibManialink; `Brightness(Vec3, Real)` color helper;
  `ComputeWidth(label)` for layout.

## 12. Porting ML:: / TL:: to Openplanet (verified mapping)

The gamemode uses ManiaScript `MathLib` (`ML::`) and `TextLib` (`TL::`). To port
the catch / assist logic to Openplanet AngelScript, map them to `Math::` / `Text::`
(verified against `OpenplanetCore.json`):

| ManiaScript | Openplanet | Notes |
|---|---|---|
| `ML::Distance(a, b)` | `Math::Distance(a, b)` | vec3 overload exists |
| `ML::Min(a, b)` / `ML::Max` | `Math::Min` / `Math::Max` | int + float overloads |
| `ML::Abs(x)` | `Math::Abs(x)` | int + float |
| `ML::Clamp(x, min, max)` | `Math::Clamp(x, min, max)` | int + float |
| `ML::PI()` | `Math::PI` | **property (float), no parentheses** |
| `ML::NearestInteger(x)` | `Math::Round(x)` | returns float -> cast `int` |
| `ML::FloorInteger(x)` | `int(Math::Floor(x))` | Floor returns float |
| `ML::ToReal(x)` | `float(x)` | cast |
| `TL::ToText(x)` | `tostring(x)` | `tostring(uint)` ambiguous -> cast int |
| `TL::ToInteger(s)` | `Text::ParseInt(s)` | verified |
| `TL::Compose("%1", x)` | `Text::Format("%s", x)` | **printf-style %s/%d, NOT positional %1/%2** |
| `TL::FormatInteger(x, n)` | `Text::Format("%0Nd", x)` | zero-pad width N |
| `TL::FormatReal(x, ...)` | `Text::Format("%.Nf", x)` | decimals N |
| `TL::Split(s, sep)` | **no `Text::Split`** | manual split (find/substr loop) |
| `TL::TimeToText(ms)` | custom | format ms -> m:ss.cc |

Pitfalls carried over: `&inout` on primitives is rejected (use a global or `&in`/
`&out`); `tostring(uint)` needs an int cast; `Math::Round`/`Floor` return float.
With this mapping the section 9 thresholds (scare 48 m / 7 m / 3 s / speed 15,
chase 96 m / 25 km/h / 60 deg / 1 s) port directly to `Math::Distance`,
`Math::Clamp`, `Math::Abs` and angle math via `Math::PI`.