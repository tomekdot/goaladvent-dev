// Goalmas 2026 - modern ImGui layer.
// Only functions verified in OpenplanetCore.json (1.29.14) are used here.
// Game data, save files and sync logic live in the other .as files.

bool g_confirmReset = false;

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------
vec4 Gold()      { return vec4(1.00, 0.82, 0.40, 1.00); }
vec4 Emerald()   { return vec4(0.18, 0.80, 0.45, 1.00); }
vec4 Crimson()   { return vec4(0.90, 0.22, 0.27, 1.00); }
vec4 Purple()    { return vec4(0.48, 0.37, 0.65, 1.00); }
vec4 Navy()      { return vec4(0.16, 0.30, 0.52, 1.00); }
vec4 Slate()     { return vec4(0.22, 0.24, 0.29, 1.00); }
vec4 CardBg()    { return vec4(0.11, 0.14, 0.20, 0.98); }
vec4 InnerBg()   { return vec4(0.14, 0.18, 0.26, 1.00); }
vec4 Silver()    { return vec4(0.72, 0.75, 0.82, 1.00); }
vec4 Bronze()    { return vec4(0.72, 0.45, 0.25, 1.00); }

vec4 Tone(vec4 col) {
    return vec4(col.x * 0.38, col.y * 0.38, col.z * 0.38, 1.00);
}

vec4 Pill(vec4 col) {
    return vec4(col.x * 0.55, col.y * 0.55, col.z * 0.55, 1.00);
}

void TextTone(const vec4 &in col, const string &in text) {
    UI::PushStyleColor(UI::Col::Text, col);
    UI::Text(text);
    UI::PopStyleColor();
}

// ---------------------------------------------------------------------------
// Dashboard style
// ---------------------------------------------------------------------------
void PushDashboardStyle() {
    UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(16, 14));
    UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(10, 8));
    UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(10, 6));
    UI::PushStyleVar(UI::StyleVar::FrameRounding, 8.0f);
    UI::PushStyleVar(UI::StyleVar::ChildRounding, 10.0f);
    UI::PushStyleVar(UI::StyleVar::TabRounding, 6.0f);

    UI::PushStyleColor(UI::Col::WindowBg, vec4(0.09, 0.11, 0.16, 0.96));
    UI::PushStyleColor(UI::Col::ChildBg, CardBg());
    UI::PushStyleColor(UI::Col::FrameBg, InnerBg());
    UI::PushStyleColor(UI::Col::Border, vec4(0.27, 0.31, 0.40, 1.00));
    UI::PushStyleColor(UI::Col::TabActive, Crimson());
    UI::PushStyleColor(UI::Col::TabSelected, Crimson());
    UI::PushStyleColor(UI::Col::TabHovered, vec4(0.72, 0.24, 0.29, 1.00));
    UI::PushStyleColor(UI::Col::TableHeaderBg, InnerBg());
}

void PopDashboardStyle() {
    UI::PopStyleColor(8);
    UI::PopStyleVar(6);
}

// ---------------------------------------------------------------------------
// Header card
// ---------------------------------------------------------------------------
// Badges are drawn as one wrapping text line instead of SameLine() pills:
// ImGui does not wrap SameLine() items, so pills overflowed the window.
vec4 BadgeColor(const string &in badge) {
    vec4 col = Emerald();
    string low = badge.ToLower();
    if (low.Contains("bounty") || low.Contains("final")) col = Gold();
    else if (low.Contains("pursuit")) col = Silver();
    else if (low.Contains("galaxy")) col = Navy();
    return col;
}

void RenderBadgeLine() {
    if (g_badges.Length == 0) return;

    // One wrapping, coloured text line. SameLine() items never wrap in ImGui,
    // so pills/segments overflowed the header with eight badges.
    string badges = "";
    for (uint i = 0; i < g_badges.Length; i++) {
        vec4 col = BadgeColor(g_badges[i]);
        badges += Text::FormatOpenplanetColor(vec3(col.x, col.y, col.z)) +
                  g_badges[i] + "\\$z   ";
    }
    UI::TextWrapped(badges);
}

void RenderHeaderCard() {
    UI::PushStyleColor(UI::Col::ChildBg, vec4(0.12, 0.15, 0.22, 1.00));
    if (UI::BeginChild("##GoalmasHeader", vec2(0, 150), UI::ChildFlags::Borders)) {
        TextTone(Gold(), Icons::SnowflakeO + "   GOALMAS 2026");
        UI::SetCursorPosY(UI::GetCursorPos().y - 2);
        UI::TextDisabled("Goal Hunt calendar - checkpoint bounties, badges and a free leaderboard");

        float gap = UI::GetContentRegionAvail().x - 150;
        if (gap > 8) UI::Dummy(vec2(gap, 0));
        UI::SameLine(0, 0);
        if (UI::Button(Icons::Refresh, vec2(34, 28)) && !g_syncing) SyncNow();
        UI::SameLine(0, 4);
        if (UI::Button(Icons::FloppyO, vec2(34, 28))) {
            SaveProgress();
            g_status = "Progress saved locally.";
        }
        UI::SameLine(0, 26);   // keep the destructive action away from Save
        UI::PushStyleColor(UI::Col::Button, vec4(0.45, 0.07, 0.09, 1.00));
        UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.70, 0.12, 0.14, 1.00));
        if (UI::Button(Icons::Trash, vec2(34, 28))) {
            if (g_confirmReset) {
                ResetProgress();
                SaveProgress();
                g_confirmReset = false;
                g_status = "Local progress reset.";
            } else {
                g_confirmReset = true;
            }
        }
        UI::PopStyleColor(2);

        float opened = float(OpenedCount()) / float(DAY_COUNT);
        UI::PushStyleColor(UI::Col::FrameBg, vec4(0.06, 0.09, 0.14, 1.00));
        UI::PushStyleColor(UI::Col::PlotHistogram, Gold());
        UI::PushStyleColor(UI::Col::PlotHistogramHovered, vec4(1.00, 0.90, 0.55, 1.00));
        UI::PushStyleVar(UI::StyleVar::FrameBorderSize, 1.0f);
        UI::ProgressBar(opened, vec2(-1, 20),
                        "Gifts " + tostring(OpenedCount()) + "/" + tostring(DAY_COUNT) +
                        "   |   Best 15: " + tostring(ScoreDays()) + " pts");
        UI::PopStyleVar();
        UI::PopStyleColor(3);

        if (g_confirmReset) {
            TextTone(Crimson(), "Reset all local progress? Press the trash icon again to confirm.");
        } else if (g_badges.Length == 0) {
            UI::TextDisabled("Badges: none (earn by playing!)");
        } else {
            RenderBadgeLine();
        }
    }
    UI::EndChild();
    UI::PopStyleColor();

    if (g_confirmReset && UI::Button("Cancel reset")) g_confirmReset = false;

    if (g_syncing) UI::TextDisabled("Syncing with the server...");
    else if (g_status.Length > 0) UI::TextDisabled(g_status);
}

// ---------------------------------------------------------------------------
// Calendar tab - two columns
// ---------------------------------------------------------------------------
vec4 DayTileColor(int day) {
    if (day == DAY_COUNT) return Gold();
    if (IsOffDay(day)) return Purple();
    if (IsPremiereDay(day)) return Crimson();
    if (g_opened[day - 1]) return Emerald();
    if (DayPlayableNow(day)) return vec4(0.12, 0.38, 0.46, 1.00);
    return vec4(0.14, 0.17, 0.24, 1.00);   // brighter navy - not a black hole
}

string DayTileIcon(int day) {
    if (day == DAY_COUNT) return Icons::Trophy;
    if (IsOffDay(day)) return Icons::MoonO;
    if (IsPremiereDay(day)) return Icons::Star;
    if (g_opened[day - 1]) return Icons::CheckCircle;
    if (DayPlayableNow(day)) return Icons::FlagCheckered;
    return Icons::Gift;   // a future gift, never an error X
}

// Moon brightness: dim blue-grey at new moon, warm white at full moon.
vec4 MoonTint(int pct) {
    float t = float(pct) / 100.0f;
    return vec4(0.38 + 0.62 * t, 0.43 + 0.53 * t, 0.55 + 0.23 * t, 1.00);
}

// Phase name + a thin illumination bar tinted by the same brightness.
void RenderMoonStrip(int day) {
    int pct = MoonIlluminationPct(day);
    vec4 tint = MoonTint(pct);
    TextTone(tint, Icons::MoonO + "  " + MoonPhaseName(day));
    UI::PushStyleColor(UI::Col::FrameBg, vec4(0.06, 0.09, 0.14, 1.00));
    UI::PushStyleColor(UI::Col::PlotHistogram, tint);
    UI::ProgressBar(float(pct) / 100.0f, vec2(-1, 8), "");
    UI::PopStyleColor(2);
    UI::TextDisabled(tostring(pct) + "% lit");
}

// Built from Calendar.as's g_offDays so the UI can never disagree with the logic.
string OffDaysText() {
    string text = "";
    for (uint i = 0; i < g_offDays.Length; i++) {
        if (i > 0) text += ", ";
        text += tostring(g_offDays[i]);
    }
    return text;
}

string DayTileStatus(int day) {
    if (g_opened[day - 1]) return "DONE";
    if (IsOffDay(day)) return "MP";
    if (IsPremiereDay(day)) return "x2";
    if (DayPlayableNow(day)) return "OPEN";
    return "WAIT";
}

// Centring with ImGui's native ButtonTextAlign. Multi-line labels are centred
// by ImGui itself, so no SetCursorScreenPos() calls and no EndChild() assertions.
bool DrawCenteredDayTile(int day, const string &in icon, const string &in label,
                         const string &in moonLine, vec4 bgCol, vec4 textCol,
                         bool isSelected, float tileW) {
    bool waiting = label.EndsWith("WAIT");
    if (isSelected || waiting) {
        UI::PushStyleVar(UI::StyleVar::FrameBorderSize, isSelected ? 2.0f : 1.0f);
        UI::PushStyleColor(UI::Col::Border, isSelected ? Gold() : vec4(0.32, 0.40, 0.55, 1.00));
    }

    UI::PushStyleVar(UI::StyleVar::ButtonTextAlign, vec2(0.5f, 0.5f));
    UI::PushStyleColor(UI::Col::Button, bgCol);
    UI::PushStyleColor(UI::Col::ButtonHovered, vec4(bgCol.x + 0.08, bgCol.y + 0.08, bgCol.z + 0.08, 1.0));
    UI::PushStyleColor(UI::Col::ButtonActive, vec4(bgCol.x + 0.14, bgCol.y + 0.14, bgCol.z + 0.14, 1.0));
    UI::PushStyleColor(UI::Col::Text, textCol);
    UI::PushFontSize(13.0f);   // three short lines have to fit the tile

    // Every one of the 25 days carries its own moon phase, not only Pursuit days.
    string caption = icon + "\n" + label + "\n" + moonLine + "##goalmastile" + tostring(day);
    bool clicked = UI::Button(caption, vec2(tileW, 78));

    UI::PopFontSize();
    UI::PopStyleColor(4);
    UI::PopStyleVar();
    if (isSelected || waiting) {
        UI::PopStyleColor();
        UI::PopStyleVar();
    }
    return clicked;
}

void RenderDayGrid() {
    UI::TextDisabled("Pursuit rest days: " + OffDaysText() + "   |   Premiere day awards x2 points");
    UI::Dummy(vec2(0, 4));

    float width = UI::GetContentRegionAvail().x;
    float tileW = (width - 24) / 5;
    if (tileW < 48) tileW = 48;

    for (int day = 1; day <= DAY_COUNT; day++) {
        string num = day < 10 ? "0" + tostring(day) : tostring(day);
        string label = num + " " + DayTileStatus(day);
        // Day 25 has a Gold tile: Gold text on it was invisible (blank tile).
        vec4 textCol = Silver();
        if (day == DAY_COUNT) textCol = vec4(0.14, 0.09, 0.02, 1.00);
        else if (IsPremiereDay(day)) textCol = Gold();

        string moonLine = Icons::MoonO + " " + tostring(MoonIlluminationPct(day)) + "%";
        if (DrawCenteredDayTile(day, DayTileIcon(day), label, moonLine,
                                DayTileColor(day), textCol, day == g_selectedDay, tileW)) {
            g_selectedDay = day;
            g_confirmReset = false;
        }
        UI::SetItemTooltip(MoonPhaseName(day) + " - " +
                           tostring(MoonIlluminationPct(day)) + "% illumination");
        if (day % 5 != 0) UI::SameLine(0, 6);
    }
}

void RenderMiniCard(const string &in id, const string &in title, const string &in line1,
                    const string &in line2, vec4 accent) {
    UI::PushStyleColor(UI::Col::ChildBg, InnerBg());
    if (UI::BeginChild(id, vec2(0, 68), UI::ChildFlags::Borders)) {
        TextTone(accent, title);
        UI::Text(line1);
        UI::Text(line2);
    }
    UI::EndChild();
    UI::PopStyleColor();
}

void RenderDayDetails() {
    int day = g_selectedDay;
    if (day < 1 || day > DAY_COUNT) day = 1;

    TextTone(Gold(), Icons::Star + "  DAY " + tostring(day) + " - " + g_titles[day - 1]);

    string status = "Available";
    vec4 statusColor = Emerald();
    if (g_opened[day - 1]) {
        status = "Completed";
        statusColor = Emerald();
    } else if (IsOffDay(day)) {
        status = "Pursuit rest day";
        statusColor = Purple();
    } else if (IsPremiereDay(day)) {
        status = "Premiere - double points";
        statusColor = Crimson();
    } else if (!DayPlayableNow(day)) {
        status = "Waiting for the event";
        statusColor = vec4(0.66, 0.70, 0.78, 1.00);   // Slate was unreadable on CardBg
    }
    TextTone(statusColor, status);
    UI::Dummy(vec2(0, 2));
    RenderMoonStrip(day);
    UI::Dummy(vec2(0, 4));

    UI::TextWrapped(g_hints[day - 1]);
    UI::Dummy(vec2(0, 6));

    if (IsOffDay(day)) {
        // Pursuit night: no CP goal and no bounty on this day - say so clearly.
        UI::PushStyleColor(UI::Col::ChildBg, vec4(0.20, 0.15, 0.30, 1.00));
        if (UI::BeginChild("##GoalmasPursuitCard", vec2(0, 118), UI::ChildFlags::Borders)) {
            TextTone(Silver(), Icons::MoonO + "  PURSUIT NIGHT ON MANIAPLANET");
            UI::TextWrapped("No Goal Hunt today - the moon belongs to Pursuit.");
            UI::TextWrapped("Your streak and points stay safe.");
            UI::TextDisabled("The next Goal Hunt window opens tomorrow.");
        }
        UI::EndChild();
        UI::PopStyleColor();
    } else {
        RenderMiniCard("##GoalmasGoalFrame", "GOAL  " + Icons::FlagCheckered,
                       "Catch " + tostring(GOAL_CP) + " CP in one run",
                       "Your best: " + tostring(g_bests[day - 1]) + " CP",
                       Emerald());

        UI::Dummy(vec2(0, 6));

        RenderMiniCard("##GoalmasBountyFrame", "BOUNTY  " + Icons::Crosshairs,
                       "Record: " + tostring(g_bountyCp[day - 1]) + " CP",
                       "Holder: " + g_bountyHolder[day - 1],
                       Crimson());
    }

    UI::Dummy(vec2(0, 8));

    string action = "OPEN DAY " + tostring(day);
    if (IsOffDay(day)) action = "PURSUIT NIGHT - NO RACE";
    else if (S_TestMode) action = "SUBMIT TEST CP (12)";

    UI::PushStyleColor(UI::Col::Button, IsOffDay(day) ? Tone(Purple()) : Crimson());
    UI::PushStyleColor(UI::Col::ButtonHovered, IsOffDay(day) ? Purple() : vec4(1.00, 0.32, 0.36, 1.00));
    if (UI::Button(action, vec2(-1, 40))) {
        if (IsOffDay(day)) {
            g_status = "Rest day - play Pursuit on ManiaPlanet.";
        } else if (S_TestMode) {
            RequestCpSubmit(day, 12);
            g_status = "Test CP submitted for day " + tostring(day) + ".";
        } else {
            g_status = "Join #" + tostring(day) + " Goal Hunt on the event server - CP count automatically.";
        }
    }
    UI::PopStyleColor(2);
}

void RenderCalendarTab() {
    float width = UI::GetContentRegionAvail().x;
    float leftW = width * 0.58f;
    float rightW = width - leftW - 8;

    if (UI::BeginChild("##GoalmasCalendarGrid", vec2(leftW, 0), UI::ChildFlags::Borders)) {
        RenderDayGrid();
    }
    UI::EndChild();
    UI::SameLine(0, 8);

    if (UI::BeginChild("##GoalmasDayDetailsCard", vec2(rightW, 0), UI::ChildFlags::Borders)) {
        RenderDayDetails();
    }
    UI::EndChild();
}

// ---------------------------------------------------------------------------
// Leaderboard tab
// ---------------------------------------------------------------------------
void RenderLeaderboardTab() {
    if (g_boardNames.Length == 0) {
        UI::TextDisabled("No entries yet. They appear after the first submitted run.");
        if (UI::Button(Icons::Refresh + " Refresh")) SyncNow();
        return;
    }

    int flags = UI::TableFlags::RowBg | UI::TableFlags::BordersInnerH | UI::TableFlags::PadOuterX;
    if (UI::BeginTable("##GoalmasBoardTable", 4, flags)) {
        UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 42);
        UI::TableSetupColumn("Player", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("Points", UI::TableColumnFlags::WidthFixed, 96);
        UI::TableSetupColumn("Bounties", UI::TableColumnFlags::WidthFixed, 96);
        UI::TableHeadersRow();

        for (uint i = 0; i < g_boardNames.Length; i++) {
            UI::TableNextRow();
            if (i < 3) {
                vec4 medal = Bronze();
                if (i == 0) medal = Gold();
                else if (i == 1) medal = Silver();
                UI::TableSetBgColor(UI::TableBgTarget::RowBg0, Tone(medal));
            }
            UI::TableSetColumnIndex(0);
            if (i < 3) TextTone(i == 0 ? Gold() : (i == 1 ? Silver() : Bronze()), tostring(int(i) + 1));
            else UI::Text(tostring(int(i) + 1));
            UI::TableSetColumnIndex(1);
            if (g_boardNames[i] == LocalName()) TextTone(Gold(), g_boardNames[i] + "  (you)");
            else UI::Text(g_boardNames[i]);
            UI::TableSetColumnIndex(2);
            TextTone(Gold(), tostring(g_boardPoints[i]));
            UI::TableSetColumnIndex(3);
            UI::Text(tostring(g_boardBounties[i]));
        }
        UI::EndTable();
    }

    UI::Dummy(vec2(0, 8));
    if (UI::Button(Icons::Refresh + " Refresh leaderboard")) SyncNow();
}

// ---------------------------------------------------------------------------
// Live feed tab
// ---------------------------------------------------------------------------
void RenderFeedTab() {
    if (g_liveFeed.Length == 0) {
        UI::TextDisabled("Nothing here yet - complete a day or take a bounty.");
        if (UI::Button(Icons::Refresh + " Refresh")) SyncNow();
        return;
    }

    int flags = UI::TableFlags::RowBg | UI::TableFlags::BordersInnerH | UI::TableFlags::PadOuterX;
    if (UI::BeginTable("##GoalmasFeedTable", 2, flags)) {
        UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 42);
        UI::TableSetupColumn("Event", UI::TableColumnFlags::WidthStretch);
        UI::TableHeadersRow();

        for (uint i = 0; i < g_liveFeed.Length; i++) {
            UI::TableNextRow();
            if (i == 0) UI::TableSetBgColor(UI::TableBgTarget::RowBg0, Tone(Gold()));
            UI::TableSetColumnIndex(0);
            UI::Text(tostring(int(i) + 1));
            UI::TableSetColumnIndex(1);
            UI::TextWrapped(g_liveFeed[i]);
        }
        UI::EndTable();
    }

    UI::Dummy(vec2(0, 8));
    if (UI::Button(Icons::Refresh + " Refresh feed")) SyncNow();
}

// ---------------------------------------------------------------------------
// Finale tab
// ---------------------------------------------------------------------------
void RenderFinaleTab() {
    TextTone(Gold(), Icons::Trophy + "  THE BIG FINALE");
    UI::Separator();

    UI::TextWrapped("Final code: " + FinalCode());
    float progress = float(OpenedCount()) / float(DAY_COUNT);
    UI::ProgressBar(progress, vec2(-1, 20),
                    "Gifts " + tostring(OpenedCount()) + "/" + tostring(DAY_COUNT));
    UI::Dummy(vec2(0, 6));

    RenderMiniCard("##GoalmasFinaleScore", "RESULT",
                   "Score (best 15 + finale): " + tostring(TotalPoints()),
                   "Bounties: " + tostring(g_bountiesWon) + "   Badges: " + BadgeSummary(),
                   Gold());

    UI::Dummy(vec2(0, 8));
    if (OpenedCount() < DAY_COUNT) {
        UI::TextDisabled("Not every gift was opened - the raffle ticket needs 25/25.");
    } else {
        TextTone(Emerald(), Icons::Check + "  Raffle ticket earned - bring the code to the event.");
    }
    UI::TextWrapped("The finale stays open until " + tostring(FINALE_GRACE_DAYS) +
                    " January, so nobody has to be online on the 25th. "
                    "The raffle is drawn after the window closes.");
}

// ---------------------------------------------------------------------------
// Main dashboard
// ---------------------------------------------------------------------------
void RenderDashboard() {
    UI::SetNextWindowSize(900, 720, UI::Cond::FirstUseEver);
    if (!UI::Begin("Goalmas 2026", g_showCalendar)) {
        UI::End();
        return;
    }

    PushDashboardStyle();
    RenderHeaderCard();
    UI::Dummy(vec2(0, 4));

    UI::BeginTabBar("##GoalmasMainTabs");
    if (UI::BeginTabItem(Icons::Calendar + "  Calendar")) {
        RenderCalendarTab();
        UI::EndTabItem();
    }
    if (UI::BeginTabItem(Icons::Trophy + "  Leaderboard")) {
        RenderLeaderboardTab();
        UI::EndTabItem();
    }
    if (UI::BeginTabItem(Icons::List + "  Live feed")) {
        RenderFeedTab();
        UI::EndTabItem();
    }
    if (UI::BeginTabItem(Icons::Star + "  Grand finale")) {
        RenderFinaleTab();
        UI::EndTabItem();
    }
    UI::EndTabBar();

    PopDashboardStyle();
    UI::End();
}

// ---------------------------------------------------------------------------
// Overlays (rendered from Render(), outside the dashboard window)
// ---------------------------------------------------------------------------
void RenderBanner() {
    if (g_bannerTimer <= 0.0f || g_bannerText.Length == 0) return;

    int screenWidth = Display::GetWidth();
    UI::SetNextWindowPos(screenWidth / 2 - 280, 40, UI::Cond::Always);
    int flags = UI::WindowFlags::NoTitleBar | UI::WindowFlags::NoResize |
                UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoMove |
                UI::WindowFlags::NoInputs;
    UI::PushStyleColor(UI::Col::WindowBg, vec4(0.45, 0.08, 0.08, 0.92));
    if (UI::Begin("##GoalmasBanner", flags)) {
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
    UI::PushStyleColor(UI::Col::WindowBg, vec4(0.06, 0.10, 0.16, 0.86));
    if (UI::Begin("##GoalmasGoalHuntHud", flags)) {
        TextTone(Gold(), Icons::FlagCheckered + " #" + tostring(day) + " GOAL HUNT");
        if (IsPremiereDay(day)) TextTone(Emerald(), "PREMIERE - x2 points");
        else UI::TextDisabled("Catch-up - x1 points");
        UI::Text("Goal " + tostring(GOAL_CP) + " CP   Session " + tostring(g_sessionCp) + " CP");
        UI::Text("Bounty " + tostring(g_bountyCp[day - 1]) + " CP (" + g_bountyHolder[day - 1] + ")");
        UI::Text("Your best " + tostring(g_bests[day - 1]) + " CP");
    }
    UI::End();
    UI::PopStyleColor();
}
