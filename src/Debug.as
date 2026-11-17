// Admin diagnostics. Enabled only by Settings -> Advanced -> Debug overlay.
// Everything here is English on purpose: log lines must be searchable.

bool g_showDebug = false;

// Rolling error history for the admin panel. The player only sees g_status;
// this keeps the last few real failures readable without opening the log.
array<string> g_debugErrors;

void DebugError(const string &in source, const string &in detail) {
    string line = "[" + tostring(int(Time::Stamp)) + "] " + source + ": " + detail;
    g_debugErrors.InsertLast(line);
    print("[goalmas][ERR] " + line);
}

void LogDebugState() {
    Time::Info now = Time::Parse();
    string localDate = tostring(now.Year) + "-" + tostring(now.Month) + "-" + tostring(now.Day);
    bool eventSeason = now.Month == 12 || (now.Month == 1 && now.Day <= FINALE_GRACE_DAYS);
    print("[goalmas][DBG] version=0.3.8-dev theme=" + (GlassTheme() ? "glass" : "obsidian") +
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
          " api=" + ApiUrl() +
          " map=" + GetCurrentMapUid() +
          " mapName=" + CurrentMapName() +
          " detected=" + tostring(DetectGoalHuntDay()) +
          " server=" + CurrentServerName() +
          " eventServer=" + tostring(OnEventServer()));
}

void RenderDebugWindow() {
    if (!S_Debug || !g_showDebug) return;

    RefreshPalette();
    int flags = UI::WindowFlags::AlwaysAutoResize;
    if (!UI::Begin(Icons::Info + " goalmas debug", g_showDebug, flags)) {
        UI::End();
        return;
    }

    UI::TextDisabled("Admin diagnostics - state is read only");
    UI::Separator();

    Time::Info now = Time::Parse();
    string localDate = tostring(now.Year) + "-" + tostring(now.Month) + "-" + tostring(now.Day);
    bool eventSeason = now.Month == 12 || (now.Month == 1 && now.Day <= FINALE_GRACE_DAYS);

    UI::Text("VERSION / VIEW");
    UI::Text("  version: 0.3.8-dev");
    UI::Text("  local date: " + localDate + "   event season: " + tostring(eventSeason));
    UI::Text("  theme: " + string(GlassTheme() ? "Transparent Glass" : "Obsidian Minimal"));
    UI::Text("  glass opacity: " + tostring(S_GlassOpacity));
    UI::Text("  dashboard visible: " + tostring(g_showCalendar));

    UI::Text("DAY / SCORING");
    UI::Text("  selected: " + tostring(g_selectedDay) + "   active: " + tostring(g_activeDay));
    UI::Text("  unlocked: " + tostring(DayUnlocked(g_selectedDay)) +
             "   playable: " + tostring(DayPlayableNow(g_selectedDay)));
    UI::Text("  opened: " + tostring(OpenedCount()) + "/" + tostring(DAY_COUNT) +
             "   score: " + tostring(ScoreDays()) + "   total: " + tostring(TotalPoints()));
    UI::Text("  session CP: " + tostring(g_sessionCp) + "/" + tostring(GOAL_CP) +
             "   last sent: " + tostring(g_lastSentCp));

    UI::Text("SUBMIT QUEUE");
    UI::Text("  pending: " + tostring(g_submitPending) +
             "   day: " + tostring(g_pendingDay) + "   cp: " + tostring(g_pendingCp));
    UI::Text("  debounce timer: " + tostring(g_submitTimer));

    UI::Text("SYNC / SERVER");
    UI::Text("  mode: " + tostring(S_SyncMode) + "   busy: " + tostring(g_syncing));
    UI::Text("  api: " + ApiUrl());
    UI::Text("  event keyword: " + S_EventServerKeyword +
             "   on event server: " + tostring(OnEventServer()));
    UI::Text("  status: " + g_status);

    UI::Text("IDENTITY / MAP");
    UI::Text("  login: " + LocalLogin());
    UI::Text("  name: " + LocalName());
    UI::Text("  server: " + CurrentServerName());
    UI::Text("  map name: " + CurrentMapName());
    UI::Text("  map UID: " + GetCurrentMapUid());
    UI::Text("  detected day now: " + tostring(DetectGoalHuntDay()) +
             "   (name parse: " + tostring(ParseDayFromMapName(CurrentMapName())) + ")");
    UI::Text("  feed rows: " + tostring(g_liveFeed.Length) +
             "   board rows: " + tostring(g_boardNames.Length));

    UI::TextWrapped("Last event: " + (g_lastTopEvent.Length > 0 ? g_lastTopEvent : "-"));

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
    if (UI::Button("Log state to Openplanet.log")) LogDebugState();
    UI::SameLine(0, 6);
    UI::BeginDisabled(g_syncing);
    if (UI::Button("Run sync now")) SyncNow();
    UI::EndDisabled();
    UI::SameLine(0, 6);
    if (UI::Button("Close")) g_showDebug = false;

    UI::End();
}
