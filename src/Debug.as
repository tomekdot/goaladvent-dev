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
    print("[goalmas][ERR] " + line);
}

string DebugStateLine() {
    Time::Info now = Time::Parse();
    string localDate = tostring(now.Year) + "-" + tostring(now.Month) + "-" + tostring(now.Day);
    bool eventSeason = now.Month == 12 || (now.Month == 1 && now.Day <= FINALE_GRACE_DAYS);
    return "version=0.4.4-dev theme=" + (GlassTheme() ? "glass" : "obsidian") +
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
           " syncAge=" + tostring(int(Time::Stamp) - g_lastSyncStamp) + "s" +
           " boardRows=" + tostring(g_boardCount) +
           " selfTest=" + g_selfTestResult +
           " api=" + ApiUrl() +
           " map=" + GetCurrentMapUid() +
           " mapName=" + CurrentMapName() +
           " detected=" + tostring(DetectGoalHuntDay()) +
           " server=" + CurrentServerName() +
           " eventServer=" + tostring(OnEventServer());
}

void LogDebugState() {
    print("[goalmas][DBG] " + DebugStateLine());
}

// Everything a support report needs, as one pasteable block.
void CopyDebugLog() {
    string text = "[goalmas][DBG] " + DebugStateLine() + "\n";
    text += "[goalmas][LOG] status: " + g_status + "\n";
    text += "[goalmas][LOG] server test: " + g_selfTestResult + "\n";
    for (uint i = 0; i < g_debugErrors.Length; i++) {
        text += "[goalmas][ERR] " + g_debugErrors[i] + "\n";
    }
    IO::SetClipboard(text);
    g_copyStatus = "Copied " + tostring(g_debugErrors.Length) + " error line(s) to clipboard.";
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

    // Answers "is it working right now?" without reading the log.
    int detectedNow = DetectGoalHuntDay();
    bool serverOk = (S_SyncMode == 2 && g_lastSyncOk);
    int syncAge = int(Time::Stamp) - g_lastSyncStamp;
    TextTone(serverOk ? Emerald() : Crimson(),
             serverOk ? Icons::CheckCircle + "  SERVER ONLINE" : Icons::Info + "  SERVER NOT CONFIRMED");
    UI::Text("  HTTP " + tostring(g_lastSyncHttp) + "   last sync " +
             (g_lastSyncStamp > 0 ? tostring(syncAge) + "s ago" : "never") +
             "   board rows " + tostring(g_boardCount));
    TextTone(detectedNow > 0 ? Emerald() : TextMuted(),
             detectedNow > 0 ? Icons::CheckCircle + "  GOAL HUNT MAP: DAY " + tostring(detectedNow)
                             : Icons::Info + "  NO GOAL HUNT MAP DETECTED");
    UI::Text("  event server: " + tostring(OnEventServer()) +
             "   playable now: " + tostring(detectedNow > 0 ? DayPlayableNow(detectedNow) : false));
    UI::Text("  server test: " + g_selfTestResult);
    UI::Separator();

    UI::Text("VERSION / VIEW");
    UI::Text("  version: 0.4.3-dev");
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
    if (UI::Button("Copy log to clipboard")) CopyDebugLog();
    UI::SetItemTooltip("Copies state, status, server test and all error lines as one pasteable block.");
    if (g_copyStatus.Length > 0) UI::TextDisabled(g_copyStatus);
    UI::SameLine(0, 6);
    if (UI::Button("Test server")) startnew(SelfTestServer);
    UI::SetItemTooltip("Sends one GET to the worker root and shows OK/FAIL above.");
    UI::SameLine(0, 6);
    if (UI::Button("Log state to Openplanet.log")) LogDebugState();
    UI::SameLine(0, 6);
    UI::BeginDisabled(g_syncing);
    if (UI::Button("Run sync now")) SyncNow();
    UI::EndDisabled();
    UI::SameLine(0, 6);
    if (UI::Button("Close")) g_showDebug = false;

    UI::End();
}
