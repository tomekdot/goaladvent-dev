// goalmas 2026 - Obsidian / Carbon Minimal ImGui layer.
// Only APIs verified against OpenplanetCore.json (1.29.14) are used.
// Game state, persistence and sync live in the other .as files.

bool g_confirmReset = false;
int g_activeTab = 0;   // 0 Calendar, 1 Leaderboard, 2 Live feed, 3 Grand finale
bool g_windowSizeApplied = false;

// ---------------------------------------------------------------------------
// Carbon palette - monochrome base, surgical accents only
// ---------------------------------------------------------------------------
vec4 Gold()      { return vec4(0.93, 0.82, 0.55, 1.00); }
vec4 Emerald()   { return vec4(0.36, 0.78, 0.52, 1.00); }
vec4 Crimson()   { return vec4(0.78, 0.32, 0.34, 1.00); }
vec4 Purple()    { return vec4(0.66, 0.60, 0.88, 1.00); }
vec4 Navy()      { return vec4(0.20, 0.24, 0.32, 1.00); }
vec4 CardBg()    { return vec4(0.082, 0.082, 0.102, 1.00); }
vec4 InnerBg()   { return vec4(0.105, 0.105, 0.130, 1.00); }
vec4 Silver()    { return vec4(0.72, 0.74, 0.78, 1.00); }
vec4 Bronze()    { return vec4(0.62, 0.50, 0.38, 1.00); }
vec4 Teal()      { return vec4(0.45, 0.62, 0.70, 1.00); }
vec4 DimNavy()   { return vec4(0.095, 0.095, 0.12, 1.00); }
vec4 TextMain()  { return vec4(0.92, 0.92, 0.95, 1.00); }
vec4 TextMuted() { return vec4(0.55, 0.55, 0.62, 1.00); }
vec4 TileBg()    { return vec4(0.095, 0.095, 0.12, 1.00); }
vec4 TileSelectedBg() { return vec4(0.14, 0.14, 0.18, 1.00); }
vec4 IceBlue()   { return vec4(0.92, 0.93, 0.96, 1.00); }

vec4 Tone(vec4 col) {
    return vec4(col.x * 0.38, col.y * 0.38, col.z * 0.38, 1.00);
}

vec4 Lift(vec4 col) {
    return vec4(col.x + 0.08, col.y + 0.08, col.z + 0.08, 1.00);
}

void TextTone(const vec4 &in col, const string &in text) {
    UI::PushStyleColor(UI::Col::Text, col);
    UI::Text(text);
    UI::PopStyleColor();
}

void DrawDot(vec2 pos, float radius, vec4 col) {
    UI::GetWindowDrawList().AddCircleFilled(pos, radius, col, 8);
}

// Short white rule before an UPPERCASE section title.
// Openplanet's AddRectFilled takes (x, y, width, height) - NOT (x1, y1, x2, y2).
void DrawSectionHeader(const string &in title) {
    vec2 p = UI::GetCursorScreenPos();
    UI::GetWindowDrawList().AddRectFilled(
        vec4(p.x, p.y + 2.0f, 3.0f, 13.0f),
        vec4(0.88, 0.88, 0.92, 1.00));
    UI::Dummy(vec2(12, 0));
    UI::SameLine(0, 0);
    TextTone(TextMuted(), title);
    UI::Dummy(vec2(0, 5));
}

// One compact monitor-style card: square icon box, small label, clear value.
void DrawStatCard(const string &in icon, const string &in label,
                  const string &in value, vec4 accent) {
    UI::PushStyleColor(UI::Col::ChildBg, InnerBg());
    UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(10, 7));
    UI::PushStyleVar(UI::StyleVar::ScrollbarSize, 0.0f);
    int flags = UI::WindowFlags::NoScrollbar | UI::WindowFlags::NoScrollWithMouse;
    if (UI::BeginChild("##stat" + label + icon, vec2(0, 64), UI::ChildFlags::Borders, flags)) {
        vec2 start = UI::GetCursorPos();
        vec2 screen = UI::GetCursorScreenPos();

        // The card is 64 px tall with 7 px vertical padding, leaving 50 px of
        // content. A 36 px box centred in it starts 7 px below the content top.
        const float boxSize = 36.0f;
        const float boxTop = 7.0f;
        UI::GetWindowDrawList().AddRectFilled(
            vec4(screen.x, screen.y + boxTop, boxSize, boxSize), Tone(accent), 3.0f);

        float iconW = UI::MeasureString(icon, null, 17.0f).x;
        UI::SetCursorPos(vec2(start.x + (boxSize - iconW) * 0.5f,
                              start.y + boxTop + (boxSize - 17.0f) * 0.5f));
        UI::PushFontSize(17.0f);
        TextTone(accent, icon);
        UI::PopFontSize();

        // 14 px clear gap after the box; the two text lines are centred as a
        // block against the same 50 px content height.
        float textX = start.x + boxSize + 14.0f;
        UI::SetCursorPos(vec2(textX, start.y + 9.0f));
        TextTone(TextMuted(), label);
        UI::SetCursorPos(vec2(textX, start.y + 26.0f));
        TextTone(TextMain(), value);
    }
    UI::EndChild();
    UI::PopStyleVar(2);
    UI::PopStyleColor();
}

// ---------------------------------------------------------------------------
// Dashboard style
// ---------------------------------------------------------------------------
void PushDashboardStyle() {
    UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(12, 10));
    UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(8, 5));
    UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(8, 4));
    UI::PushStyleVar(UI::StyleVar::WindowRounding, 6.0f);
    UI::PushStyleVar(UI::StyleVar::ChildRounding, 5.0f);
    UI::PushStyleVar(UI::StyleVar::FrameRounding, 4.0f);
    UI::PushStyleVar(UI::StyleVar::GrabRounding, 4.0f);
    UI::PushStyleVar(UI::StyleVar::TabRounding, 4.0f);
    UI::PushStyleVar(UI::StyleVar::ChildBorderSize, 1.0f);
    UI::PushStyleVar(UI::StyleVar::FrameBorderSize, 1.0f);

    UI::PushStyleColor(UI::Col::WindowBg, vec4(0.055, 0.055, 0.067, 0.98));
    UI::PushStyleColor(UI::Col::ChildBg, CardBg());
    UI::PushStyleColor(UI::Col::FrameBg, InnerBg());
    UI::PushStyleColor(UI::Col::Border, vec4(0.16, 0.16, 0.20, 1.00));
    UI::PushStyleColor(UI::Col::TabActive, vec4(0.13, 0.13, 0.16, 1.00));
    UI::PushStyleColor(UI::Col::TabSelected, vec4(0.13, 0.13, 0.16, 1.00));
    UI::PushStyleColor(UI::Col::TabHovered, vec4(0.17, 0.17, 0.21, 1.00));
    UI::PushStyleColor(UI::Col::TableHeaderBg, InnerBg());
    UI::PushStyleColor(UI::Col::Button, vec4(0.11, 0.11, 0.14, 1.00));
    UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.17, 0.17, 0.21, 1.00));
    UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.21, 0.21, 0.26, 1.00));
    UI::PushStyleColor(UI::Col::Text, TextMain());
    UI::PushStyleColor(UI::Col::TextDisabled, TextMuted());
}

void PopDashboardStyle() {
    UI::PopStyleColor(13);
    UI::PopStyleVar(10);
}

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------
void RenderTopBar() {
    TextTone(TextMain(), Icons::SnowflakeO + "  goalmas 2026");

    // Title and the three small buttons share ONE row. SameLine first, then an
    // absolute X on that row, otherwise ImGui drops the buttons to a new line.
    UI::SameLine(0, 0);
    UI::SetCursorPosX(UI::GetWindowSize().x - 138.0f);

    UI::BeginDisabled(g_syncing);
    if (UI::Button(Icons::Refresh, vec2(28, 24))) SyncNow();
    UI::SetItemTooltip(g_syncing ? "Sync in progress..." : "Refresh results from the event server.");
    UI::EndDisabled();
    UI::SameLine(0, 4);
    if (UI::Button(Icons::FloppyO, vec2(28, 24))) {
        SaveProgress();
        g_status = "Progress saved locally.";
    }
    UI::SetItemTooltip("Save progress to this PC.");
    UI::SameLine(0, 10);
    UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.38, 0.12, 0.14, 1.00));
    if (UI::Button(Icons::Trash, vec2(28, 24))) {
        if (g_confirmReset) {
            ResetProgress();
            SaveProgress();
            g_confirmReset = false;
            g_status = "Local progress reset.";
        } else {
            g_confirmReset = true;
        }
    }
    UI::SetItemTooltip(g_confirmReset ? "Press again to confirm - this clears local progress."
                                      : "Reset local progress (press twice).");
    UI::PopStyleColor();
    UI::SameLine(0, 8);
    if (UI::Button(Icons::Cog, vec2(28, 24))) g_showSettings = !g_showSettings;
    UI::SetItemTooltip("Open goalmas settings - theme and options.");
    UI::Separator();
}

// ---------------------------------------------------------------------------
// Sidebar
// ---------------------------------------------------------------------------
void SidebarTab(int id, const string &in icon, const string &in label) {
    bool active = (g_activeTab == id);
    UI::PushStyleColor(UI::Col::Button, active ? vec4(0.13, 0.13, 0.16, 1.00) : vec4(0, 0, 0, 0));
    UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.15, 0.15, 0.19, 1.00));
    UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.19, 0.19, 0.23, 1.00));
    UI::PushStyleColor(UI::Col::Text, active ? TextMain() : TextMuted());
    UI::PushStyleVar(UI::StyleVar::FrameBorderSize, active ? 1.0f : 0.0f);
    UI::PushStyleColor(UI::Col::Border, active ? vec4(0.30, 0.30, 0.36, 1.00) : vec4(0, 0, 0, 0));
    // Left-aligned menu: icons and labels start at the same x on every row.
    UI::PushStyleVar(UI::StyleVar::ButtonTextAlign, vec2(0.0f, 0.5f));
    UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(12.0f, 4.0f));
    if (UI::Button(icon + "    " + label, vec2(-1, 32))) {
        g_activeTab = id;
        g_confirmReset = false;
    }
    UI::PopStyleVar(2);
    UI::PopStyleColor();
    UI::PopStyleVar();
    UI::PopStyleColor(4);
}

void RenderSidebar() {
    UI::PushStyleColor(UI::Col::ChildBg, CardBg());
    if (UI::BeginChild("##goalmasSidebar", vec2(175, -36), UI::ChildFlags::Borders)) {
        SidebarTab(0, Icons::Calendar, "Calendar");
        SidebarTab(1, Icons::Trophy, "Leaderboard");
        SidebarTab(2, Icons::Rss, "Live feed");
        SidebarTab(3, Icons::Star, "Grand finale");

        float remain = UI::GetContentRegionAvail().y - 78.0f;
        if (remain > 0) UI::Dummy(vec2(0, remain));

        TextTone(TextMuted(), "PROGRESS   " + tostring(OpenedCount()) + "/" + tostring(DAY_COUNT));
        UI::PushStyleColor(UI::Col::FrameBg, vec4(0.13, 0.13, 0.16, 1.00));
        UI::PushStyleColor(UI::Col::PlotHistogram, vec4(0.90, 0.90, 0.94, 1.00));
        UI::ProgressBar(float(OpenedCount()) / float(DAY_COUNT), vec2(-1, 4), "");
        UI::PopStyleColor(2);
        UI::Dummy(vec2(0, 6));
        // The sidebar describes the selected day; connection status belongs in
        // the footer only. Green is reserved for a playable Goal Hunt day.
        if (IsOffDay(g_selectedDay)) {
            TextTone(Purple(), Icons::Circle + "  PURSUIT NIGHT");
        } else if (!DayUnlocked(g_selectedDay)) {
            TextTone(TextMuted(), Icons::Circle + "  LOCKED DAY");
        } else {
            TextTone(Emerald(), Icons::Circle + "  GOAL HUNT DAY");
        }
    }
    UI::EndChild();
    UI::PopStyleColor();
}

// ---------------------------------------------------------------------------
// Calendar grid
// ---------------------------------------------------------------------------
// One dark tile per day; state is a small accent dot, never a coloured block.
vec4 DayAccent(int day) {
    if (day == DAY_COUNT) return Gold();
    if (IsOffDay(day)) return Purple();
    if (IsPremiereDay(day)) return Crimson();
    if (g_opened[day - 1]) return Emerald();
    if (DayPlayableNow(day)) return Teal();
    return vec4(0.30, 0.30, 0.36, 1.00);
}

string DayTileIcon(int day) {
    if (day == DAY_COUNT) return Icons::Trophy;
    if (IsOffDay(day)) return Icons::MoonO;
    if (IsPremiereDay(day)) return Icons::Star;
    if (g_opened[day - 1]) return Icons::CheckCircle;
    if (DayPlayableNow(day)) return Icons::FlagCheckered;
    return Icons::Gift;
}

vec4 MoonTint(int pct) {
    float t = float(pct) / 100.0f;
    return vec4(0.42 + 0.50 * t, 0.44 + 0.46 * t, 0.52 + 0.38 * t, 1.00);
}

string OffDaysText() {
    string text = "";
    for (uint i = 0; i < g_offDays.Length; i++) {
        if (i > 0) text += ", ";
        text += tostring(g_offDays[i]);
    }
    return text;
}

// Short status keeps the tile centred; no repeated "WAIT" on 20 tiles.
string DayTileShort(int day) {
    string num = day < 10 ? "0" + tostring(day) : tostring(day);
    if (day == DAY_COUNT) return num + " FIN";
    if (IsOffDay(day)) return num + " MP";
    if (IsPremiereDay(day)) return num + " x2";
    if (g_opened[day - 1]) return num + " OK";
    if (DayPlayableNow(day)) return num + " GO";
    return num;   // locked: the number alone is enough
}

bool DrawCenteredDayTile(int day, const string &in icon, const string &in label,
                         const string &in moonLine, vec4 bgCol, vec4 textCol,
                         vec4 accent, bool isSelected, float tileW) {
    UI::PushStyleVar(UI::StyleVar::FrameBorderSize, isSelected ? 1.5f : 1.0f);
    UI::PushStyleColor(UI::Col::Border, isSelected ? IceBlue() : vec4(0.16, 0.16, 0.20, 1.00));
    UI::PushStyleColor(UI::Col::Button, bgCol);
    UI::PushStyleColor(UI::Col::ButtonHovered, Lift(bgCol));
    UI::PushStyleColor(UI::Col::ButtonActive, Lift(Lift(bgCol)));
    UI::PushStyleColor(UI::Col::Text, textCol);

    // The button carries only its ID. Its two lines are drawn separately so
    // the short icon is centred on the tile, not on the wider status text.
    bool clicked = UI::Button("##goalmastile" + tostring(day), vec2(tileW, 60));
    vec4 r = UI::GetItemRect();
    float cx = r.x + r.z * 0.5f;
    float iconW = UI::MeasureString(icon, null, 15.0f).x;
    float labelW = UI::MeasureString(label, null, 13.0f).x;
    UI::GetWindowDrawList().AddText(vec2(cx - iconW * 0.5f, r.y + 7.0f),
                                    textCol, icon, null, 15.0f);
    UI::GetWindowDrawList().AddText(vec2(cx - labelW * 0.5f, r.y + 28.0f),
                                    textCol, label, null, 13.0f);

    // Illumination sits in the top-right corner on its own, so the short status
    // line can never push the percentage past the right edge of the tile.
    float pctW = UI::MeasureString(moonLine, null, 11.0f).x;
    UI::GetWindowDrawList().AddText(vec2(r.x + r.z - pctW - 6.0f, r.y + 4.0f),
                                    TextMuted(), moonLine, null, 11.0f);
    DrawDot(vec2(r.x + 5.0f, r.y + 5.0f), 2.5f, accent);

    UI::PopStyleColor(5);
    UI::PopStyleVar();
    return clicked;
}

void RenderDayGrid() {
    UI::TextDisabled("Pursuit rest days: " + OffDaysText() + "   |   premiere x2 points");
    if (S_ShowTips) {
        UI::TextWrapped("Tip: play #" + tostring(DAY_COUNT) + " Goal Hunt on the event server (" +
                        tostring(GOAL_CP) + " CP/run).");
    }

    // Absolute column positions fill the panel edge to edge. SameLine() left a
    // 20 px unused strip after the fifth column because its spacing stacked
    // with the fixed 24 px deduction.
    vec2 origin = UI::GetCursorPos();
    float availW = UI::GetContentRegionAvail().x;
    const float spacing = 6.0f;
    const float tileH = 60.0f;
    float tileW = (availW - 4.0f * spacing) / 5.0f;
    if (tileW < 48.0f) tileW = 48.0f;

    for (int day = 1; day <= DAY_COUNT; day++) {
        int col = (day - 1) % 5;
        int row = (day - 1) / 5;
        UI::SetCursorPos(vec2(origin.x + col * (tileW + spacing),
                              origin.y + row * (tileH + spacing)));

        vec4 textCol = (day == DAY_COUNT || IsPremiereDay(day)) ? Gold() : TextMain();
        string moonLine = tostring(MoonIlluminationPct(day)) + "%";
        vec4 bg = (day == g_selectedDay) ? TileSelectedBg() : TileBg();
        if (DrawCenteredDayTile(day, DayTileIcon(day), DayTileShort(day), moonLine,
                                bg, textCol, DayAccent(day), day == g_selectedDay, tileW)) {
            g_selectedDay = day;
            g_confirmReset = false;
        }
        UI::SetItemTooltip(MoonPhaseName(day) + " - " +
                           tostring(MoonIlluminationPct(day)) + "% illumination");
    }
    // SetCursorPos() past the last tile extends the child boundary, so ImGui
    // requires an item afterwards - otherwise EndChild() throws an assertion.
    UI::SetCursorPos(vec2(origin.x, origin.y + 5.0f * (tileH + spacing)));
    UI::Dummy(vec2(0, 1));
}

// ---------------------------------------------------------------------------
// Day details - compact monitor cards
// ---------------------------------------------------------------------------
void RenderDayDetails() {
    int day = g_selectedDay;
    if (day < 1 || day > DAY_COUNT) day = 1;

    bool locked = !IsOffDay(day) && !DayUnlocked(day);

    TextTone(TextMain(), "DAY " + tostring(day) + "  -  " + g_titles[day - 1]);
    string status = "Available";
    vec4 statusCol = Emerald();
    if (locked) {
        status = "Locked until Dec " + tostring(day);
        statusCol = TextMuted();
    } else if (g_opened[day - 1]) {
        status = "Completed";
    } else if (IsOffDay(day)) {
        status = "Pursuit rest day";
        statusCol = Purple();
    } else if (IsPremiereDay(day)) {
        status = "Premiere - double points";
        statusCol = Gold();
    } else if (!DayPlayableNow(day)) {
        status = "Waiting for the event";
        statusCol = TextMuted();
    }
    TextTone(statusCol, status);
    UI::Dummy(vec2(0, 4));

    DrawStatCard(Icons::MoonO, "MOON PHASE",
                 MoonPhaseName(day) + "  " + tostring(MoonIlluminationPct(day)) + "%",
                 MoonTint(MoonIlluminationPct(day)));
    UI::Dummy(vec2(0, 5));

    if (IsOffDay(day)) {
        DrawStatCard(Icons::MoonO, "DAY MODE", "Pursuit Night (ManiaPlanet)", Purple());
        UI::Dummy(vec2(0, 5));
        DrawStatCard(Icons::CheckCircle, "STREAK STATUS", "Protected - No Race", Emerald());
    } else {
        DrawStatCard(Icons::FlagCheckered, "GOAL TARGET",
                     "Catch " + tostring(GOAL_CP) + " CP   Best " + tostring(g_bests[day - 1]), Teal());
        UI::Dummy(vec2(0, 5));
        DrawStatCard(Icons::Crosshairs, "BOUNTY RECORD",
                     tostring(g_bountyCp[day - 1]) + " CP  -  " + g_bountyHolder[day - 1], Gold());
        UI::Dummy(vec2(0, 5));
        DrawStatCard(Icons::Star, "YOUR BADGES", BadgeSummary(), Silver());
    }
    if (locked) {
        UI::TextDisabled("This gift opens on December " + tostring(day) + ".");
    } else {
        UI::TextWrapped(g_hints[day - 1]);
    }

    if (g_confirmReset) TextTone(Crimson(), "Press the trash icon again to reset local progress.");
    else if (g_status.Length > 0) UI::TextDisabled(g_status);

    // Pin the action row 12 px above the bottom edge of the details card.
    const float rowH = 34.0f;
    float targetY = UI::GetWindowSize().y - 12.0f - rowH;
    float curY = UI::GetCursorPos().y;
    if (targetY > curY) UI::SetCursorPosY(targetY);

    if (locked || IsOffDay(day)) {
        UI::PushStyleColor(UI::Col::Button, vec4(0.11, 0.11, 0.14, 1.00));
        UI::PushStyleColor(UI::Col::Text, TextMuted());
        UI::Button(locked ? "AVAILABLE DEC " + tostring(day) : "Pursuit Night - No Race", vec2(-1, rowH));
        UI::PopStyleColor(2);
        return;
    }

    // One white CTA is the only high-contrast element in the whole dashboard.
    // Width -96 leaves exactly 8 px gap + 88 px Sync button on the same row.
    UI::PushStyleColor(UI::Col::Button, vec4(0.95, 0.95, 0.97, 1.00));
    UI::PushStyleColor(UI::Col::ButtonHovered, vec4(1.00, 1.00, 1.00, 1.00));
    UI::PushStyleColor(UI::Col::Text, vec4(0.06, 0.06, 0.08, 1.00));
    string action = S_TestMode ? "SUBMIT TEST CP (12)" : "OPEN DAY " + tostring(day);
    if (UI::Button(action, vec2(-96, rowH))) {
        if (S_TestMode) {
            RequestCpSubmit(day, 12);
            g_status = "Test CP submitted for day " + tostring(day) + ".";
        } else {
            g_status = "Join #" + tostring(day) + " Goal Hunt on the event server - CP count automatically.";
        }
    }
    UI::SetItemTooltip("Join #" + tostring(day) + " Goal Hunt; reach " + tostring(GOAL_CP) +
                       " CP in one run to complete this day.");
    UI::PopStyleColor(3);
    UI::SameLine(0, 8);
    UI::BeginDisabled(g_syncing);
    if (UI::Button(Icons::Refresh + "  Sync", vec2(88, rowH))) SyncNow();
    UI::EndDisabled();
}

// ---------------------------------------------------------------------------
// Workspace panes
// ---------------------------------------------------------------------------
void RenderCalendarTab() {
    float width = UI::GetContentRegionAvail().x;
    float leftW = width * 0.58f;
    float rightW = width - leftW - 8;

    if (UI::BeginChild("##goalmasCalendarGrid", vec2(leftW, 0), UI::ChildFlags::Borders)) {
        DrawSectionHeader("ADVENT CALENDAR");
        RenderDayGrid();
    }
    UI::EndChild();
    UI::SameLine(0, 8);
    if (UI::BeginChild("##goalmasDayDetailsCard", vec2(rightW, 0), UI::ChildFlags::Borders)) {
        DrawSectionHeader("DAY DETAILS");
        RenderDayDetails();
    }
    UI::EndChild();
}

void RenderLeaderboardTab() {
    DrawSectionHeader("LEADERBOARD");
    if (g_boardNames.Length == 0) {
        UI::TextDisabled("No entries yet. They appear after the first submitted run.");
        UI::BeginDisabled(g_syncing);
        if (UI::Button(Icons::Refresh + " Refresh")) SyncNow();
        UI::EndDisabled();
        return;
    }

    int flags = UI::TableFlags::RowBg | UI::TableFlags::BordersInnerH | UI::TableFlags::PadOuterX;
    if (UI::BeginTable("##goalmasBoardTable", 4, flags)) {
        UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 42);
        UI::TableSetupColumn("Player", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("Points", UI::TableColumnFlags::WidthFixed, 96);
        UI::TableSetupColumn("Bounties", UI::TableColumnFlags::WidthFixed, 96);
        UI::TableHeadersRow();
        for (uint i = 0; i < g_boardNames.Length; i++) {
            UI::TableNextRow();
            bool mine = g_boardNames[i] == LocalName();
            if (mine) {
                UI::TableSetBgColor(UI::TableBgTarget::RowBg0, Tone(Navy()));
                UI::TableSetBgColor(UI::TableBgTarget::RowBg1, Tone(Navy()));
            } else if (i < 3) {
                vec4 medal = Bronze();
                if (i == 0) medal = Gold();
                else if (i == 1) medal = Silver();
                UI::TableSetBgColor(UI::TableBgTarget::RowBg0, Tone(medal));
                UI::TableSetBgColor(UI::TableBgTarget::RowBg1, Tone(medal));
            }
            UI::TableSetColumnIndex(0);
            if (i < 3) TextTone(i == 0 ? Gold() : (i == 1 ? Silver() : Bronze()), tostring(int(i) + 1));
            else UI::Text(tostring(int(i) + 1));
            UI::TableSetColumnIndex(1);
            if (mine) TextTone(Gold(), g_boardNames[i] + "  (you)");
            else UI::Text(g_boardNames[i]);
            UI::TableSetColumnIndex(2);
            TextTone(Gold(), tostring(g_boardPoints[i]));
            UI::TableSetColumnIndex(3);
            UI::Text(tostring(g_boardBounties[i]));
        }
        UI::EndTable();
    }
    UI::BeginDisabled(g_syncing);
    if (UI::Button(Icons::Refresh + " Refresh leaderboard")) SyncNow();
    UI::EndDisabled();
}

void RenderFeedTab() {
    DrawSectionHeader("LIVE FEED");
    if (g_liveFeed.Length == 0) {
        UI::TextDisabled("Nothing here yet - complete a day or take a bounty.");
        UI::BeginDisabled(g_syncing);
        if (UI::Button(Icons::Refresh + " Refresh")) SyncNow();
        UI::EndDisabled();
        return;
    }
    int flags = UI::TableFlags::RowBg | UI::TableFlags::BordersInnerH | UI::TableFlags::PadOuterX;
    if (UI::BeginTable("##goalmasFeedTable", 2, flags)) {
        UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 42);
        UI::TableSetupColumn("Event", UI::TableColumnFlags::WidthStretch);
        UI::TableHeadersRow();
        for (uint i = 0; i < g_liveFeed.Length; i++) {
            UI::TableNextRow();
            if (i == 0) {
                UI::TableSetBgColor(UI::TableBgTarget::RowBg0, Tone(Gold()));
                UI::TableSetBgColor(UI::TableBgTarget::RowBg1, Tone(Gold()));
            }
            UI::TableSetColumnIndex(0);
            UI::Text(tostring(int(i) + 1));
            UI::TableSetColumnIndex(1);
            UI::TextWrapped(g_liveFeed[i]);
        }
        UI::EndTable();
    }
    UI::BeginDisabled(g_syncing);
    if (UI::Button(Icons::Refresh + " Refresh feed")) SyncNow();
    UI::EndDisabled();
}

void RenderFinaleTab() {
    DrawSectionHeader("GRAND FINALE");
    TextTone(Gold(), Icons::Trophy + "  THE BIG FINALE");
    UI::TextWrapped("Final code: " + FinalCode());
    UI::ProgressBar(float(OpenedCount()) / float(DAY_COUNT), vec2(-1, 10),
                    tostring(OpenedCount()) + "/" + tostring(DAY_COUNT) + " Gifts");
    UI::Dummy(vec2(0, 8));
    DrawStatCard(Icons::Trophy, "RESULT", "Score (best 15) " + tostring(TotalPoints()), Gold());
    UI::Dummy(vec2(0, 5));
    DrawStatCard(Icons::Crosshairs, "BOUNTIES", tostring(g_bountiesWon) + "   Badges: " + BadgeSummary(), Emerald());
    if (OpenedCount() < DAY_COUNT) {
        UI::TextDisabled("Not every gift was opened - the raffle ticket needs 25/25.");
    } else {
        TextTone(Emerald(), Icons::CheckCircle + "  Raffle ticket earned.");
    }
    UI::TextWrapped("The finale stays open until " + tostring(FINALE_GRACE_DAYS) +
                    " January. The raffle is drawn after the window closes.");
}

// ---------------------------------------------------------------------------
// Dashboard and footer
// ---------------------------------------------------------------------------
void RenderFooter() {
    UI::Separator();
    // Footer = connection status, sidebar = day mode. No duplicate OFFLINE.
    string link = S_SyncMode == 0 ? "OFFLINE" : "CONNECTED";
    vec4 linkCol = S_SyncMode == 0 ? TextMuted() : Emerald();
    TextTone(linkCol, Icons::Circle + "  " + link + "  |  goalmas 2026");
    UI::SameLine(0, 0);
    string right = "BEST 15: " + tostring(ScoreDays()) + " PTS  |  " +
                   tostring(OpenedCount()) + "/25 GIFTS";
    float w = UI::MeasureString(right, null, 0.0f, 0.0f).x;
    if (w < 1.0f) w = 220.0f;
    UI::SetCursorPosX(UI::GetWindowSize().x - w - 16.0f);
    TextTone(TextMuted(), right);
}

void RenderWorkspace() {
    UI::PushStyleColor(UI::Col::ChildBg, vec4(0.055, 0.055, 0.067, 1.00));
    if (UI::BeginChild("##goalmasWorkspace", vec2(0, -36), UI::ChildFlags::Borders)) {
        if (g_activeTab == 0) RenderCalendarTab();
        else if (g_activeTab == 1) RenderLeaderboardTab();
        else if (g_activeTab == 2) RenderFeedTab();
        else RenderFinaleTab();
    }
    UI::EndChild();
    UI::PopStyleColor();
}

void RenderSettingsWindow() {
    if (!g_showSettings) return;

    int flags = UI::WindowFlags::AlwaysAutoResize;
    if (!UI::Begin(Icons::Cog + " goalmas settings", g_showSettings, flags)) {
        UI::End();
        return;
    }

    TextTone(TextMain(), "APPEARANCE");
    UI::Separator();
    if (UI::RadioButton("Obsidian Minimal", g_Theme == UiTheme::ObsidianMinimal)) {
        g_Theme = UiTheme::ObsidianMinimal;
    }
    if (UI::RadioButton("Pursuit Native", g_Theme == UiTheme::PursuitNative)) {
        g_Theme = UiTheme::PursuitNative;
    }
    UI::TextDisabled("Switch themes live - no game restart needed.");

    UI::Dummy(vec2(0, 8));
    TextTone(TextMain(), "OPTIONS");
    UI::Separator();
    S_ShowMoonPct = UI::Checkbox("Show moon phase %", S_ShowMoonPct);
    S_ShowTips = UI::Checkbox("Show in-game tips", S_ShowTips);
    S_AutoSync = UI::Checkbox("Auto sync", S_AutoSync);

    UI::Dummy(vec2(0, 8));
    if (UI::Button("Close")) g_showSettings = false;
    UI::End();
}

void RenderDashboard() {
    if (PursuitTheme()) {
        RenderPursuitDashboard();
        RenderSettingsWindow();
        return;
    }

    // Apply once per plugin load: the saved ImGui size can be taller than a
    // 1024x768 game window and leave the footer off-screen.
    if (!g_windowSizeApplied) {
        UI::SetNextWindowSize(980, 620, UI::Cond::Always);
        UI::SetNextWindowPos(24, 40, UI::Cond::Always);
        g_windowSizeApplied = true;
    }
    if (!UI::Begin("goalmas 2026", g_showCalendar)) {
        UI::End();
        return;
    }

    PushDashboardStyle();
    RenderTopBar();
    RenderSidebar();
    UI::SameLine(0, 8);
    RenderWorkspace();
    RenderFooter();
    PopDashboardStyle();
    UI::End();

    RenderSettingsWindow();
}

// ---------------------------------------------------------------------------
// Overlays
// ---------------------------------------------------------------------------
void RenderBanner() {
    if (g_bannerTimer <= 0.0f || g_bannerText.Length == 0) return;
    int screenWidth = Display::GetWidth();
    UI::SetNextWindowPos(screenWidth / 2, 40, UI::Cond::Always, 0.5f, 0.0f);
    int flags = UI::WindowFlags::NoTitleBar | UI::WindowFlags::NoResize |
                UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoMove |
                UI::WindowFlags::NoInputs;
    UI::PushStyleColor(UI::Col::WindowBg, vec4(0.08, 0.08, 0.10, 0.94));
    if (UI::Begin("##goalmasBanner", flags)) {
        TextTone(Gold(), Icons::SnowflakeO + "  " + g_bannerText);
    }
    UI::End();
    UI::PopStyleColor();
}

void RenderGoalHuntHud() {
    if (g_activeDay <= 0 || g_activeDay > DAY_COUNT) return;
    int day = g_activeDay;
    UI::SetNextWindowPos(20, 120, UI::Cond::FirstUseEver);
    int flags = UI::WindowFlags::NoTitleBar | UI::WindowFlags::AlwaysAutoResize;
    UI::PushStyleColor(UI::Col::WindowBg, vec4(0.055, 0.055, 0.067, 0.90));
    if (UI::Begin("##goalmasGoalHuntHud", flags)) {
        TextTone(TextMain(), Icons::FlagCheckered + " #" + tostring(day) + " GOAL HUNT");
        if (IsPremiereDay(day)) TextTone(Gold(), "PREMIERE - x2 points");
        else UI::TextDisabled("Catch-up - x1 points");
        UI::Text("Goal " + tostring(GOAL_CP) + " CP   Session " + tostring(g_sessionCp) + " CP");
        UI::Text("Bounty " + tostring(g_bountyCp[day - 1]) + " CP (" + g_bountyHolder[day - 1] + ")");
        UI::Text("Your best " + tostring(g_bests[day - 1]) + " CP");
    }
    UI::End();
    UI::PopStyleColor();
}
