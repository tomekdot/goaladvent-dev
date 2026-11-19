// GoalAdvent 2026 - one ImGui layout, two colour themes.
// Only APIs verified against OpenplanetCore.json (1.29.14) are used.
// Theme.as owns every colour and radius; these wrappers read the active one.

bool g_confirmReset = false;
int g_activeTab = 0;   // 0 Calendar, 1 Leaderboard, 2 Live feed, 3 Bounties, 4 Finale
bool g_windowSizeApplied = false;

// One type scale for the whole dashboard - every text call uses one of these.
// They are refreshed from S_UiScale so the setting scales text and cards
// together instead of overflowing them.
float FS_LABEL = 13.0f;   // labels, footer, captions
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

void ApplyUiScale() {
    float s = UiScale();
    FS_LABEL = 13.0f * s;
    FS_BODY = 15.0f * s;
    FS_TITLE = 18.0f * s;
}

// ---------------------------------------------------------------------------
// Palette accessors - the layout calls these, never hard-coded colours
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
    return "Event starts Dec 1 (in " + tostring(days) + " days)";
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
    // Preserve alpha: in the glass theme a tile is white with alpha 0.07 and
    // forcing alpha to 1 made the hovered tile an opaque white block with
    // invisible text. Translucent colours get a small alpha bump instead.
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

// Short white rule before an UPPERCASE section title.
// Openplanet's AddRectFilled takes (x, y, width, height) - NOT (x1, y1, x2, y2).
void DrawSectionHeader(const string &in title) {
    vec2 p = UI::GetCursorScreenPos();
    UI::GetWindowDrawList().AddRectFilled(
        vec4(p.x, p.y + 2.0f * UiK(), 3.0f * UiK(), 15.0f * UiK()),
        g_palette.iceBlue);
    UI::Dummy(vec2(12.0f * UiK(), 0));
    UI::SameLine(0, 0);
    UI::PushFontSize(FS_BODY);
    TextTone(MixCol(TextMuted(), TextMain(), 0.65f), title);
    UI::PopFontSize();
    UI::Dummy(vec2(0, 5));
}

// One quiet glass strip: accent edge on the left, icon + label row, value.
void DrawStatCard(const string &in icon, const string &in label,
                  const string &in value, vec4 accent) {
    UI::PushStyleColor(UI::Col::ChildBg, InnerBg());
    UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(12.0f * UiK(), 6.0f * UiK()));
    UI::PushStyleVar(UI::StyleVar::ScrollbarSize, 0.0f);
    int flags = UI::WindowFlags::NoScrollbar | UI::WindowFlags::NoScrollWithMouse;
    if (UI::BeginChild("##stat" + label + icon, vec2(0, 76.0f * UiK()), UI::ChildFlags::None, flags)) {
        vec2 start = UI::GetCursorPos();
        UI::PushFontSize(FS_LABEL);
        TextTone(accent, icon);
        UI::PopFontSize();
        UI::SameLine(0, 6.0f * UiK());
        UI::PushFontSize(FS_LABEL);
        TextTone(TextMuted(), label);
        UI::PopFontSize();
        UI::SetCursorPos(vec2(start.x, start.y + 22.0f * UiK()));
        UI::PushFontSize(FS_BODY);
        TextToneWrapped(TextMain(), value);
        UI::PopFontSize();
    }
    UI::EndChild();
    // Subtle 2 px accent edge on the left, drawn once the rect is known.
    vec4 r = UI::GetItemRect();
    UI::GetWindowDrawList().AddRectFilled(vec4(r.x, r.y, 2.0f * UiK(), r.w), accent);
    UI::PopStyleVar(2);
    UI::PopStyleColor();
}

// ---------------------------------------------------------------------------
// Dashboard style
// ---------------------------------------------------------------------------
void PushDashboardStyle() {
    UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(16.0f * UiK(), 14.0f * UiK()));
    UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(10.0f * UiK(), 10.0f * UiK()));
    UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(8.0f * UiK(), 4.0f * UiK()));
    UI::PushStyleVar(UI::StyleVar::WindowRounding, g_palette.windowRounding);
    UI::PushStyleVar(UI::StyleVar::ChildRounding, g_palette.childRounding);
    UI::PushStyleVar(UI::StyleVar::FrameRounding, g_palette.frameRounding);
    UI::PushStyleVar(UI::StyleVar::GrabRounding, g_palette.frameRounding);
    UI::PushStyleVar(UI::StyleVar::TabRounding, g_palette.tabRounding);
    UI::PushStyleVar(UI::StyleVar::ChildBorderSize, 1.0f);
    UI::PushStyleVar(UI::StyleVar::FrameBorderSize, 1.0f);
    UI::PushStyleVar(UI::StyleVar::TabBorderSize, 0.0f);
    UI::PushStyleVar(UI::StyleVar::TabBarBorderSize, 0.0f);

    UI::PushStyleColor(UI::Col::WindowBg, g_palette.windowBg);
    UI::PushStyleColor(UI::Col::ChildBg, g_palette.childBg);
    UI::PushStyleColor(UI::Col::FrameBg, g_palette.innerBg);
    UI::PushStyleColor(UI::Col::Border, g_palette.border);
    UI::PushStyleColor(UI::Col::Separator, g_palette.border);
    vec4 interaction = MixCol(g_palette.buttonHover, g_palette.iceBlue, 0.30f);
    UI::PushStyleColor(UI::Col::Tab, g_palette.tabBg);
    UI::PushStyleColor(UI::Col::TabActive, g_palette.tabActiveBg);
    UI::PushStyleColor(UI::Col::TabSelected, g_palette.tabActiveBg);
    UI::PushStyleColor(UI::Col::TabHovered, g_palette.tabHoverBg);
    UI::PushStyleColor(UI::Col::TableHeaderBg, g_palette.tableHeaderBg);
    UI::PushStyleColor(UI::Col::Button, g_palette.buttonBg);
    UI::PushStyleColor(UI::Col::ButtonHovered, interaction);
    UI::PushStyleColor(UI::Col::ButtonActive, g_palette.buttonActive);
    UI::PushStyleColor(UI::Col::Text, g_palette.text);
    UI::PushStyleColor(UI::Col::TextDisabled, TextMuted());
}

void PopDashboardStyle() {
    UI::PopStyleColor(15);
    UI::PopStyleVar(12);
}

// ---------------------------------------------------------------------------
// Header card - identity, quick actions and event progress in one place
// ---------------------------------------------------------------------------
void RenderHeaderCard() {
    UI::PushStyleColor(UI::Col::ChildBg, g_palette.containerBg);
    UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(14.0f * UiK(), 10.0f * UiK()));
    UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(8.0f * UiK(), 7.0f * UiK()));
    UI::PushStyleVar(UI::StyleVar::ScrollbarSize, 0.0f);
    int flags = UI::WindowFlags::NoScrollbar | UI::WindowFlags::NoScrollWithMouse;
    if (UI::BeginChild("##goaladventHeader", vec2(0, 0),
                       UI::ChildFlags::AutoResizeY, flags)) {
        // Row 1: snowflake + tagline on the left, icon actions on the right.
        // Brighter icon buttons so they read on both matte and glass backgrounds.
        vec4 btn = MixCol(g_palette.buttonBg, g_palette.text, 0.12f);
        UI::PushStyleColor(UI::Col::Button, btn);
        UI::PushStyleColor(UI::Col::ButtonHovered, Lift(btn));
        UI::PushStyleColor(UI::Col::ButtonActive, Lift(Lift(btn)));

        // Save the row origin BEFORE any text: after Text the cursor drops to
        // the next line, so GetContentRegionAvail() there is the full width
        // and a SameLine offset derived from it pushes the buttons off-screen.
        vec2 rowStart = UI::GetCursorPos();
        float contentW = UI::GetContentRegionAvail().x;

        UI::PushFontSize(FS_TITLE);
        TextTone(IceBlue(), Icons::SnowflakeO);
        UI::PopFontSize();
        UI::SameLine(0, 8.0f * UiK());
        UI::PushFontSize(FS_BODY);
        UI::TextDisabled("25 days of checkpoints, bounties and badges");
        UI::PopFontSize();

        // Right-align the button group on the SAME row by restoring the saved
        // row baseline, never by a SameLine offset measured after the text.
        float btnW = 30.0f * UiK();
        float btnH = 26.0f * UiK();
        float gap = 4.0f * UiK();
        float groupW = btnW * 4.0f + gap * 3.0f;
        float btnX = rowStart.x + contentW - groupW;
        if (btnX < rowStart.x) btnX = rowStart.x;
        UI::SetCursorPos(vec2(btnX, rowStart.y));

        UI::BeginDisabled(g_syncing);
        if (UI::Button(Icons::Refresh + "##headerSync", vec2(btnW, btnH))) SyncNow();
        UI::SetItemTooltip(g_syncing ? "Sync in progress..." : "Refresh results from the event server.");
        UI::EndDisabled();
        UI::SameLine(0, gap);
        if (UI::Button(Icons::FloppyO + "##headerSave", vec2(btnW, btnH))) {
            SaveProgress();
            g_status = "Progress saved locally.";
        }
        UI::SetItemTooltip("Save progress to this PC.");
        UI::SameLine(0, gap * 2.0f);
        // Destructive action: crimson icon at rest, solid crimson when armed
        // (first press), so the two-step reset is impossible to mistake.
        vec4 trashBg = g_confirmReset ? MixCol(g_palette.buttonBg, Crimson(), 0.60f)
                                      : MixCol(g_palette.buttonBg, Crimson(), 0.10f);
        UI::PushStyleColor(UI::Col::Button, trashBg);
        UI::PushStyleColor(UI::Col::ButtonHovered, Crimson());
        UI::PushStyleColor(UI::Col::Text, g_confirmReset ? TextMain() : Crimson());
        if (UI::Button(Icons::Trash + "##headerReset", vec2(btnW, btnH))) {
            if (g_confirmReset) {
                ResetProgress();
                SaveProgress();
                g_confirmReset = false;
                g_status = "Local progress reset.";
            } else {
                g_confirmReset = true;
            }
        }
        UI::SetItemTooltip(g_confirmReset ? "Press again to confirm | this clears local progress."
                                          : "Reset local progress (press twice).");
        UI::PopStyleColor(3);
        UI::SameLine(0, gap);
        if (UI::Button(Icons::Cog + "##headerTheme", vec2(btnW, btnH))) {
            g_Theme = (g_Theme == UiTheme::TransparentGlass)
                ? UiTheme::ObsidianMinimal : UiTheme::TransparentGlass;
        }
        UI::SetItemTooltip("Switch theme | Obsidian / Transparent Glass");
        UI::PopStyleColor(3);
    }
    UI::EndChild();
    UI::PopStyleVar(3);
    UI::PopStyleColor();
}

// ---------------------------------------------------------------------------
// Calendar grid
// ---------------------------------------------------------------------------
// Each day is a status tile: gold premiere/finale, emerald completed, crimson
// bounty/action, purple Pursuit rest, gray locked. The accent is carried by
// the tile surface, border and top rule, not by a tiny dot.
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

// Next playable Goal Hunt day after `from`, skipping the Pursuit nights.
int NextGoalHuntDay(int from) {
    for (int d = from + 1; d <= DAY_COUNT; d++) {
        if (!IsOffDay(d)) return d;
    }
    return DAY_COUNT;
}

// The tile label is only the day number. REST / FINAL sit on the line below,
// so a wide word can never overflow the narrowest (48 px) tile.
string DayTileShort(int day) {
    return day < 10 ? "0" + tostring(day) : tostring(day);
}

// Bar caption suffix: exception words first (REST, x2, FINAL, DONE), then the
// moon percent so the calendar itself carries the info. S_ShowMoonPct hides it.
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

// Frosted-glass slot: large state icon in the glass area, dark status bar
// along the bottom carrying the day number and an exception word. Sharp
// corners, quiet edge; only the selected day gets a bright white frame.
bool DrawCenteredDayTile(int day, const string &in icon, const string &in label,
                         const string &in statusLine, vec4 bgCol, vec4 _textCol,
                         vec4 accent, bool isSelected, bool _isToday, float tileW, float tileH) {
    UI::PushStyleVar(UI::StyleVar::FrameBorderSize, isSelected ? 2.0f : 1.0f);
    UI::PushStyleVar(UI::StyleVar::FrameRounding, 0.0f);
    vec4 borderCol = isSelected
        ? vec4(IceBlue().x, IceBlue().y, IceBlue().z, 0.95f)
        : g_palette.tileEdge;
    UI::PushStyleColor(UI::Col::Border, borderCol);
    UI::PushStyleColor(UI::Col::Button, bgCol);
    UI::PushStyleColor(UI::Col::ButtonHovered, g_palette.tileHover);
    UI::PushStyleColor(UI::Col::ButtonActive, Lift(g_palette.tileHover));
    UI::PushStyleColor(UI::Col::Text, g_palette.text);

    // The button carries only its ID; every visual is drawn on the window
    // draw list so the icon, bar and badge stay perfectly placed.
    bool clicked = UI::Button("##goaladventtile" + tostring(day), vec2(tileW, tileH));
    vec4 r = UI::GetItemRect();
    float cx = r.x + r.z * 0.5f;
    UI::DrawList@ dl = UI::GetWindowDrawList();

    // Dark status bar along the bottom edge (sharp corners match the tile).
    float barH = 24.0f * UiK();
    dl.AddRectFilled(vec4(r.x, r.y + r.w - barH, r.z, barH), g_palette.tileFooter);
    string caption = label;
    if (statusLine.Length > 0) caption += " | " + statusLine;
    vec2 capSize = UI::MeasureString(caption, null, FS_LABEL);
    // Narrow tiles keep just the number; the icon already carries the state.
    if (capSize.x > tileW - 6.0f * UiK() && statusLine.Length > 0) {
        caption = label;
        capSize = UI::MeasureString(caption, null, FS_LABEL);
    }
    dl.AddText(vec2(cx - capSize.x * 0.5f,
                    r.y + r.w - barH + (barH - capSize.y) * 0.5f),
               TextMain(), caption, null, FS_LABEL);

    // Large state-coloured icon centred in the glass area above the bar.
    vec2 iconSize = UI::MeasureString(icon, null, FS_TITLE);
    float glassH = r.w - barH;
    vec4 iconCol = MixCol(accent, vec4(1.0f, 1.0f, 1.0f, 1.0f), 0.25f);
    dl.AddText(vec2(cx - iconSize.x * 0.5f, r.y + (glassH - iconSize.y) * 0.5f),
               iconCol, icon, null, FS_TITLE);

    // Completed day: white circle with a dark check, bottom-right of the glass.
    if (g_opened[day - 1]) {
        float cr = 8.0f * UiK();
        vec2 cc = vec2(r.x + r.z - 12.0f * UiK(), r.y + glassH - 12.0f * UiK());
        dl.AddCircleFilled(cc, cr, vec4(IceBlue().x, IceBlue().y, IceBlue().z, 0.95f), 16);
        vec2 checkSize = UI::MeasureString(Icons::Check, null, FS_LABEL);
        dl.AddText(vec2(cc.x - checkSize.x * 0.5f, cc.y - checkSize.y * 0.5f),
                   g_palette.tabActiveText, Icons::Check, null, FS_LABEL);
    }

    UI::PopStyleColor(5);
    UI::PopStyleVar(2);
    return clicked;
}

void RenderDayGrid() {
    // One subtle info line above the grid; day specifics live in DAY DETAILS.
    // Pre-event the countdown replaces the date range on the same line.
    if (S_ShowTips) {
        string info = "Dec 1 to 25 | Tue: Pursuit rest | Premiere: x2 pts";
        string countdown = EventCountdown();
        if (countdown.Length > 0) info = countdown + " | Tue: Pursuit rest | x2 pts";
        UI::PushFontSize(FS_LABEL);
        TextTone(TextMuted(), info);
        UI::PopFontSize();
        UI::Dummy(vec2(0, 2.0f * UiK()));
    }

    // Fill the column height, but keep tiles close to square (max 1.3x wide)
    // and centre the resulting grid instead of leaving a strip on the right.
    // The minimum height fits both tile rows at the current font scale.
    vec2 origin = UI::GetCursorPos();
    vec2 avail = UI::GetContentRegionAvail();
    const float spacing = 6.0f * UiK();
    // Minimum height: glass icon area + the dark status bar, measured so the
    // grid fits without a scrollbar at any overlay scale or UI scale.
    float minTileH = UI::MeasureString("00", null, FS_TITLE).y + 34.0f * UiK();
    float tileH = (avail.y - 4.0f * spacing) / 5.0f;
    if (tileH < minTileH) tileH = minTileH;
    if (tileH > 110.0f * UiK()) tileH = 110.0f * UiK();
    float tileW = (avail.x - 4.0f * spacing) / 5.0f;
    if (tileW < 48.0f * UiK()) tileW = 48.0f * UiK();
    if (tileW > tileH * 1.3f) tileW = tileH * 1.3f;
    float gridW = 5.0f * tileW + 4.0f * spacing;
    float gridX = origin.x + (avail.x - gridW) * 0.5f;
    int today = CurrentEventDayUtc();

    for (int day = 1; day <= DAY_COUNT; day++) {
        int col = (day - 1) % 5;
        int row = (day - 1) / 5;
        UI::SetCursorPos(vec2(gridX + col * (tileW + spacing),
                              origin.y + row * (tileH + spacing)));

        vec4 accent = DayAccent(day);
        bool lockedDay = !IsOffDay(day) && !DayUnlocked(day);
        if (lockedDay) {
            // A muted, low-alpha gray keeps locked days visibly inactive
            // instead of giving them the same bright rule as playable days.
            accent = vec4(g_palette.textMuted.x, g_palette.textMuted.y,
                          g_palette.textMuted.z, 0.35f);
        }
        vec4 textCol = MixCol(TextMain(), accent, 0.35f);
        if (IsOffDay(day) || lockedDay) textCol = MixCol(textCol, TextMuted(), 0.35f);
        // Every tile carries a bar caption; the tooltip always has the full
        // moon phase and bounty record.
        string statusLine = DayTileStatus(day, tileW);
        // Uniform frosted glass: state lives in the icon colour and caption,
        // not in a surface tint (keeps the HUD calm and consistent).
        vec4 bg = (day == g_selectedDay) ? TileSelectedBg() : TileBg();
        if (DrawCenteredDayTile(day, DayTileIcon(day), DayTileShort(day), statusLine,
                                bg, textCol, accent, day == g_selectedDay,
                                day == today && today > 0, tileW, tileH)) {
            g_selectedDay = day;
            g_confirmReset = false;
        }
        UI::SetItemTooltip(MoonPhaseName(day) + " | " +
                           tostring(MoonIlluminationPct(day)) + "% lit\n" +
                           "Bounty: " + tostring(g_bountyCp[day - 1]) + " CP | " +
                           Text::StripFormatCodes(g_bountyHolder[day - 1]) + "\n" +
                           g_hints[day - 1]);
    }
    // SetCursorPos() past the last tile extends the child boundary, so ImGui
    // requires an item afterwards - otherwise EndChild() throws an assertion.
    // Land exactly on the grid height (5 rows + 4 gaps), not one gap further,
    // or the child scrolls by a few pixels.
    UI::SetCursorPos(vec2(origin.x, origin.y + 5.0f * tileH + 4.0f * spacing));
    UI::Dummy(vec2(0, 1));
}

// Keep button text off the edges: use the shorter wording when the measured
// label plus frame padding would not fit the available width.
string FitLabel(const string &in longLabel, const string &in shortLabel, float maxW) {
    vec2 ts = UI::MeasureString(longLabel, null, FS_BODY);
    if (ts.x + 20.0f * UiK() <= maxW) return longLabel;
    return shortLabel;
}

// Panel action button: FS_BODY, centred in the content region instead of
// hugging the left edge.
bool CenteredButton(const string &in label) {
    UI::PushFontSize(FS_BODY);
    float btnW = UI::MeasureString(label, null, FS_BODY).x + 16.0f * UiK();
    float avail = UI::GetContentRegionAvail().x;
    if (btnW < avail) {
        UI::SetCursorPosX(UI::GetCursorPos().x + (avail - btnW) * 0.5f);
    }
    bool clicked = UI::Button(label);
    UI::PopFontSize();
    return clicked;
}

// One thin label/value pair for the optional details strip - no card box.
void DetailLine(const string &in label, const string &in value, vec4 valueCol) {
    UI::PushFontSize(FS_LABEL);
    TextTone(TextMuted(), label);
    UI::PopFontSize();
    UI::PushFontSize(FS_LABEL);
    TextToneWrapped(valueCol, value);
    UI::PopFontSize();
}

// Optional details strip (S_ShowDayDetails). The default view is the
// full-width calendar; this panel is opt-in for players who want the facts
// beside the grid instead of in the tile tooltips.
void RenderDayDetails() {
    int day = g_selectedDay;
    if (day < 1 || day > DAY_COUNT) day = 1;

    bool locked = !IsOffDay(day) && !DayUnlocked(day);

    UI::PushFontSize(FS_TITLE);
    TextTone(TextMain(), "DAY " + tostring(day) + " | " + g_titles[day - 1]);
    UI::PopFontSize();
    string status = "Available";
    vec4 statusCol = Emerald();
    if (locked) {
        status = "Locked until Dec " + tostring(day);
        statusCol = TextMuted();
    } else if (g_opened[day - 1]) {
        status = "Completed";
    } else if (IsOffDay(day)) {
        status = "Pursuit night";
        statusCol = Purple();
    } else if (IsPremiereDay(day)) {
        status = "Premiere | double points";
        statusCol = Gold();
    } else if (!DayPlayableNow(day)) {
        status = "Waiting for the event";
        statusCol = TextMuted();
    }
    int detectedDay = DetectGoalHuntDay();
    if (!IsOffDay(day) && detectedDay > 0) {
        status += " | map #" + tostring(detectedDay);
    }
    UI::PushFontSize(FS_BODY);
    TextTone(statusCol, status);
    UI::PopFontSize();

    if (IsOffDay(day)) {
        DetailLine("PURSUIT BONUS", "Bonus 20:00 CET (19:00 UTC)", Purple());
        DetailLine("MOON", MoonPhaseName(day) + " | " + tostring(MoonIlluminationPct(day)) + "%", TextMain());
        DetailLine("STREAK", "Protected | no race tonight", Emerald());
    } else {
        DetailLine("BOUNTY", tostring(g_bountyCp[day - 1]) + " CP | " +
                   Text::StripFormatCodes(g_bountyHolder[day - 1]), Gold());
        DetailLine("GOAL", "Catch " + tostring(GOAL_CP) + " CP | best " + tostring(g_bests[day - 1]), TextMain());
        DetailLine("MOON", MoonPhaseName(day) + " | " + tostring(MoonIlluminationPct(day)) + "%", TextMain());
    }
    if (locked) {
        UI::TextDisabled("This gift opens on December " + tostring(day) + ".");
    } else if (!IsOffDay(day)) {
        UI::TextWrapped(g_hints[day - 1]);
    }
}

// Fixed action row of the optional details strip, outside the scrolling body.
void RenderDayAction(int day) {
    const float rowH = 40.0f * UiK();
    bool locked = !IsOffDay(day) && !DayUnlocked(day);
    float maxW = UI::GetContentRegionAvail().x;

    if (locked || IsOffDay(day)) {
        UI::BeginDisabled(true);
        UI::PushStyleColor(UI::Col::Button, MixCol(g_palette.buttonBg, g_palette.text, 0.04f));
        UI::PushStyleColor(UI::Col::Text, MixCol(TextMuted(), g_palette.text, 0.20f));
        if (locked) {
            UI::Button(FitLabel("AVAILABLE DEC " + tostring(day),
                                "OPENS DEC " + tostring(day), maxW), vec2(-1, rowH));
        } else {
            UI::Button(FitLabel("Next hunt: Dec " + tostring(NextGoalHuntDay(day)),
                                "Hunt: Dec " + tostring(NextGoalHuntDay(day)), maxW), vec2(-1, rowH));
            UI::SetItemTooltip("No race tonight | next Goal Hunt: Dec " +
                               tostring(NextGoalHuntDay(day)));
        }
        UI::PopStyleColor(2);
        UI::EndDisabled();
        return;
    }

    // White text on a deep glass pill with a strong frame - the CTA stays
    // the standout element without any dark-on-light text.
    UI::PushStyleColor(UI::Col::Button, g_palette.tabActiveBg);
    UI::PushStyleColor(UI::Col::ButtonHovered, MixCol(g_palette.tabActiveBg, g_palette.text, 0.10f));
    UI::PushStyleColor(UI::Col::Text, TextMain());
    UI::PushStyleColor(UI::Col::Border, g_palette.borderStrong);
    string action = S_TestMode ? "SUBMIT TEST (12)" : "OPEN DAY " + tostring(day);
    string actionShort = S_TestMode ? "TEST (12)" : "OPEN " + tostring(day);
    if (UI::Button(FitLabel(action, actionShort, maxW), vec2(-1, rowH))) {
        if (S_TestMode) {
            RequestCpSubmit(day, 12);
            g_status = "Test CP submitted for day " + tostring(day) + ".";
        } else {
            g_status = "Join #" + tostring(day) + " Goal Hunt on the event server | CP count automatically.";
        }
    }
    UI::SetItemTooltip("Join #" + tostring(day) + " Goal Hunt | reach " + tostring(GOAL_CP) +
                       " CP in one run to complete this day.");
    UI::PopStyleColor(4);
}

// ---------------------------------------------------------------------------
// Day bar - one thin row under the full-width grid: identity + status on the
// left, the day action on the right. All other facts live on the tiles and
// their tooltips, so the calendar keeps the whole window.
// ---------------------------------------------------------------------------
void RenderDayBar(int day) {
    bool locked = !IsOffDay(day) && !DayUnlocked(day);
    string status = "Available";
    vec4 statusCol = Emerald();
    if (locked) {
        status = "Locked until Dec " + tostring(day);
        statusCol = TextMuted();
    } else if (g_opened[day - 1]) {
        status = "Completed";
    } else if (IsOffDay(day)) {
        status = "Pursuit night";
        statusCol = Purple();
    } else if (IsPremiereDay(day)) {
        status = "Premiere | double points";
        statusCol = Gold();
    } else if (!DayPlayableNow(day)) {
        status = "Waiting for the event";
        statusCol = TextMuted();
    }
    int detectedDay = DetectGoalHuntDay();
    if (!IsOffDay(day) && detectedDay > 0) {
        status += " | map #" + tostring(detectedDay);
    }

    // Save the row origin before any text: after Text the cursor drops a line
    // and GetContentRegionAvail would report the full width.
    vec2 rowStart = UI::GetCursorPos();
    float contentW = UI::GetContentRegionAvail().x;
    float rowH = 36.0f * UiK();

    // Size the button to its label so the text never touches the edges.
    float maxBtnW = contentW * 0.5f;
    string label;
    if (locked) {
        label = FitLabel("AVAILABLE DEC " + tostring(day), "OPENS DEC " + tostring(day), maxBtnW);
    } else if (IsOffDay(day)) {
        label = FitLabel("Next hunt: Dec " + tostring(NextGoalHuntDay(day)),
                         "Hunt: Dec " + tostring(NextGoalHuntDay(day)), maxBtnW);
    } else {
        label = FitLabel(S_TestMode ? "SUBMIT TEST (12)" : "OPEN DAY " + tostring(day),
                         S_TestMode ? "TEST (12)" : "OPEN " + tostring(day), maxBtnW);
    }
    float btnW = UI::MeasureString(label, null, FS_BODY).x + 24.0f * UiK();
    if (btnW < 150.0f * UiK()) btnW = 150.0f * UiK();
    if (btnW > maxBtnW) btnW = maxBtnW;

    UI::PushFontSize(FS_BODY);
    TextTone(TextMain(), "DAY " + tostring(day) + " | " + g_titles[day - 1]);
    UI::PopFontSize();
    UI::SameLine(0, 8.0f * UiK());
    UI::PushFontSize(FS_LABEL);
    TextTone(statusCol, status);
    UI::PopFontSize();

    float btnX = rowStart.x + contentW - btnW;
    if (btnX < rowStart.x) btnX = rowStart.x;
    UI::SetCursorPos(vec2(btnX, rowStart.y));

    if (locked || IsOffDay(day)) {
        // Clearly disabled: no hover, low contrast, no CTA styling.
        UI::BeginDisabled(true);
        UI::PushStyleColor(UI::Col::Button, MixCol(g_palette.buttonBg, g_palette.text, 0.04f));
        UI::PushStyleColor(UI::Col::Text, MixCol(TextMuted(), g_palette.text, 0.20f));
        UI::Button(label, vec2(btnW, rowH));
        if (!locked) {
            UI::SetItemTooltip("No race tonight | next Goal Hunt: Dec " +
                               tostring(NextGoalHuntDay(day)));
        }
        UI::PopStyleColor(2);
        UI::EndDisabled();
        return;
    }

    // The framed CTA is the only high-contrast element in the whole dashboard.
    // White text on a deep glass pill with a strong frame - the CTA stays
    // the standout element without any dark-on-light text.
    UI::PushStyleColor(UI::Col::Button, g_palette.tabActiveBg);
    UI::PushStyleColor(UI::Col::ButtonHovered, MixCol(g_palette.tabActiveBg, g_palette.text, 0.10f));
    UI::PushStyleColor(UI::Col::Text, TextMain());
    UI::PushStyleColor(UI::Col::Border, g_palette.borderStrong);
    if (UI::Button(label, vec2(btnW, rowH))) {
        if (S_TestMode) {
            RequestCpSubmit(day, 12);
            g_status = "Test CP submitted for day " + tostring(day) + ".";
        } else {
            g_status = "Join #" + tostring(day) + " Goal Hunt on the event server | CP count automatically.";
        }
    }
    UI::SetItemTooltip("Join #" + tostring(day) + " Goal Hunt | reach " + tostring(GOAL_CP) +
                       " CP in one run to complete this day.");
    UI::PopStyleColor(4);
}

// ---------------------------------------------------------------------------
// Workspace panes
// ---------------------------------------------------------------------------
// Shared grid child: transparent, no scrollbars, legend on the header tooltip.
void RenderCalendarGrid(float w, float hReserve) {
    UI::PushStyleColor(UI::Col::ChildBg, g_palette.containerBg);
    UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(10.0f * UiK(), 8.0f * UiK()));
    UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(6.0f * UiK(), 4.0f * UiK()));
    UI::PushStyleVar(UI::StyleVar::ScrollbarSize, 0.0f);
    int gridFlags = UI::WindowFlags::NoScrollbar | UI::WindowFlags::NoScrollWithMouse;
    if (UI::BeginChild("##goaladventCalendarGrid", vec2(w, hReserve), UI::ChildFlags::None, gridFlags)) {
        DrawSectionHeader("ADVENT CALENDAR");
        // Legend on the header tooltip keeps the grid chrome to one line.
        UI::SetItemTooltip("REST = Pursuit night | FINAL = day 25 finale | DONE = completed | gray gift = opens later");
        RenderDayGrid();
    }
    UI::EndChild();
    UI::PopStyleVar(3);
    UI::PopStyleColor();
}

void RenderCalendarTab() {
    int day = g_selectedDay;
    if (day < 1 || day > DAY_COUNT) day = 1;

    // Default: calendar only, 25 tiles and a thin day bar. The details strip
    // is opt-in (Settings -> Appearance -> Show day details).
    if (!S_ShowDayDetails) {
        RenderCalendarGrid(0, -46.0f * UiK());
        RenderDayBar(day);
        return;
    }

    float width = UI::GetContentRegionAvail().x;
    float leftW = width * 0.72f;
    float rightW = width - leftW - 8.0f * UiK();
    RenderCalendarGrid(leftW, 0);
    UI::SameLine(0, 8);
    UI::PushStyleColor(UI::Col::ChildBg, g_palette.containerBg);
    UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(10.0f * UiK(), 8.0f * UiK()));
    UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(10.0f * UiK(), 6.0f * UiK()));
    if (UI::BeginChild("##goaladventDayDetailsCard", vec2(rightW, 0), UI::ChildFlags::None)) {
        DrawSectionHeader("DAY DETAILS");
        // Fixed action row below the body; the body itself never scrolls.
        int gridFlags = UI::WindowFlags::NoScrollbar | UI::WindowFlags::NoScrollWithMouse;
        UI::PushStyleColor(UI::Col::ChildBg, g_palette.containerBg);
        UI::PushStyleVar(UI::StyleVar::ScrollbarSize, 0.0f);
        if (UI::BeginChild("##goaladventDayDetailsBody", vec2(0, -46), UI::ChildFlags::None, gridFlags)) {
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
        if (CenteredButton(Icons::Refresh + " Refresh")) SyncNow();
        UI::EndDisabled();
        return;
    }

    // No BordersInnerH: its default ImGui border is blue. Neutral stone rows
    // keep the scoreboard matte and readable in both themes.
    int flags = UI::TableFlags::RowBg | UI::TableFlags::PadOuterX;
    UI::PushStyleColor(UI::Col::TableRowBg, vec4(0.10, 0.10, 0.11, 0.55));
    UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14, 0.14, 0.15, 0.55));
    UI::PushFontSize(FS_BODY);
    if (UI::BeginTable("##goaladventBoardTable", 4, flags)) {
        UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 46.0f * UiK());
        UI::TableSetupColumn("PLAYER", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("POINTS", UI::TableColumnFlags::WidthFixed, 104.0f * UiK());
        UI::TableSetupColumn("BOUNTIES", UI::TableColumnFlags::WidthFixed, 104.0f * UiK());
        UI::TableHeadersRow();
        for (uint i = 0; i < g_boardNames.Length; i++) {
            UI::TableNextRow();
            bool mine = i < g_boardAccountIds.Length && g_boardAccountIds[i] == AccountId();
            if (!mine && g_boardNames[i] == LocalName() && (i >= g_boardAccountIds.Length || g_boardAccountIds[i].Length == 0)) mine = true;
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
    UI::PopFontSize();
    UI::PopStyleColor(2);
    UI::BeginDisabled(g_syncing);
    if (CenteredButton(Icons::Refresh + " Refresh leaderboard")) SyncNow();
    UI::EndDisabled();
}

void RenderFeedTab() {
    DrawSectionHeader("LIVE FEED");
    if (g_liveFeed.Length == 0) {
        UI::TextDisabled("Nothing here yet | complete a day or take a bounty.");
        UI::BeginDisabled(g_syncing);
        if (CenteredButton(Icons::Refresh + " Refresh")) SyncNow();
        UI::EndDisabled();
        return;
    }
    // Neutral stone rows, no blue ImGui borders.
    int flags = UI::TableFlags::RowBg | UI::TableFlags::PadOuterX;
    UI::PushStyleColor(UI::Col::TableRowBg, vec4(0.10, 0.10, 0.11, 0.55));
    UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14, 0.14, 0.15, 0.55));
    UI::PushFontSize(FS_BODY);
    if (UI::BeginTable("##goaladventFeedTable", 2, flags)) {
        UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 46.0f * UiK());
        UI::TableSetupColumn("EVENT", UI::TableColumnFlags::WidthStretch);
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
    UI::PopFontSize();
    UI::PopStyleColor(2);
    UI::BeginDisabled(g_syncing);
    if (CenteredButton(Icons::Refresh + " Refresh feed")) SyncNow();
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
    UI::PushFontSize(FS_BODY);
    if (UI::BeginTable("##goaladventBountyTable", 4, flags, vec2(0, -34))) {
        UI::TableSetupColumn("DAY", UI::TableColumnFlags::WidthFixed, 72.0f * UiK());
        UI::TableSetupColumn("MAP", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("RECORD", UI::TableColumnFlags::WidthFixed, 96.0f * UiK());
        UI::TableSetupColumn("HOLDER", UI::TableColumnFlags::WidthFixed, 164.0f * UiK());
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
            else DrawMpName(g_bountyHolder[day - 1], TextMain());
        }
        UI::EndTable();
    }
    UI::PopFontSize();
    UI::PopStyleColor(2);
    UI::BeginDisabled(g_syncing);
    if (CenteredButton(Icons::Refresh + " Refresh bounties")) SyncNow();
    UI::EndDisabled();
}

void RenderFinaleTab() {
    DrawSectionHeader("GRAND FINALE");
    UI::PushFontSize(FS_TITLE);
    TextTone(Gold(), Icons::Trophy + "  THE BIG FINALE");
    UI::PopFontSize();
    UI::TextWrapped("Final code: " + FinalCode());
    // A 10 px bar cannot fit overlay text - keep the label on its own line.
    UI::TextDisabled("GIFTS | " + tostring(OpenedCount()) + "/" + tostring(DAY_COUNT) + " opened");
    UI::ProgressBar(float(OpenedCount()) / float(DAY_COUNT), vec2(-1, 6.0f * UiK()), "");
    UI::Dummy(vec2(0, 8));
    DrawStatCard(Icons::Trophy, "RESULT", "Score | " + tostring(TotalPoints()) + " pts", Gold());
    UI::Dummy(vec2(0, 5));
    DrawStatCard(Icons::Crosshairs, "BOUNTIES", tostring(g_bountiesWon) + " won | " + BadgeShort(), Emerald());
    if (OpenedCount() < DAY_COUNT) {
        UI::TextDisabled("Not every gift was opened | the raffle ticket needs 25/25.");
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
    // The footer is the single status line: live connection health on the
    // left, points / gifts / badges on the right. The selected day lives in
    // the day bar above, so it is not repeated here.
    string link;
    vec4 linkCol;
    if (S_SyncMode == 0) {
        link = "Offline | saved locally";
        linkCol = TextMuted();
    } else if (g_syncing) {
        link = "Syncing results...";
        linkCol = IceBlue();
    } else if (g_debugErrors.Length > 0 || g_status.Contains("failed")) {
        link = "Results error | open Debug";
        linkCol = Crimson();
    } else if (g_lastSyncStamp > 0) {
        link = "Connected | " + tostring(g_boardCount) + " players | synced " +
               tostring(int(Time::Stamp) - g_lastSyncStamp) + "s";
        linkCol = Emerald();
    } else {
        link = "Connecting to results...";
        linkCol = TextMuted();
    }
    UI::PushFontSize(FS_LABEL);
    TextTone(linkCol, Icons::Circle + "  " + link);
    UI::SameLine(0, 0);
    string badgeWord = g_badges.Length == 1 ? "badge" : "badges";
    string right = Icons::Trophy + " " + tostring(TotalPoints()) + " pts | " +
                   Icons::Gift + " " + tostring(OpenedCount()) + "/" + tostring(DAY_COUNT) + " gifts | " +
                   Icons::Star + " " + tostring(g_badges.Length) + " " + badgeWord;
    float w = UI::MeasureString(right, null, FS_LABEL, 0.0f).x + 8.0f * UiK();
    if (w < 1.0f) w = 320.0f * UiK();
    UI::SetCursorPosX(UI::GetWindowSize().x - w - 16.0f * UiK());
    TextTone(MixCol(TextMuted(), TextMain(), 0.50f), right);
    UI::PopFontSize();
}

void RenderWorkspace() {
    // Compact tab bar replaces the old five-button sidebar. The workspace
    // stays transparent so glass does not stack into an opaque wall.
    UI::PushStyleColor(UI::Col::ChildBg, g_palette.containerBg);
    if (UI::BeginChild("##goaladventWorkspace", vec2(0, -30), UI::ChildFlags::None)) {
        UI::PushFontSize(FS_BODY);
        // ARMAS-style tab strip: tight 2 px gaps, uppercase labels, white
        // active rectangle with dark text, dark glass with white text else.
        UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(2.0f * UiK(), 8.0f * UiK()));
        // BeginTabBar returns void in this build: never capture its result.
        UI::BeginTabBar("##goaladventTabs");
        UI::PushStyleColor(UI::Col::Text, g_activeTab == 0 ? g_palette.tabActiveText : g_palette.text);
        if (UI::BeginTabItem(Icons::Calendar + " CALENDAR")) {
            if (g_activeTab != 0) { g_activeTab = 0; g_confirmReset = false; }
            RenderCalendarTab();
            UI::EndTabItem();
        }
        UI::PopStyleColor();
        UI::PushStyleColor(UI::Col::Text, g_activeTab == 1 ? g_palette.tabActiveText : g_palette.text);
        if (UI::BeginTabItem(Icons::Trophy + " LEADERBOARD")) {
            if (g_activeTab != 1) { g_activeTab = 1; g_confirmReset = false; }
            RenderLeaderboardTab();
            UI::EndTabItem();
        }
        UI::PopStyleColor();
        UI::PushStyleColor(UI::Col::Text, g_activeTab == 2 ? g_palette.tabActiveText : g_palette.text);
        if (UI::BeginTabItem(Icons::Rss + " LIVE FEED")) {
            if (g_activeTab != 2) { g_activeTab = 2; g_confirmReset = false; }
            RenderFeedTab();
            UI::EndTabItem();
        }
        UI::PopStyleColor();
        UI::PushStyleColor(UI::Col::Text, g_activeTab == 3 ? g_palette.tabActiveText : g_palette.text);
        if (UI::BeginTabItem(Icons::Crosshairs + " BOUNTIES")) {
            if (g_activeTab != 3) { g_activeTab = 3; g_confirmReset = false; }
            RenderBountyTab();
            UI::EndTabItem();
        }
        UI::PopStyleColor();
        UI::PushStyleColor(UI::Col::Text, g_activeTab == 4 ? g_palette.tabActiveText : g_palette.text);
        if (UI::BeginTabItem(Icons::Star + " FINALE")) {
            if (g_activeTab != 4) { g_activeTab = 4; g_confirmReset = false; }
            RenderFinaleTab();
            UI::EndTabItem();
        }
        UI::PopStyleColor();
        UI::EndTabBar();
        UI::PopStyleVar();
        UI::PopFontSize();
    }
    UI::EndChild();
    UI::PopStyleColor();
}

// All options live in Openplanet -> Settings -> Plugins -> GoalAdvent 2026. There is no
// separate settings window: the [Setting] declarations in Config.as are the
// single source of truth and are edited in the Openplanet menu.
void RenderDashboard() {
    ApplyUiScale();      // the setting scales text and containers together
    RefreshPalette();   // one layout, colours chosen by the active theme

    // Apply once per plugin load: compact default matching the preferred
    // layout (~524x588 on screen at OverlayScale 0.85). One-shot Always
    // overrides the saved size; afterwards the window drags and resizes freely.
    if (!g_windowSizeApplied) {
        UI::SetNextWindowSize(616, 692, UI::Cond::Always);
        UI::SetNextWindowPos(24, 40, UI::Cond::Always);
        g_windowSizeApplied = true;
    }
    if (!UI::Begin("GoalAdvent 2026", g_showCalendar)) {
        UI::End();
        return;
    }

    PushDashboardStyle();
    RenderHeaderCard();
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

    // Gift geometry: the box pops in, then the lid lifts and the halo expands.
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

    // Sparkles around the opening box.
    float tw = 0.55f + 0.45f * open;
    dl.AddCircleFilled(vec2(cx - 46.0f * UiK(), bodyTop - 12.0f * UiK()), 2.0f * UiK() * tw, FadeCol(Gold(), alpha * open));
    dl.AddCircleFilled(vec2(cx + 44.0f * UiK(), bodyTop - 6.0f * UiK()), 2.4f * UiK() * tw, FadeCol(Gold(), alpha * open));
    dl.AddCircleFilled(vec2(cx - 34.0f * UiK(), bodyTop - 34.0f * UiK()), 1.6f * UiK() * tw, FadeCol(accent, alpha * open));
    dl.AddCircleFilled(vec2(cx + 34.0f * UiK(), bodyTop - 30.0f * UiK()), 1.6f * UiK() * tw, FadeCol(accent, alpha * open));

    // Box body and ribbon.
    dl.AddRectFilled(vec4(bodyLeft, bodyTop, bw, bh),
                     FadeCol(vec4(accent.x * 0.32f, accent.y * 0.32f, accent.z * 0.32f, 1.0f), alpha), 3.0f * UiK());
    dl.AddRectFilled(vec4(cx - 4.0f * UiK(), bodyTop, 8.0f * UiK(), bh), FadeCol(accent, alpha), 1.0f);
    dl.AddRectFilled(vec4(bodyLeft, cy - 4.0f * UiK(), bw, 8.0f * UiK()), FadeCol(accent, alpha), 1.0f);

    // Lid rises and takes the bow with it.
    float lidLift = open * 26.0f * UiK();
    float lidH = 14.0f * UiK() * (0.60f + 0.40f * pop);
    float lidW = bw + 10.0f * UiK();
    float lidY = bodyTop - lidH - lidLift;
    dl.AddRectFilled(vec4(cx - lidW * 0.5f, lidY, lidW, lidH), FadeCol(accent, alpha), 3.0f * UiK());
    dl.AddCircleFilled(vec2(cx - 7.0f * UiK(), lidY - 5.0f * UiK()), 6.0f * UiK(), FadeCol(accent, alpha), 12);
    dl.AddCircleFilled(vec2(cx + 7.0f * UiK(), lidY - 5.0f * UiK()), 6.0f * UiK(), FadeCol(accent, alpha), 12);
    dl.AddCircleFilled(vec2(cx, lidY - 5.0f * UiK()), 3.5f * UiK(), FadeCol(Gold(), alpha), 10);

    // Result text.
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
               tostring(OpenedCount()) + "/" + tostring(DAY_COUNT) + " gifts open",
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
        if (InWarmupGate()) UI::TextDisabled("Warmup | CP counting paused");
        UI::Text("Goal " + tostring(GOAL_CP) + " CP | session " + tostring(g_sessionCp) + " CP");
        UI::Text("Bounty " + tostring(g_bountyCp[day - 1]) + " CP | " +
                 Text::StripFormatCodes(g_bountyHolder[day - 1]));
        UI::Text("Best | " + tostring(g_bests[day - 1]) + " CP");
        UI::PopFontSize();
    }
    UI::End();
    UI::PopStyleColor();
}
