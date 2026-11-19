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
    IO::SetClipboard(text);
    g_copyStatus = "Copied " + tostring(g_debugErrors.Length) + " error line(s) to clipboard.";
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

    UI::Text("VERSION | VIEW");
    UI::Text("  version: " + PLUGIN_VERSION);
    UI::Text("  local date: " + localDate + " | event season: " + tostring(eventSeason));
    UI::Text("  theme: " + string(GlassTheme() ? "Galaxy transparent" : "GoalAdvent dark"));
    UI::Text("  glass opacity: " + tostring(S_GlassOpacity));
    UI::Text("  dashboard visible: " + tostring(g_showCalendar));

    UI::Text("DAY | SCORING");
    UI::Text("  selected: " + tostring(g_selectedDay) + " | active: " + tostring(g_activeDay));
    UI::Text("  unlocked: " + tostring(DayUnlocked(g_selectedDay)) +
             " | playable: " + tostring(DayPlayableNow(g_selectedDay)));
    UI::Text("  opened: " + tostring(OpenedCount()) + "/" + tostring(DAY_COUNT) +
             " | score: " + tostring(ScoreDays()) + " | total: " + tostring(TotalPoints()));
    UI::Text("  session CP: " + tostring(g_sessionCp) + "/" + tostring(GOAL_CP) +
             " | last sent: " + tostring(g_lastSentCp));

    UI::Text("SUBMIT QUEUE");
    UI::Text("  pending: " + tostring(g_submitPending) +
             " | day: " + tostring(g_pendingDay) + " | cp: " + tostring(g_pendingCp));
    UI::Text("  debounce timer: " + tostring(g_submitTimer));

    UI::Text("SYNC | SERVER");
    UI::Text("  mode: " + tostring(S_SyncMode) + " | busy: " + tostring(g_syncing));
    UI::Text("  api: " + ApiUrl());
    UI::Text("  event keyword: " + S_EventServerKeyword +
             " | on event server: " + tostring(OnEventServer()));
    UI::Text("  status: " + g_status);

    UI::Text("IDENTITY | MAP");
    UI::Text("  login: " + LocalLogin());
    UI::Text("  name: " + LocalName());
    UI::Text("  server: " + CurrentServerName());
    UI::Text("  map name: " + CurrentMapName());
    UI::Text("  map type: " + CurrentMapType());
    UI::Text("  map UID: " + GetCurrentMapUid());
    UI::Text("  detected day now: " + tostring(DetectGoalHuntDay()) +
             " | (name parse: " + tostring(ParseDayFromMapName(CurrentMapName())) + ")");
    UI::Text("  feed rows: " + tostring(g_liveFeed.Length) +
             " | board rows: " + tostring(g_boardNames.Length));

    UI::TextWrapped("Last event: " + (g_lastTopEvent.Length > 0 ? Text::StripFormatCodes(g_lastTopEvent) : "-"));
    // Recent feed events with plain names - the notification history to debug.
    if (g_liveFeed.Length > 0) {
        UI::Text("RECENT EVENTS");
        uint n = g_liveFeed.Length < 5 ? g_liveFeed.Length : 5;
        for (uint i = 0; i < n; i++) {
            UI::TextWrapped("  " + Text::StripFormatCodes(g_liveFeed[i]));
        }
    }

    // Pursuit role probe: dump the candidate role signals per player so a
    // live Pursuit round reveals which field marks hunter (police) vs hunted
    // (thief). TeamNum is the primary hypothesis; clan and race state backup.
    UI::Separator();
    UI::Text("PURSUIT ROLE PROBE");
    auto probeApp = cast<CGameManiaPlanet>(GetApp());
    if (probeApp is null || probeApp.CurrentPlayground is null) {
        UI::TextWrapped("  no playground | join a Pursuit server to read roles.");
    } else {
        auto probePg = probeApp.CurrentPlayground;
        UI::TextWrapped("  players: " + tostring(int(probePg.Players.Length)) +
                        " | find the team/clan that splits hunters from hunted.");
        for (uint i = 0; i < probePg.Players.Length; i++) {
            auto probeP = cast<CTrackManiaPlayer>(probePg.Players[i]);
            if (probeP is null) continue;
            string probeLogin = probeP.User is null ? "?" : probeP.User.Login;
            int probeTeam = probeP.Score is null ? -1 : int(probeP.Score.TeamNum);
            int probeClan = probeP.ScriptAPI is null ? -1 : probeP.ScriptAPI.CurrentClan;
            UI::TextWrapped("  " + probeLogin + " | team " + tostring(probeTeam) +
                            " | clan " + tostring(probeClan) +
                            " | race " + tostring(int(probeP.RaceState)) +
                            " | spawned " + (probeP.IsSpawned ? "Y" : "N"));
        }
    }

    UI::Separator();
    UI::Text("LAST ERRORS (" + tostring(g_debugErrors.Length) + ")");
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
