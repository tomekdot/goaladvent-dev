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
vec4 CardBg()    { return vec4(0.11, 0.14, 0.20, 0.98); }
vec4 InnerBg()   { return vec4(0.14, 0.18, 0.26, 1.00); }
vec4 Silver()    { return vec4(0.72, 0.75, 0.82, 1.00); }
vec4 Bronze()    { return vec4(0.72, 0.45, 0.25, 1.00); }
vec4 Teal()      { return vec4(0.12, 0.38, 0.46, 1.00); }   // OPEN day tile
vec4 DimNavy()   { return vec4(0.14, 0.17, 0.24, 1.00); }   // WAIT day tile
vec4 TextMain()  { return vec4(0.90, 0.92, 0.96, 1.00); }
vec4 TextMuted() { return vec4(0.62, 0.66, 0.74, 1.00); }

// Moon phase tint lives in RenderMoonStrip(), next to the phase bar it colours.

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

// ---------------------------------------------------------------------------
// Dashboard style
// ---------------------------------------------------------------------------
void PushDashboardStyle() {
    // One spacing/rounding scale for the whole dashboard.
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
    // Secondary buttons are Navy by default; primary actions override this with
    // Crimson and the destructive reset with its own dark red.
    UI::PushStyleColor(UI::Col::Button, Navy());
    UI::PushStyleColor(UI::Col::ButtonHovered, Lift(Navy()));
    UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.24, 0.40, 0.64, 1.00));
    UI::PushStyleColor(UI::Col::Text, TextMain());
    UI::PushStyleColor(UI::Col::TextDisabled, TextMuted());
}

void PopDashboardStyle() {
    UI::PopStyleColor(13);
    UI::PopStyleVar(6);
}

// ---------------------------------------------------------------------------
// Header card
// ---------------------------------------------------------------------------
// Badges are real pills again, but wrapping is done by hand: ImGui never wraps
// SameLine() items, so the width of each pill is measured first and a new row
// starts when the next one would not fit.
vec4 BadgeColor(const string &in badge) {
    vec4 col = Emerald();
    string low = badge.ToLower();
    if (low.Contains("bounty") || low.Contains("final")) col = Gold();
    else if (low.Contains("pursuit")) col = Silver();
    else if (low.Contains("galaxy")) col = vec4(0.35, 0.65, 1.00, 1.00);
    return col;
}

float BadgePillWidth(const string &in badge) {
    return UI::MeasureString(badge, null, 13.0f, 0.0f).x + 22.0f;
}

// Rows the pill strip needs at the given width. Used for the header height
// before anything is drawn, so a second row can never be clipped.
int BadgeRowCount(float availW) {
    if (g_badges.Length == 0) return 1;
    float lineW = 0.0f;
    int rows = 1;
    for (uint i = 0; i < g_badges.Length; i++) {
        float w = BadgePillWidth(g_badges[i]);
        if (lineW > 0.0f && lineW + 6.0f + w > availW) {
            rows++;
            lineW = w;
        } else {
            lineW += (lineW > 0.0f ? 6.0f : 0.0f) + w;
        }
    }
    return rows;
}

void RenderBadgePills() {
    if (g_badges.Length == 0) return;

    bool midline = false;
    UI::PushFontSize(13.0f);
    for (uint i = 0; i < g_badges.Length; i++) {
        vec4 col = BadgeColor(g_badges[i]);
        float w = BadgePillWidth(g_badges[i]);
        if (midline && UI::GetContentRegionAvail().x >= w) UI::SameLine(0, 6);

        UI::PushStyleVar(UI::StyleVar::FrameRounding, 11.0f);
        UI::PushStyleColor(UI::Col::Button, Tone(col));
        UI::PushStyleColor(UI::Col::ButtonHovered, Lift(Tone(col)));
        UI::PushStyleColor(UI::Col::ButtonActive, Lift(Lift(Tone(col))));
        UI::PushStyleColor(UI::Col::Text, col);
        UI::Button(g_badges[i] + "##badge" + tostring(int(i)), vec2(w, 22));
        UI::PopStyleColor(4);
        UI::PopStyleVar();
        midline = true;
    }
    UI::PopFontSize();
}

void RenderHeaderCard() {
    // Pills need as many rows as they measure; the card must know the count
    // before BeginChild, otherwise the second row would be silently clipped.
    float innerW = UI::GetContentRegionAvail().x - 34.0f;
    int badgeRows = g_confirmReset ? 1 : BadgeRowCount(innerW);
    float headerH = 168.0f + float(badgeRows - 1) * 30.0f;

    UI::PushStyleColor(UI::Col::ChildBg, vec4(0.12, 0.15, 0.22, 1.00));
    if (UI::BeginChild("##GoalmasHeader", vec2(0, headerH), UI::ChildFlags::Borders)) {
        TextTone(Gold(), Icons::SnowflakeO + "   GOALMAS 2026");
        UI::SetCursorPosY(UI::GetCursorPos().y - 2);
        UI::TextDisabled("Goal Hunt calendar - checkpoint bounties, badges and a free leaderboard");

        float gap = UI::GetContentRegionAvail().x - 150;
        if (gap > 8) UI::Dummy(vec2(gap, 0));
        UI::SameLine(0, 0);
        UI::BeginDisabled(g_syncing);   // visible "busy" state, not a hidden guard
        if (UI::Button(Icons::Refresh, vec2(34, 28))) SyncNow();
        UI::EndDisabled();
        UI::SameLine(0, 4);
        if (UI::Button(Icons::FloppyO, vec2(34, 28))) {
            SaveProgress();
            g_status = "Progress saved locally.";
        }
        UI::SameLine(0, 26);   // keep the destructive action away from Save
        UI::PushStyleColor(UI::Col::Button, vec4(0.45, 0.07, 0.09, 1.00));
        UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.53, 0.15, 0.17, 1.00));
        UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.61, 0.23, 0.25, 1.00));
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
        UI::PopStyleColor(3);

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
            RenderBadgePills();
        }
    }
    UI::EndChild();
    UI::PopStyleColor();

    if (g_confirmReset) {
        UI::PushStyleColor(UI::Col::Button, Crimson());
        UI::PushStyleColor(UI::Col::ButtonHovered, Lift(Crimson()));
        if (UI::Button("Cancel reset")) g_confirmReset = false;
        UI::PopStyleColor(2);
    }

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
    if (DayPlayableNow(day)) return Teal();
    return DimNavy();   // WAIT: dimmed navy, brightened by its border
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
        UI::PushStyleColor(UI::Col::Border, isSelected ? Gold() : vec4(0.40, 0.48, 0.64, 1.00));
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

    float width = UI::GetContentRegionAvail().x;
    float tileW = (width - 24) / 5;
    if (tileW < 48) tileW = 48;

    for (int day = 1; day <= DAY_COUNT; day++) {
        string num = day < 10 ? "0" + tostring(day) : tostring(day);
        string label = num + " " + DayTileStatus(day);
        // Day 25 has a Gold tile: Gold text on it was invisible (blank tile).
        vec4 textCol = TextMain();
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
    if (UI::BeginChild(id, vec2(0, 80), UI::ChildFlags::Borders)) {
        TextTone(accent, title);
        UI::TextWrapped(line1);   // never spills out of the card at 700 px width
        UI::TextWrapped(line2);
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
        statusColor = TextMuted();   // Slate was unreadable on CardBg
    }
    TextTone(statusColor, status);
    RenderMoonStrip(day);   // phase name + illumination bar, tinted by brightness

    UI::TextWrapped(g_hints[day - 1]);

    if (IsOffDay(day)) {
        // Pursuit night: no CP goal and no bounty on this day - say so clearly.
        UI::PushStyleColor(UI::Col::ChildBg, vec4(0.20, 0.15, 0.30, 1.00));
        if (UI::BeginChild("##GoalmasPursuitCard", vec2(0, 124), UI::ChildFlags::Borders)) {
            TextTone(MoonTint(MoonIlluminationPct(day)), Icons::MoonO + "  PURSUIT NIGHT ON MANIAPLANET");
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

        RenderMiniCard("##GoalmasBountyFrame", "BOUNTY  " + Icons::Crosshairs,
                       "Record: " + tostring(g_bountyCp[day - 1]) + " CP",
                       "Holder: " + g_bountyHolder[day - 1],
                       Crimson());
    }

    string action = "OPEN DAY " + tostring(day);
    if (IsOffDay(day)) action = "PURSUIT NIGHT - NO RACE";
    else if (S_TestMode) action = "SUBMIT TEST CP (12)";

    UI::PushStyleColor(UI::Col::Button, IsOffDay(day) ? DimNavy() : Crimson());
    UI::PushStyleColor(UI::Col::ButtonHovered, IsOffDay(day) ? Purple() : Lift(Crimson()));
    UI::PushStyleColor(UI::Col::ButtonActive, IsOffDay(day) ? Lift(Purple()) : vec4(1.00, 0.40, 0.44, 1.00));
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
    UI::PopStyleColor(3);
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
        UI::BeginDisabled(g_syncing);
        if (UI::Button(Icons::Refresh + " Refresh")) SyncNow();
        UI::EndDisabled();
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
            bool mine = g_boardNames[i] == LocalName();
            if (mine) {
                // Own row: a quiet navy wash set in both row-bg slots so the
                // alternating stripe cannot override it.
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

// ---------------------------------------------------------------------------
// Live feed tab
// ---------------------------------------------------------------------------
void RenderFeedTab() {
    if (g_liveFeed.Length == 0) {
        UI::TextDisabled("Nothing here yet - complete a day or take a bounty.");
        UI::BeginDisabled(g_syncing);
        if (UI::Button(Icons::Refresh + " Refresh")) SyncNow();
        UI::EndDisabled();
        return;
    }

    int flags = UI::TableFlags::RowBg | UI::TableFlags::BordersInnerH | UI::TableFlags::PadOuterX;
    if (UI::BeginTable("##GoalmasFeedTable", 2, flags)) {
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

    RenderMiniCard("##GoalmasFinaleScore", "RESULT",
                   "Score (best 15 + finale): " + tostring(TotalPoints()),
                   "Bounties: " + tostring(g_bountiesWon) + "   Badges: " + BadgeSummary(),
                   Gold());

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
    // Pivot 0.5 on X: the auto-sized window centres itself, whatever the text
    // length, instead of assuming a fixed 560 px width.
    UI::SetNextWindowPos(screenWidth / 2, 40, UI::Cond::Always, 0.5f, 0.0f);
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
