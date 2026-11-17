// Pursuit Native theme - translucent ManiaPlanet scoreboard layout.
// Data comes from Calendar.as / Config.as; only the ImGui presentation differs.
// Every native used here is verified in OpenplanetCore.json (1.29.14).

vec4 PGlass()  { return vec4(0.11, 0.13, 0.16, 0.84); }
vec4 PHeader() { return vec4(0.08, 0.09, 0.11, 0.92); }
vec4 PRowA()   { return vec4(0.16, 0.18, 0.22, 0.78); }
vec4 PRowB()   { return vec4(0.13, 0.15, 0.18, 0.78); }
vec4 PWhite()  { return vec4(1.00, 1.00, 1.00, 1.00); }
vec4 PGold()   { return vec4(1.00, 0.82, 0.40, 1.00); }
vec4 PDark()   { return vec4(0.06, 0.07, 0.09, 0.94); }

void PushPursuitStyle() {
    UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(12, 10));
    UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(6, 3));
    UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(6, 3));
    UI::PushStyleVar(UI::StyleVar::WindowRounding, 0.0f);
    UI::PushStyleVar(UI::StyleVar::ChildRounding, 0.0f);
    UI::PushStyleVar(UI::StyleVar::FrameRounding, 0.0f);
    UI::PushStyleVar(UI::StyleVar::TabRounding, 0.0f);
    UI::PushStyleVar(UI::StyleVar::ChildBorderSize, 1.0f);
    UI::PushStyleVar(UI::StyleVar::FrameBorderSize, 1.0f);
    UI::PushStyleVar(UI::StyleVar::ScrollbarSize, 0.0f);

    UI::PushStyleColor(UI::Col::WindowBg, PGlass());
    UI::PushStyleColor(UI::Col::ChildBg, vec4(0.12, 0.14, 0.17, 0.80));
    UI::PushStyleColor(UI::Col::FrameBg, PRowB());
    UI::PushStyleColor(UI::Col::Border, vec4(0.32, 0.34, 0.38, 0.85));
    UI::PushStyleColor(UI::Col::TableHeaderBg, PHeader());
    UI::PushStyleColor(UI::Col::TableRowBg, PRowA());
    UI::PushStyleColor(UI::Col::TableRowBgAlt, PRowB());
    UI::PushStyleColor(UI::Col::Header, PHeader());
    UI::PushStyleColor(UI::Col::Text, PWhite());
    UI::PushStyleColor(UI::Col::TextDisabled, vec4(0.72, 0.74, 0.78, 1.00));
    UI::PushStyleColor(UI::Col::Button, vec4(0.16, 0.18, 0.22, 0.90));
    UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.26, 0.28, 0.33, 0.95));
    UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.34, 0.36, 0.42, 0.95));
}

void PopPursuitStyle() {
    UI::PopStyleColor(13);
    UI::PopStyleVar(10);
}

void PCenteredText(const string &in text, float size, vec4 col) {
    float w = UI::MeasureString(text, null, size).x;
    UI::SetCursorPosX((UI::GetWindowSize().x - w) * 0.5f);
    UI::PushFontSize(size);
    TextTone(col, text);
    UI::PopFontSize();
}

string PModeLabel(int day) {
    if (day == DAY_COUNT) return Icons::Trophy + " FINALE";
    if (IsOffDay(day)) return Icons::MoonO + " PURSUIT";
    if (IsPremiereDay(day)) return Icons::Star + " PREMIERE x2";
    return "GOAL HUNT";
}

void PRowTint(int row, bool selected) {
    vec4 c = (row % 2 == 0) ? PRowA() : PRowB();
    if (selected) c = vec4(1.00, 1.00, 1.00, 0.20);
    UI::TableSetBgColor(UI::TableBgTarget::RowBg0, c);
    UI::TableSetBgColor(UI::TableBgTarget::RowBg1, c);
}

void RenderPursuitDays() {
    int flags = UI::TableFlags::RowBg | UI::TableFlags::BordersInnerH | UI::TableFlags::PadOuterX;
    if (!UI::BeginTable("##PursuitDays", 5, flags)) return;

    UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 30);
    UI::TableSetupColumn("DAY", UI::TableColumnFlags::WidthFixed, 48);
    UI::TableSetupColumn("MODE", UI::TableColumnFlags::WidthStretch);
    UI::TableSetupColumn("MOON", UI::TableColumnFlags::WidthFixed, 54);
    UI::TableSetupColumn("GOAL", UI::TableColumnFlags::WidthFixed, 60);
    UI::TableHeadersRow();

    for (int day = 1; day <= DAY_COUNT; day++) {
        UI::TableNextRow();
        PRowTint(day, day == g_selectedDay);

        UI::TableSetColumnIndex(0);
        if (UI::Button(tostring(day), vec2(26, 0))) {
            g_selectedDay = day;
            g_confirmReset = false;
        }

        UI::TableSetColumnIndex(1);
        UI::Text(DayTileShort(day));

        UI::TableSetColumnIndex(2);
        UI::Text(PModeLabel(day));

        UI::TableSetColumnIndex(3);
        if (S_ShowMoonPct) UI::Text(tostring(MoonIlluminationPct(day)) + "%");
        else UI::Text("-");

        UI::TableSetColumnIndex(4);
        UI::Text(tostring(g_bests[day - 1]) + "/" + tostring(GOAL_CP));
    }
    UI::EndTable();
}

void RenderPursuitDetails() {
    int day = g_selectedDay;
    if (day < 1 || day > DAY_COUNT) day = 1;

    int flags = UI::TableFlags::RowBg | UI::TableFlags::BordersInnerH | UI::TableFlags::PadOuterX;
    if (UI::BeginTable("##PursuitDetail", 4, flags)) {
        UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 30);
        UI::TableSetupColumn("DAY DETAILS", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("BOUNTY", UI::TableColumnFlags::WidthFixed, 120);
        UI::TableSetupColumn("PTS", UI::TableColumnFlags::WidthFixed, 58);
        UI::TableHeadersRow();

        UI::TableNextRow();
        PRowTint(day, true);

        UI::TableSetColumnIndex(0);
        UI::Text(tostring(day));

        UI::TableSetColumnIndex(1);
        TextTone(PGold(), Icons::Star + "  DAY " + tostring(day) + " - " + g_titles[day - 1]);
        string status = IsOffDay(day) ? "Pursuit rest day"
                      : (g_opened[day - 1] ? "Completed"
                      : (!DayUnlocked(day) ? "Locked until Dec " + tostring(day) : "Goal Hunt open"));
        UI::Text(status);
        UI::TextWrapped(MoonPhaseName(day) + " - " +
                        tostring(MoonIlluminationPct(day)) + "% illumination");
        UI::TextWrapped(IsOffDay(day) ? "No Goal Hunt today - play Pursuit on ManiaPlanet."
                                      : g_hints[day - 1]);

        UI::TableSetColumnIndex(2);
        UI::Text(Icons::Shield + " " + tostring(g_bountyCp[day - 1]) + " CP");
        UI::Text(g_bountyHolder[day - 1]);

        UI::TableSetColumnIndex(3);
        if (g_points.Length > day - 1) UI::Text(tostring(g_points[day - 1]));
        else UI::Text("0");
        UI::EndTable();
    }

    UI::Dummy(vec2(0, 6));
    UI::TextDisabled("BADGES");
    UI::TextWrapped(BadgeSummary());

    UI::Dummy(vec2(0, 8));
    if (IsOffDay(day) || !DayUnlocked(day)) {
        UI::PushStyleColor(UI::Col::Button, vec4(0.14, 0.15, 0.18, 0.90));
        UI::PushStyleColor(UI::Col::Text, vec4(0.70, 0.70, 0.74, 1.00));
        UI::Button(IsOffDay(day) ? "PURSUIT NIGHT - NO RACE" : "AVAILABLE DEC " + tostring(day),
                   vec2(-1, 32));
        UI::PopStyleColor(2);
    } else {
        UI::PushStyleColor(UI::Col::Button, PWhite());
        UI::PushStyleColor(UI::Col::Text, vec4(0.06, 0.06, 0.08, 1.00));
        if (UI::Button(S_TestMode ? "SUBMIT TEST CP (12)" : "OPEN DAY " + tostring(day), vec2(-1, 32))) {
            if (S_TestMode) {
                RequestCpSubmit(day, 12);
                g_status = "Test CP submitted for day " + tostring(day) + ".";
            } else {
                g_status = "Join #" + tostring(day) + " Goal Hunt on the event server.";
            }
        }
        UI::PopStyleColor(2);
    }
}

void RenderPursuitFooter() {
    float w = UI::GetWindowSize().x;
    UI::PushStyleColor(UI::Col::ChildBg, PDark());
    if (UI::BeginChild("##PursuitFooter", vec2(0, 56), UI::ChildFlags::Borders)) {
        UI::SetCursorPos(vec2(12, 8));
        TextTone(PWhite(), LocalName());
        UI::TextDisabled(BadgeSummary());

        UI::SetCursorPos(vec2(w * 0.42f, 10));
        UI::Text("GIFTS  " + tostring(OpenedCount()) + "/" + tostring(DAY_COUNT) +
                 "    BOUNTIES  " + tostring(g_bountiesWon) +
                 "    STREAK  " + tostring(OpenedCount()) + "/" + tostring(DAY_COUNT));

        UI::SetCursorPos(vec2(w - 250.0f, 8));
        UI::PushFontSize(20.0f);
        TextTone(PGold(), "TOTAL POINTS  " + tostring(ScoreDays()));
        UI::PopFontSize();
        UI::Text("ROUND  DAY " + tostring(g_selectedDay) + " / " + tostring(DAY_COUNT));
    }
    UI::EndChild();
    UI::PopStyleColor();
}

void RenderPursuitDashboard() {
    if (!g_windowSizeApplied) {
        UI::SetNextWindowSize(980, 620, UI::Cond::Always);
        UI::SetNextWindowPos(24, 40, UI::Cond::Always);
        g_windowSizeApplied = true;
    }
    if (!UI::Begin("goalmas 2026", g_showCalendar)) {
        UI::End();
        return;
    }

    PushPursuitStyle();

    PCenteredText(Icons::Star + " GOALMAS " + Icons::Star, 26.0f, PWhite());
    string sub = "DAY " + tostring(g_selectedDay) + "/" + tostring(DAY_COUNT) + "   " +
                 (IsOffDay(g_selectedDay) ? Icons::MoonO + " PURSUIT NIGHT"
                                          : Icons::Crosshairs + " GOAL HUNT");
    PCenteredText(sub, 15.0f, vec4(0.86, 0.87, 0.91, 1.00));
    UI::Dummy(vec2(0, 4));

    if (UI::Button(Icons::Calendar + " Calendar", vec2(112, 0))) g_activeTab = 0;
    UI::SameLine(0, 4);
    if (UI::Button(Icons::Trophy + " Leaderboard", vec2(124, 0))) g_activeTab = 1;
    UI::SameLine(0, 4);
    if (UI::Button(Icons::List + " Live", vec2(78, 0))) g_activeTab = 2;
    UI::SameLine(0, 4);
    if (UI::Button(Icons::Star + " Finale", vec2(88, 0))) g_activeTab = 3;
    UI::SameLine(0, 4);
    if (UI::Button(Icons::Cog + " Settings", vec2(104, 0))) g_showSettings = !g_showSettings;
    UI::Separator();

    float fullW = UI::GetContentRegionAvail().x;
    float leftW = fullW * 0.52f;
    if (UI::BeginChild("##PursuitLeft", vec2(leftW - 4, -68), UI::ChildFlags::Borders)) {
        RenderPursuitDays();
    }
    UI::EndChild();
    UI::SameLine(0, 8);
    if (UI::BeginChild("##PursuitRight", vec2(0, -68), UI::ChildFlags::Borders)) {
        RenderPursuitDetails();
    }
    UI::EndChild();

    UI::SetCursorPosY(UI::GetWindowSize().y - 68.0f);
    RenderPursuitFooter();

    PopPursuitStyle();
    UI::End();
}
