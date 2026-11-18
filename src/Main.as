// goaladvent Calendar & Bounty - entry points.
// Windows stay closed until the player opens them from the Openplanet menu.

// Dev-only helper: the local QA script drops this marker file when new sources
// are ready. The plugin reloads itself so no keyboard/menu interaction is
// needed while iterating on the UI. The file is deleted immediately.
const string AGENT_RELOAD_MARKER = "C:/Users/tomekdot/Openplanet4/Plugins/goaladvent-dev/.agent-reload";
Meta::Plugin@ g_selfPlugin;

void Main() {
    @g_selfPlugin = Meta::ExecutingPlugin();
    startnew(AgentReloadLoop);

    LoadProgress();

    // Zero-setup sync: a baked or configured worker URL wins over offline mode.
    if (S_SyncMode == 0 && ApiUrl().Length > 0) S_SyncMode = 2;

    if (S_ShowOnStart) g_showCalendar = true;

    if (S_SyncMode == 1) {
        WriteFolderFile();
        RefreshFolderBoard();
    } else if (S_SyncMode == 2) {
        startnew(SyncState);
    }

    startnew(AutoSyncLoop);

    // No startup banner: the window opens itself when S_ShowOnStart is on.
    // Banners are reserved for in-game events (completed day, bounty taken).

    print("[goaladvent] Loaded: " + tostring(DAY_COUNT) + " days, goal " +
          tostring(GOAL_CP) + " CP, sync mode " + tostring(S_SyncMode) + ".");
    if (S_Debug) LogDebugState();
}

void OnDisabled() {
    SaveProgress();
}

// Reload on demand from the local QA script. Sleeping in a coroutine keeps
// this off the render thread; no Openplanet menu clicks are required.
void AgentReloadLoop() {
    while (true) {
        sleep(1000);
        if (!IO::FileExists(AGENT_RELOAD_MARKER)) continue;
        IO::Delete(AGENT_RELOAD_MARKER);
        if (g_selfPlugin is null) continue;
        print("[goaladvent] Reload requested by local QA.");
        Meta::ReloadPlugin(g_selfPlugin);
        return;
    }
}

// Background leaderboard refresh - never blocks the game loop.
void AutoSyncLoop() {
    while (true) {
        sleep(uint64(SYNC_INTERVAL_SEC) * 1000);
        if (!S_AutoSync) continue;
        if (S_SyncMode == 1) {
            RefreshFolderBoard();
        } else if (S_SyncMode == 2) {
            SyncState();
        }
    }
}

void Update(float dt) {
    if (g_bannerTimer > 0.0f) g_bannerTimer -= dt / 1000.0f;
    if (g_openAnimActive) {
        g_openAnimTimer -= dt / 1000.0f;
        if (g_openAnimTimer <= 0.0f) {
            g_openAnimTimer = 0.0f;
            g_openAnimActive = false;
        }
    }
    TrackGoalHunt(dt);
}

void Render() {
    RefreshPalette();   // overlays use the same theme colours as the dashboard
    RenderBanner();
    RenderOpenAnimation();
    RenderGoalHuntHud();
    if (S_Debug) RenderDebugWindow();
}

void RenderInterface() {
    // All panels are tabs of one dashboard; the menu controls its visibility.
    if (g_showCalendar) RenderDashboard();
}

void RenderMenu() {
    if (UI::MenuItem(Icons::Calendar + " GoalAdvent 2026", "", g_showCalendar)) {
        g_showCalendar = !g_showCalendar;
    }
    UI::SetItemTooltip("Open the GoalAdvent 2026 dashboard | calendar, bounties and leaderboard.");
    if (S_Debug && UI::MenuItem(Icons::Info + " Debug", "", g_showDebug)) {
        g_showDebug = !g_showDebug;
    }
}
