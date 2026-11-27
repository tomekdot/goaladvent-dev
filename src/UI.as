// GoalAdvent 2026 - one ImGui layout, two colour themes.
// Only APIs verified against OpenplanetCore.json (1.29.14) are used.
// Theme.as owns every colour and radius; these wrappers read the active one.

bool g_confirmReset = false;
int g_activeTab = 0;   // 0 Calendar, 1 Leaderboard, 2 Live feed, 3 Bounties, 4 Finale
bool g_windowSizeApplied = false;

// One type scale for the whole dashboard - every text call uses one of these.
float FS_LABEL = 13.0f;   // labels, captions
float FS_BODY = 15.0f;    // values, sentences, table rows
float FS_TITLE = 18.0f;   // day title, app name, section headers

float UiScale() {
    float s = S_UiScale;
    if (s < 1.0f) s = 1.0f;
    if (s > 2.0f) s = 2.0f;
    return s;
}

// Geometry factor: 1.5 is the designed size, so 1.5 -> 1.0.
float UiK() { return UiScale() / 1.5f; }

// Text-only tab labels. One source for the bar and the window-width floor.
string[] TabNames() {
    string[] names = { "CALENDAR", "LEADERBOARD", "LIVE FEED", "BOUNTIES", "FINALE" };
    return names;
}

// Tab row geometry, shared by the drawing code and the window-width floor.
float TabGap() { return 3.0f * UiK(); }
float SyncButtonWidth() { return 28.0f * UiK(); }
float TabSyncGap() { return 8.0f * UiK(); }

// Width of one tab button. Measure inside the same font state used to draw the
// label; a measurement taken outside it can report a smaller advance and clip
// the last letters. The fallback is one em per character, so it cannot
// underestimate these uppercase labels when measurement is unavailable.
float TabButtonWidth(const string &in name) {
    UI::PushFontSize(FS_BODY);
    float measured = UI::MeasureString(name, null, FS_BODY).x;
    UI::PopFontSize();
    float fallback = float(int(name.Length)) * 0.68f * FS_BODY;
    float labelW = measured > fallback ? measured : fallback;
    // FramePadding is 8 px on each side plus a 1 px border; 22 px leaves a
    // small safety margin so FINALE can never be cut to "FI".
    return labelW + 22.0f * UiK();
}

// Five tab buttons, the four gaps between them, the sync button and the gap
// before it. The bar and the window floor both use this helper.
float TabRowWidth() {
    string[] names = TabNames();
    float total = 0.0f;
    for (uint i = 0; i < names.Length; i++) {
        if (i > 0) total += TabGap();
        total += TabButtonWidth(names[i]);
    }
    return total + SyncButtonWidth() + TabSyncGap();
}

// The calendar grid reads the same constants when it lays out the tiles and
// when the window computes its minimum, so the fifth column cannot be clipped.
float GridGap() { return 6.0f * UiK(); }
float GridTileMinW() { return 48.0f * UiK(); }
float GridMinWidth() { return 5.0f * GridTileMinW() + 4.0f * GridGap(); }

// Padding swallowed by the nested windows. PushDashboardStyle() sets
// WindowPadding = 14 px per side; it applies to the main window and to every
// child, including the workspace and the calendar grid. Counting only the
// outer padding leaves the tab row one child padding short, which is what
// clips FINALE and the fifth grid column.
float WindowPadWidth()    { return 2.0f * 14.0f * UiK(); }
float WorkspacePadWidth() { return 2.0f * 14.0f * UiK(); }
float GridPadWidth()      { return 2.0f * 6.0f * UiK(); }

// Minimum width of the workspace content region: the widest of the measured
// tab row, the 5x5 grid at its tile minimum, and that grid inside the 68%
// details column (plus the column gap and a usable details pane).
float WorkspaceMinWidth() {
    float tabsNeed = TabRowWidth();
    float gridNeed = GridMinWidth() + GridPadWidth();
    float detailsNeed = (GridMinWidth() + GridPadWidth()) / 0.68f +
                        8.0f * UiK() + 100.0f * UiK();
    float need = tabsNeed > gridNeed ? tabsNeed : gridNeed;
    if (need < detailsNeed) need = detailsNeed;
    return need;
}

void ApplyUiScale() {
    float s = UiScale();
    FS_LABEL = 13.0f * s;
    FS_BODY = 15.0f * s;
    FS_TITLE = 18.0f * s;
}

// ---------------------------------------------------------------------------
// Palette accessors
// ---------------------------------------------------------------------------
vec4 Gold()      { return g_palette.gold; }
vec4 Emerald()   { return g_palette.emerald; }
vec4 Crimson()   { return g_palette.crimson; }
vec4 Purple()    { return g_palette.purple; }
vec4 Navy()      { return g_palette.navy; }
vec4 InnerBg()   { return g_palette.innerBg; }
vec4 Silver()    { return g_palette.silver; }
vec4 Bronze()    { return g_palette.bronze; }
vec4 Teal()      { return g_palette.teal; }
vec4 DimNavy()   { return g_palette.dimNavy; }
vec4 TextMain()  { return g_palette.text; }

vec4 MixCol(vec4 a, vec4 b, float t) {
    return vec4(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t,
                a.z + (b.z - a.z) * t, a.w + (b.w - a.w) * t);
}

vec4 TextMuted() { return MixCol(g_palette.textMuted, g_palette.text, 0.40f); }
vec4 TileBg()    { return g_palette.tileBg; }
vec4 TileSelectedBg() { return g_palette.tileSelectedBg; }
vec4 IceBlue()   { return g_palette.iceBlue; }

// Checkpoint tier colours: emerald = done, silver = 15 CP, gold = 30 CP.
vec4 CpTierColour(int tier) {
    if (tier >= 3) return Gold();
    if (tier == 2) return Silver();
    if (tier == 1) return Emerald();
    return TextMuted();
}

string EventCountdown() {
    Time::Info now = Time::ParseUTC();
    if (now.Month == 12) return "";
    int days = 0;
    if (now.Month == 11) days = 31 - now.Day;
    else if (now.Month < 11) days = (11 - now.Month) * 30 + (31 - now.Day);
    if (days <= 0) return "";
    return "Event starts Dec 1 (in " + tostring(days) + (days == 1 ? " day)" : " days)");
}

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
    float a = col.w;
    if (a < 0.99f) {
        a += 0.10f;
        if (a > 1.00f) a = 1.00f;
    }
    float r = col.x + 0.08f; if (r > 1.00f) r = 1.00f;
    float g = col.y + 0.08f; if (g > 1.00f) g = 1.00f;
    float b = col.z + 0.08f; if (b > 1.00f) b = 1.00f;
    return vec4(r, g, b, a);
}

void TextTone(const vec4 &in col, const string &in text) {
    UI::PushStyleColor(UI::Col::Text, col);
    UI::Text(text);
    UI::PopStyleColor();
}

void TextToneWrapped(const vec4 &in col, const string &in text) {
    UI::PushStyleColor(UI::Col::Text, col);
    UI::TextWrapped(text);
    UI::PopStyleColor();
}

void DrawDot(vec2 pos, float radius, vec4 col) {
    UI::GetWindowDrawList().AddCircleFilled(pos, radius, col, 8);
}

void DrawSectionHeader(const string &in title, const string &in suffix = "") {
    vec2 p = UI::GetCursorScreenPos();
    UI::GetWindowDrawList().AddRectFilled(
        vec4(p.x, p.y + 2.0f * UiK(), 3.0f * UiK(), 15.0f * UiK()),
        g_palette.iceBlue);
    UI::Dummy(vec2(12.0f * UiK(), 0));
    UI::SameLine(0, 0);
    UI::PushFontSize(FS_BODY);
    TextTone(MixCol(TextMuted(), TextMain(), 0.65f), title);
    UI::PopFontSize();
    if (suffix.Length > 0) {
        UI::SameLine(0, 8.0f * UiK());
        UI::PushFontSize(FS_LABEL);
        TextTone(TextMuted(), suffix);
        UI::PopFontSize();
    }
    UI::Dummy(vec2(0, 5));
}

// Compact stat card: sharp corners, 2 px accent bar on the left.
void DrawStatCard(const string &in icon, const string &in label,
                  const string &in value, vec4 accent) {
    UI::PushStyleColor(UI::Col::ChildBg, g_palette.tileBg);
    UI::PushStyleColor(UI::Col::Border, g_palette.tileEdge);
    UI::PushStyleVar(UI::StyleVar::ChildRounding, 0.0f);
    UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(12.0f * UiK(), 8.0f * UiK()));
    UI::PushStyleVar(UI::StyleVar::ScrollbarSize, 0.0f);
    int flags = UI::WindowFlags::NoScrollbar | UI::WindowFlags::NoScrollWithMouse;
    if (UI::BeginChild("##stat" + label + icon, vec2(0, 58.0f * UiK()), UI::ChildFlags::Borders, flags)) {
        vec2 start = UI::GetCursorPos();
        UI::PushFontSize(FS_LABEL);
        TextTone(accent, icon);
        UI::PopFontSize();
        UI::SameLine(0, 6.0f * UiK());
        UI::PushFontSize(FS_LABEL);
        TextTone(TextMuted(), label);
        UI::PopFontSize();
        UI::SetCursorPos(vec2(start.x, start.y + 20.0f * UiK()));
        UI::PushFontSize(FS_BODY);
        TextToneWrapped(TextMain(), value);
        UI::PopFontSize();
    }
    UI::EndChild();
    vec4 r = UI::GetItemRect();
    UI::GetWindowDrawList().AddRectFilled(vec4(r.x, r.y, 2.0f * UiK(), r.w), accent);
    UI::PopStyleVar(3);
    UI::PopStyleColor(2);
}

// Glass card with a dark footer strip for the title.
void DrawGlassBoxCard(const string &in icon, const string &in title,
                      const string &in value, vec4 accent, float w, float h) {
    UI::PushStyleVar(UI::StyleVar::FrameRounding, 0.0f);
    UI::PushStyleVar(UI::StyleVar::FrameBorderSize, 1.0f);
    UI::PushStyleColor(UI::Col::Border, g_palette.tileEdge);
    UI::PushStyleColor(UI::Col::Button, g_palette.tileBg);
    UI::PushStyleColor(UI::Col::ButtonHovered, g_palette.tileBg);
    UI::PushStyleColor(UI::Col::ButtonActive, g_palette.tileBg);

    UI::Button("##glasscard_" + title, vec2(w, h));
    vec4 r = UI::GetItemRect();
    UI::DrawList@ dl = UI::GetWindowDrawList();

    // 2 px left accent.
    dl.AddRectFilled(vec4(r.x, r.y, 2.0f * UiK(), r.w), accent);

    // Dark bottom bar.
    float barH = 22.0f * UiK();
    dl.AddRectFilled(vec4(r.x, r.y + r.w - barH, r.z, barH), g_palette.tileFooter);

    vec2 titleSz = UI::MeasureString(title, null, FS_LABEL);
    dl.AddText(vec2(r.x + (r.z - titleSz.x) * 0.5f,
                    r.y + r.w - barH + (barH - titleSz.y) * 0.5f),
               TextMuted(), title, null, FS_LABEL);

    // Centred icon + value in the glass area.
    float glassH = r.w - barH;
    string fullLine = icon + "  " + value;
    vec2 valSz = UI::MeasureString(fullLine, null, FS_BODY);
    float tx = r.x + (r.z - valSz.x) * 0.5f;
    float ty = r.y + (glassH - valSz.y) * 0.5f;
    vec2 iconSz = UI::MeasureString(icon + "  ", null, FS_BODY);
    dl.AddText(vec2(tx, ty), accent, icon, null, FS_BODY);
    dl.AddText(vec2(tx + iconSz.x, ty), TextMain(), value, null, FS_BODY);

    UI::PopStyleColor(4);
    UI::PopStyleVar(2);
}

// Glass action button (buttons are glass, consistent with the tiles).
bool GlassButton(const string &in label, vec2 size = vec2(0, 0)) {
    UI::PushStyleVar(UI::StyleVar::FrameRounding, 0.0f);
    UI::PushStyleVar(UI::StyleVar::FrameBorderSize, 1.0f);
    UI::PushStyleColor(UI::Col::Border, g_palette.tileEdge);
    UI::PushStyleColor(UI::Col::Button, g_palette.tileBg);
    UI::PushStyleColor(UI::Col::ButtonHovered, g_palette.tileHover);
    UI::PushStyleColor(UI::Col::ButtonActive, Lift(g_palette.tileHover));
    UI::PushStyleColor(UI::Col::Text, TextMain());
    bool clicked = UI::Button(label, size);
    UI::PopStyleColor(5);
    UI::PopStyleVar(2);
    return clicked;
}

// ---------------------------------------------------------------------------
// Dashboard style
// ---------------------------------------------------------------------------
void PushDashboardStyle() {
    UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(14.0f * UiK(), 12.0f * UiK()));
    UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(10.0f * UiK(), 8.0f * UiK()));
    UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(8.0f * UiK(), 4.0f * UiK()));
    UI::PushStyleVar(UI::StyleVar::WindowRounding, 0.0f);
    UI::PushStyleVar(UI::StyleVar::ChildRounding, 0.0f);
    UI::PushStyleVar(UI::StyleVar::FrameRounding, 0.0f);
    UI::PushStyleVar(UI::StyleVar::GrabRounding, 0.0f);
    UI::PushStyleVar(UI::StyleVar::TabRounding, 0.0f);
    UI::PushStyleVar(UI::StyleVar::ChildBorderSize, 1.0f);
    UI::PushStyleVar(UI::StyleVar::FrameBorderSize, 1.0f);
    UI::PushStyleVar(UI::StyleVar::TabBorderSize, 0.0f);
    UI::PushStyleVar(UI::StyleVar::TabBarBorderSize, 0.0f);

    UI::PushStyleColor(UI::Col::WindowBg, g_palette.windowBg);
    UI::PushStyleColor(UI::Col::ChildBg, g_palette.containerBg);
    UI::PushStyleColor(UI::Col::FrameBg, g_palette.tileBg);
    UI::PushStyleColor(UI::Col::Border, g_palette.tileEdge);
    UI::PushStyleColor(UI::Col::Separator, g_palette.tileEdge);
    UI::PushStyleColor(UI::Col::Tab, g_palette.tabBg);
    UI::PushStyleColor(UI::Col::TabActive, g_palette.tabActiveBg);
    UI::PushStyleColor(UI::Col::TabSelected, g_palette.tabActiveBg);
    UI::PushStyleColor(UI::Col::TabHovered, g_palette.tabHoverBg);
    UI::PushStyleColor(UI::Col::TableHeaderBg, g_palette.tableHeaderBg);
    UI::PushStyleColor(UI::Col::Button, g_palette.tileBg);
    UI::PushStyleColor(UI::Col::ButtonHovered, g_palette.tileHover);
    UI::PushStyleColor(UI::Col::ButtonActive, Lift(g_palette.tileHover));
    UI::PushStyleColor(UI::Col::Text, g_palette.text);
    UI::PushStyleColor(UI::Col::TextDisabled, TextMuted());
}

void PopDashboardStyle() {
    UI::PopStyleColor(15);
    UI::PopStyleVar(12);
}

// Kept for compatibility (not called in the main window).
void RenderHeaderCard() {}
void RenderFooter() {}

// ---------------------------------------------------------------------------
// Calendar grid
// ---------------------------------------------------------------------------
vec4 DayAccent(int day) {
    if (day == DAY_COUNT) return Gold();
    if (IsOffDay(day)) return Purple();
    if (g_opened[day - 1]) return Emerald();
    if (IsPremiereDay(day)) return Gold();
    if (DayPlayableNow(day)) return Crimson();
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

int NextGoalHuntDay(int from) {
    for (int d = from + 1; d <= DAY_COUNT; d++) {
        if (!IsOffDay(d)) return d;
    }
    return DAY_COUNT;
}

string DayTileShort(int day) {
    return day < 10 ? "0" + tostring(day) : tostring(day);
}

string DayTileStatus(int day, float tileW) {
    if (day == DAY_COUNT) return "FINAL";
    if (IsOffDay(day)) return "REST";
    if (g_opened[day - 1]) return "DONE";
    if (IsPremiereDay(day)) return "x2";
    if (S_ShowMoonPct && tileW >= 40.0f * UiK()) {
        return tostring(MoonIlluminationPct(day)) + "%";
    }
    return "";
}

bool DrawCenteredDayTile(int day, const string &in icon, const string &in label,
                         const string &in statusLine, vec4 bgCol, vec4 _textCol,
                         vec4 accent, bool isSelected, bool _isToday, int cpTier,
                         float tileW, float tileH) {
    if (S_TraditionalTiles) {
        vec4 tint = MixCol(vec4(bgCol.x, bgCol.y, bgCol.z, 1.0f),
                           vec4(accent.x, accent.y, accent.z, 1.0f), 0.85f);
        bgCol = vec4(tint.x, tint.y, tint.z, 0.30f);
    }
    // The border still marks a completed day; the tile surface stays light.
    bool completed = g_opened[day - 1];
    vec4 em = Emerald();
    UI::PushStyleVar(UI::StyleVar::FrameBorderSize,
                     isSelected ? 2.0f : (cpTier > 0 || completed ? 2.0f : 1.0f));
    UI::PushStyleVar(UI::StyleVar::FrameRounding, 0.0f);
    vec4 edgeCol = S_TraditionalTiles ? MixCol(g_palette.tileEdge, accent, 0.65f)
                                      : g_palette.tileEdge;
    // Selection border is enough; no corner badges are drawn over the tiles.
    vec4 borderCol = isSelected
        ? vec4(1.0f, 1.0f, 1.0f, 0.95f)
        : (cpTier > 0 ? CpTierColour(cpTier) : (completed ? em : edgeCol));
    UI::PushStyleColor(UI::Col::Border, borderCol);
    UI::PushStyleColor(UI::Col::Button, bgCol);
    UI::PushStyleColor(UI::Col::ButtonHovered, g_palette.tileHover);
    UI::PushStyleColor(UI::Col::ButtonActive, Lift(g_palette.tileHover));
    UI::PushStyleColor(UI::Col::Text, g_palette.text);

    bool clicked = UI::Button("##goaladventtile" + tostring(day), vec2(tileW, tileH));
    vec4 r = UI::GetItemRect();
    float cx = r.x + r.z * 0.5f;
    UI::DrawList@ dl = UI::GetWindowDrawList();

    float barH = 24.0f * UiK();
    dl.AddRectFilled(vec4(r.x, r.y + r.w - barH, r.z, barH), g_palette.tileFooter);
    string caption = label;
    if (statusLine.Length > 0) caption += " | " + statusLine;
    vec2 capSize = UI::MeasureString(caption, null, FS_LABEL);
    if (capSize.x > tileW - 6.0f * UiK() && statusLine.Length > 0) {
        caption = label;
        capSize = UI::MeasureString(caption, null, FS_LABEL);
    }
    dl.AddText(vec2(cx - capSize.x * 0.5f,
                    r.y + r.w - barH + (barH - capSize.y) * 0.5f),
               TextMain(), caption, null, FS_LABEL);

    vec2 iconSize = UI::MeasureString(icon, null, FS_TITLE);
    float glassH = r.w - barH;
    vec4 iconCol = MixCol(accent, vec4(1.0f, 1.0f, 1.0f, 1.0f), 0.25f);
    dl.AddText(vec2(cx - iconSize.x * 0.5f, r.y + (glassH - iconSize.y) * 0.5f),
               iconCol, icon, null, FS_TITLE);

    // The completed state is already the centre icon plus the DONE caption.
    // Corner checkmarks and tier dots looked like stray glyphs on every tile.

    UI::PopStyleColor(5);
    UI::PopStyleVar(2);
    return clicked;
}

void RenderDayGrid() {
    if (S_ShowTips) {
        string rules = "Tue: Pursuit rest | Premiere day: x2 pts";
        string countdown = EventCountdown();
        string info = countdown.Length > 0
            ? countdown + " | " + rules
            : "Dec 1 to " + tostring(DAY_COUNT) + " | " + rules;
        UI::PushFontSize(FS_LABEL);
        TextTone(TextMuted(), info);
        UI::PopFontSize();
        UI::Dummy(vec2(0, 2.0f * UiK()));
    }

    vec2 origin = UI::GetCursorPos();
    vec2 avail = UI::GetContentRegionAvail();
    const float spacing = GridGap();
    float minTileH = UI::MeasureString("00", null, FS_TITLE).y + 34.0f * UiK();
    float tileH = (avail.y - 4.0f * spacing) / 5.0f;
    if (tileH < minTileH) tileH = minTileH;
    if (tileH > 130.0f * UiK()) tileH = 130.0f * UiK();
    float tileW = (avail.x - 4.0f * spacing) / 5.0f;
    if (tileW < GridTileMinW()) tileW = GridTileMinW();
    if (tileW > 200.0f * UiK()) tileW = 200.0f * UiK();
    float gridW = 5.0f * tileW + 4.0f * spacing;
    float gridX = origin.x + (avail.x - gridW) * 0.5f;
    // Never push the first or fifth column outside the panel; a negative
    // centering offset would clip both edges instead of centering the grid.
    if (gridX < origin.x) gridX = origin.x;
    int today = CurrentEventDayUtc();

    for (int day = 1; day <= DAY_COUNT; day++) {
        int col = (day - 1) % 5;
        int row = (day - 1) / 5;
        UI::SetCursorPos(vec2(gridX + col * (tileW + spacing),
                              origin.y + row * (tileH + spacing)));

        vec4 accent = DayAccent(day);
        bool lockedDay = !IsOffDay(day) && !DayUnlocked(day);
        if (lockedDay) {
            accent = vec4(g_palette.textMuted.x, g_palette.textMuted.y,
                          g_palette.textMuted.z, 0.35f);
        }
        vec4 textCol = MixCol(TextMain(), accent, 0.35f);
        if (IsOffDay(day) || lockedDay) textCol = MixCol(textCol, TextMuted(), 0.35f);
        string statusLine = DayTileStatus(day, tileW);
        vec4 bg = (day == g_selectedDay) ? TileSelectedBg() : TileBg();
        int best = BestCp(day);
        int tier = CpTier(best);
        if (DrawCenteredDayTile(day, DayTileIcon(day), DayTileShort(day), statusLine,
                                bg, textCol, accent, day == g_selectedDay,
                                day == today && today > 0, tier, tileW, tileH)) {
            g_selectedDay = day;
            g_confirmReset = false;
        }
        UI::SetItemTooltip(MoonPhaseName(day) + " | " +
                           tostring(MoonIlluminationPct(day)) + "% lit\n" +
                           "Bounty: " + tostring(g_bountyCp[day - 1]) + " CP | " +
                           Text::StripFormatCodes(g_bountyHolder[day - 1]) + "\n" +
                           "Best: " + tostring(best) + " CP | " + CpTierLabel(tier) + "\n" +
                           MilestoneSummary(best) + "\n" +
                           g_hints[day - 1]);
    }
    UI::SetCursorPos(vec2(origin.x, origin.y + 5.0f * tileH + 4.0f * spacing));
    UI::Dummy(vec2(0, 1));
}

string FitLabel(const string &in longLabel, const string &in shortLabel, float maxW) {
    vec2 ts = UI::MeasureString(longLabel, null, FS_BODY);
    if (ts.x + 20.0f * UiK() <= maxW) return longLabel;
    return shortLabel;
}

// Three steps: full text, short text, then a stub that always fits. The stub
// matters in a narrow window - a label wider than its button gets clipped by
// the window edge, which looks like the button itself was cut off.
string FitLabel3(const string &in full, const string &in short,
                 const string &in stub, float maxW) {
    if (UI::MeasureString(full, null, FS_BODY).x + 20.0f * UiK() <= maxW) return full;
    if (UI::MeasureString(short, null, FS_BODY).x + 20.0f * UiK() <= maxW) return short;
    return stub;
}

bool CenteredButton(const string &in label) {
    UI::PushFontSize(FS_BODY);
    float btnW = UI::MeasureString(label, null, FS_BODY).x + 20.0f * UiK();
    float avail = UI::GetContentRegionAvail().x;
    if (btnW < avail) {
        UI::SetCursorPosX(UI::GetCursorPos().x + (avail - btnW) * 0.5f);
    }
    bool clicked = GlassButton(label, vec2(btnW, 30.0f * UiK()));
    UI::PopFontSize();
    return clicked;
}

void DetailLine(const string &in label, const string &in value, vec4 valueCol) {
    UI::PushFontSize(FS_LABEL);
    TextTone(TextMuted(), label);
    UI::PopFontSize();
    UI::PushFontSize(FS_BODY);
    TextToneWrapped(valueCol, value);
    UI::PopFontSize();
}

// One source for the status colour used by the details pane and the day bar.
// Same precedence as DayStatusText(): locked -> completed -> rest -> premiere.
vec4 DayStatusColour(int day) {
    bool locked = !IsOffDay(day) && !DayUnlocked(day);
    if (locked) return TextMuted();
    if (IsOffDay(day)) return Purple();
    if (g_opened[day - 1]) return Emerald();
    if (IsPremiereDay(day)) return Gold();
    if (!DayPlayableNow(day)) return TextMuted();
    return Emerald();
}

// One source for the status line used by the details pane and the day bar.
string DayStatusText(int day) {
    bool locked = !IsOffDay(day) && !DayUnlocked(day);
    string status = "Available";
    if (locked) {
        status = "Locked until Dec " + tostring(day);
    } else if (g_opened[day - 1]) {
        status = "Completed";
    } else if (IsOffDay(day)) {
        // The tile and the details card already say "rest day". Repeating it
        // under the day title only crowds the row.
        status = "";
    } else if (IsPremiereDay(day)) {
        status = "Premiere | double points";
    } else if (!DayPlayableNow(day)) {
        status = "Waiting for the event";
    }
    int detectedDay = DetectGoalHuntDay();
    if (!IsOffDay(day) && detectedDay > 0) {
        status += " | map #" + tostring(detectedDay);
    }
    return status;
}

void RenderDayDetails() {
    int day = g_selectedDay;
    if (day < 1 || day > DAY_COUNT) day = 1;

    bool locked = !IsOffDay(day) && !DayUnlocked(day);

    UI::PushFontSize(FS_TITLE);
    TextTone(TextMain(), "DAY " + tostring(day) + " | " + g_titles[day - 1]);
    UI::PopFontSize();
    vec4 statusCol = DayStatusColour(day);
    string status = DayStatusText(day);
    if (status.Length > 0) {
        UI::PushFontSize(FS_BODY);
        TextTone(statusCol, status);
        UI::PopFontSize();
    }

    int best = BestCp(day);
    int tier = CpTier(best);
    if (IsOffDay(day)) {
        DetailLine("PURSUIT BONUS", "20:00 CET (19:00 UTC)", Purple());
        DetailLine("MOON", MoonPhaseName(day) + " | " + tostring(MoonIlluminationPct(day)) + "% lit", TextMain());
        DetailLine("STREAK", "Protected | no race tonight", Emerald());
    } else {
        DetailLine("BOUNTY", tostring(g_bountyCp[day - 1]) + " CP | " +
                   Text::StripFormatCodes(g_bountyHolder[day - 1]), Gold());
        DetailLine("GOAL", "Catch " + tostring(GOAL_CP) + " CP in one run | best " +
                   tostring(best) + " CP", TextMain());
        DetailLine("RUN TIER", CpTierLabel(tier) + " | silver " + tostring(SILVER_CP) +
                   " CP | gold " + tostring(GOLD_CP) + " CP", CpTierColour(tier));
        DetailLine("MILESTONE", "reached " + tostring(LastMilestone(best)) + " CP | " +
                   MilestoneText(best), Emerald());
        DetailLine("MOON", MoonPhaseName(day) + " | " + tostring(MoonIlluminationPct(day)) + "% lit", TextMain());
    }
    if (locked) {
        UI::TextDisabled("This gift opens on December " + tostring(day) + ".");
    } else if (!IsOffDay(day)) {
        UI::TextWrapped(g_hints[day - 1]);
    }
}

void RenderDayAction(int day) {
    const float rowH = 38.0f * UiK();
    bool locked = !IsOffDay(day) && !DayUnlocked(day);
    float maxW = UI::GetContentRegionAvail().x;

    if (locked || IsOffDay(day)) {
        UI::BeginDisabled(true);
        UI::PushStyleVar(UI::StyleVar::FrameRounding, 0.0f);
        UI::PushStyleVar(UI::StyleVar::FrameBorderSize, 1.0f);
        UI::PushStyleColor(UI::Col::Border, g_palette.tileEdge);
        UI::PushStyleColor(UI::Col::Button, vec4(0.0f, 0.0f, 0.0f, 0.35f));
        UI::PushStyleColor(UI::Col::Text, TextMuted());
        if (locked) {
            UI::Button(FitLabel("AVAILABLE DEC " + tostring(day),
                                "OPENS DEC " + tostring(day), maxW), vec2(-1, rowH));
        } else {
            UI::Button(FitLabel("Next hunt: Dec " + tostring(NextGoalHuntDay(day)),
                                "Hunt: Dec " + tostring(NextGoalHuntDay(day)), maxW), vec2(-1, rowH));
            UI::SetItemTooltip("No race tonight | next Goal Hunt: Dec " +
                               tostring(NextGoalHuntDay(day)));
        }
        UI::PopStyleColor(3);
        UI::PopStyleVar(2);
        UI::EndDisabled();
        return;
    }

    string action = S_TestMode ? "SUBMIT TEST (12)" : "OPEN DAY " + tostring(day);
    string actionShort = S_TestMode ? "TEST (12)" : "OPEN " + tostring(day);
    if (GlassButton(FitLabel(action, actionShort, maxW), vec2(-1, rowH))) {
        if (S_TestMode) {
            RequestCpSubmit(day, 12);
            g_status = "Test CP submitted for day " + tostring(day) + ".";
        } else {
            g_status = "Join #" + tostring(day) + " Goal Hunt on the event server. Checkpoints are counted automatically.";
        }
    }
    UI::SetItemTooltip("Join #" + tostring(day) + " Goal Hunt | reach " + tostring(GOAL_CP) +
                       " CP in one run to complete this day.");
}

void RenderDayBar(int day) {
    bool locked = !IsOffDay(day) && !DayUnlocked(day);
    vec4 statusCol = DayStatusColour(day);
    string status = DayStatusText(day);

    vec2 rowStart = UI::GetCursorPos();
    float contentW = UI::GetContentRegionAvail().x;
    float rowH = 30.0f * UiK();
    float gap = 10.0f * UiK();

    // The day title keeps its space; the action takes the rest, up to 70%.
    // A right inset keeps the button off the border instead of being clipped.
    string dayTitle = "DAY " + tostring(day) + " | " + g_titles[day - 1];
    float titleMeasure = UI::MeasureString(dayTitle, null, FS_BODY).x;
    float minTitleW = titleMeasure + gap;
    if (minTitleW > contentW * 0.55f) minTitleW = contentW * 0.55f;
    float maxBtnW = contentW - minTitleW - gap;
    if (maxBtnW > contentW * 0.70f) maxBtnW = contentW * 0.70f;
    if (maxBtnW < 110.0f * UiK()) maxBtnW = 110.0f * UiK();

    string label;
    if (locked) {
        label = FitLabel3("AVAILABLE DEC " + tostring(day), "OPENS DEC " + tostring(day),
                          "LOCKED", maxBtnW);
    } else if (IsOffDay(day)) {
        label = FitLabel3("Next hunt: Dec " + tostring(NextGoalHuntDay(day)),
                          "Hunt: Dec " + tostring(NextGoalHuntDay(day)), "NEXT", maxBtnW);
    } else {
        label = FitLabel3(S_TestMode ? "SUBMIT TEST (12)" : "OPEN DAY " + tostring(day),
                          S_TestMode ? "TEST (12)" : "OPEN " + tostring(day),
                          S_TestMode ? "TEST" : "OPEN", maxBtnW);
    }
    float btnW = UI::MeasureString(label, null, FS_BODY).x + 20.0f * UiK();
    if (btnW > maxBtnW) btnW = maxBtnW;
    if (btnW < 90.0f * UiK()) btnW = 90.0f * UiK();

    float leftAvail = contentW - btnW - 2.0f * gap;
    float statusW = status.Length > 0
        ? UI::MeasureString(status, null, FS_LABEL).x + gap : 0.0f;
    UI::PushFontSize(FS_BODY);
    TextTone(TextMain(), dayTitle);
    UI::PopFontSize();
    if (status.Length > 0 && titleMeasure + statusW <= leftAvail) {
        UI::SameLine(0, gap);
        UI::PushFontSize(FS_LABEL);
        TextTone(statusCol, status);
        UI::PopFontSize();
    } else if (status.Length > 0) {
        UI::SetItemTooltip(status);
    }

    // The button frame is taller than the text, so lift it: its label then
    // centres on the "DAY N | ..." line instead of sitting near the row bottom.
    float btnX = rowStart.x + contentW - btnW - 6.0f * UiK();
    if (btnX < rowStart.x) btnX = rowStart.x;
    float btnY = rowStart.y - 8.0f * UiK();
    if (btnY < 0.0f) btnY = 0.0f;
    UI::SetCursorPos(vec2(btnX, btnY));

    bool clicked = false;
    UI::PushFontSize(FS_BODY);
    if (locked || IsOffDay(day)) {
        UI::BeginDisabled(true);
        UI::PushStyleVar(UI::StyleVar::FrameRounding, 0.0f);
        UI::PushStyleVar(UI::StyleVar::FrameBorderSize, 1.0f);
        UI::PushStyleColor(UI::Col::Border, g_palette.tileEdge);
        UI::PushStyleColor(UI::Col::Button, vec4(0.0f, 0.0f, 0.0f, 0.35f));
        UI::PushStyleColor(UI::Col::Text, TextMuted());
        UI::Button(label, vec2(btnW, rowH));
        if (!locked) {
            UI::SetItemTooltip("No race tonight | next Goal Hunt: Dec " +
                               tostring(NextGoalHuntDay(day)));
        }
        UI::PopStyleColor(3);
        UI::PopStyleVar(2);
        UI::EndDisabled();
    } else {
        clicked = GlassButton(label, vec2(btnW, rowH));
    }
    UI::PopFontSize();
    if (locked || IsOffDay(day)) return;

    if (clicked) {
        if (S_TestMode) {
            RequestCpSubmit(day, 12);
            g_status = "Test CP submitted for day " + tostring(day) + ".";
        } else {
            g_status = "Join #" + tostring(day) + " Goal Hunt on the event server | CP count automatically.";
        }
    }
    UI::SetItemTooltip("Join #" + tostring(day) + " Goal Hunt | reach " + tostring(GOAL_CP) +
                       " CP in one run to complete this day.");
}

// ---------------------------------------------------------------------------
// Workspace panes
// ---------------------------------------------------------------------------
void RenderCalendarGrid(float w, float hReserve) {
    UI::PushStyleColor(UI::Col::ChildBg, g_palette.containerBg);
    UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(6.0f * UiK(), 6.0f * UiK()));
    UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(6.0f * UiK(), 4.0f * UiK()));
    UI::PushStyleVar(UI::StyleVar::ScrollbarSize, 0.0f);
    int gridFlags = UI::WindowFlags::NoScrollbar | UI::WindowFlags::NoScrollWithMouse;
    if (UI::BeginChild("##goaladventCalendarGrid", vec2(w, hReserve), UI::ChildFlags::None, gridFlags)) {
        DrawSectionHeader("ADVENT CALENDAR",
                          "OPENED | " + tostring(OpenedCount()) + " / " + tostring(DAY_COUNT));
        UI::SetItemTooltip("REST = Pursuit night | FINAL = day " + tostring(DAY_COUNT) +
                           " finale | DONE = completed | gray gift = opens later");
        RenderDayGrid();
    }
    UI::EndChild();
    UI::PopStyleVar(3);
    UI::PopStyleColor();
}

void RenderCalendarTab() {
    int day = g_selectedDay;
    if (day < 1 || day > DAY_COUNT) day = 1;

    if (!S_ShowDayDetails) {
        RenderCalendarGrid(0, -48.0f * UiK());
        // Room for the action button to sit on the title line, not below it.
        UI::Dummy(vec2(0, 12.0f * UiK()));
        RenderDayBar(day);
        return;
    }

    float width = UI::GetContentRegionAvail().x;
    float leftW = width * 0.68f;
    float rightW = width - leftW - 8.0f * UiK();
    RenderCalendarGrid(leftW, 0);
    UI::SameLine(0, 8.0f * UiK());
    UI::PushStyleColor(UI::Col::ChildBg, g_palette.containerBg);
    UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(8.0f * UiK(), 6.0f * UiK()));
    UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(10.0f * UiK(), 6.0f * UiK()));
    if (UI::BeginChild("##goaladventDayDetailsCard", vec2(rightW, 0), UI::ChildFlags::None)) {
        DrawSectionHeader("DAY DETAILS");
        int gridFlags = UI::WindowFlags::NoScrollbar | UI::WindowFlags::NoScrollWithMouse;
        UI::PushStyleColor(UI::Col::ChildBg, g_palette.containerBg);
        UI::PushStyleVar(UI::StyleVar::ScrollbarSize, 0.0f);
        if (UI::BeginChild("##goaladventDayDetailsBody", vec2(0, -46.0f * UiK()), UI::ChildFlags::None, gridFlags)) {
            RenderDayDetails();
        }
        UI::EndChild();
        UI::PopStyleVar();
        UI::PopStyleColor();
        RenderDayAction(day);
    }
    UI::EndChild();
    UI::PopStyleVar(2);
    UI::PopStyleColor();
}

// ManiaPlanet nicknames carry inline colour codes ($fff, $48b, $z, ...).
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
            if (control == "z") colour = fallback;
            i += 2;
            continue;
        }
        i++;
    }
}

bool FeedEventIsMine(const string &in line) {
    string me = Text::StripFormatCodes(LocalName()).Trim().ToLower();
    if (me.Length == 0) return false;
    string plain = Text::StripFormatCodes(line).ToLower();
    return plain.Contains(me);
}

vec4 FeedEventColour(const string &in line) {
    string plain = Text::StripFormatCodes(line).ToLower();
    if (plain.Contains("bounty") || plain.Contains("stole") || plain.Contains("record")) {
        return Gold();
    }
    if (plain.Contains("finished") || plain.Contains("completed") ||
        plain.Contains("reached") || plain.Contains("finale")) {
        return Emerald();
    }
    if (plain.Contains("pursuit") || plain.Contains("rest")) {
        return Purple();
    }
    return IceBlue();
}

void RenderLeaderboardTab() {
    DrawSectionHeader("LEADERBOARD", tostring(int(g_boardNames.Length)) + " players");
    if (g_boardNames.Length == 0) {
        UI::TextDisabled("No entries yet. They appear after the first submitted run.");
        UI::BeginDisabled(g_syncing);
        if (CenteredButton(Icons::Refresh + " Refresh")) SyncNow();
        UI::EndDisabled();
        return;
    }

    int flags = UI::TableFlags::RowBg | UI::TableFlags::PadOuterX;
    UI::PushStyleColor(UI::Col::TableRowBg, vec4(0.10, 0.10, 0.11, 0.55));
    UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14, 0.14, 0.15, 0.55));
    UI::PushFontSize(FS_BODY);
    if (UI::BeginTable("##goaladventBoardTable", 4, flags)) {
        UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 36.0f * UiK());
        UI::TableSetupColumn("PLAYER", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("POINTS", UI::TableColumnFlags::WidthFixed, 84.0f * UiK());
        UI::TableSetupColumn("BOUNTIES", UI::TableColumnFlags::WidthFixed, 88.0f * UiK());
        UI::TableHeadersRow();
        for (uint i = 0; i < g_boardNames.Length; i++) {
            UI::TableNextRow();
            bool mine = i < g_boardAccountIds.Length && g_boardAccountIds[i] == AccountId();
            if (!mine && g_boardNames[i] == LocalName() &&
                (i >= g_boardAccountIds.Length || g_boardAccountIds[i].Length == 0)) {
                mine = true;
            }
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
            else if (mine) TextTone(IceBlue(), tostring(int(i) + 1));
            else TextTone(TextMuted(), tostring(int(i) + 1));
            UI::TableSetColumnIndex(1);
            DrawMpName(g_boardNames[i], mine ? Gold() : TextMain());
            if (mine) {
                UI::SameLine(0, 6);
                TextTone(TextMuted(), "(you)");
            }
            UI::SetItemTooltip(Text::StripFormatCodes(g_boardNames[i]));
            UI::TableSetColumnIndex(2);
            TextTone(Gold(), tostring(g_boardPoints[i]));
            UI::TableSetColumnIndex(3);
            UI::Text(tostring(g_boardBounties[i]));
        }
        UI::EndTable();
    }
    UI::PopFontSize();
    UI::PopStyleColor(2);
    UI::BeginDisabled(g_syncing);
    if (CenteredButton(Icons::Refresh + " Refresh leaderboard")) SyncNow();
    UI::EndDisabled();
}

void RenderFeedTab() {
    DrawSectionHeader("LIVE FEED", tostring(int(g_liveFeed.Length)) + " events");
    if (g_liveFeed.Length == 0) {
        UI::TextDisabled("Nothing here yet | complete a day or take a bounty.");
        UI::BeginDisabled(g_syncing);
        if (CenteredButton(Icons::Refresh + " Refresh")) SyncNow();
        UI::EndDisabled();
        return;
    }

    int flags = UI::TableFlags::RowBg | UI::TableFlags::PadOuterX;
    UI::PushStyleColor(UI::Col::TableRowBg, vec4(0.10, 0.10, 0.11, 0.55));
    UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14, 0.14, 0.15, 0.55));
    UI::PushFontSize(FS_BODY);
    if (UI::BeginTable("##goaladventFeedTable", 2, flags)) {
        UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 36.0f * UiK());
        UI::TableSetupColumn("EVENT", UI::TableColumnFlags::WidthStretch);
        UI::TableHeadersRow();
        for (uint i = 0; i < g_liveFeed.Length; i++) {
            UI::TableNextRow();
            bool mine = FeedEventIsMine(g_liveFeed[i]);
            vec4 evCol = FeedEventColour(g_liveFeed[i]);

            // Same visual language as the leaderboard: Navy for your own rows,
            // a subtle podium-like tint for the three newest events.
            if (mine) {
                UI::TableSetBgColor(UI::TableBgTarget::RowBg0, Tone(Navy()));
                UI::TableSetBgColor(UI::TableBgTarget::RowBg1, Tone(Navy()));
            } else if (i < 3) {
                vec4 rowTint = (i == 0 && evCol.x == IceBlue().x) ? Gold() : evCol;
                if (i == 1 && rowTint.x == Gold().x && rowTint.y == Gold().y) rowTint = Silver();
                UI::TableSetBgColor(UI::TableBgTarget::RowBg0, Tone(rowTint));
                UI::TableSetBgColor(UI::TableBgTarget::RowBg1, Tone(rowTint));
            }

            UI::TableSetColumnIndex(0);
            TextTone(mine ? IceBlue() : evCol, tostring(int(i) + 1));
            UI::TableSetColumnIndex(1);
            DrawMpName(g_liveFeed[i], mine ? Gold() : TextMain());
            if (mine) {
                UI::SameLine(0, 6);
                TextTone(TextMuted(), "(you)");
            }
            UI::SetItemTooltip(Text::StripFormatCodes(g_liveFeed[i]));
        }
        UI::EndTable();
    }
    UI::PopFontSize();
    UI::PopStyleColor(2);
    UI::BeginDisabled(g_syncing);
    if (CenteredButton(Icons::Refresh + " Refresh feed")) SyncNow();
    UI::EndDisabled();
}


void RenderBountyTab() {
    DrawSectionHeader("BOUNTY BOARD");
    UI::TextDisabled("Each day keeps its own record. Beat the holder's CP to steal it (+" +
                     tostring(BOUNTY_POINTS) + " pts once per day).");
    UI::Dummy(vec2(0, 4));

    int flags = UI::TableFlags::RowBg | UI::TableFlags::PadOuterX |
                UI::TableFlags::ScrollY | UI::TableFlags::NoSavedSettings;
    UI::PushStyleColor(UI::Col::TableRowBg, vec4(0.10, 0.10, 0.11, 0.55));
    UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14, 0.14, 0.15, 0.55));
    UI::PushFontSize(FS_BODY);
    if (UI::BeginTable("##goaladventBountyTable", 4, flags, vec2(0, -38.0f * UiK()))) {
        UI::TableSetupColumn("DAY", UI::TableColumnFlags::WidthFixed, 68.0f * UiK());
        UI::TableSetupColumn("MAP", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("RECORD", UI::TableColumnFlags::WidthFixed, 80.0f * UiK());
        UI::TableSetupColumn("HOLDER", UI::TableColumnFlags::WidthFixed, 128.0f * UiK());
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
            UI::SetItemTooltip(IsOffDay(day) ? "Pursuit night | no Goal Hunt today."
                                             : g_titles[day - 1]);
            UI::TableSetColumnIndex(2);
            TextTone(Gold(), tostring(g_bountyCp[day - 1]) + " CP");
            UI::TableSetColumnIndex(3);
            // The server owns the account id; a nickname can be spoofed or
            // changed. Older rows without an id fall back to the name.
            string holderId = g_bountyHolderId[day - 1];
            bool mine = holderId.Length > 0 ? holderId == AccountId()
                                            : g_bountyHolder[day - 1] == LocalName();
            if (mine) TextTone(Gold(), "you");
            else DrawMpName(g_bountyHolder[day - 1], TextMain());
            UI::SetItemTooltip("Holder: " + Text::StripFormatCodes(g_bountyHolder[day - 1]));
        }
        UI::EndTable();
    }
    UI::PopFontSize();
    UI::PopStyleColor(2);
    UI::BeginDisabled(g_syncing);
    if (CenteredButton(Icons::Refresh + " Refresh bounties")) SyncNow();
    UI::EndDisabled();
}

void DrawManiaPlanetMark(UI::DrawList@ dl, vec2 center, float radius, float alpha) {
    dl.AddCircleFilled(center, radius, vec4(0.10, 0.48, 0.82, alpha), 24);
    vec4 white = vec4(1.0, 1.0, 1.0, alpha);
    float w = radius * 0.62f;
    float h = radius * 0.50f;
    float t = radius * 0.13f;
    dl.AddRectFilled(vec4(center.x - w, center.y - h, t, h * 1.6f), white, t * 0.4f);
    dl.AddRectFilled(vec4(center.x + w - t, center.y - h, t, h * 1.6f), white, t * 0.4f);
    dl.AddTriangle(vec2(center.x - w, center.y - h),
                   vec2(center.x, center.y + h * 0.45f),
                   vec2(center.x - w + t * 2.2f, center.y - h), white);
    dl.AddTriangle(vec2(center.x + w, center.y - h),
                   vec2(center.x, center.y + h * 0.45f),
                   vec2(center.x + w - t * 2.2f, center.y - h), white);
}

void RenderFinaleTab() {
    // No blue ManiaPlanet mark and no bottom button - just clean glass cards.
    UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(8.0f * UiK(), 8.0f * UiK()));
    UI::PushStyleVar(UI::StyleVar::ScrollbarSize, 0.0f);
    UI::PushStyleColor(UI::Col::ChildBg, g_palette.containerBg);
    int flags = UI::WindowFlags::NoScrollbar | UI::WindowFlags::NoScrollWithMouse;
    if (UI::BeginChild("##goaladventFinale", vec2(0, 0), UI::ChildFlags::None, flags)) {
        UI::DrawList@ dl = UI::GetWindowDrawList();
        vec2 headerScreen = UI::GetCursorScreenPos();
        float availW = UI::GetContentRegionAvail().x;

        // 1. Header: title + final code on the left, status pill on the right.
        UI::PushFontSize(FS_TITLE);
        TextTone(Gold(), Icons::Trophy + "  THE BIG FINALE");
        UI::PopFontSize();

        UI::PushFontSize(FS_LABEL);
        TextTone(TextMuted(), "FINAL CODE: " + FinalCode());
        UI::PopFontSize();

        bool raffleReady = OpenedCount() >= DAY_COUNT;
        string pillTxt = raffleReady ? (Icons::Check + "  TICKET EARNED") : (Icons::Times + "  NEEDS " + tostring(DAY_COUNT) + "/" + tostring(DAY_COUNT));
        vec4 pillCol = raffleReady ? Emerald() : TextMuted();
        float pillW = UI::MeasureString(pillTxt, null, FS_LABEL).x + 18.0f * UiK();
        float pillH = 24.0f * UiK();
        vec4 pillRect = vec4(headerScreen.x + availW - pillW, headerScreen.y + 4.0f * UiK(), pillW, pillH);
        dl.AddRectFilled(pillRect, g_palette.tileBg);
        dl.AddRect(pillRect, MixCol(pillCol, g_palette.tileEdge, 0.45f), 0.0f, 1.0f);
        vec2 ptSz = UI::MeasureString(pillTxt, null, FS_LABEL);
        dl.AddText(vec2(pillRect.x + (pillW - ptSz.x) * 0.5f, pillRect.y + (pillH - ptSz.y) * 0.5f),
                   pillCol, pillTxt, null, FS_LABEL);

        UI::Dummy(vec2(0, 10.0f * UiK()));

        // 2. Three glass cards side by side.
        float gap = 8.0f * UiK();
        float rowW = UI::GetContentRegionAvail().x;
        float cardW = (rowW - 2.0f * gap) / 3.0f;
        float cardH = 74.0f * UiK();

        DrawGlassBoxCard(Icons::Gift, "GIFTS OPENED",
                         tostring(OpenedCount()) + " / " + tostring(DAY_COUNT),
                         Gold(), cardW, cardH);
        UI::SameLine(0, gap);
        DrawGlassBoxCard(Icons::Trophy, "TOTAL SCORE",
                         tostring(TotalPoints()) + " pts",
                         IceBlue(), cardW, cardH);
        UI::SameLine(0, gap);
        DrawGlassBoxCard(Icons::Crosshairs, "BOUNTIES",
                         tostring(g_bountiesWon) + " won",
                         Emerald(), cardW, cardH);

        UI::Dummy(vec2(0, 12.0f * UiK()));

        // 3. Flat, sharp progress bar.
        DrawSectionHeader("FINALE PROGRESS");
        float prog = float(OpenedCount()) / float(DAY_COUNT);
        if (prog < 0.0f) prog = 0.0f;
        if (prog > 1.0f) prog = 1.0f;
        vec2 barPos = UI::GetCursorScreenPos();
        float barW = UI::GetContentRegionAvail().x;
        float barH = 8.0f * UiK();
        dl.AddRectFilled(vec4(barPos.x, barPos.y, barW, barH), g_palette.tileFooter);
        if (prog > 0.0f) {
            dl.AddRectFilled(vec4(barPos.x, barPos.y, barW * prog, barH),
                             raffleReady ? Emerald() : IceBlue());
        }
        dl.AddRect(vec4(barPos.x, barPos.y, barW, barH), g_palette.tileEdge, 0.0f, 1.0f);
        UI::Dummy(vec2(barW, barH + 10.0f * UiK()));

        // 4. Badges + finale rules (no extra button at the bottom).
        DrawStatCard(Icons::Star, "YOUR BADGES", BadgeShort(), IceBlue());
        UI::Dummy(vec2(0, 10.0f * UiK()));

        UI::PushFontSize(FS_BODY);
        TextTone(raffleReady ? Emerald() : TextMuted(),
                 raffleReady ? (Icons::CheckCircle + "  Raffle ticket earned.")
                             : "Raffle needs " + tostring(DAY_COUNT) + "/" + tostring(DAY_COUNT) + " gifts opened.");
        TextToneWrapped(TextMuted(),
            "The event runs 1-25 December UTC. The raffle is drawn after the window closes.");
        UI::PopFontSize();
    }
    UI::EndChild();
    UI::PopStyleColor();
    UI::PopStyleVar(2);
}

// ---------------------------------------------------------------------------
// Workspace & Dashboard (no footer, full height, glass buttons)
// ---------------------------------------------------------------------------
void RenderWorkspace() {
    UI::PushStyleColor(UI::Col::ChildBg, g_palette.containerBg);
    // Zero the workspace child padding: PushDashboardStyle() sets 14 px on
    // every child, which silently steals width from the tabs and the grid.
    UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(0.0f, 0.0f));
    UI::PushStyleVar(UI::StyleVar::ScrollbarSize, 0.0f);
    int wsFlags = UI::WindowFlags::NoScrollbar | UI::WindowFlags::NoScrollWithMouse;
    if (UI::BeginChild("##goaladventWorkspace", vec2(0, 0), UI::ChildFlags::None, wsFlags)) {
        string[] tabNames = TabNames();

        UI::PushFontSize(FS_BODY);
        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(8.0f * UiK(), 4.0f * UiK()));
        UI::PushStyleVar(UI::StyleVar::FrameRounding, 0.0f);
        UI::PushStyleVar(UI::StyleVar::FrameBorderSize, 1.0f);
        UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(3.0f * UiK(), 8.0f * UiK()));

        float tabH = 28.0f * UiK();
        float syncW = SyncButtonWidth();

        for (int i = 0; i < 5; i++) {
            if (i > 0) UI::SameLine(0, TabGap());
            bool active = (g_activeTab == i);
            // Grey by default; hover only changes the shade. The active tab is
            // marked by brighter text and a stronger border, never a white fill.
            vec4 txt = active ? TextMain() : TextMuted();
            vec4 brd = active ? g_palette.borderStrong : g_palette.tileEdge;

            UI::PushStyleColor(UI::Col::Button, g_palette.tabBg);
            UI::PushStyleColor(UI::Col::ButtonHovered, g_palette.tabHoverBg);
            UI::PushStyleColor(UI::Col::ButtonActive, g_palette.tabHoverBg);
            UI::PushStyleColor(UI::Col::Text, txt);
            UI::PushStyleColor(UI::Col::Border, brd);
            float tw = TabButtonWidth(tabNames[i]);
            if (UI::Button(tabNames[i] + "##tab" + tostring(i), vec2(tw, tabH))) {
                g_activeTab = i;
                g_confirmReset = false;
            }
            UI::PopStyleColor(5);
        }

        // Glass sync icon on the right, in the same tab row.
        float availRight = UI::GetContentRegionAvail().x;
        if (availRight >= syncW + 4.0f * UiK()) {
            UI::SameLine(0, availRight - syncW);
            UI::BeginDisabled(g_syncing);
            if (GlassButton(Icons::Refresh + "##topSync", vec2(syncW, tabH))) {
                SyncNow();
            }
            UI::SetItemTooltip("Sync with server now");
            UI::EndDisabled();
        }

        UI::PopStyleVar(4);
        UI::PopFontSize();

        UI::Dummy(vec2(0, 4.0f * UiK()));

        if (g_activeTab == 0) RenderCalendarTab();
        else if (g_activeTab == 1) RenderLeaderboardTab();
        else if (g_activeTab == 2) RenderFeedTab();
        else if (g_activeTab == 3) RenderBountyTab();
        else if (g_activeTab == 4) RenderFinaleTab();
    }
    UI::EndChild();
    UI::PopStyleVar(2);
    UI::PopStyleColor();
}

void RenderDashboard() {
    ApplyUiScale();
    RefreshPalette();

    // Resizable on every tab. The size only seeds the first layout (ImGui keeps
    // whatever the player picks afterwards), and the grid, the tables and the
    // details pane all derive their geometry from the content region.
    // The constraint is a window size, so add back every layer of padding
    // between the outer window and the drawn content: the window itself, the
    // workspace child (it inherits WindowPadding) and the calendar grid child.
    // WorkspaceMinWidth() takes the widest of the measured tab row, the 5x5
    // grid at its tile minimum and the 68% details column, so neither FINALE
    // nor the fifth calendar column is clipped at the minimum.
    float minW = WorkspaceMinWidth() + WorkspacePadWidth() + WindowPadWidth();
    float minH = (S_ShowDayDetails ? 460.0f : 400.0f) * UiK();

    float winW = (S_ShowDayDetails ? 820.0f : 650.0f) * UiK();
    if (winW < minW + 40.0f * UiK()) winW = minW + 40.0f * UiK();
    float winH = 620.0f * UiK();
    if (winH < minH) winH = minH;
    UI::SetNextWindowSize(int(winW), int(winH), UI::Cond::FirstUseEver);
    UI::SetNextWindowSizeConstraints(int(minW), int(minH), 4000, 4000);
    if (!g_windowSizeApplied) {
        UI::SetNextWindowPos(24, 40, UI::Cond::FirstUseEver);
        g_windowSizeApplied = true;
    }
    int winFlags = UI::WindowFlags::NoScrollbar |
                   UI::WindowFlags::NoScrollWithMouse;
    if (!UI::Begin("GoalAdvent 2026", g_showCalendar, winFlags)) {
        UI::End();
        return;
    }

    PushDashboardStyle();
    RenderWorkspace();
    PopDashboardStyle();
    UI::End();
}

// ---------------------------------------------------------------------------
// Advent gift-opening animation
// ---------------------------------------------------------------------------
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
    ApplyUiScale();
    if (!g_openAnimActive) return;
    float t = Clamp01(1.0f - g_openAnimTimer / OPEN_ANIM_SEC);
    float alpha = Clamp01(t / 0.10f) * (1.0f - EaseOutCubic((t - 0.84f) / 0.16f));
    if (alpha <= 0.001f) return;

    vec4 accent = g_openAnimBounty ? Gold() : IceBlue();
    vec4 bg = g_palette.windowBg;
    UI::DrawList@ dl = UI::GetForegroundDrawList();

    const float cardW = 410.0f * UiK();
    const float cardH = 182.0f * UiK();
    float x = (Display::GetWidth() - cardW) * 0.5f;
    float y = 42.0f * UiK();

    dl.AddRectFilled(vec4(x, y, cardW, cardH),
                     FadeCol(vec4(bg.x, bg.y, bg.z, 0.95f), alpha), 10.0f * UiK());
    dl.AddRect(vec4(x, y, cardW, cardH), FadeCol(accent, alpha * 0.85f), 10.0f * UiK(), 1.5f * UiK());

    float pop = EaseOutCubic(t / 0.16f);
    float open = EaseOutCubic((t - 0.18f) / 0.32f);
    float cx = x + 82.0f * UiK();
    float cy = y + 104.0f * UiK();
    float bw = 58.0f * UiK() * (0.55f + 0.45f * pop);
    float bh = 46.0f * UiK() * (0.55f + 0.45f * pop);
    float bodyTop = cy - bh * 0.5f;
    float bodyLeft = cx - bw * 0.5f;

    float ring = EaseOutCubic((t - 0.26f) / 0.58f);
    if (ring > 0.01f && ring < 0.99f) {
        dl.AddCircle(vec2(cx, bodyTop), 16.0f * UiK() + 56.0f * UiK() * ring,
                     FadeCol(accent, alpha * (0.55f - ring * 0.50f)), 32, 2.0f);
    }

    float tw = 0.55f + 0.45f * open;
    dl.AddCircleFilled(vec2(cx - 46.0f * UiK(), bodyTop - 12.0f * UiK()), 2.0f * UiK() * tw, FadeCol(Gold(), alpha * open));
    dl.AddCircleFilled(vec2(cx + 44.0f * UiK(), bodyTop - 6.0f * UiK()), 2.4f * UiK() * tw, FadeCol(Gold(), alpha * open));
    dl.AddCircleFilled(vec2(cx - 34.0f * UiK(), bodyTop - 34.0f * UiK()), 1.6f * UiK() * tw, FadeCol(accent, alpha * open));
    dl.AddCircleFilled(vec2(cx + 34.0f * UiK(), bodyTop - 30.0f * UiK()), 1.6f * UiK() * tw, FadeCol(accent, alpha * open));

    dl.AddRectFilled(vec4(bodyLeft, bodyTop, bw, bh),
                     FadeCol(vec4(accent.x * 0.32f, accent.y * 0.32f, accent.z * 0.32f, 1.0f), alpha), 3.0f * UiK());
    dl.AddRectFilled(vec4(cx - 4.0f * UiK(), bodyTop, 8.0f * UiK(), bh), FadeCol(accent, alpha), 1.0f);
    dl.AddRectFilled(vec4(bodyLeft, cy - 4.0f * UiK(), bw, 8.0f * UiK()), FadeCol(accent, alpha), 1.0f);

    float lidLift = open * 26.0f * UiK();
    float lidH = 14.0f * UiK() * (0.60f + 0.40f * pop);
    float lidW = bw + 10.0f * UiK();
    float lidY = bodyTop - lidH - lidLift;
    dl.AddRectFilled(vec4(cx - lidW * 0.5f, lidY, lidW, lidH), FadeCol(accent, alpha), 3.0f * UiK());
    dl.AddCircleFilled(vec2(cx - 7.0f * UiK(), lidY - 5.0f * UiK()), 6.0f * UiK(), FadeCol(accent, alpha), 12);
    dl.AddCircleFilled(vec2(cx + 7.0f * UiK(), lidY - 5.0f * UiK()), 6.0f * UiK(), FadeCol(accent, alpha), 12);
    dl.AddCircleFilled(vec2(cx, lidY - 5.0f * UiK()), 3.5f * UiK(), FadeCol(Gold(), alpha), 10);

    float tx = x + 140.0f * UiK();
    float ty = y + 20.0f * UiK();
    string head = g_openAnimBounty
        ? "BOUNTY TAKEN"
        : ("DAY " + tostring(g_openAnimDay) + " OPENED");
    dl.AddText(vec2(tx, ty), FadeCol(accent, alpha), head, null, FS_TITLE);
    dl.AddText(vec2(tx, ty + 28.0f * UiK()), FadeCol(TextMain(), alpha), g_openAnimTitle, null, FS_BODY);
    dl.AddText(vec2(tx, ty + 52.0f * UiK()), FadeCol(TextMain(), alpha),
               "+" + tostring(g_openAnimPoints) + " pts | " + tostring(g_openAnimCp) + " CP",
               null, FS_BODY);
    int idx = g_openAnimDay - 1;
    dl.AddText(vec2(tx, ty + 78.0f * UiK()), FadeCol(TextMuted(), alpha),
               "Bounty: " + tostring(g_bountyCp[idx]) + " CP by " +
               Text::StripFormatCodes(g_bountyHolder[idx]),
               null, FS_LABEL);
    dl.AddText(vec2(tx, ty + 104.0f * UiK()), FadeCol(TextMuted(), alpha),
               tostring(OpenedCount()) + "/" + tostring(DAY_COUNT) + " gifts opened",
               null, FS_LABEL);
}

// ---------------------------------------------------------------------------
// Overlays
// ---------------------------------------------------------------------------
void RenderBanner() {
    ApplyUiScale();
    if (g_bannerTimer <= 0.0f || g_bannerText.Length == 0) return;
    int screenWidth = Display::GetWidth();
    UI::SetNextWindowPos(screenWidth / 2, 40, UI::Cond::Always, 0.5f, 0.0f);
    int flags = UI::WindowFlags::NoTitleBar | UI::WindowFlags::NoResize |
                UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoMove |
                UI::WindowFlags::NoInputs;
    UI::PushStyleColor(UI::Col::WindowBg, g_palette.windowBg);
    if (UI::Begin("##goaladventBanner", flags)) {
        UI::PushFontSize(FS_BODY);
        TextTone(Gold(), Icons::SnowflakeO + "  " + g_bannerText);
        UI::PopFontSize();
    }
    UI::End();
    UI::PopStyleColor();
}

// Which checkpoint numbers are still missing on the current lap. Values come
// from the per-lap set, which is marked only when a checkpoint is credited.
string MapCpStatus() {
    int total = g_curRaceNbCp;
    if (total < 1) return "";
    int passed = 0;
    string left = "";
    for (int i = 1; i <= total; i++) {
        bool isDone = (i < int(g_mapCpPassed.Length)) && g_mapCpPassed[i];
        if (isDone) {
            passed++;
        } else {
            if (left.Length > 24) {
                if (!left.EndsWith(",...")) left += ",...";
            } else {
                if (left.Length > 0) left += ",";
                left += tostring(i);
            }
        }
    }
    return "Map CP " + tostring(passed) + "/" + tostring(total) +
           (left.Length > 0 ? " | left " + left : " | complete");
}

void RenderGoalHuntHud() {
    ApplyUiScale();
    if (g_activeDay <= 0 || g_activeDay > DAY_COUNT) return;
    int day = g_activeDay;
    UI::SetNextWindowPos(20, 120, UI::Cond::FirstUseEver);
    int flags = UI::WindowFlags::NoTitleBar | UI::WindowFlags::AlwaysAutoResize;
    UI::PushStyleColor(UI::Col::WindowBg, g_palette.windowBg);
    if (UI::Begin("##goaladventGoalHuntHud", flags)) {
        UI::PushFontSize(FS_BODY);
        TextTone(TextMain(), Icons::FlagCheckered + " #" + tostring(day) + " GOAL HUNT");
        if (IsPremiereDay(day)) TextTone(Gold(), "Premiere | x2 points");
        else UI::TextDisabled("Catch-up | x1 points");
        if (InWarmupGate()) UI::TextDisabled("Warmup | checkpoints count");
        if (g_bucketDate.Length > 0) {
            UI::TextDisabled("Bucket " + g_bucketDate + " | rolls " +
                             tostring(DAY_ROLLOVER_HOUR_UTC) + ":00 UTC");
        }
        string mapCp = MapCpStatus();
        if (mapCp.Length > 0) UI::Text(mapCp);
        int dayCp = ClampCp(g_sessionCp);
        TextTone(Emerald(), "Day " + tostring(g_activeDay) + " | CP " + tostring(dayCp) +
                 " | reached " + tostring(LastMilestone(dayCp)) + " CP");
        TextTone(TextMain(), MilestoneText(dayCp));
        UI::ProgressBar(MilestoneProgress(dayCp), vec2(220.0f * UiK(), 6.0f * UiK()), "");
        UI::Text("Goal " + tostring(GOAL_CP) + " CP | run " + tostring(g_runCp) +
                 " CP | day total " + tostring(dayCp) + " CP");
        UI::Text("Bounty " + tostring(g_bountyCp[day - 1]) + " CP | " +
                 Text::StripFormatCodes(g_bountyHolder[day - 1]));
        int best = BestCp(day);
        int tier = CpTier(best);
        TextTone(CpTierColour(tier),
                 "Best " + tostring(best) + " CP | " + CpTierLabel(tier));
        UI::PopFontSize();
    }
    UI::End();
    UI::PopStyleColor();
}
