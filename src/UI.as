// goalmas 2026 - one ImGui layout, two colour themes.
// Only APIs verified against OpenplanetCore.json (1.29.14) are used.
// Theme.as owns every colour and radius; these wrappers read the active one.

bool g_confirmReset = false;
int g_activeTab = 0;   // 0 Calendar, 1 Leaderboard, 2 Live feed, 3 Grand finale
bool g_windowSizeApplied = false;

// ---------------------------------------------------------------------------
// Palette accessors - the layout calls these, never hard-coded colours
// ---------------------------------------------------------------------------
vec4 Gold()      { return g_palette.gold; }
vec4 Emerald()   { return g_palette.emerald; }
vec4 Crimson()   { return g_palette.crimson; }
vec4 Purple()    { return g_palette.purple; }
vec4 Navy()      { return g_palette.navy; }
vec4 CardBg()    { return g_palette.childBg; }
vec4 InnerBg()   { return g_palette.innerBg; }
vec4 Silver()    { return g_palette.silver; }
vec4 Bronze()    { return g_palette.bronze; }
vec4 Teal()      { return g_palette.teal; }
vec4 DimNavy()   { return g_palette.dimNavy; }
vec4 TextMain()  { return g_palette.text; }
// Muted text is pulled 40% toward the main text colour: labels, hints and the
// footer were too faint to read on dark and glass backgrounds.
vec4 MixCol(vec4 a, vec4 b, float t) {
    return vec4(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t,
                a.z + (b.z - a.z) * t, a.w + (b.w - a.w) * t);
}
vec4 TextMuted() { return MixCol(g_palette.textMuted, g_palette.text, 0.40f); }
vec4 TileBg()    { return g_palette.tileBg; }
vec4 TileSelectedBg() { return g_palette.tileSelectedBg; }
vec4 IceBlue()   { return g_palette.iceBlue; }

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
        g_palette.iceBlue);
    UI::Dummy(vec2(12, 0));
    UI::SameLine(0, 0);
    TextTone(MixCol(TextMuted(), TextMain(), 0.50f), title);
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

        // A button with ButtonTextAlign centres the glyph reliably. Measuring
        // an icon with MeasureString is not dependable across Openplanet fonts.
        const float boxSize = 36.0f;
        vec4 boxCol = vec4(accent.x * 0.50f, accent.y * 0.50f, accent.z * 0.50f, 1.00f);
        UI::PushStyleVar(UI::StyleVar::ButtonTextAlign, vec2(0.5f, 0.5f));
        UI::PushStyleVar(UI::StyleVar::FrameRounding, 4.0f);
        UI::PushStyleColor(UI::Col::Button, boxCol);
        UI::PushStyleColor(UI::Col::ButtonHovered, boxCol);
        UI::PushStyleColor(UI::Col::ButtonActive, boxCol);
        UI::PushStyleColor(UI::Col::Text, accent);
        UI::PushFontSize(17.0f);
        UI::Button(icon + "##statIcon" + label, vec2(boxSize, boxSize));
        UI::PopFontSize();
        UI::PopStyleColor(4);
        UI::PopStyleVar(2);

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
    UI::PushStyleVar(UI::StyleVar::WindowRounding, g_palette.windowRounding);
    UI::PushStyleVar(UI::StyleVar::ChildRounding, g_palette.childRounding);
    UI::PushStyleVar(UI::StyleVar::FrameRounding, g_palette.frameRounding);
    UI::PushStyleVar(UI::StyleVar::GrabRounding, g_palette.frameRounding);
    UI::PushStyleVar(UI::StyleVar::TabRounding, g_palette.tabRounding);
    UI::PushStyleVar(UI::StyleVar::ChildBorderSize, 1.0f);
    UI::PushStyleVar(UI::StyleVar::FrameBorderSize, 1.0f);

    UI::PushStyleColor(UI::Col::WindowBg, g_palette.windowBg);
    UI::PushStyleColor(UI::Col::ChildBg, g_palette.childBg);
    UI::PushStyleColor(UI::Col::FrameBg, g_palette.innerBg);
    UI::PushStyleColor(UI::Col::Border, g_palette.border);
    UI::PushStyleColor(UI::Col::TabActive, g_palette.buttonBg);
    UI::PushStyleColor(UI::Col::TabSelected, g_palette.buttonBg);
    UI::PushStyleColor(UI::Col::TabHovered, g_palette.buttonHover);
    UI::PushStyleColor(UI::Col::TableHeaderBg, g_palette.tableHeaderBg);
    UI::PushStyleColor(UI::Col::Button, g_palette.buttonBg);
    UI::PushStyleColor(UI::Col::ButtonHovered, g_palette.buttonHover);
    UI::PushStyleColor(UI::Col::ButtonActive, g_palette.buttonActive);
    UI::PushStyleColor(UI::Col::Text, g_palette.text);
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
    TextTone(IceBlue(), Icons::SnowflakeO);
    UI::SameLine(0, 8);
    TextTone(TextMain(), "goalmas 2026");
    UI::SameLine(0, 8);
    UI::TextDisabled("- 25 days of checkpoints, bounties and badges");

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
    UI::PushStyleColor(UI::Col::ButtonHovered, Crimson());
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
    UI::PushStyleColor(UI::Col::Button, active ? g_palette.buttonBg : vec4(0, 0, 0, 0));
    UI::PushStyleColor(UI::Col::ButtonHovered, g_palette.buttonHover);
    UI::PushStyleColor(UI::Col::ButtonActive, g_palette.buttonActive);
    UI::PushStyleColor(UI::Col::Text, active ? TextMain() : TextMuted());
    UI::PushStyleVar(UI::StyleVar::FrameBorderSize, active ? 1.0f : 0.0f);
    UI::PushStyleColor(UI::Col::Border, active ? g_palette.borderStrong : vec4(0, 0, 0, 0));
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
        UI::Separator();   // thin divider using the theme border colour

        float remain = UI::GetContentRegionAvail().y - 78.0f;
        if (remain > 0) UI::Dummy(vec2(0, remain));

        TextTone(TextMuted(), "PROGRESS   " + tostring(OpenedCount()) + "/" + tostring(DAY_COUNT));
        UI::PushStyleColor(UI::Col::FrameBg, g_palette.frameBg);
        UI::PushStyleColor(UI::Col::PlotHistogram, g_palette.text);
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
    return TextMuted();
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
    vec4 a = g_palette.purple;      // new moon
    vec4 b = g_palette.iceBlue;     // full moon
    return vec4(a.x + (b.x - a.x) * t,
                a.y + (b.y - a.y) * t,
                a.z + (b.z - a.z) * t, 1.00);
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
                         vec4 accent, bool isSelected, float tileW, float tileH) {
    UI::PushStyleVar(UI::StyleVar::FrameBorderSize, isSelected ? 1.5f : 1.0f);
    UI::PushStyleColor(UI::Col::Border, isSelected ? g_palette.borderStrong : g_palette.borderWeak);
    UI::PushStyleColor(UI::Col::Button, bgCol);
    UI::PushStyleColor(UI::Col::ButtonHovered, Lift(bgCol));
    UI::PushStyleColor(UI::Col::ButtonActive, Lift(Lift(bgCol)));
    UI::PushStyleColor(UI::Col::Text, textCol);

    // The button carries only its ID. Its lines are drawn separately so the
    // short icon stays centred and the percentage never overlaps it.
    float top = (tileH - 60.0f) * 0.5f;
    bool clicked = UI::Button("##goalmastile" + tostring(day), vec2(tileW, tileH));
    vec4 r = UI::GetItemRect();
    float cx = r.x + r.z * 0.5f;
    float iconW = UI::MeasureString(icon, null, 15.0f).x;
    float labelW = UI::MeasureString(label, null, 13.0f).x;
    UI::GetWindowDrawList().AddText(vec2(cx - iconW * 0.5f, r.y + 7.0f + top),
                                    textCol, icon, null, 15.0f);
    UI::GetWindowDrawList().AddText(vec2(cx - labelW * 0.5f, r.y + 28.0f + top),
                                    textCol, label, null, 13.0f);

    // Illumination goes on its own centred line under the status, so a narrow
    // tile can never push "45%" over the gift icon.
    float pctW = UI::MeasureString(moonLine, null, 11.0f).x;
    UI::GetWindowDrawList().AddText(vec2(cx - pctW * 0.5f, r.y + 44.0f + top),
                                    TextMuted(), moonLine, null, 11.0f);
    DrawDot(vec2(r.x + 5.0f, r.y + 5.0f), 2.5f, accent);
    if (isSelected) {
        // Thin accent underline: the selected day reads at a glance.
        UI::GetWindowDrawList().AddRectFilled(
            vec4(r.x + 10.0f, r.y + r.w - 4.0f, r.z - 20.0f, 2.0f), accent, 1.0f);
    }

    UI::PopStyleColor(5);
    UI::PopStyleVar();
    return clicked;
}

void RenderDayGrid() {
    UI::TextDisabled("Pursuit rest days: " + OffDaysText() + "   |   premiere x2 points");
    if (S_ShowTips) {
        UI::TextWrapped("Tip: play #" + tostring(g_selectedDay) + " Goal Hunt on the event server (" +
                        tostring(GOAL_CP) + " CP/run).");
    }

    // Absolute column positions fill the panel edge to edge. SameLine() left a
    // 20 px unused strip after the fifth column because its spacing stacked
    // with the fixed 24 px deduction.
    vec2 origin = UI::GetCursorPos();
    vec2 avail = UI::GetContentRegionAvail();
    const float spacing = 6.0f;
    // Height comes from the column so five rows fill it instead of stopping
    // halfway down the panel. Clamped so small windows stay readable.
    float tileH = (avail.y - 4.0f * spacing) / 5.0f;
    if (tileH < 60.0f) tileH = 60.0f;
    if (tileH > 84.0f) tileH = 84.0f;
    float tileW = (avail.x - 4.0f * spacing) / 5.0f;
    if (tileW < 48.0f) tileW = 48.0f;

    for (int day = 1; day <= DAY_COUNT; day++) {
        int col = (day - 1) % 5;
        int row = (day - 1) / 5;
        UI::SetCursorPos(vec2(origin.x + col * (tileW + spacing),
                              origin.y + row * (tileH + spacing)));

        vec4 textCol = (day == DAY_COUNT || IsPremiereDay(day)) ? Gold() : TextMain();
        string moonLine = S_ShowMoonPct ? tostring(MoonIlluminationPct(day)) + "%" : "";
        vec4 bg = (day == g_selectedDay) ? TileSelectedBg() : TileBg();
        // A subtle accent wash separates playable / completed days from the
        // locked ones without turning the whole grid into coloured blocks.
        if (g_opened[day - 1] || DayPlayableNow(day)) {
            bg = MixCol(bg, DayAccent(day), 0.15f);
        }
        if (DrawCenteredDayTile(day, DayTileIcon(day), DayTileShort(day), moonLine,
                                bg, textCol, DayAccent(day), day == g_selectedDay, tileW, tileH)) {
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
        UI::PushStyleColor(UI::Col::Button, g_palette.buttonBg);
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

    // Columns stay fully transparent - only the window and the cards tint.
    UI::PushStyleColor(UI::Col::ChildBg, g_palette.containerBg);
    if (UI::BeginChild("##goalmasCalendarGrid", vec2(leftW, 0), UI::ChildFlags::Borders)) {
        DrawSectionHeader("ADVENT CALENDAR");
        RenderDayGrid();
    }
    UI::EndChild();
    UI::PopStyleColor();
    UI::SameLine(0, 8);
    UI::PushStyleColor(UI::Col::ChildBg, g_palette.containerBg);
    if (UI::BeginChild("##goalmasDayDetailsCard", vec2(rightW, 0), UI::ChildFlags::Borders)) {
        DrawSectionHeader("DAY DETAILS");
        RenderDayDetails();
    }
    UI::EndChild();
    UI::PopStyleColor();
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
    // A 10 px bar cannot fit overlay text - keep the label on its own line.
    UI::TextDisabled("Gifts " + tostring(OpenedCount()) + " / " + tostring(DAY_COUNT));
    UI::ProgressBar(float(OpenedCount()) / float(DAY_COUNT), vec2(-1, 12), "");
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
    string link = S_SyncMode == 0 ? "Offline - progress saved on this PC"
                                  : "Connected to the event server";
    vec4 linkCol = S_SyncMode == 0 ? TextMuted() : Emerald();
    TextTone(linkCol, Icons::Circle + "  " + link);
    UI::SameLine(0, 0);
    string right = "DAY " + tostring(g_selectedDay) + "/25   BEST 15: " +
                   tostring(ScoreDays()) + " PTS   " +
                   tostring(OpenedCount()) + "/25 GIFTS";
    float w = UI::MeasureString(right, null, 13.0f, 0.0f).x + 8.0f;
    if (w < 1.0f) w = 300.0f;
    UI::SetCursorPosX(UI::GetWindowSize().x - w - 16.0f);
    TextTone(MixCol(TextMuted(), TextMain(), 0.50f), right);
}

void RenderWorkspace() {
    // No extra background layer here: stacking translucent panels would turn
    // the glass into an opaque wall.
    UI::PushStyleColor(UI::Col::ChildBg, g_palette.containerBg);
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
    if (UI::RadioButton("Transparent Glass", g_Theme == UiTheme::TransparentGlass)) {
        g_Theme = UiTheme::TransparentGlass;
    }
    UI::TextDisabled("Switch themes live - no game restart needed.");

    UI::Dummy(vec2(0, 8));
    TextTone(TextMain(), "OPTIONS");
    UI::Separator();
    if (GlassTheme()) {
        S_GlassOpacity = UI::SliderFloat("Glass Opacity", S_GlassOpacity, 0.15f, 0.80f, "%.2f");
        UI::TextDisabled("Lower = more of the game visible behind the window.");
    }
    S_ShowMoonPct = UI::Checkbox("Show moon phase %", S_ShowMoonPct);
    S_ShowTips = UI::Checkbox("Show in-game tips", S_ShowTips);
    S_AutoSync = UI::Checkbox("Auto sync", S_AutoSync);

    UI::Dummy(vec2(0, 8));
    if (UI::Button("Close")) g_showSettings = false;
    UI::End();
}

void RenderDashboard() {
    RefreshPalette();   // one layout, colours chosen by the active theme

    // Apply once per plugin load: the saved ImGui size can be taller than a
    // 1024x768 game window and leave the footer off-screen.
    if (!g_windowSizeApplied) {
        UI::SetNextWindowSize(940, 580, UI::Cond::FirstUseEver);
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
    UI::PushStyleColor(UI::Col::WindowBg, g_palette.windowBg);
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
    UI::PushStyleColor(UI::Col::WindowBg, g_palette.windowBg);
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
