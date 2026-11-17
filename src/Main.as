// goalmas Calendar & Bounty - entry points.
// Windows stay closed until the player opens them from the Openplanet menu.

void Main() {
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

    print("[goalmas] Loaded: " + tostring(DAY_COUNT) + " days, goal " +
          tostring(GOAL_CP) + " CP, sync mode " + tostring(S_SyncMode) + ".");
}

void OnDisabled() {
    SaveProgress();
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
    TrackGoalHunt(dt);
}

void Render() {
    RefreshPalette();   // overlays use the same theme colours as the dashboard
    RenderBanner();
    RenderGoalHuntHud();
}

void RenderInterface() {
    // All panels are tabs of one dashboard; the menu controls its visibility.
    if (g_showCalendar) RenderDashboard();
}

void RenderMenu() {
    if (UI::MenuItem(Icons::Calendar + " goalmas", "", g_showCalendar)) {
        g_showCalendar = !g_showCalendar;
    }
    UI::SetItemTooltip("Open the goalmas dashboard - calendar, bounties and leaderboard.");
    if (UI::MenuItem(Icons::Cog + " Settings", "", g_showSettings)) {
        g_showSettings = !g_showSettings;
    }
}
