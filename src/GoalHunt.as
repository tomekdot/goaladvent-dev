// Goal Hunt detection and checkpoint tracking for ManiaPlanet 4.

// ---------------------------------------------------------------------------
// Local player identity
// ---------------------------------------------------------------------------
string LocalLogin() {
    auto app = cast<CGameManiaPlanet>(GetApp());
    if (app !is null && app.CurrentProfile !is null && app.CurrentProfile.AccountSettings !is null) {
        string login = app.CurrentProfile.AccountSettings.OnlineLogin;
        if (login.Length > 0) return login;
    }

    string fallback = GetLocalLogin();
    if (fallback.Length > 0) return fallback;

    if (app !is null) {
        auto net = cast<CTrackManiaNetwork>(app.Network);
        if (net !is null && net.PlayerInfo !is null) return net.PlayerInfo.Login;
    }
    return "";
}

string LocalName() {
    auto app = cast<CGameManiaPlanet>(GetApp());
    if (app !is null) {
        if (app.CurrentProfile !is null && app.CurrentProfile.AccountSettings !is null) {
            string nick = string(app.CurrentProfile.AccountSettings.NickName);
            if (nick.Length > 0) return nick;
        }
        string login = LocalLogin();
        auto playground = app.CurrentPlayground;
        if (login.Length > 0 && playground !is null) {
            for (uint i = 0; i < playground.Players.Length; i++) {
                auto player = cast<CTrackManiaPlayer>(playground.Players[i]);
                if (player is null || player.User is null) continue;
                if (player.User.Login == login) return string(player.User.Name);
            }
        }
    }
    if (S_Nickname.Trim().Length > 0) return S_Nickname.Trim();
    return "Player";
}

// Stable key for scoreboards shared between players. The live login wins when
// available; while the profile is still loading we reuse the last saved id so
// the same player never gets a second, nickname-based leaderboard row.
string AccountId() {
    string login = LocalLogin();
    if (login.Length > 0) {
        g_cachedAccountId = login;
        return login;
    }
    if (g_cachedAccountId.Length > 0) return g_cachedAccountId;
    g_cachedAccountId = "local-" + LocalName().ToLower().Replace(" ", "-");
    return g_cachedAccountId;
}

// ---------------------------------------------------------------------------
// Server helpers
// ---------------------------------------------------------------------------
string CurrentServerName() {
    auto app = cast<CGameManiaPlanet>(GetApp());
    if (app is null || app.CurrentPlayground is null) return "";
    auto pgInterface = app.CurrentPlayground.Interface;
    if (pgInterface is null || pgInterface.ServerInfo is null) return "";
    return string(pgInterface.ServerInfo.ServerName);
}

string CurrentServerLogin() {
    auto app = cast<CGameManiaPlanet>(GetApp());
    if (app is null || app.CurrentPlayground is null) return "";
    auto pgInterface = app.CurrentPlayground.Interface;
    if (pgInterface is null || pgInterface.ServerInfo is null) return "";
    return pgInterface.ServerInfo.ServerLogin;
}

// Keywords used for the community badges (Pursuit / MP-Galaxy servers).
void CheckCommunityBadges() {
    string srv = (CurrentServerName() + " " + CurrentServerLogin()).ToLower();
    if (srv.Contains("pursuit")) AddBadge("PURSUIT");
    if (srv.Contains("galaxy")) AddBadge("MP-GALAXY");
}

// ---------------------------------------------------------------------------
// Map detection
// ---------------------------------------------------------------------------
string GetCurrentMapUid() {
    auto app = cast<CGameManiaPlanet>(GetApp());
    if (app is null || app.RootMap is null || app.RootMap.MapInfo is null) return "";
    return app.RootMap.MapInfo.MapUid;
}

string CurrentMapName() {
    auto app = cast<CGameManiaPlanet>(GetApp());
    if (app is null || app.RootMap is null || app.RootMap.MapInfo is null) return "";
    return string(app.RootMap.MapInfo.Name);
}

string CurrentMapType() {
    auto app = cast<CGameManiaPlanet>(GetApp());
    if (app is null || app.RootMap is null) return "";
    return string(app.RootMap.MapType);
}

bool OnEventServer() {
    string keyword = S_EventServerKeyword.Trim().ToLower();
    if (keyword.Length == 0) return true;
    if (CurrentServerName().ToLower().Contains(keyword)) return true;
    if (CurrentServerLogin().ToLower().Contains(keyword)) return true;
    return false;
}

bool IsGoalHuntMapName(const string &in rawName) {
    string name = Text::StripFormatCodes(rawName).ToLower();
    if (name.Contains("goal hunt") || name.Contains("goalhunt") ||
        name.Contains("goal-hunt")) return true;
    // Accept the documented short form "GH 7" only as a whole token, so
    // words like "high" do not match.
    int p = name.IndexOf("gh ");
    return p == 0 || (p > 0 && name.SubStr(p - 1, 1) == " ");
}

int DayDigitsAt(const string &in name, int start) {
    int day = 0;
    int digits = 0;
    for (int i = start; i < int(name.Length); i++) {
        string ch = name.SubStr(i, 1);
        int value = -1;
        for (uint d = 0; d < g_digits.Length; d++) {
            if (g_digits[d] == ch) {
                value = int(d);
                break;
            }
        }
        if (value < 0) break;
        day = day * 10 + value;
        digits++;
    }
    // Read the whole number (no 2-digit truncation) and validate 1-25, so
    // "Goal Hunt 2026" cannot be mistaken for day 20.
    if (digits == 0 || day < 1 || day > DAY_COUNT) return 0;
    return day;
}

// Accepts #7, "Day 7", "GH 7", "Goal Hunt 7" and goalhuntarena maps.
int ParseDayFromMapName(const string &in rawName) {
    string name = Text::StripFormatCodes(rawName).ToLower();
    if (!IsGoalHuntMapName(name)) return 0;

    int hash = name.IndexOf("#");
    if (hash >= 0) {
        int d = DayDigitsAt(name, hash + 1);
        if (d > 0) return d;
    }

    // Explicit Goal Hunt patterns first; generic "day " / "gh " last.
    string[] prefixes = { "goal hunt - ", "goal hunt ", "goalhunt ", "goal-hunt ",
                          "gh ", "day ", "arena " };
    for (uint i = 0; i < prefixes.Length; i++) {
        int pos = name.IndexOf(prefixes[i]);
        if (pos < 0) continue;
        int d = DayDigitsAt(name, pos + int(prefixes[i].Length));
        if (d > 0) return d;
    }
    return 0;   // recognised Goal Hunt map, but no number in the name
}

int DayFromUidMapping(const string &in uid) {
    if (uid.Length == 0) return 0;

    // Mappings learned by the worker from real submits, shared with all players.
    for (uint i = 0; i < g_serverMapUids.Length; i++) {
        if (g_serverMapUids[i] == uid) return g_serverMapDays[i];
    }

    if (S_MapUidDays.Length == 0) return 0;
    string[]@ parts = S_MapUidDays.Split(",");
    for (uint i = 0; i < parts.Length; i++) {
        string part = parts[i].Trim();
        int eq = part.IndexOf("=");
        if (eq <= 0) continue;
        if (part.SubStr(0, eq).Trim() != uid) continue;
        int day = Text::ParseInt(part.SubStr(eq + 1).Trim());
        if (day >= 1 && day <= DAY_COUNT) return day;
    }
    return 0;
}

bool IsGoalHuntMapType(const string &in rawType) {
    string t = rawType.ToLower();
    return t.Contains("goalhunt") || t.Contains("goal hunt") || t.Contains("goal-hunt");
}

// Detects the event day: explicit override, then UID mapping, then the name
// parser, then the map-type metadata (GoalHuntArena), then the UTC event day.
// Name and MapType are both checked because many event maps are named simply
// "Goal Hunt - Complex" while their MapType carries "GoalHuntArena".
int DetectGoalHuntDay() {
    auto app = cast<CGameManiaPlanet>(GetApp());
    if (app is null || app.RootMap is null || app.RootMap.MapInfo is null) return 0;
    if (!OnEventServer()) return 0;

    string name = string(app.RootMap.MapInfo.Name);
    string mapType = string(app.RootMap.MapType);
    bool goalMap = IsGoalHuntMapName(name) || IsGoalHuntMapType(mapType);
    if (!goalMap) return 0;

    if (S_MapDayOverride >= 1 && S_MapDayOverride <= DAY_COUNT) return S_MapDayOverride;
    int mapped = DayFromUidMapping(GetCurrentMapUid());
    if (mapped > 0) return mapped;

    int fromName = ParseDayFromMapName(name);
    if (fromName > 0) return fromName;

    // A new Goal Hunt / GoalHuntArena map with no day number: during the event
    // the day is today's UTC date - the same clock the worker uses.
    return CurrentEventDayUtc();
}

// Called from the debug panel: remember the current map as the selected day.
void AssignCurrentMapToDay(int day) {
    string uid = GetCurrentMapUid();
    if (uid.Length == 0 || day < 1 || day > DAY_COUNT) return;

    string result = "";
    string[]@ parts = S_MapUidDays.Split(",");
    for (uint i = 0; i < parts.Length; i++) {
        string part = parts[i].Trim();
        if (part.Length == 0) continue;
        int eq = part.IndexOf("=");
        if (eq > 0 && part.SubStr(0, eq).Trim() == uid) continue;   // replace old entry
        if (result.Length > 0) result += ",";
        result += part;
    }
    if (result.Length > 0) result += ",";
    result += uid + "=" + tostring(day);
    S_MapUidDays = result;

    // Apply immediately - the player is already on this map, so waiting for a
    // UID change would leave the debug panel showing "not detected".
    g_activeDay = day;
    g_selectedDay = day;
}

// ---------------------------------------------------------------------------
// Checkpoint tracking
// ---------------------------------------------------------------------------
// Server warmup flag, read through the same null-safe nod chain as the server
// name. Community modes may not set it; the 15 s race gate covers those.
bool ServerIsWarmUp() {
    auto app = cast<CGameManiaPlanet>(GetApp());
    if (app is null || app.CurrentPlayground is null) return false;
    auto pgInterface = app.CurrentPlayground.Interface;
    if (pgInterface is null || pgInterface.ServerInfo is null) return false;
    return pgInterface.ServerInfo.IsWarmUp;
}

// True while the current race is inside the warmup gate. Single source for
// the tracker and the HUD, so both always agree.
bool InWarmupGate() {
    if (g_activeDay <= 0) return false;
    if (ServerIsWarmUp()) return true;
    return Time::Stamp - g_raceStartStamp < WARMUP_GRACE_SEC;
}

// Checkpoints collected by the local player in the current race.
// Uses the same path as the working chase-mode overlay (CTrackManiaPlayer.ScriptAPI).
// Also refreshes g_curRaceState and g_curRaceNbCp for the warmup/finish logic.
int CurrentCpCount() {
    g_curRaceState = RACE_BEFORE_START;
    g_curRaceNbCp = 0;
    auto app = cast<CGameManiaPlanet>(GetApp());
    if (app is null || app.CurrentPlayground is null) return 0;

    auto playground = app.CurrentPlayground;
    string login = LocalLogin();

    for (uint i = 0; i < playground.Players.Length; i++) {
        auto player = cast<CTrackManiaPlayer>(playground.Players[i]);
        if (player is null || player.User is null) continue;
        if (login.Length > 0 && player.User.Login != login) continue;
        if (player.ScriptAPI is null || player.ScriptAPI.CurRace is null) return 0;
        g_curRaceState = int(player.ScriptAPI.RaceState);
        if (player.ScriptAPI.Score !is null) {
            g_curRaceNbCp = int(player.ScriptAPI.Score.LapsNbCheckpoint);
        }
        return int(player.ScriptAPI.CurRace.Checkpoints.Length);
    }
    return 0;
}

// ---------------------------------------------------------------------------
// Rewards
// ---------------------------------------------------------------------------
void CompleteDay(int day, int cp) {
    if (day < 1 || day > DAY_COUNT) return;
    int idx = day - 1;
    if (cp > g_bests[idx]) g_bests[idx] = cp;
    if (g_opened[idx]) return;

    int mult = DayMultiplier(day);
    int points = (day == DAY_COUNT ? FINALE_POINTS : BASE_POINTS) * mult;
    g_opened[idx] = true;
    g_points[idx] += points;
    AddBadge("GOALMAS-PLAYER");

    int opened = OpenedCount();
    if (opened >= 10) AddBadge("ELF-VETERAN");
    if (opened >= 24) AddBadge("GOALMAS-24");
    if (opened >= DAY_COUNT) AddBadge("FINALIST");

    string msg = LocalName() + " finished day " + tostring(day) + " with " + tostring(cp) +
                 " CP (+" + tostring(points) + " pts)";
    if (S_OpenAnimation) StartOpenAnimation(day, points, cp, false);
    else ShowBanner("Day " + tostring(day) + " completed: " + tostring(cp) + " CP, +" + tostring(points) + " pts");
    PushFeed(msg);
    SaveProgress();
}

void ClaimBounty(int day, int cp) {
    if (day < 1 || day > DAY_COUNT) return;
    int idx = day - 1;
    if (cp <= g_bountyCp[idx]) return;

    bool newRecord = cp > g_bountyCp[idx];
    g_bountyCp[idx] = cp;
    g_bountyHolder[idx] = LocalName();
    int points = 0;
    // The bonus is granted once per day, exactly like the worker's `b` flag.
    if (newRecord && !g_bountyClaimed[idx]) {
        g_bountyClaimed[idx] = true;
        points = BOUNTY_POINTS * DayMultiplier(day);
        g_points[idx] += points;
        g_bountiesWon++;
        AddBadge("BOUNTY-HUNTER");
    }

    string msg = LocalName() + " stole the day " + tostring(day) + " bounty with " +
                 tostring(cp) + " CP";
    if (points > 0) {
        if (S_OpenAnimation) StartOpenAnimation(day, points, cp, true);
        else ShowBanner("BOUNTY TAKEN: " + tostring(cp) + " CP, +" + tostring(points) + " pts");
        PushFeed(msg);
    } else if (S_OpenAnimation && g_openAnimActive && g_openAnimDay == day) {
        // The day-completion card is already on screen; only upgrade its badge.
        g_openAnimBounty = true;
    }
    SaveProgress();
}

// ---------------------------------------------------------------------------
// Session loop (called from Update)
// ---------------------------------------------------------------------------
void ResetSession() {
    g_sessionCp = 0;
    g_lastSentCp = 0;
    g_submitPending = false;
    g_submitTimer = 0.0f;
    g_lastRaceState = -1;
    g_lastCpBuffer = 0;
    g_warmupCpBaseline = 0;
    g_raceStartStamp = 0;
}

void TrackGoalHunt(float dt) {
    string uid = GetCurrentMapUid();
    if (uid != g_lastMapUid) {
        // Flush a finished run before the map change drops it from the queue.
        if (g_submitPending && g_activeDay > 0 && g_sessionCp > g_lastSentCp) {
            RequestCpSubmit(g_activeDay, g_sessionCp);
        }
        g_lastMapUid = uid;
        ResetSession();
        g_activeDay = DetectGoalHuntDay();
        // Record every map played for the detection history (debug window/log).
        string histName = Text::StripFormatCodes(CurrentMapName());
        bool histGoal = IsGoalHuntMapName(CurrentMapName()) || IsGoalHuntMapType(CurrentMapType());
        g_mapHistory.InsertLast(histName + " -> day " + tostring(g_activeDay) +
            " | GH:" + (histGoal ? "Y" : "N") + " | srv:" + (OnEventServer() ? "Y" : "N"));
        if (g_mapHistory.Length > 12) g_mapHistory.RemoveAt(0);
        CheckCommunityBadges();
        if (g_activeDay > 0) {
            g_selectedDay = g_activeDay;
            ShowBanner("Day " + tostring(g_activeDay) + " Goal Hunt detected | hunt checkpoints!");
        }
        if (S_Debug) {
            print("[goaladvent][DBG] Map '" + CurrentMapName() + "' -> day " +
                  tostring(g_activeDay) + " (event server: " + tostring(OnEventServer()) + ")");
        }
    }

    if (g_activeDay <= 0) return;

    int cp = CurrentCpCount();
    int raceState = g_curRaceState;

    // A new race starts when the state enters Running, or when the checkpoint
    // buffer drops: arena respawn can recycle CurRace without a state flip.
    bool newRace = false;
    if (raceState == RACE_RUNNING && g_lastRaceState != RACE_RUNNING) newRace = true;
    if (cp < g_lastCpBuffer) newRace = true;
    if (newRace) {
        // The previous run is over: flush its final CP before resetting.
        if (g_submitPending && g_sessionCp > g_lastSentCp) {
            RequestCpSubmit(g_activeDay, g_sessionCp);
        }
        ResetSession();
        g_raceStartStamp = Time::Stamp;
        g_warmupCpBaseline = cp;
    }
    g_lastRaceState = raceState;
    g_lastCpBuffer = cp;

    // Warmup never counts. Track the buffer while gated so CP passed during
    // warmup are subtracted afterwards instead of counted retroactively.
    if (InWarmupGate()) {
        if (cp > g_warmupCpBaseline) g_warmupCpBaseline = cp;
        return;
    }

    int effective = cp - g_warmupCpBaseline;
    if (effective < 0) effective = 0;

    // The finish line is the map's last checkpoint. Arena mode can recycle
    // CurRace before the buffer shows it, so a finished race credits the full
    // map checkpoint count (Score.LapsNbCheckpoint) - never more.
    if (raceState == RACE_FINISHED && g_curRaceNbCp > effective) {
        effective = g_curRaceNbCp;
    }

    if (effective > g_sessionCp) {
        g_sessionCp = effective;
        if (effective >= GOAL_CP) CompleteDay(g_activeDay, effective);
        if (effective > g_bountyCp[g_activeDay - 1]) ClaimBounty(g_activeDay, effective);
        g_submitPending = true;
        g_submitTimer = 0.0f;
    }

    if (!g_submitPending) return;
    g_submitTimer += dt / 1000.0f;
    if (g_submitTimer < SUBMIT_DEBOUNCE_SEC) return;

    g_submitPending = false;
    if (g_sessionCp <= g_lastSentCp) return;
    // Do NOT advance g_lastSentCp here. If a sync is in flight the submit is
    // queued, and only the successful upload may mark these CP as sent.
    RequestCpSubmit(g_activeDay, g_sessionCp);
}

// ---------------------------------------------------------------------------
// Upload
// ---------------------------------------------------------------------------
void RequestCpSubmit(int day, int cp) {
    if (day < 1 || day > DAY_COUNT) return;
    if (cp <= 0) return;
    g_pendingDay = day;
    g_pendingCp = cp;

    if (S_SyncMode == 2) {
        // A /state request may be in flight. Wait for it instead of dropping
        // the submit - otherwise these CP are never retried.
        if (!g_submitQueued) {
            g_submitQueued = true;
            startnew(SubmitWhenFree);
        }
    } else if (S_SyncMode == 1) {
        WriteFolderFile();
    }
}

void SubmitWhenFree() {
    while (g_syncing) yield();
    g_submitQueued = false;
    Coroutine_SubmitCp();   // still inside a coroutine, yield() is legal here
}

void Coroutine_SubmitCp() {
    if (g_syncing) return;
    if (S_SyncMode != 2 || ApiUrl().Length == 0) return;

    int day = g_pendingDay;
    int cp = g_pendingCp;
    string mapUid = S_TestMode ? "" : g_lastMapUid;

    g_syncing = true;

    Json::Value@ payload = Json::Object();
    payload["accountId"] = AccountId();
    payload["name"] = LocalName();
    payload["day"] = day;
    payload["mapUid"] = mapUid;
    payload["cpCount"] = cp;
    payload["timeMs"] = 0;

    Net::HttpRequest@ req = Net::HttpPost(ApiUrl() + "/submit", Json::Write(payload), "application/json");
    if (req is null) {
        DebugError("submit", "could not create upload request");
        g_syncing = false;
        QueueSubmitRetry();
        return;
    }
    while (!req.Finished()) yield();

    int code = req.ResponseCode();
    g_syncing = false;

    if (code == 200) {
        g_submitRetries = 0;
        if (cp > g_lastSentCp) g_lastSentCp = cp;
        g_status = "Sent " + tostring(cp) + " CP to the event server.";
        SyncState();
    } else {
        g_status = "Upload failed (HTTP " + tostring(code) + ") | retrying.";
        DebugError("submit", "HTTP " + tostring(code));
        QueueSubmitRetry();
    }
}

// A failed upload must not lose the run: wait a few seconds, then send the
// still-pending CP again. g_lastSentCp stays unchanged until HTTP 200.
void QueueSubmitRetry() {
    if (g_submitQueued || g_submitRetries >= 5) return;
    g_submitRetries++;
    g_submitQueued = true;
    startnew(RetrySubmitLater);
}

void RetrySubmitLater() {
    sleep(5000);
    while (g_syncing) yield();
    g_submitQueued = false;
    Coroutine_SubmitCp();
}
