// goaladvent Calendar & Bounty - ManiaPlanet 4 / Openplanet 1.29
// 25 days of Goal Hunt checkpoint hunting, bounties, badges and a free
// leaderboard (offline, shared folder or a free HTTP worker + D1).
// Code, comments and UI strings are English by project convention.

// ---------------------------------------------------------------------------
// Appearance
// ---------------------------------------------------------------------------
enum UiTheme { ObsidianMinimal, TransparentGlass }

[Setting category="Appearance" name="UI Theme" description="Obsidian Minimal is matte carbon; Transparent Glass is neutral smoke with white frosted cards."]
UiTheme g_Theme = UiTheme::ObsidianMinimal;

[Setting category="Appearance" name="UI scale" description="Scales every font and the cards around it. 1.25 is the default; adjust it to taste." min=1.0 max=2.0]
float S_UiScale = 1.25f;

[Setting category="Appearance" name="Glass Opacity" description="Window tint strength. Lower values let more of the game show through." min=0.15 max=0.80]
float S_GlassOpacity = 0.55f;

bool GlassTheme() { return g_Theme == UiTheme::TransparentGlass; }

[Setting category="Advanced" name="Debug overlay" description="Admin-only diagnostics: live plugin state and a button that writes one readable line to Openplanet.log."]
bool S_Debug = false;

[Setting category="Appearance" name="Show moon phase percent" description="Show the illumination percentage on each calendar tile."]
bool S_ShowMoonPct = true;

[Setting category="Sync" name="Auto sync" description="Refresh the leaderboard every 20 seconds in the background."]
bool S_AutoSync = true;

[Setting category="Event" name="Map UID to day" description="Comma-separated UID=day pairs for maps whose name has no #N, e.g. P_abc=3,P_def=7. The debug panel can add the current map."]
string S_MapUidDays = "";

[Setting category="Event" name="Force current map as day" description="0 = auto-detect. Set 1-25 to treat the current map as that day (useful for testing)."]
int S_MapDayOverride = 0;



const string PLUGIN_VERSION = "0.5.14-dev";

// ---------------------------------------------------------------------------
// Tuning
// ---------------------------------------------------------------------------
const int DAY_COUNT = 25;
const int GOAL_CP = 10;            // checkpoints needed to complete a day
const int BASE_POINTS = 100;       // days 1..24
const int FINALE_POINTS = 300;     // day 25
const int BOUNTY_POINTS = 150;
const int DEFAULT_BOUNTY_CP = 15;  // starting GrinchBot record
const float SUBMIT_DEBOUNCE_SEC = 6.0f;
const int SYNC_INTERVAL_SEC = 20;
const int FINALE_GRACE_DAYS = 5;   // finale / catch-up window after Christmas

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------
[Setting category="General" name="Show dashboard on start" description="Open the GoalAdvent window when the game starts. Turn off to hide it until selected from the menu."]
bool S_ShowOnStart = true;

[Setting category="General" name="Test mode (unlock every day)" description="Unlock all 25 days for testing. Not intended for the real event."]
bool S_TestMode = false;

[Setting category="General" name="Show notifications" description="Enable in-game banners for completed days and bounties."]
bool S_Notifications = true;

[Setting category="General" name="Show in-game tips" description="Show the short how-to-play hint inside the calendar tab."]
bool S_ShowTips = true;

[Setting category="General" name="Opening animation" description="Play a short gift-opening card when a day is completed or a bounty is stolen."]
bool S_OpenAnimation = true;

[Setting category="General" name="Display name" description="Used only when the game login cannot be read."]
string S_Nickname = "Player";

[Setting category="Sync" name="Sync mode: 0 = offline, 1 = shared folder, 2 = HTTP worker"]
int S_SyncMode = 0;

[Setting category="Sync" name="Worker URL" description="Cloudflare Workers + D1 base URL, e.g. https://goaladvent.example.workers.dev (no trailing slash)."]
string S_ApiBaseUrl = "";

[Setting category="Sync" name="Shared folder" description="SMB / OneDrive / Dropbox folder shared by all players."]
string S_SharedFolder = "";

[Setting category="Event" name="Event server keyword" description="Part of the event server name or login. Empty = accept any server (testing)."]
string S_EventServerKeyword = "pursuit";

// ---------------------------------------------------------------------------
// Storage
// ---------------------------------------------------------------------------
const string SAVE_FILE = IO::FromStorageFolder("GoalmasAdvent.json");
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

// ---------------------------------------------------------------------------
// Goal Hunt state
// ---------------------------------------------------------------------------
int g_activeDay = 0;
string g_lastMapUid = "";
int g_sessionCp = 0;
int g_lastSentCp = 0;
int g_pendingDay = 0;
int g_pendingCp = 0;
bool g_submitPending = false;
bool g_submitQueued = false;
int g_submitRetries = 0;
float g_submitTimer = 0.0f;

// Digits used by the "#N Goal Hunt" name parser.
array<string> g_digits = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" };
