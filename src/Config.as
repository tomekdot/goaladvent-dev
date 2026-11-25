// goaladvent Calendar & Bounty - ManiaPlanet 4 / Openplanet 1.29
// 25 days of Goal Hunt checkpoint hunting, bounties, badges and a free
// leaderboard (offline, shared folder or a free HTTP worker + D1).
// Code, comments and UI strings are English by project convention.

// ---------------------------------------------------------------------------
// Appearance
// ---------------------------------------------------------------------------
enum UiTheme { Classic, GoalAdvent, Galaxy }

[Setting category="Appearance" name="UI Theme" description="Classic = blue accents; GoalAdvent = matte carbon; Galaxy = transparent glass."]
UiTheme g_Theme = UiTheme::Classic;

// Button palette, edited directly in Openplanet's settings panel (same style
// as the Event Calendar plugin). No extra window is needed.
[Setting category="Appearance" name="Button colour" description="Dashboard button base colour (RGBA)."]
vec4 S_ButtonColour = vec4(0.11, 0.11, 0.14, 1.0);
[Setting category="Appearance" name="Button hover colour" description="Dashboard button hover colour (RGBA)."]
vec4 S_ButtonHoverColour = vec4(0.17, 0.17, 0.21, 1.0);
[Setting category="Appearance" name="Button active colour" description="Dashboard button pressed colour (RGBA)."]
vec4 S_ButtonActiveColour = vec4(0.21, 0.21, 0.26, 1.0);
[Setting category="Appearance" name="Text colour" description="Dashboard text colour (RGBA)."]
vec4 S_ButtonTextColour = vec4(0.92, 0.92, 0.95, 1.0);

// Openplanet caches enum settings until a full game restart. This switch makes
// the new Galaxy theme active immediately; turn it off to use the selector.
[Setting category="Appearance" name="Galaxy theme" description="ON = transparent Galaxy look now. OFF = follow the UI Theme selector."]
bool S_GalaxyOn = true;

[Setting category="Appearance" name="UI scale" description="Scales every font and the cards around it. 1.25 is the default; adjust it to taste." min=1.0 max=2.0]
float S_UiScale = 1.25f;

[Setting category="Appearance" name="Glass Opacity" description="Window tint strength. Lower values let more of the game show through." min=0.15 max=0.80]
float S_GlassOpacity = 0.55f;

bool GlassTheme() { return S_GalaxyOn || g_Theme == UiTheme::Galaxy; }

[Setting category="Advanced" name="QA preview" description="Dev only: 0 off, 1 all days done, 2 CP tier mix, 3 finale only. Fills the dashboard with a mock 25-day season; preview data is never saved or submitted." min=0 max=3]
int S_QaPreview = 0;

[Setting category="Advanced" name="Debug overlay" description="Admin-only diagnostics: live plugin state and a button that writes one readable line to Openplanet.log."]
bool S_Debug = false;

[Setting category="Appearance" name="Show moon phase percent" description="Show the moon illumination percent on the calendar tiles."]
bool S_ShowMoonPct = true;

[Setting category="Appearance" name="Show day details" description="Show the day details strip next to the calendar. Off = full-width calendar only."]
bool S_ShowDayDetails = false;

[Setting category="Appearance" name="Traditional tiles" description="Colour each calendar tile surface by its state: gold premiere/finale, emerald completed, crimson action, purple rest, gray locked. Off = uniform frosted glass."]
bool S_TraditionalTiles = false;

[Setting category="Sync" name="Auto sync" description="Refresh the leaderboard every 20 seconds in the background."]
bool S_AutoSync = true;

[Setting category="Event" name="Map UID to day" description="Comma-separated UID=day pairs for maps whose name has no #N, e.g. P_abc=3,P_def=7. The debug panel can add the current map."]
string S_MapUidDays = "";

[Setting category="Event" name="Force current map as day" description="0 = auto-detect. Set 1-25 to treat the current map as that day (useful for testing)." min=0 max=25]
int S_MapDayOverride = 0;



// Debug overlay only. info.toml is the real version source; keep this in sync.
const string PLUGIN_VERSION = "0.6.7-dev";

// ---------------------------------------------------------------------------
// Tuning
// ---------------------------------------------------------------------------
const int DAY_COUNT = 25;
const int BEST_OF_DAYS = 15;       // best days 1..24 count toward the score
const int GOAL_CP = 10;            // checkpoints needed to complete a day
const int BASE_POINTS = 100;       // days 1..24
const int FINALE_POINTS = 300;     // day 25
const int BOUNTY_POINTS = 150;
const int DEFAULT_BOUNTY_CP = 15;  // starting GrinchBot record
// Run tiers are cosmetic only - points stay 100 / 300 / bounty 150.
const int SILVER_CP = DEFAULT_BOUNTY_CP;   // 15 CP, the starting bounty record
const int GOLD_CP = 30;            // top-tier run
const int MAX_CP = 250;            // must match MAX_CP in backend/worker.js
const float SUBMIT_DEBOUNCE_SEC = 6.0f;
const int SYNC_INTERVAL_SEC = 20;
const int SERVER_CLOCK_TTL_SEC = 180;      // server day mirror stays valid 3x the sync interval
const int FINALE_GRACE_DAYS = 5;   // finale / catch-up window after Christmas
const int MAX_FEED_EVENTS = 15;    // must match MAX_EVENTS in backend/worker.js
const int ELF_VETERAN_DAYS = 10;   // badge threshold, both client and server

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------
[Setting category="General" name="Show dashboard on start" description="Open the GoalAdvent window when the game starts. Turn off to hide it until selected from the menu."]
bool S_ShowOnStart = true;

[Setting category="General" name="Test mode" description="Unlock all 25 days and allow submitting test CP. Not intended for the real event."]
bool S_TestMode = false;

[Setting category="General" name="Show notifications" description="Enable in-game banners for completed days and bounties."]
bool S_Notifications = true;

[Setting category="General" name="Show in-game tips" description="Show the short how-to-play hint inside the calendar tab."]
bool S_ShowTips = true;

[Setting category="General" name="Opening animation" description="Play a short gift-opening card when a day is completed or a bounty is stolen."]
bool S_OpenAnimation = true;

[Setting category="General" name="Display name" description="Used only when the game login cannot be read."]
string S_Nickname = "Player";

[Setting category="Sync" name="Sync mode" description="0 = offline, 1 = shared folder, 2 = HTTP worker. Values outside 0-2 are ignored." min=0 max=2]
int S_SyncMode = 0;

[Setting category="Sync" name="Worker URL" description="Cloudflare Workers + D1 base URL, e.g. https://goaladvent.example.workers.dev (no trailing slash)."]
string S_ApiBaseUrl = "";

[Setting category="Sync" name="Shared folder" description="SMB / OneDrive / Dropbox folder shared by all players."]
string S_SharedFolder = "";

[Setting category="Event" name="Event server keyword" description="Part of the event server name or login. Empty = accept any server (testing)."]
string S_EventServerKeyword = "pursuit";

[Setting category="Event" name="Allowed titlepacks" description="Comma-separated TitleIds where detection may run, e.g. Pursuit,PursuitStadium. Empty = allow any titlepack."]
string S_AllowedTitlepacks = "Pursuit,PursuitStadium";

// ---------------------------------------------------------------------------
// Storage
// ---------------------------------------------------------------------------
const string SAVE_FILE = IO::FromStorageFolder("GoalmasAdvent.json");
// Written by tests/qa_checks.js; the debug panel shows PASS/FAIL from it.
const string QA_RESULT_FILE = "C:/Users/tomekdot/Openplanet4/Plugins/goaladvent-dev/tests/qa-result.json";
// Written by QA to force a clean local slate on the next reload.
const string QA_CLEAN_MARKER = "C:/Users/tomekdot/Openplanet4/Plugins/goaladvent-dev/.qa-clean-slate";
const string SYNC_SUBFOLDER = "GoalAdvent";

// Deployed worker URL. Paste it here once and every player syncs with no setup:
// the plugin switches to HTTP mode automatically when this is not empty.
const string DEFAULT_API_URL = "https://goalmas.tomekdot-goalmas.workers.dev";

// ---------------------------------------------------------------------------
// Windows
// ---------------------------------------------------------------------------
bool g_showCalendar = false;
bool g_showDay = false;
bool g_showFinale = false;
bool g_showBoard = false;
bool g_showFeed = false;
int g_selectedDay = 1;
string g_status = "";

// ---------------------------------------------------------------------------
// Progress
// ---------------------------------------------------------------------------
array<bool> g_opened;
array<int> g_bests;        // best checkpoint count of the local player
array<int> g_points;       // points collected per day
array<int> g_bountyCp;     // current bounty record per day
array<bool> g_bountyClaimed;  // bounty bonus already granted per day
array<string> g_bountyHolder;
array<string> g_badges;
int g_bountiesWon = 0;
// Last known account id, persisted so a profile that has not loaded yet does
// not fall back to a nickname-based id and create a second leaderboard row.
string g_cachedAccountId = "";

// Map detection history: every map played this session -> detected day, so the
// debug window can verify text detection catches each Goal Hunt map on the server.
array<string> g_mapHistory;

// ---------------------------------------------------------------------------
// Leaderboard cache (shared folder or worker)
// ---------------------------------------------------------------------------
array<string> g_boardNames;
array<string> g_boardAccountIds;   // stable MP4 login, independent of the nickname
array<int> g_boardPoints;
array<int> g_boardBounties;

// ---------------------------------------------------------------------------
// Live feed / banner
// ---------------------------------------------------------------------------
array<string> g_liveFeed;
string g_bannerText = "";
float g_bannerTimer = 0.0f;
string g_lastTopEvent = "";

// Advent opening animation. A completed day replaces the plain banner with a
// short gift-opening card; it never takes input so it cannot block driving.
const float OPEN_ANIM_SEC = 4.2f;
bool g_openAnimActive = false;
float g_openAnimTimer = 0.0f;
int g_openAnimDay = 0;
int g_openAnimPoints = 0;
int g_openAnimCp = 0;
bool g_openAnimBounty = false;
string g_openAnimTitle = "";

// ---------------------------------------------------------------------------
// Sync state
// ---------------------------------------------------------------------------
bool g_syncing = false;
int g_lastSyncStamp = 0;
bool g_lastSyncOk = false;
int g_lastSyncHttp = 0;
int g_boardCount = 0;
string g_selfTestResult = "not run";
// UID->day pairs learned from the server (shared by all players).
array<string> g_serverMapUids;
array<int> g_serverMapDays;
// Server clock mirror. The worker decides which day is open and which day is a
// premiere; these four values only let the UI show the same answer. They go
// stale on purpose so a long offline session falls back to the local clock.
int g_serverMonth = 0;
int g_serverDate = 0;
int g_serverDay = 0;
bool g_serverCatchUp = false;
int g_serverClockStamp = 0;
int g_resetEpoch = 0;      // server reset counter; 0 until the first /state

// ---------------------------------------------------------------------------
// Goal Hunt state
// ---------------------------------------------------------------------------
int g_activeDay = 0;
string g_lastMapUid = "";
int g_sessionCp = 0;
int g_liveCp = 0;
int g_liveTrigger = 0;
int g_prevTrigger = 0;
int g_lastSentCp = 0;
int g_pendingDay = 0;
int g_pendingCp = 0;
bool g_submitPending = false;
bool g_submitQueued = false;
int g_submitRetries = 0;
float g_submitTimer = 0.0f;

// Warmup gate: the first seconds of a race never count checkpoints, and any
// server warmup phase is excluded too. CP passed during warmup are subtracted
// via a baseline, so they cannot leak into the count when the gate lifts.
const int64 WARMUP_GRACE_SEC = 15;
// CTrackManiaScriptPlayer::ERaceState values (BeforeStart, Running, Finished,
// Eliminated) as ints, so the tracker does not depend on enum scope syntax.
const int RACE_BEFORE_START = 0;
const int RACE_RUNNING = 1;
const int RACE_FINISHED = 2;
int64 g_raceStartStamp = 0;   // Time::Stamp when the local race last started
int g_lastRaceState = -1;     // previous ERaceState snapshot
int g_lastCpBuffer = 0;
int g_lastCpTime = 0;
int g_prevCpTime = 0;       // previous raw Checkpoints.Length
int g_warmupCpBaseline = 0;   // buffer value accumulated during warmup
int g_curRaceState = 0;       // refreshed by CurrentCpCount()
int g_curRaceNbCp = 0;        // map checkpoints per lap (Score.LapsNbCheckpoint)

// Digits used by the "#N Goal Hunt" name parser.
array<string> g_digits = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" };
