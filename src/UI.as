// GoalAdvent 2026 - one ImGui layout, two colour themes.
// Only APIs verified against OpenplanetCore.json (1.29.14) are used.
// Theme.as owns every colour and radius; these wrappers read the active one.

bool g_confirmReset = false;
int g_activeTab = 0;   // 0 Calendar, 1 Leaderboard, 2 Live feed, 3 Bounties, 4 Finale
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

// Countdown shown above the calendar until the event starts (1 December UTC).
string EventCountdown() {
    Time::Info now = Time::ParseUTC();
    if (now.Month == 12) return "";
    if (now.Month == 1 && now.Day <= FINALE_GRACE_DAYS) return "";
    int days = 0;
    if (now.Month == 11) days = 31 - now.Day;
    else if (now.Month < 11) days = (11 - now.Month) * 30 + (31 - now.Day);
    if (days <= 0) return "";
    return "Starts in " + tostring(days) + " days - Dec 1";
}

// Keep the badges field on one line: show at most three, then a +N counter.
string BadgeShort() {
    if (g_badges.Length <= 3) return BadgeSummary();
    string text = "";
    for (uint i = 0; i < 3; i++) {
        if (i > 0) text += ", ";
        text += g_badges[i];
    }
    return text + "  +" + tostring(int(g_badges.Length) - 3);
}

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
    UI::PushFontSize(15.0f);
    TextTone(MixCol(TextMuted(), TextMain(), 0.65f), title);
    UI::PopFontSize();
    UI::Dummy(vec2(0, 5));
}

// One compact monitor-style card: square icon box, small label, clear value.
void DrawStatCard(const string &in icon, const string &in label,
                  const string &in value, vec4 accent) {
    UI::PushStyleColor(UI::Col::ChildBg, InnerBg());
    UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(10, 7));
    UI::PushStyleVar(UI::StyleVar::ScrollbarSize, 0.0f);
    int flags = UI::WindowFlags::NoScrollbar | UI::WindowFlags::NoScrollWithMouse;
    if (UI::BeginChild("##stat" + label + icon, vec2(0, 54), UI::ChildFlags::Borders, flags)) {
        vec2 start = UI::GetCursorPos();

        // A button with ButtonTextAlign centres the glyph reliably. Measuring
        // an icon with MeasureString is not dependable across Openplanet fonts.
        const float boxSize = 32.0f;
        const float boxTop = 6.0f;   // centre 32 px box in the 40 px content area
        vec4 boxCol = vec4(accent.x * 0.50f, accent.y * 0.50f, accent.z * 0.50f, 1.00f);
        UI::SetCursorPos(vec2(start.x, start.y + boxTop));
        UI::PushStyleVar(UI::StyleVar::ButtonTextAlign, vec2(0.5f, 0.5f));
        UI::PushStyleVar(UI::StyleVar::FrameRounding, 4.0f);
        UI::PushStyleColor(UI::Col::Button, boxCol);
        UI::PushStyleColor(UI::Col::ButtonHovered, boxCol);
        UI::PushStyleColor(UI::Col::ButtonActive, boxCol);
        UI::PushStyleColor(UI::Col::Text, accent);
        UI::PushFontSize(16.0f);
        UI::Button(icon + "##statIcon" + label, vec2(boxSize, boxSize));
        UI::PopFontSize();
        UI::PopStyleColor(4);
        UI::PopStyleVar(2);

        // Compact gap after the box; both lines fit the 54 px card.
        float textX = start.x + boxSize + 12.0f;
        UI::SetCursorPos(vec2(textX, start.y + 7.0f));
        TextTone(TextMuted(), label);
        UI::SetCursorPos(vec2(textX, start.y + 23.0f));
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
    vec4 interaction = MixCol(g_palette.buttonHover, g_palette.iceBlue, 0.30f);
    UI::PushStyleColor(UI::Col::TabActive, MixCol(g_palette.buttonBg, g_palette.iceBlue, 0.20f));
    UI::PushStyleColor(UI::Col::TabSelected, MixCol(g_palette.buttonBg, g_palette.iceBlue, 0.20f));
    UI::PushStyleColor(UI::Col::TabHovered, interaction);
    UI::PushStyleColor(UI::Col::TableHeaderBg, g_palette.tableHeaderBg);
    UI::PushStyleColor(UI::Col::Button, g_palette.buttonBg);
    UI::PushStyleColor(UI::Col::ButtonHovered, interaction);
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
    // Brighter icon buttons so they read on both matte and glass backgrounds.
    vec4 btn = MixCol(g_palette.buttonBg, g_palette.text, 0.12f);
    UI::PushStyleColor(UI::Col::Button, btn);
    UI::PushStyleColor(UI::Col::ButtonHovered, Lift(btn));
    UI::PushStyleColor(UI::Col::ButtonActive, Lift(Lift(btn)));

    // The window title already shows the name; the inner header is only a
    // subtitle, so it is not repeated twice on screen.
    UI::PushFontSize(16.0f);
    TextTone(IceBlue(), Icons::SnowflakeO);
    UI::PopFontSize();
    UI::SameLine(0, 8);
    UI::PushFontSize(13.0f);
    UI::TextDisabled("25 days of checkpoints, bounties and badges");
    UI::PopFontSize();

    // Right-align the three buttons on the SAME row as the title. Deriving the
    // offset from the remaining width keeps them aligned when the window size
    // changes; an absolute X used to drop them below the separator.
    float btnW = 28.0f;
    float gap = 4.0f;
    float groupW = btnW * 3.0f + gap * 2.0f;
    float rightOffset = UI::GetContentRegionAvail().x - groupW;
    if (rightOffset < 0.0f) rightOffset = 0.0f;
    UI::SameLine(0, rightOffset);

    UI::BeginDisabled(g_syncing);
    if (UI::Button(Icons::Refresh, vec2(btnW, 22))) SyncNow();
    UI::SetItemTooltip(g_syncing ? "Sync in progress..." : "Refresh results from the event server.");
    UI::EndDisabled();
    UI::SameLine(0, gap);
    if (UI::Button(Icons::FloppyO, vec2(btnW, 22))) {
        SaveProgress();
        g_status = "Progress saved locally.";
    }
    UI::SetItemTooltip("Save progress to this PC.");
    UI::SameLine(0, gap);
    UI::PushStyleColor(UI::Col::ButtonHovered, Crimson());
    if (UI::Button(Icons::Trash, vec2(btnW, 22))) {
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
    UI::PopStyleColor(3);
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
    if (UI::BeginChild("##goaladventSidebar", vec2(175, -30), UI::ChildFlags::Borders)) {
        SidebarTab(0, Icons::Calendar, "Calendar");
        SidebarTab(1, Icons::Trophy, "Leaderboard");
        SidebarTab(2, Icons::Rss, "Live feed");
        SidebarTab(3, Icons::Crosshairs, "Bounties");
        SidebarTab(4, Icons::Star, "Grand finale");
        UI::Separator();   // thin divider using the theme border colour

        // Mini summary fills the otherwise empty middle of the sidebar.
        float remain = UI::GetContentRegionAvail().y - 220.0f;
        if (remain > 0) UI::Dummy(vec2(0, remain));
        UI::TextDisabled("POINTS   " + tostring(TotalPoints()));
        UI::TextDisabled("BADGES   " + tostring(g_badges.Length));
        if (g_liveFeed.Length > 0) {
            string last = Text::StripFormatCodes(g_liveFeed[0]);
            if (last.Length > 28) last = last.SubStr(0, 28) + "...";
            UI::TextDisabled("LAST: " + last);
        }

        TextTone(TextMuted(), "PROGRESS   " + tostring(OpenedCount()) + "/" + tostring(DAY_COUNT));
        UI::PushStyleColor(UI::Col::FrameBg, g_palette.frameBg);
        UI::PushStyleColor(UI::Col::PlotHistogram, Emerald());
        UI::ProgressBar(float(OpenedCount()) / float(DAY_COUNT), vec2(-1, 12), "");
        UI::PopStyleColor(2);
        UI::Dummy(vec2(0, 6));

        // Dedicated status field: the selected day gets a real box with a
        // short explanation instead of a bare dot and a truncated label.
        UI::PushStyleColor(UI::Col::ChildBg, InnerBg());
        UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(8, 6));
        int statusFlags = UI::WindowFlags::NoScrollbar | UI::WindowFlags::NoScrollWithMouse;
        if (UI::BeginChild("##goaladventSidebarStatus", vec2(0, 52), UI::ChildFlags::Borders, statusFlags)) {
            string status;
            string detail;
            vec4 col;
            if (IsOffDay(g_selectedDay)) {
                status = "PURSUIT NIGHT";
                detail = "Bonus 20:00 CET";
                col = Purple();
            } else if (!DayUnlocked(g_selectedDay)) {
                status = "LOCKED - DAY " + tostring(g_selectedDay);
                detail = "Opens Dec " + tostring(g_selectedDay);
                col = TextMuted();
            } else {
                status = "GOAL HUNT OPEN";
                detail = "Catch " + tostring(GOAL_CP) + " CP / run";
                col = Emerald();
            }
            TextTone(col, Icons::Circle + "  " + status);
            UI::TextDisabled(detail);
        }
        UI::EndChild();
        UI::PopStyleVar();
        UI::PopStyleColor();
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
                         vec4 accent, bool isSelected, bool isToday, float tileW, float tileH) {
    UI::PushStyleVar(UI::StyleVar::FrameBorderSize, (isSelected || isToday) ? 2.0f : 1.0f);
    UI::PushStyleColor(UI::Col::Border, (isSelected || isToday) ? IceBlue() : g_palette.borderWeak);
    UI::PushStyleColor(UI::Col::Button, bgCol);
    UI::PushStyleColor(UI::Col::ButtonHovered, Lift(bgCol));
    UI::PushStyleColor(UI::Col::ButtonActive, Lift(Lift(bgCol)));
    UI::PushStyleColor(UI::Col::Text, textCol);

    // The button carries only its ID. Its lines are drawn separately so the
    // short icon stays centred and the percentage never overlaps it.
    const float iconF = 18.0f;
    const float labelF = 16.0f;
    const float pctF = 13.0f;
    float top = (tileH - 68.0f) * 0.5f;
    if (top < 0.0f) top = 0.0f;
    bool clicked = UI::Button("##goaladventtile" + tostring(day), vec2(tileW, tileH));
    vec4 r = UI::GetItemRect();
    float cx = r.x + r.z * 0.5f;
    float iconW = UI::MeasureString(icon, null, iconF).x;
    float labelW = UI::MeasureString(label, null, labelF).x;
    vec4 bright = MixCol(textCol, vec4(1.0f, 1.0f, 1.0f, 1.0f), 0.25f);
    UI::GetWindowDrawList().AddText(vec2(cx - iconW * 0.5f, r.y + 5.0f + top),
                                    bright, icon, null, iconF);
    UI::GetWindowDrawList().AddText(vec2(cx - labelW * 0.5f, r.y + 25.0f + top),
                                    bright, label, null, labelF);

    // Illumination goes on its own centred line under the status, so a narrow
    // tile can never push "45%" over the gift icon.
    float pctW = UI::MeasureString(moonLine, null, pctF).x;
    UI::GetWindowDrawList().AddText(vec2(cx - pctW * 0.5f, r.y + 45.0f + top),
                                    MixCol(TextMuted(), vec4(1.0f, 1.0f, 1.0f, 1.0f), 0.35f),
                                    moonLine, null, pctF);
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
    if (S_ShowTips) {
        UI::PushFontSize(14.0f);
        UI::TextWrapped("Tip: play #" + tostring(g_selectedDay) + " Goal Hunt on the event server (" +
                        tostring(GOAL_CP) + " CP/run).");
        UI::PopFontSize();
    }

    string countdown = EventCountdown();
    if (countdown.Length > 0) {
        UI::PushFontSize(13.0f);
        TextTone(Gold(), countdown);
        UI::PopFontSize();
    }

    // Fill the column height, but keep tiles close to square (max 1.3x wide)
    // and centre the resulting grid instead of leaving a strip on the right.
    vec2 origin = UI::GetCursorPos();
    vec2 avail = UI::GetContentRegionAvail();
    const float spacing = 6.0f;
    float tileH = (avail.y - 4.0f * spacing) / 5.0f;
    if (tileH < 60.0f) tileH = 60.0f;
    if (tileH > 110.0f) tileH = 110.0f;
    float tileW = (avail.x - 4.0f * spacing) / 5.0f;
    if (tileW < 48.0f) tileW = 48.0f;
    if (tileW > tileH * 1.3f) tileW = tileH * 1.3f;
    float gridW = 5.0f * tileW + 4.0f * spacing;
    float gridX = origin.x + (avail.x - gridW) * 0.5f;
    int today = CurrentEventDayUtc();

    for (int day = 1; day <= DAY_COUNT; day++) {
        int col = (day - 1) % 5;
        int row = (day - 1) / 5;
        UI::SetCursorPos(vec2(gridX + col * (tileW + spacing),
                              origin.y + row * (tileH + spacing)));

        vec4 textCol = (day == DAY_COUNT || IsPremiereDay(day)) ? Gold() : TextMain();
        if (IsOffDay(day) || !DayUnlocked(day)) textCol = MixCol(textCol, TextMuted(), 0.45f);
        // By default show the percentage only on Pursuit days and the selected
        // tile; S_ShowMoonPct forces it everywhere. The tooltip always has it.
        bool showPct = S_ShowMoonPct || IsOffDay(day) || day == g_selectedDay;
        string moonLine = showPct ? tostring(MoonIlluminationPct(day)) + "%" : "";
        vec4 bg = (day == g_selectedDay) ? TileSelectedBg() : TileBg();
        // A subtle accent wash separates playable / completed days from the
        // locked ones without turning the whole grid into coloured blocks.
        if (g_opened[day - 1] || DayPlayableNow(day)) {
            bg = MixCol(bg, DayAccent(day), 0.15f);
        }
        if (DrawCenteredDayTile(day, DayTileIcon(day), DayTileShort(day), moonLine,
                                bg, textCol, DayAccent(day), day == g_selectedDay,
                                day == today && today > 0, tileW, tileH)) {
            g_selectedDay = day;
            g_confirmReset = false;
        }
        UI::SetItemTooltip(MoonPhaseName(day) + " - " +
                           tostring(MoonIlluminationPct(day)) + "% illumination\n" +
                           "Bounty: " + tostring(g_bountyCp[day - 1]) + " CP by " +
                           g_bountyHolder[day - 1]);
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

    UI::PushFontSize(16.0f);
    TextTone(TextMain(), "DAY " + tostring(day) + "  -  " + g_titles[day - 1]);
    UI::PopFontSize();
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

    // Always-visible proof that the local server / map detection path works.
    int detectedDay = DetectGoalHuntDay();
    DrawStatCard(detectedDay > 0 ? Icons::FlagCheckered : Icons::Crosshairs,
                 "GOAL HUNT MAP",
                 detectedDay > 0 ? ("#" + tostring(detectedDay) + " detected") : "not detected",
                 detectedDay > 0 ? Emerald() : TextMuted());
    UI::Dummy(vec2(0, 5));

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
        DrawStatCard(Icons::Star, "YOUR BADGES", BadgeShort(), Silver());
    }
    if (locked) {
        UI::TextDisabled("This gift opens on December " + tostring(day) + ".");
    } else {
        UI::TextWrapped(g_hints[day - 1]);
    }

}

// Fixed footer of the details panel. It lives outside the scrolling body, so
// the action button can never be pushed below the visible window edge.
void RenderDayAction(int day) {
    const float rowH = 34.0f;
    bool locked = !IsOffDay(day) && !DayUnlocked(day);

    if (locked || IsOffDay(day)) {
        // Clearly disabled: no hover, low contrast, no CTA styling.
        UI::BeginDisabled(true);
        UI::PushStyleColor(UI::Col::Button, MixCol(g_palette.buttonBg, g_palette.text, 0.04f));
        UI::PushStyleColor(UI::Col::Text, MixCol(TextMuted(), g_palette.text, 0.20f));
        UI::Button(locked ? "AVAILABLE DEC " + tostring(day) : "Pursuit Night - No Race", vec2(-1, rowH));
        UI::PopStyleColor(2);
        UI::EndDisabled();
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
    if (UI::BeginChild("##goaladventCalendarGrid", vec2(leftW, 0), UI::ChildFlags::Borders)) {
        DrawSectionHeader("ADVENT CALENDAR");
        RenderDayGrid();
    }
    UI::EndChild();
    UI::PopStyleColor();
    UI::SameLine(0, 8);
    UI::PushStyleColor(UI::Col::ChildBg, g_palette.containerBg);
    if (UI::BeginChild("##goaladventDayDetailsCard", vec2(rightW, 0), UI::ChildFlags::Borders)) {
        DrawSectionHeader("DAY DETAILS");
        int day = g_selectedDay;
        if (day < 1 || day > DAY_COUNT) day = 1;

        // The body may scroll; the action row below it never moves out of view.
        UI::PushStyleColor(UI::Col::ChildBg, g_palette.containerBg);
        if (UI::BeginChild("##goaladventDayDetailsBody", vec2(0, -46), UI::ChildFlags::None)) {
            RenderDayDetails();
        }
        UI::EndChild();
        UI::PopStyleColor();

        UI::Separator();
        RenderDayAction(day);
    }
    UI::EndChild();
    UI::PopStyleColor();
}

// ManiaPlanet nicknames carry inline colour codes ($fff, $48b, $z, ...).
// ImGui has no rich text, so draw each coloured span with a Text style push.
bool MpIsHexTriplet(const string &in s) {
    if (s.Length != 3) return false;
    for (int i = 0; i < 3; i++) {
        string c = s.SubStr(i, 1);
        if (!(c == "0" || c == "1" || c == "2" || c == "3" || c == "4" ||
              c == "5" || c == "6" || c == "7" || c == "8" || c == "9" ||
              c == "a" || c == "b" || c == "c" || c == "d" || c == "e" || c == "f" ||
              c == "A" || c == "B" || c == "C" || c == "D" || c == "E" || c == "F")) return false;
    }
    return true;
}

int MpHexDigit(const string &in s, int index) {
    string c = s.SubStr(index, 1).ToLower();
    if (c == "0") return 0;
    if (c == "1") return 1;
    if (c == "2") return 2;
    if (c == "3") return 3;
    if (c == "4") return 4;
    if (c == "5") return 5;
    if (c == "6") return 6;
    if (c == "7") return 7;
    if (c == "8") return 8;
    if (c == "9") return 9;
    if (c == "a") return 10;
    if (c == "b") return 11;
    if (c == "c") return 12;
    if (c == "d") return 13;
    if (c == "e") return 14;
    return 15;
}

vec4 MpColour(const string &in hex) {
    return vec4(float(MpHexDigit(hex, 0)) / 15.0f,
                float(MpHexDigit(hex, 1)) / 15.0f,
                float(MpHexDigit(hex, 2)) / 15.0f, 1.0f);
}

bool DrawMpSpan(const string &in text, const vec4 &in colour, bool first) {
    if (text.Length == 0) return first;
    if (!first) UI::SameLine(0, 0);
    UI::PushStyleColor(UI::Col::Text, colour);
    UI::Text(text);
    UI::PopStyleColor();
    return false;
}

void DrawMpName(const string &in raw, const vec4 &in fallback) {
    vec4 colour = fallback;
    bool first = true;
    int len = int(raw.Length);
    int i = 0;
    while (i < len) {
        if (raw.SubStr(i, 1) != "$") {
            int start = i;
            while (i < len && raw.SubStr(i, 1) != "$") i++;
            first = DrawMpSpan(raw.SubStr(start, i - start), colour, first);
            continue;
        }
        if (i + 1 < len && raw.SubStr(i + 1, 1) == "$") {
            first = DrawMpSpan("$", colour, first);
            i += 2;
            continue;
        }
        if (i + 3 < len && MpIsHexTriplet(raw.SubStr(i + 1, 3))) {
            colour = MpColour(raw.SubStr(i + 1, 3));
            i += 4;
            continue;
        }
        if (i + 1 < len) {
            string control = raw.SubStr(i + 1, 1).ToLower();
            if (control == "z") colour = fallback;  // $z = default colour
            // $s/$n/$t/$w/$i/$o are style toggles; skip them.
            i += 2;
            continue;
        }
        i++;
    }
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

    // No BordersInnerH: its default ImGui border is blue. Neutral stone rows
    // keep the scoreboard matte and readable in both themes.
    int flags = UI::TableFlags::RowBg | UI::TableFlags::PadOuterX;
    UI::PushStyleColor(UI::Col::TableRowBg, vec4(0.10, 0.10, 0.11, 0.55));
    UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14, 0.14, 0.15, 0.55));
    if (UI::BeginTable("##goaladventBoardTable", 4, flags)) {
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
            DrawMpName(g_boardNames[i], mine ? Gold() : TextMain());
            if (mine) {
                UI::SameLine(0, 6);
                TextTone(TextMuted(), "(you)");
            }
            UI::TableSetColumnIndex(2);
            TextTone(Gold(), tostring(g_boardPoints[i]));
            UI::TableSetColumnIndex(3);
            UI::Text(tostring(g_boardBounties[i]));
        }
        UI::EndTable();
    }
    UI::PopStyleColor(2);
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
    // Neutral stone rows, no blue ImGui borders.
    int flags = UI::TableFlags::RowBg | UI::TableFlags::PadOuterX;
    UI::PushStyleColor(UI::Col::TableRowBg, vec4(0.10, 0.10, 0.11, 0.55));
    UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14, 0.14, 0.15, 0.55));
    if (UI::BeginTable("##goaladventFeedTable", 2, flags)) {
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
            // Feed lines arrive with ManiaPlanet format codes ($fff, $f04,
            // $z ...). Render them instead of printing raw escape sequences.
            DrawMpName(g_liveFeed[i], TextMain());
        }
        UI::EndTable();
    }
    UI::PopStyleColor(2);
    UI::BeginDisabled(g_syncing);
    if (UI::Button(Icons::Refresh + " Refresh feed")) SyncNow();
    UI::EndDisabled();
}

// Every day owns a bounty record, so the board is a 25-row table rather than a
// single "best player" line. It is read-only; clicking a day on the calendar
// still opens its details.
void RenderBountyTab() {
    DrawSectionHeader("BOUNTY BOARD");
    UI::TextDisabled("Each day keeps its own record. Beat the holder's CP to steal it (+" +
                     tostring(BOUNTY_POINTS) + " pts once per day).");
    UI::Dummy(vec2(0, 4));

    int flags = UI::TableFlags::RowBg | UI::TableFlags::PadOuterX |
                UI::TableFlags::ScrollY | UI::TableFlags::NoSavedSettings;
    UI::PushStyleColor(UI::Col::TableRowBg, vec4(0.10, 0.10, 0.11, 0.55));
    UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14, 0.14, 0.15, 0.55));
    if (UI::BeginTable("##goaladventBountyTable", 4, flags, vec2(0, -34))) {
        UI::TableSetupColumn("Day", UI::TableColumnFlags::WidthFixed, 64);
        UI::TableSetupColumn("Map", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("Record", UI::TableColumnFlags::WidthFixed, 88);
        UI::TableSetupColumn("Holder", UI::TableColumnFlags::WidthFixed, 150);
        UI::TableHeadersRow();
        for (int day = 1; day <= DAY_COUNT; day++) {
            UI::TableNextRow();
            if (day == g_selectedDay) {
                UI::TableSetBgColor(UI::TableBgTarget::RowBg0, Tone(Gold()));
                UI::TableSetBgColor(UI::TableBgTarget::RowBg1, Tone(Gold()));
            }
            UI::TableSetColumnIndex(0);
            TextTone(IsOffDay(day) ? Purple() : (g_opened[day - 1] ? Emerald() : TextMain()),
                     "DAY " + tostring(day));
            UI::TableSetColumnIndex(1);
            if (IsOffDay(day)) UI::TextDisabled("Pursuit night");
            else UI::Text(g_titles[day - 1]);
            UI::TableSetColumnIndex(2);
            TextTone(Gold(), tostring(g_bountyCp[day - 1]) + " CP");
            UI::TableSetColumnIndex(3);
            if (g_bountyHolder[day - 1] == LocalName()) TextTone(Gold(), "you");
            else UI::Text(g_bountyHolder[day - 1]);
        }
        UI::EndTable();
    }
    UI::PopStyleColor(2);
    UI::BeginDisabled(g_syncing);
    if (UI::Button(Icons::Refresh + " Refresh bounties")) SyncNow();
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
    DrawStatCard(Icons::Crosshairs, "BOUNTIES", tostring(g_bountiesWon) + "   Badges: " + BadgeShort(), Emerald());
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
    // Live health, not just the configured mode: a failed HTTP call must not
    // keep claiming "Connected". This is the one always-visible status line.
    string link;
    vec4 linkCol;
    if (S_SyncMode == 0) {
        link = "Offline - saved locally";
        linkCol = TextMuted();
    } else if (g_syncing) {
        link = "Syncing results...";
        linkCol = IceBlue();
    } else if (g_debugErrors.Length > 0 || g_status.Contains("failed")) {
        link = "Results error - open Debug";
        linkCol = Crimson();
    } else if (g_lastSyncStamp > 0) {
        link = "Connected - " + tostring(g_boardCount) + " players - synced " +
               tostring(int(Time::Stamp) - g_lastSyncStamp) + "s ago";
        linkCol = Emerald();
    } else {
        link = "Connecting to results...";
        linkCol = TextMuted();
    }
    UI::PushFontSize(14.0f);
    TextTone(linkCol, Icons::Circle + "  " + link);
    UI::SameLine(0, 0);
    string right = "DAY " + tostring(g_selectedDay) + "/25   TOTAL: " +
                   tostring(TotalPoints()) + " PTS   " +
                   tostring(OpenedCount()) + "/25 GIFTS";
    float w = UI::MeasureString(right, null, 14.0f, 0.0f).x + 8.0f;
    if (w < 1.0f) w = 320.0f;
    UI::SetCursorPosX(UI::GetWindowSize().x - w - 16.0f);
    TextTone(MixCol(TextMuted(), TextMain(), 0.50f), right);
    UI::PopFontSize();
}

void RenderWorkspace() {
    // No extra background layer here: stacking translucent panels would turn
    // the glass into an opaque wall.
    UI::PushStyleColor(UI::Col::ChildBg, g_palette.containerBg);
    if (UI::BeginChild("##goaladventWorkspace", vec2(0, -30), UI::ChildFlags::Borders)) {
        if (g_activeTab == 0) RenderCalendarTab();
        else if (g_activeTab == 1) RenderLeaderboardTab();
        else if (g_activeTab == 2) RenderFeedTab();
        else if (g_activeTab == 3) RenderBountyTab();
        else RenderFinaleTab();
    }
    UI::EndChild();
    UI::PopStyleColor();
}

// All options live in Openplanet -> Settings -> Plugins -> goaladvent. There is no
// separate settings window: the [Setting] declarations in Config.as are the
// single source of truth and are edited in the Openplanet menu.
void RenderDashboard() {
    RefreshPalette();   // one layout, colours chosen by the active theme

    // Apply once per plugin load: the saved ImGui size can be taller than a
    // 1024x768 game window and leave the footer off-screen.
    if (!g_windowSizeApplied) {
        UI::SetNextWindowSize(940, 580, UI::Cond::FirstUseEver);
        UI::SetNextWindowPos(24, 40, UI::Cond::Always);
        g_windowSizeApplied = true;
    }
    if (!UI::Begin("GoalAdvent 2026", g_showCalendar)) {
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
}

// ---------------------------------------------------------------------------
// Advent gift-opening animation
// ---------------------------------------------------------------------------
// Shown after a day is completed (or a bounty is stolen). It is drawn on the
// foreground draw list, so it does not create a window, does not capture the
// mouse and cannot get in the way while driving.
float Clamp01(float v) {
    if (v < 0.0f) return 0.0f;
    if (v > 1.0f) return 1.0f;
    return v;
}

float EaseOutCubic(float t) {
    t = Clamp01(t);
    float inv = 1.0f - t;
    return 1.0f - inv * inv * inv;
}

vec4 FadeCol(vec4 col, float a) {
    return vec4(col.x, col.y, col.z, col.w * Clamp01(a));
}

void StartOpenAnimation(int day, int points, int cp, bool bounty) {
    if (!S_OpenAnimation) return;
    if (day < 1 || day > DAY_COUNT) return;
    // A single run can both complete the day and steal the bounty. Keep one
    // card, merge the points and upgrade it to the bounty variant.
    bool same = g_openAnimActive && g_openAnimDay == day;
    g_openAnimActive = true;
    g_openAnimTimer = OPEN_ANIM_SEC;
    g_openAnimDay = day;
    g_openAnimPoints = (same ? g_openAnimPoints : 0) + points;
    g_openAnimCp = same && g_openAnimCp > cp ? g_openAnimCp : cp;
    g_openAnimBounty = (same && g_openAnimBounty) || bounty;
    g_openAnimTitle = g_titles[day - 1];
}

void RenderOpenAnimation() {
    if (!g_openAnimActive) return;
    float t = Clamp01(1.0f - g_openAnimTimer / OPEN_ANIM_SEC);
    float alpha = Clamp01(t / 0.10f) * (1.0f - EaseOutCubic((t - 0.84f) / 0.16f));
    if (alpha <= 0.001f) return;

    vec4 accent = g_openAnimBounty ? Gold() : IceBlue();
    vec4 bg = g_palette.windowBg;
    DrawList@ dl = UI::GetForegroundDrawList();

    const float cardW = 360.0f;
    const float cardH = 150.0f;
    float x = (Display::GetWidth() - cardW) * 0.5f;
    float y = 42.0f;

    dl.AddRectFilled(vec4(x, y, cardW, cardH),
                     FadeCol(vec4(bg.x, bg.y, bg.z, 0.95f), alpha), 10.0f);
    dl.AddRect(vec4(x, y, cardW, cardH), FadeCol(accent, alpha * 0.85f), 10.0f, 1.5f);

    // Gift geometry: the box pops in, then the lid lifts and the halo expands.
    float pop = EaseOutCubic(t / 0.16f);
    float open = EaseOutCubic((t - 0.18f) / 0.32f);
    float cx = x + 76.0f;
    float cy = y + 88.0f;
    float bw = 58.0f * (0.55f + 0.45f * pop);
    float bh = 46.0f * (0.55f + 0.45f * pop);
    float bodyTop = cy - bh * 0.5f;
    float bodyLeft = cx - bw * 0.5f;

    float ring = EaseOutCubic((t - 0.26f) / 0.58f);
    if (ring > 0.01f && ring < 0.99f) {
        dl.AddCircle(vec2(cx, bodyTop), 16.0f + 56.0f * ring,
                     FadeCol(accent, alpha * (0.55f - ring * 0.50f)), 32, 2.0f);
    }

    // Sparkles around the opening box.
    float tw = 0.55f + 0.45f * open;
    dl.AddCircleFilled(vec2(cx - 46.0f, bodyTop - 12.0f), 2.0f * tw, FadeCol(Gold(), alpha * open));
    dl.AddCircleFilled(vec2(cx + 44.0f, bodyTop - 6.0f), 2.4f * tw, FadeCol(Gold(), alpha * open));
    dl.AddCircleFilled(vec2(cx - 34.0f, bodyTop - 34.0f), 1.6f * tw, FadeCol(accent, alpha * open));
    dl.AddCircleFilled(vec2(cx + 34.0f, bodyTop - 30.0f), 1.6f * tw, FadeCol(accent, alpha * open));

    // Box body and ribbon.
    dl.AddRectFilled(vec4(bodyLeft, bodyTop, bw, bh),
                     FadeCol(vec4(accent.x * 0.32f, accent.y * 0.32f, accent.z * 0.32f, 1.0f), alpha), 3.0f);
    dl.AddRectFilled(vec4(cx - 4.0f, bodyTop, 8.0f, bh), FadeCol(accent, alpha), 1.0f);
    dl.AddRectFilled(vec4(bodyLeft, cy - 4.0f, bw, 8.0f), FadeCol(accent, alpha), 1.0f);

    // Lid rises and takes the bow with it.
    float lidLift = open * 26.0f;
    float lidH = 14.0f * (0.60f + 0.40f * pop);
    float lidW = bw + 10.0f;
    float lidY = bodyTop - lidH - lidLift;
    dl.AddRectFilled(vec4(cx - lidW * 0.5f, lidY, lidW, lidH), FadeCol(accent, alpha), 3.0f);
    dl.AddCircleFilled(vec2(cx - 7.0f, lidY - 5.0f), 6.0f, FadeCol(accent, alpha), 12);
    dl.AddCircleFilled(vec2(cx + 7.0f, lidY - 5.0f), 6.0f, FadeCol(accent, alpha), 12);
    dl.AddCircleFilled(vec2(cx, lidY - 5.0f), 3.5f, FadeCol(Gold(), alpha), 10);

    // Result text.
    float tx = x + 128.0f;
    float ty = y + 18.0f;
    string head = g_openAnimBounty
        ? "BOUNTY TAKEN"
        : ("DAY " + tostring(g_openAnimDay) + " OPENED");
    dl.AddText(vec2(tx, ty), FadeCol(accent, alpha), head, null, 16.0f);
    dl.AddText(vec2(tx, ty + 24.0f), FadeCol(TextMain(), alpha), g_openAnimTitle, null, 13.0f);
    dl.AddText(vec2(tx, ty + 44.0f), FadeCol(TextMain(), alpha),
               "+" + tostring(g_openAnimPoints) + " PTS   -   " + tostring(g_openAnimCp) + " CP",
               null, 13.0f);
    int idx = g_openAnimDay - 1;
    dl.AddText(vec2(tx, ty + 66.0f), FadeCol(TextMuted(), alpha),
               "Bounty: " + tostring(g_bountyCp[idx]) + " CP by " + g_bountyHolder[idx],
               null, 12.0f);
    dl.AddText(vec2(tx, ty + 88.0f), FadeCol(TextMuted(), alpha),
               tostring(OpenedCount()) + "/" + tostring(DAY_COUNT) + " gifts open",
               null, 12.0f);
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
    if (UI::Begin("##goaladventBanner", flags)) {
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
    if (UI::Begin("##goaladventGoalHuntHud", flags)) {
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
