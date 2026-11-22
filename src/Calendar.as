// Calendar content, date rules, scoring and local storage.

// ---------------------------------------------------------------------------
// Content
// ---------------------------------------------------------------------------
// Rest-day labels are aligned with g_offDays = { 1, 8, 15, 22 }. An earlier
// version shifted them by two days, so day 3 wrongly showed "Rest Day I".
array<string> g_titles = {
    "Rest Day I", "First Snow", "The Old Garage", "Warm Cocoa", "Night Drive",
    "Frozen Circuit", "Hidden Checkpoint", "Rest Day II", "Snowman Crew", "Golden Turbo",
    "Winter Radio", "Lantern Trail", "Gift Wrap", "Starlight Lap", "Rest Day III",
    "Reindeer Shortcut", "Candlelight Run", "Frostbite Drift", "A Little Help", "Silver Bell",
    "Midnight Map", "Rest Day IV", "Snowball Fight", "The Long Way Home", "THE BIG FINALE"
};

array<string> g_hints = {
    "Pursuit night | no Goal Hunt today.",
    "Collect the goals near the spawn, then look up.",
    "Someone left the garage door open | drive through it.",
    "The warm line is never the direct line.",
    "The dark route holds two extra goals.",
    "Ice changes the racing line | brake early.",
    "One goal is not visible on the minimap.",
    "Pursuit night | no Goal Hunt today.",
    "Three snowmen point at the hidden goals.",
    "The boost pad is brighter than it looks.",
    "Turn the radio on and follow the beat.",
    "Follow the lanterns, not the road.",
    "Some goals are wrapped | bump them open.",
    "Count the stars above the finish line.",
    "Pursuit night | no Goal Hunt today.",
    "There is a shortcut only reindeer use.",
    "Slow down to see the last two goals.",
    "Drift on the cold side of the road.",
    "A friend is waiting on the roof.",
    "Listen for the bell before the last goal.",
    "The map changes after midnight.",
    "Pursuit night | no Goal Hunt today.",
    "Aim at the biggest snowball.",
    "The shortcut is the long way around.",
    "Bring all 24 fragments together and chase every goal."
};

array<string> g_fragments = {
    "M", "E", "R", "R", "Y", "X", "M", "A", "S", "O", "P", "E",
    "N", "P", "L", "A", "N", "E", "T", "2", "0", "2", "6", "!"
};

// Rest days: Tuesdays without a Goal Hunt. Must match worker.js (TUESDAY_OFF_DAYS).
array<int> g_offDays = { 1, 8, 15, 22 };

// ---------------------------------------------------------------------------
// Dates
// ---------------------------------------------------------------------------
bool IsOffDay(int day) {
    for (uint i = 0; i < g_offDays.Length; i++) {
        if (g_offDays[i] == day) return true;
    }
    return false;
}

// Every event-window decision uses the server UTC clock, matching the worker.
Time::Info Today() {
    return Time::ParseUTC();
}

// A fresh /state response is the authority for the event calendar. Offline or
// after a long outage, the local UTC clock is the only clock available.
bool ServerClockFresh() {
    if (g_serverClockStamp <= 0) return false;
    int age = int(Time::Stamp) - g_serverClockStamp;
    return age >= 0 && age <= SERVER_CLOCK_TTL_SEC;
}

bool IsPremiereDay(int day) {
    // The worker awards x2 from the server UTC clock. Use the same clock here
    // so the local badge/preview never disagrees with the leaderboard.
    if (ServerClockFresh()) return g_serverMonth == 12 && g_serverDate == day;
    Time::Info now = Today();
    return now.Month == 12 && now.Day == day;
}

// ---------------------------------------------------------------------------
// Moon phase (offline, no data file): synodic month counted from the new moon
// of 2000-01-06 18:14 UTC. Accurate to about a day, plenty for a tile caption.
// ---------------------------------------------------------------------------
const double SYNODIC_DAYS = 29.530588853;
const int64 NEW_MOON_REF = 947182440;     // 2000-01-06 18:14 UTC
const int64 EVENT_DAY1_UTC = 1796083200;  // 2026-12-01 00:00 UTC

// Moon age in days (0 = new moon) at noon UTC of the given event day.
double MoonAge(int day) {
    int64 stamp = EVENT_DAY1_UTC + int64(day - 1) * 86400 + 43200;
    double days = double(stamp - NEW_MOON_REF) / 86400.0;
    double age = days - Math::Floor(days / SYNODIC_DAYS) * SYNODIC_DAYS;
    return age;
}

string MoonPhaseName(int day) {
    double age = MoonAge(day);
    if (age < 1.85) return "New moon";
    if (age < 5.54) return "Waxing crescent";
    if (age < 9.23) return "First quarter";
    if (age < 12.92) return "Waxing gibbous";
    if (age < 16.61) return "Full moon";
    if (age < 20.30) return "Waning gibbous";
    if (age < 23.99) return "Last quarter";
    if (age < 27.68) return "Waning crescent";
    return "New moon";
}

int MoonIlluminationPct(int day) {
    double frac = (1.0 - Math::Cos(2.0 * Math::PI * MoonAge(day) / SYNODIC_DAYS)) * 0.5;
    return int(frac * 100.0 + 0.5);
}

// Double points only on the day a map premieres (server time decides online).
int DayMultiplier(int day) {
    return IsPremiereDay(day) ? 2 : 1;
}

// The finale stays open until 5 January so nobody has to be online on the 25th.
bool FinaleOpen() {
    if (ServerClockFresh()) {
        if (g_serverMonth == 12) return g_serverDate >= DAY_COUNT;
        return g_serverMonth == 1 && g_serverDate <= FINALE_GRACE_DAYS;
    }
    Time::Info now = Today();
    if (now.Month == 12) return now.Day >= DAY_COUNT;
    if (now.Month == 1) return now.Day <= FINALE_GRACE_DAYS;
    return false;
}

// Day unlock (and the premiere shown on a tile) follows the worker clock when
// it was heard recently. A changed PC clock can still unlock tiles offline,
// but /submit re-checks the day against server UTC before it counts anything.
bool ServerDayUnlocked(int day) {
    if (g_serverCatchUp) return true;
    if (g_serverMonth == 12) return g_serverDate >= day;
    return false;
}

// Event day from the server-side UTC clock, used when a Goal Hunt map has no
// day number in its name. Returns 0 outside 1-25 December / finale window.
int CurrentEventDayUtc() {
    if (ServerClockFresh()) return g_serverDay;
    Time::Info now = Time::ParseUTC();
    if (now.Month == 12) {
        // 26-31 December are still the finale window.
        return now.Day >= 1 && now.Day <= DAY_COUNT ? now.Day : DAY_COUNT;
    }
    // In January a nameless map cannot be assigned to a specific catch-up day.
    return 0;
}

bool DayUnlocked(int day) {
    if (S_TestMode) return true;
    if (day < 1 || day > DAY_COUNT) return false;
    if (day == DAY_COUNT) return FinaleOpen();
    if (ServerClockFresh()) return ServerDayUnlocked(day);
    Time::Info now = Today();
    if (now.Month == 12) return now.Day >= day;
    return now.Month == 1 && now.Day <= FINALE_GRACE_DAYS;   // catch-up after the event
}

// Every day stays playable until the end of the event, so a missed day
// only costs the premium multiplier, never the streak.
bool DayPlayableNow(int day) {
    if (S_TestMode) return true;
    if (IsOffDay(day)) return false;
    if (day == DAY_COUNT) return FinaleOpen();
    if (ServerClockFresh()) return ServerDayUnlocked(day);
    Time::Info now = Today();
    if (now.Month == 12) return now.Day >= day;
    return now.Month == 1 && now.Day <= FINALE_GRACE_DAYS;
}

// ---------------------------------------------------------------------------
// Checkpoint tiers (visual only, never a scoring rule)
// ---------------------------------------------------------------------------
// The tracker, the HUD and the tiles all read the same numbers: a run can
// never show more CP than the server accepts, and never a negative count.
int ClampCp(int cp) {
    if (cp < 0) return 0;
    if (cp > MAX_CP) return MAX_CP;
    return cp;
}

// 0 = below the goal, 1 = day complete, 2 = silver, 3 = gold.
int CpTier(int cp) {
    if (cp >= GOLD_CP) return 3;
    if (cp >= SILVER_CP) return 2;
    if (cp >= GOAL_CP) return 1;
    return 0;
}

string CpTierLabel(int tier) {
    if (tier >= 3) return "gold";
    if (tier == 2) return "silver";
    if (tier == 1) return "completed";
    return "no run";
}

// Best known run for one day. While that day's Goal Hunt is active the live
// session wins, so the tile, the details pane and the HUD always agree.
int BestCp(int day) {
    if (day < 1 || day > DAY_COUNT) return 0;
    int best = ClampCp(g_bests[day - 1]);
    if (g_activeDay == day && g_sessionCp > best) best = ClampCp(g_sessionCp);
    return best;
}

// ---------------------------------------------------------------------------
// Scoring
// ---------------------------------------------------------------------------
int OpenedCount() {
    int n = 0;
    for (uint i = 0; i < g_opened.Length; i++) {
        if (g_opened[i]) n++;
    }
    return n;
}

// Best 15 of the 24 regular days - a missed day never kills the run.
int ScoreDays() {
    array<int> vals;
    for (int d = 1; d < DAY_COUNT; d++) {
        if (g_opened[d - 1]) vals.InsertLast(g_points[d - 1]);
    }
    vals.SortAsc();
    int total = 0;
    int start = int(vals.Length) > BEST_OF_DAYS ? int(vals.Length) - BEST_OF_DAYS : 0;
    for (int i = start; i < int(vals.Length); i++) total += vals[i];
    return total;
}

int TotalPoints() {
    int total = ScoreDays();
    total += g_points[24];   // finale always counts
    return total;
}

string FinalCode() {
    string code = "";
    for (uint i = 0; i < g_fragments.Length; i++) code += g_fragments[i];
    return code;
}

// ---------------------------------------------------------------------------
// Badges
// ---------------------------------------------------------------------------
bool HasBadge(const string &in name) {
    for (uint i = 0; i < g_badges.Length; i++) {
        if (g_badges[i] == name) return true;
    }
    return false;
}

void AddBadge(const string &in name) {
    if (name.Length == 0) return;
    if (HasBadge(name)) return;
    g_badges.InsertLast(name);
}

string BadgeSummary() {
    if (g_badges.Length == 0) return "none";
    string result = "";
    for (uint i = 0; i < g_badges.Length; i++) {
        if (i > 0) result += ", ";
        result += g_badges[i];
    }
    return result;
}

// ---------------------------------------------------------------------------
// Storage
// ---------------------------------------------------------------------------
void ResetProgress() {
    g_opened.Resize(DAY_COUNT);
    g_bests.Resize(DAY_COUNT);
    g_points.Resize(DAY_COUNT);
    g_bountyCp.Resize(DAY_COUNT);
    g_bountyHolder.Resize(DAY_COUNT);
    g_bountyClaimed.Resize(DAY_COUNT);
    for (int i = 0; i < DAY_COUNT; i++) {
        g_opened[i] = false;
        g_bests[i] = 0;
        g_points[i] = 0;
        g_bountyCp[i] = DEFAULT_BOUNTY_CP;
        g_bountyHolder[i] = "GrinchBot";
        g_bountyClaimed[i] = false;
    }
    g_badges.Resize(0);
    g_bountiesWon = 0;
}

// Dev-only preview of a complete season. It changes in-memory arrays so the
// tiles, details, board and HUD can be reviewed before release; SaveProgress()
// and the submit path are disabled while it is on, so the real save is safe.
void ApplyQaPreview() {
    if (S_QaPreview <= 0) return;
    g_badges.Resize(0);
    g_bountiesWon = 0;
    for (int i = 0; i < DAY_COUNT; i++) {
        bool finale = (i == DAY_COUNT - 1);
        bool open = S_QaPreview == 3 ? finale : true;
        g_opened[i] = open;
        g_bountyClaimed[i] = false;
        g_bountyHolder[i] = "QA Bot";
        g_bountyCp[i] = S_QaPreview == 3 ? DEFAULT_BOUNTY_CP : GOLD_CP;
        if (!open) {
            g_bests[i] = 0;
            g_points[i] = 0;
            continue;
        }
        if (S_QaPreview == 2) {
            int mode = i % 3;
            g_bests[i] = mode == 0 ? GOAL_CP : (mode == 1 ? SILVER_CP : GOLD_CP);
        } else {
            g_bests[i] = S_QaPreview == 3 ? GOLD_CP : SILVER_CP;
        }
        g_points[i] = finale ? FINALE_POINTS : BASE_POINTS;
    }
    AddBadge("GOALMAS-2026");
    AddBadge("GOALMAS-PLAYER");
    AddBadge("BOUNTY-HUNTER");
    AddBadge("ELF-VETERAN");
    AddBadge("GOALMAS-24");
    AddBadge("FINALIST");
    AddBadge("PURSUIT");
    AddBadge("MP-GALAXY");
}

void LoadArrayBool(Json::Value@ root, const string &in key, array<bool> &inout target) {
    if (root is null || !root.HasKey(key)) return;
    Json::Value@ arr = root[key];
    if (arr is null || arr.GetType() != Json::Type::Array) return;
    for (uint i = 0; i < target.Length && i < arr.Length; i++) {
        target[i] = bool(arr[i]);
    }
}

void LoadArrayInt(Json::Value@ root, const string &in key, array<int> &inout target) {
    if (root is null || !root.HasKey(key)) return;
    Json::Value@ arr = root[key];
    if (arr is null || arr.GetType() != Json::Type::Array) return;
    for (uint i = 0; i < target.Length && i < arr.Length; i++) {
        target[i] = int(arr[i]);
    }
}

void LoadProgress() {
    ResetProgress();
    if (!IO::FileExists(SAVE_FILE)) return;

    Json::Value@ root = Json::FromFile(SAVE_FILE);
    if (root is null || root.GetType() != Json::Type::Object) return;

    if (root.HasKey("accountId")) g_cachedAccountId = string(root["accountId"]);
    if (root.HasKey("bounties")) g_bountiesWon = int(root["bounties"]);
    if (root.HasKey("resetEpoch")) {
        Json::Value@ epoch = root["resetEpoch"];
        if (epoch !is null && epoch.GetType() == Json::Type::Number) {
            g_resetEpoch = int(epoch);
        }
    }
    LoadArrayBool(root, "opened", g_opened);
    LoadArrayInt(root, "bests", g_bests);
    LoadArrayInt(root, "points", g_points);
    LoadArrayInt(root, "bountyCp", g_bountyCp);
    LoadArrayBool(root, "bountyClaimed", g_bountyClaimed);

    if (root.HasKey("bountyHolder")) {
        Json::Value@ arr = root["bountyHolder"];
        if (arr !is null && arr.GetType() == Json::Type::Array) {
            for (uint i = 0; i < g_bountyHolder.Length && i < arr.Length; i++) {
                g_bountyHolder[i] = string(arr[i]);
            }
        }
    }
    if (root.HasKey("badges")) {
        Json::Value@ arr = root["badges"];
        if (arr !is null && arr.GetType() == Json::Type::Array) {
            for (uint i = 0; i < arr.Length; i++) AddBadge(string(arr[i]));
        }
    }
    ApplyQaPreview();
}

void SaveProgress() {
    if (S_QaPreview > 0) return;   // never write mock data over a real save
    Json::Value@ root = Json::Object();
    root["version"] = 2;
    root["accountId"] = AccountId();
    root["bounties"] = g_bountiesWon;
    root["resetEpoch"] = g_resetEpoch;

    Json::Value@ opened = Json::Array();
    Json::Value@ bests = Json::Array();
    Json::Value@ points = Json::Array();
    Json::Value@ bountyCp = Json::Array();
    Json::Value@ bountyHolder = Json::Array();
    Json::Value@ bountyClaimed = Json::Array();
    for (int i = 0; i < DAY_COUNT; i++) {
        opened.Add(g_opened[i]);
        bests.Add(g_bests[i]);
        points.Add(g_points[i]);
        bountyCp.Add(g_bountyCp[i]);
        bountyHolder.Add(g_bountyHolder[i]);
        bountyClaimed.Add(g_bountyClaimed[i]);
    }
    root["opened"] = opened;
    root["bests"] = bests;
    root["points"] = points;
    root["bountyCp"] = bountyCp;
    root["bountyHolder"] = bountyHolder;
    root["bountyClaimed"] = bountyClaimed;

    Json::Value@ badges = Json::Array();
    for (uint i = 0; i < g_badges.Length; i++) badges.Add(g_badges[i]);
    root["badges"] = badges;

    Json::ToFile(SAVE_FILE, root, true);
}
