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

// Stable key for scoreboards shared between players.
string AccountId() {
    string login = LocalLogin();
    if (login.Length > 0) return login;
    return "local-" + LocalName().ToLower().Replace(" ", "-");
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

bool OnEventServer() {
    string keyword = S_EventServerKeyword.Trim().ToLower();
    if (keyword.Length == 0) return true;
    if (CurrentServerName().ToLower().Contains(keyword)) return true;
    if (CurrentServerLogin().ToLower().Contains(keyword)) return true;
    return false;
}

// Reads "#N" from a map name like "#7 Goal Hunt" / "#7 GoalHunt".
int ParseDayFromMapName(const string &in rawName) {
    string name = Text::StripFormatCodes(rawName).ToLower();
    if (!name.Contains("goal hunt") && !name.Contains("goalhunt") && !name.Contains("goal-hunt")) {
        return 0;
    }

    int hash = name.IndexOf("#");
    if (hash < 0) return 0;

    int day = 0;
    int digits = 0;
    for (int i = hash + 1; i < int(name.Length) && digits < 2; i++) {
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

    if (digits == 0) return 0;
    if (day < 1 || day > DAY_COUNT) return 0;
    return day;
}

// Detects the event day from the running map, without knowing the map UID.
int DetectGoalHuntDay() {
    auto app = cast<CGameManiaPlanet>(GetApp());
    if (app is null || app.RootMap is null || app.RootMap.MapInfo is null) return 0;
    if (!OnEventServer()) return 0;
    return ParseDayFromMapName(string(app.RootMap.MapInfo.Name));
}

// ---------------------------------------------------------------------------
// Checkpoint tracking
// ---------------------------------------------------------------------------
// Checkpoints collected by the local player in the current race.
// Uses the same path as the working chase-mode overlay (CTrackManiaPlayer.ScriptAPI).
int CurrentCpCount() {
    auto app = cast<CGameManiaPlanet>(GetApp());
    if (app is null || app.CurrentPlayground is null) return 0;

    auto playground = app.CurrentPlayground;
    string login = LocalLogin();

    for (uint i = 0; i < playground.Players.Length; i++) {
        auto player = cast<CTrackManiaPlayer>(playground.Players[i]);
        if (player is null || player.User is null) continue;
        if (login.Length > 0 && player.User.Login != login) continue;
        if (player.ScriptAPI is null || player.ScriptAPI.CurRace is null) return 0;
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
    ShowBanner("Day " + tostring(day) + " completed: " + tostring(cp) + " CP, +" + tostring(points) + " pts");
    PushFeed(msg);
    SaveProgress();
}

void ClaimBounty(int day, int cp) {
    if (day < 1 || day > DAY_COUNT) return;
    int idx = day - 1;
    if (cp <= g_bountyCp[idx]) return;

    g_bountyCp[idx] = cp;
    g_bountyHolder[idx] = LocalName();
    int mult = DayMultiplier(day);
    int points = BOUNTY_POINTS * mult;
    g_points[idx] += points;
    g_bountiesWon++;
    AddBadge("BOUNTY-HUNTER");

    string msg = LocalName() + " stole the day " + tostring(day) + " bounty with " +
                 tostring(cp) + " CP";
    ShowBanner("BOUNTY TAKEN: " + tostring(cp) + " CP, +" + tostring(points) + " pts");
    PushFeed(msg);
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
}

void TrackGoalHunt(float dt) {
    string uid = GetCurrentMapUid();
    if (uid != g_lastMapUid) {
        g_lastMapUid = uid;
        ResetSession();
        g_activeDay = DetectGoalHuntDay();
        CheckCommunityBadges();
        if (g_activeDay > 0) {
            g_selectedDay = g_activeDay;
            ShowBanner("Day " + tostring(g_activeDay) + " Goal Hunt detected - hunt checkpoints!");
        }
    }

    if (g_activeDay <= 0) return;

    int cp = CurrentCpCount();
    if (cp > g_sessionCp) {
        g_sessionCp = cp;
        if (cp >= GOAL_CP) CompleteDay(g_activeDay, cp);
        if (cp > g_bountyCp[g_activeDay - 1]) ClaimBounty(g_activeDay, cp);
        g_submitPending = true;
        g_submitTimer = 0.0f;
    }

    if (!g_submitPending) return;
    g_submitTimer += dt / 1000.0f;
    if (g_submitTimer < SUBMIT_DEBOUNCE_SEC) return;

    g_submitPending = false;
    if (g_sessionCp <= g_lastSentCp) return;
    g_lastSentCp = g_sessionCp;
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

    if (S_SyncMode == 2 && !g_syncing) {
        startnew(Coroutine_SubmitCp);
    } else if (S_SyncMode == 1) {
        WriteFolderFile();
    }
}

void Coroutine_SubmitCp() {
    if (g_syncing) return;
    if (S_SyncMode != 2 || ApiUrl().Length == 0) return;

    int day = g_pendingDay;
    int cp = g_pendingCp;
    string mapUid = g_lastMapUid;

    g_syncing = true;

    Json::Value@ payload = Json::Object();
    payload["accountId"] = AccountId();
    payload["name"] = LocalName();
    payload["day"] = day;
    payload["mapUid"] = mapUid;
    payload["cpCount"] = cp;
    payload["timeMs"] = 0;

    Net::HttpRequest@ req = Net::HttpPost(ApiUrl() + "/submit", Json::Write(payload), "application/json");
    while (!req.Finished()) yield();

    int code = req.ResponseCode();
    g_syncing = false;

    if (code == 200) {
        g_status = "Sent " + tostring(cp) + " CP to the event server.";
        SyncState();
    } else {
        g_status = "Upload failed (HTTP " + tostring(code) + ").";
    }
}
