// Admin diagnostics. Enabled only by Settings -> Advanced -> Debug overlay.
// Everything here is English on purpose: log lines must be searchable.

bool g_showDebug = false;
string g_copyStatus = "";

// Rolling error history for the admin panel. The player only sees g_status;
// this keeps the last few real failures readable without opening the log.
array<string> g_debugErrors;

void DebugError(const string &in source, const string &in detail) {
    string line = "[" + tostring(int(Time::Stamp)) + "] " + source + ": " + detail;
    g_debugErrors.InsertLast(line);
    print("[goaladvent][ERR] " + line);
}

string DebugStateLine() {
    Time::Info now = Time::Parse();
    string localDate = tostring(now.Year) + "-" + tostring(now.Month) + "-" + tostring(now.Day);
    bool eventSeason = now.Month == 12 || (now.Month == 1 && now.Day <= FINALE_GRACE_DAYS);
    return "version=" + PLUGIN_VERSION + " theme=" + (GlassTheme() ? "galaxy" : "goaladvent") +
           " localDate=" + localDate +
           " eventSeason=" + tostring(eventSeason) +
           " errors=" + tostring(g_debugErrors.Length) +
           " opacity=" + tostring(S_GlassOpacity) +
           " selected=" + tostring(g_selectedDay) +
           " active=" + tostring(g_activeDay) +
           " sessionCp=" + tostring(g_sessionCp) +
           " sentCp=" + tostring(g_lastSentCp) +
           " pending=" + tostring(g_submitPending) +
           " unlocked=" + tostring(DayUnlocked(g_selectedDay)) +
           " playable=" + tostring(DayPlayableNow(g_selectedDay)) +
           " opens=" + tostring(OpenedCount()) +
           " score=" + tostring(ScoreDays()) +
           " syncMode=" + tostring(S_SyncMode) +
           " syncing=" + tostring(g_syncing) +
           " lastSyncOk=" + tostring(g_lastSyncOk) +
           " lastHttp=" + tostring(g_lastSyncHttp) +
           " syncAge=" + (g_lastSyncStamp > 0 ? tostring(int(Time::Stamp) - g_lastSyncStamp) + "s" : "never") +
           " boardRows=" + tostring(g_boardCount) +
           " selfTest=" + g_selfTestResult +
           " api=" + ApiUrl() +
           " map=" + GetCurrentMapUid() +
           " mapName=" + CurrentMapName() +
           " mapType=" + CurrentMapType() +
           " detected=" + tostring(DetectGoalHuntDay()) +
           " server=" + CurrentServerName() +
           " eventServer=" + tostring(OnEventServer());
}

// Dump candidate Pursuit role signals per player to Openplanet.log so a live
// round can be read from the log file (no UI needed). TeamNum is the primary
// hunter/hunted hypothesis; clan and race state are backups.
void DumpPursuitRoles() {
    auto app = cast<CGameManiaPlanet>(GetApp());
    if (app is null || app.CurrentPlayground is null) {
        print("[goaladvent][DBG] ROLE no playground");
        return;
    }
    auto pg = app.CurrentPlayground;
    print("[goaladvent][DBG] ROLE players=" + tostring(int(pg.Players.Length)));
    for (uint i = 0; i < pg.Players.Length; i++) {
        auto p = cast<CTrackManiaPlayer>(pg.Players[i]);
        if (p is null) continue;
        string login = p.User is null ? "?" : p.User.Login;
        int team = p.Score is null ? -1 : int(p.Score.TeamNum);
        int clan = p.ScriptAPI is null ? -1 : p.ScriptAPI.CurrentClan;
        // Pursuit roles are clans: escaping clan 2 = thief, 3-2 = 1 = police
        // (default; Swap mode flips the escaping clan). 0 = spectator.
        string role = clan == 2 ? "THIEF" : (clan == 1 ? "POLICE" : (clan == 0 ? "SPEC" : "?"));
        // Proximity to the nearest other spawned player: a catch drops this
        // toward zero, revealing the gamemode catch radius in a live round.
        string near = "-";
        if (p.IsSpawned) {
            float best = -1.0f;
            for (uint j = 0; j < pg.Players.Length; j++) {
                if (j == i) continue;
                auto q = cast<CTrackManiaPlayer>(pg.Players[j]);
                if (q is null || !q.IsSpawned) continue;
                float d = Math::Distance(p.Position, q.Position);
                if (best < 0.0f || d < best) best = d;
            }
            if (best >= 0.0f) near = tostring(int(best)) + "m";
        }
        print("[goaladvent][DBG] ROLE " + login + " team=" + tostring(team) +
              " clan=" + tostring(clan) + " role=" + role + " race=" + tostring(int(p.RaceState)) +
              " spawned=" + (p.IsSpawned ? "Y" : "N") + " near=" + near);
    }
}

void LogDebugState() {
    print("[goaladvent][DBG] " + DebugStateLine());
    DumpPursuitRoles();
}

// Everything a support report needs, as one pasteable block.
void CopyDebugLog() {
    string text = "[goaladvent][DBG] " + DebugStateLine() + "\n";
    text += "[goaladvent][LOG] status: " + g_status + "\n";
    text += "[goaladvent][LOG] server test: " + g_selfTestResult + "\n";
    for (uint i = 0; i < g_debugErrors.Length; i++) {
        text += "[goaladvent][ERR] " + g_debugErrors[i] + "\n";
    }
    for (uint i = 0; i < g_mapHistory.Length; i++) {
        text += "[goaladvent][MAP] " + g_mapHistory[i] + "\n";
    }
    IO::SetClipboard(text);
    g_copyStatus = "Copied " + tostring(g_debugErrors.Length) + " error line(s) to clipboard.";
}

// Readability helpers for the debug window: a spaced gold section header with
// a rule, and an aligned label/value row (muted label, bright value in a column).
void DebugSection(const string &in title) {
    UI::Dummy(vec2(0, 7.0f));
    UI::PushStyleColor(UI::Col::Text, Gold());
    UI::Text(title);
    UI::PopStyleColor();
    UI::Separator();
}
void DebugKV(const string &in label, const string &in value) {
    UI::TextDisabled(label);
    UI::SameLine(150.0f);
    UI::Text(value);
}

void RenderDebugWindow() {
    if (!S_Debug || !g_showDebug) return;

    RefreshPalette();
    int flags = UI::WindowFlags::AlwaysAutoResize;
    if (!UI::Begin(Icons::Info + " GoalAdvent 2026 debug", g_showDebug, flags)) {
        UI::End();
        return;
    }

    UI::PushFontSize(15.0f);
    UI::TextDisabled("Admin diagnostics | state is read only");
    UI::Separator();

    Time::Info now = Time::Parse();
    string localDate = tostring(now.Year) + "-" + tostring(now.Month) + "-" + tostring(now.Day);
    bool eventSeason = now.Month == 12 || (now.Month == 1 && now.Day <= FINALE_GRACE_DAYS);

    // Answers "is it working right now?" without reading the log.
    int detectedNow = DetectGoalHuntDay();
    bool serverOk = (S_SyncMode == 2 && g_lastSyncOk);
    int syncAge = int(Time::Stamp) - g_lastSyncStamp;
    TextTone(serverOk ? Emerald() : Crimson(),
             serverOk ? Icons::CheckCircle + "  SERVER ONLINE" : Icons::Info + "  SERVER NOT CONFIRMED");
    UI::Text("  HTTP " + tostring(g_lastSyncHttp) + " | last sync " +
             (g_lastSyncStamp > 0 ? tostring(syncAge) + "s ago" : "never") +
             " | board rows " + tostring(g_boardCount));
    TextTone(detectedNow > 0 ? Emerald() : TextMuted(),
             detectedNow > 0 ? Icons::CheckCircle + "  GOAL HUNT MAP: DAY " + tostring(detectedNow)
                             : Icons::Info + "  NO GOAL HUNT MAP DETECTED");
    UI::Text("  event server: " + tostring(OnEventServer()) +
             " | playable now: " + tostring(detectedNow > 0 ? DayPlayableNow(detectedNow) : false));
    UI::Text("  server test: " + g_selfTestResult);
    UI::Separator();

    DebugSection("VERSION | VIEW");
    DebugKV("version", PLUGIN_VERSION);
    DebugKV("local date", localDate + " | event season: " + tostring(eventSeason));
    DebugKV("theme", string(GlassTheme() ? "Galaxy transparent" : "GoalAdvent dark"));
    DebugKV("glass opacity", tostring(S_GlassOpacity));
    DebugKV("dashboard visible", tostring(g_showCalendar));

    DebugSection("DAY | SCORING");
    DebugKV("selected", tostring(g_selectedDay) + " | active: " + tostring(g_activeDay));
    DebugKV("unlocked", tostring(DayUnlocked(g_selectedDay)) +
            " | playable: " + tostring(DayPlayableNow(g_selectedDay)));
    DebugKV("opened", tostring(OpenedCount()) + "/" + tostring(DAY_COUNT) +
            " | score: " + tostring(ScoreDays()) + " | total: " + tostring(TotalPoints()));
    DebugKV("session CP", tostring(g_sessionCp) + "/" + tostring(GOAL_CP) +
            " | last sent: " + tostring(g_lastSentCp));

    DebugSection("SUBMIT QUEUE");
    DebugKV("pending", tostring(g_submitPending) +
            " | day: " + tostring(g_pendingDay) + " | cp: " + tostring(g_pendingCp));
    DebugKV("debounce timer", tostring(g_submitTimer));

    DebugSection("SYNC | SERVER");
    DebugKV("mode", tostring(S_SyncMode) + " | busy: " + tostring(g_syncing));
    DebugKV("api", ApiUrl());
    DebugKV("event keyword", S_EventServerKeyword +
            " | on event server: " + tostring(OnEventServer()));
    DebugKV("status", g_status);

    DebugSection("IDENTITY | MAP");
    DebugKV("login", LocalLogin());
    DebugKV("name", LocalName());
    DebugKV("server", CurrentServerName());
    DebugKV("map name", CurrentMapName());
    DebugKV("map type", CurrentMapType());
    DebugKV("map UID", GetCurrentMapUid());
    DebugKV("detected day", tostring(DetectGoalHuntDay()) +
            " | name parse: " + tostring(ParseDayFromMapName(CurrentMapName())));
    DebugKV("feed / board rows", tostring(g_liveFeed.Length) + " / " + tostring(g_boardNames.Length));

    // Every map played this session and its detected day - verify text detection
    // catches each Goal Hunt map on the server.
    DebugSection("MAP DETECTION HISTORY (" + tostring(g_mapHistory.Length) + ")");
    if (g_mapHistory.Length == 0) {
        UI::Text("  none yet | play a map on the server.");
    } else {
        for (uint i = g_mapHistory.Length; i > 0; i--) {
            UI::TextWrapped("  " + g_mapHistory[i - 1]);
        }
    }

    UI::TextWrapped("Last event: " + (g_lastTopEvent.Length > 0 ? Text::StripFormatCodes(g_lastTopEvent) : "-"));
    // Recent feed events with plain names - the notification history to debug.
    if (g_liveFeed.Length > 0) {
        DebugSection("RECENT EVENTS");
        uint n = g_liveFeed.Length < 5 ? g_liveFeed.Length : 5;
        for (uint i = 0; i < n; i++) {
            UI::TextWrapped("  " + Text::StripFormatCodes(g_liveFeed[i]));
        }
    }

    // Pursuit scoreboard: detect each player's role from CurrentClan (verified
    // from Pursuit.Script.txt: escaping clan 2 = thief, 3-2 = 1 = police, 0 =
    // spectator; Swap mode flips the escaping clan). Shown in the plugin menu.
    DebugSection("PURSUIT SCOREBOARD");
    auto sbApp = cast<CGameManiaPlanet>(GetApp());
    if (sbApp is null || sbApp.CurrentPlayground is null) {
        UI::TextWrapped("  no playground | join a Pursuit round to read roles.");
    } else {
        auto sbPg = sbApp.CurrentPlayground;
        int nPolice = 0; int nThief = 0; int nSpec = 0;
        for (uint i = 0; i < sbPg.Players.Length; i++) {
            auto p = cast<CTrackManiaPlayer>(sbPg.Players[i]);
            if (p is null) continue;
            int c = p.ScriptAPI is null ? -1 : p.ScriptAPI.CurrentClan;
            if (c == 1) nPolice++;
            else if (c == 2) nThief++;
            else nSpec++;
        }
        UI::Text("  police " + tostring(nPolice) + " | thieves " + tostring(nThief) +
                 " | spectator " + tostring(nSpec));
        for (uint i = 0; i < sbPg.Players.Length; i++) {
            auto p = cast<CTrackManiaPlayer>(sbPg.Players[i]);
            if (p is null) continue;
            string login = p.User is null ? "?" : Text::StripFormatCodes(p.User.Login);
            int c = p.ScriptAPI is null ? -1 : p.ScriptAPI.CurrentClan;
            string role = c == 2 ? "[THIEF]" : (c == 1 ? "[POLICE]" : (c == 0 ? "[SPEC]" : "[?]"));
            vec4 roleCol = c == 2 ? Crimson() : (c == 1 ? IceBlue() : TextMuted());
            UI::PushStyleColor(UI::Col::Text, roleCol);
            UI::Text("  " + role + " " + login);
            UI::PopStyleColor();
            UI::SetItemTooltip("clan " + tostring(c) + " | race " + tostring(int(p.RaceState)) +
                               " | spawned " + (p.IsSpawned ? "Y" : "N"));
        }
    }

    DebugSection("LAST ERRORS (" + tostring(g_debugErrors.Length) + ")");
    if (g_debugErrors.Length == 0) {
        UI::Text("  none");
    } else {
        uint start = g_debugErrors.Length > 8 ? g_debugErrors.Length - 8 : 0;
        for (uint i = g_debugErrors.Length; i > start; i--) {
            UI::TextWrapped("  " + g_debugErrors[i - 1]);
        }
    }

    UI::Separator();
    if (UI::Button("Copy log to clipboard")) CopyDebugLog();
    UI::SetItemTooltip("Copies state, status, server test and all error lines as one pasteable block.");
    UI::SameLine(0, 6);
    if (UI::Button("Clear errors")) {
        g_debugErrors.Resize(0);
        g_copyStatus = "Error history cleared.";
    }
    UI::SetItemTooltip("Clears only the in-memory list, not Openplanet.log.");
    if (g_copyStatus.Length > 0) UI::TextDisabled(g_copyStatus);
    UI::SameLine(0, 6);
    if (UI::Button("Test server")) startnew(SelfTestServer);
    UI::SetItemTooltip("Sends one GET to the worker root and shows OK/FAIL above.");
    UI::SameLine(0, 6);
    if (UI::Button("Assign this map to day " + tostring(g_selectedDay))) {
        AssignCurrentMapToDay(g_selectedDay);
        g_copyStatus = "Map saved as day " + tostring(g_selectedDay) + ".";
    }
    UI::SetItemTooltip("Maps without #N in the name need a UID mapping to be detected.");
    UI::SameLine(0, 6);
    if (UI::Button("Log state to Openplanet.log")) LogDebugState();
    UI::SameLine(0, 6);
    UI::BeginDisabled(g_syncing);
    if (UI::Button("Run sync now")) SyncNow();
    UI::EndDisabled();
    UI::SameLine(0, 6);
    if (UI::Button("Close")) g_showDebug = false;

    UI::PopFontSize();
    UI::End();
}
