// Banner / feed helpers and the two free sync transports.

// ---------------------------------------------------------------------------
// Banner and feed
// ---------------------------------------------------------------------------
void ShowBanner(const string &in text) {
    // Player names arrive with ManiaPlanet colour codes ($fff$s...$z);
    // banners and toasts must show plain names, never the raw escapes.
    string clean = Text::StripFormatCodes(text);
    g_bannerText = clean;
    g_bannerTimer = 6.0f;
    if (S_Notifications) {
        UI::ShowNotification("GoalAdvent 2026", clean, 5000);
    }
}

void PushFeed(const string &in text) {
    string line = text;
    g_liveFeed.InsertAt(0, line);
    while (g_liveFeed.Length > MAX_FEED_EVENTS) g_liveFeed.RemoveAt(g_liveFeed.Length - 1);
}

string ApiUrl() {
    string url = S_ApiBaseUrl.Trim();
    if (url.Length == 0) url = DEFAULT_API_URL.Trim();
    while (url.EndsWith("/")) url = url.SubStr(0, url.Length - 1);
    return url;
}

// ---------------------------------------------------------------------------
// Shared folder transport (SMB / OneDrive / Dropbox)
// ---------------------------------------------------------------------------
string SyncFolder() {
    string folder = S_SharedFolder.Trim();
    while (folder.EndsWith("\\") || folder.EndsWith("/")) {
        folder = folder.SubStr(0, folder.Length - 1);
    }
    if (folder.Length == 0) return "";
    return folder + "/" + SYNC_SUBFOLDER;
}

string SafeFileName(const string &in raw) {
    string safe = raw;
    safe = safe.Replace("/", "_");
    safe = safe.Replace("\\", "_");
    safe = safe.Replace(":", "_");
    safe = safe.Replace(" ", "_");
    if (safe.Length == 0) safe = "player";
    return safe;
}

Json::Value@ BuildLocalEntry() {
    Json::Value@ entry = Json::Object();
    entry["accountId"] = AccountId();
    entry["name"] = LocalName();
    entry["points"] = TotalPoints();
    entry["bounties"] = g_bountiesWon;
    entry["badges"] = BadgeSummary();

    Json::Value@ bests = Json::Object();
    for (int i = 0; i < DAY_COUNT; i++) {
        bests[tostring(i + 1)] = g_bests[i];
    }
    entry["bests"] = bests;
    return entry;
}

void WriteFolderFile() {
    string folder = SyncFolder();
    if (folder.Length == 0) return;
    if (!IO::FolderExists(folder)) IO::CreateFolder(folder, true);

    string path = folder + "/" + SafeFileName(AccountId()) + ".json";
    IO::File file(path, IO::FileMode::Write);
    file.Write(Json::Write(BuildLocalEntry(), true));
    file.Close();
    g_status = "Progress written to the shared folder.";
}

void AddBoardRow(const string &in name, int points, int bounties, const string &in accountId) {
    if (name.Length == 0) return;
    for (uint i = 0; i < g_boardNames.Length; i++) {
        bool same = accountId.Length > 0
            ? (i < g_boardAccountIds.Length && g_boardAccountIds[i] == accountId)
            : g_boardNames[i] == name;
        if (!same) continue;
        if (points > g_boardPoints[i]) {
            g_boardPoints[i] = points;
            g_boardBounties[i] = bounties;
        }
        return;
    }
    g_boardNames.InsertLast(name);
    g_boardAccountIds.InsertLast(accountId);
    g_boardPoints.InsertLast(points);
    g_boardBounties.InsertLast(bounties);
}

void SortBoard() {
    // Simple insertion sort - the board never holds more than ~50 players.
    for (int i = 1; i < int(g_boardPoints.Length); i++) {
        int points = g_boardPoints[i];
        int bounties = g_boardBounties[i];
        string name = g_boardNames[i];
        string accountId = i < int(g_boardAccountIds.Length) ? g_boardAccountIds[uint(i)] : "";
        int j = i - 1;
        while (j >= 0 && g_boardPoints[j] < points) {
            g_boardPoints[j + 1] = g_boardPoints[j];
            g_boardBounties[j + 1] = g_boardBounties[j];
            g_boardNames[j + 1] = g_boardNames[j];
            if (j >= 0 && uint(j) < g_boardAccountIds.Length) g_boardAccountIds[uint(j) + 1] = g_boardAccountIds[uint(j)];
            j--;
        }
        g_boardPoints[j + 1] = points;
        g_boardBounties[j + 1] = bounties;
        g_boardNames[j + 1] = name;
        if (i < int(g_boardAccountIds.Length)) g_boardAccountIds[uint(j) + 1] = accountId;
    }
}

void RefreshFolderBoard() {
    string folder = SyncFolder();
    if (folder.Length == 0) return;
    if (!IO::FolderExists(folder)) return;

    g_boardNames.Resize(0);
    g_boardAccountIds.Resize(0);
    g_boardPoints.Resize(0);
    g_boardBounties.Resize(0);

    string[]@ files = IO::IndexFolder(folder, false);
    if (files is null) return;
    for (uint i = 0; i < files.Length; i++) {
        string path = files[i];
        if (!path.ToLower().EndsWith(".json")) continue;
        IO::File file(path, IO::FileMode::Read);
        string text = file.ReadToEnd();
        file.Close();

        Json::Value@ entry = Json::Parse(text);
        if (entry is null || entry.GetType() != Json::Type::Object) continue;
        string name = entry.HasKey("name") ? string(entry["name"]) : "";
        int points = entry.HasKey("points") ? int(entry["points"]) : 0;
        int bounties = entry.HasKey("bounties") ? int(entry["bounties"]) : 0;
        string accountId = entry.HasKey("accountId") ? string(entry["accountId"]) : "";
        AddBoardRow(name, points, bounties, accountId);
    }
    SortBoard();
    g_lastSyncStamp = int(Time::Stamp);
}

// ---------------------------------------------------------------------------
// HTTP transport (free Cloudflare Worker + D1)
// ---------------------------------------------------------------------------
// /state is untrusted input: every value is read through a type check so one
// malformed row can never throw a script exception in the middle of a sync.
int JsonIntOr(Json::Value@ obj, const string &in key, int fallback) {
    if (obj is null || !obj.HasKey(key)) return fallback;
    Json::Value@ value = obj[key];
    if (value is null || value.GetType() != Json::Type::Number) return fallback;
    return int(value);
}

string JsonStrOr(Json::Value@ obj, const string &in key, const string &in fallback) {
    if (obj is null || !obj.HasKey(key)) return fallback;
    Json::Value@ value = obj[key];
    if (value is null || value.GetType() != Json::Type::String) return fallback;
    return string(value);
}

bool JsonBoolOr(Json::Value@ obj, const string &in key, bool fallback) {
    if (obj is null || !obj.HasKey(key)) return fallback;
    Json::Value@ value = obj[key];
    if (value is null || value.GetType() != Json::Type::Boolean) return fallback;
    return bool(value);
}

void ApplyState(const string &in body) {
    Json::Value@ root = Json::Parse(body);
    if (root is null || root.GetType() != Json::Type::Object) return;

    int srvMonth = JsonIntOr(root, "serverMonth", 0);
    int srvDate = JsonIntOr(root, "serverDate", 0);

    // An admin reset bumps the server epoch. Drop the local save once, then
    // keep syncing normally - other players are unaffected.
    int epoch = JsonIntOr(root, "resetEpoch", 0);
    if (epoch > 0 && epoch != g_resetEpoch) {
        // A missing/zero epoch means an older save, which may still hold test
        // progress from before the reset. Clear once, then persist the new one.
        g_resetEpoch = epoch;
        ResetProgress();
        SaveProgress();
        g_status = "Server data was reset | local progress cleared.";
    }
    if (srvMonth >= 1 && srvMonth <= 12 && srvDate >= 1 && srvDate <= 31) {
        g_serverMonth = srvMonth;
        g_serverDate = srvDate;
        g_serverDay = JsonIntOr(root, "serverDay", 0);
        g_serverClockStamp = int(Time::Stamp);
    }

    // The server bucket is authoritative. A changed bucket closes the previous
    // event day: only then is the whole-day counter allowed to restart.
    string bucket = JsonStrOr(root, "bucketDate", "");
    if (bucket.Length > 0 && bucket != g_bucketDate) {
        g_bucketDate = bucket;
        ResetSession();
        if (g_serverDay > 0) {
            g_activeDay = g_serverDay;
            g_selectedDay = g_serverDay;
        }
        g_status = "New event day | checkpoint total restarted.";
    }
    int serverDayCp = ClampCp(JsonIntOr(root, "dayCp", 0));
    if (serverDayCp > g_dayCp) g_dayCp = serverDayCp;
    // A reinstall or a second client can already have a higher bucket total
    // than this local run; keep the whole-day number in sync with the server.
    if (serverDayCp > g_sessionCp) {
        g_sessionCp = serverDayCp;
        if (g_sessionCp > g_lastSentCp) g_lastSentCp = g_sessionCp;
    }

    if (root.HasKey("badges")) {
        Json::Value@ badges = root["badges"];
        if (badges !is null && badges.GetType() == Json::Type::Array) {
            for (uint i = 0; i < badges.Length; i++) {
                Json::Value@ badge = badges[i];
                if (badge is null || badge.GetType() != Json::Type::String) continue;
                AddBadge(string(badge));
            }
        }
    }

    Json::Value@ days = root["days"];
    if (days !is null && days.GetType() == Json::Type::Array) {
        for (uint i = 0; i < days.Length; i++) {
            Json::Value@ dayObj = days[i];
            if (dayObj is null || dayObj.GetType() != Json::Type::Object) continue;
            if (!dayObj.HasKey("day")) continue;
            int day = JsonIntOr(dayObj, "day", 0);
            if (day < 1 || day > DAY_COUNT) continue;
            int idx = day - 1;

            int value = ClampCp(JsonIntOr(dayObj, "bountyCp", 0));
            if (value > g_bountyCp[idx]) g_bountyCp[idx] = value;
            string holder = JsonStrOr(dayObj, "bountyHolder", "");
            if (holder.Length > 0) g_bountyHolder[idx] = holder;
            // Canonical owner from the server. An empty value means an older
            // worker or a legacy row, so the display name stays the fallback.
            g_bountyHolderId[idx] = JsonStrOr(dayObj, "bountyHolderAccountId", "");
            int best = ClampCp(JsonIntOr(dayObj, "myBestCp", 0));
            if (best > g_bests[idx]) g_bests[idx] = best;
        }
    }

    Json::Value@ board = root["leaderboard"];
    if (board !is null && board.GetType() == Json::Type::Array) {
        g_boardNames.Resize(0);
        g_boardAccountIds.Resize(0);
        g_boardPoints.Resize(0);
        g_boardBounties.Resize(0);
        for (uint i = 0; i < board.Length; i++) {
            Json::Value@ row = board[i];
            if (row is null || row.GetType() != Json::Type::Object) continue;
            string name = JsonStrOr(row, "name", "");
            int points = JsonIntOr(row, "points", 0);
            int bounties = JsonIntOr(row, "bounties", 0);
            string accountId = JsonStrOr(row, "accountId", "");
            AddBoardRow(name, points, bounties, accountId);
        }
        SortBoard();
        g_boardCount = g_boardNames.Length;
    }

    Json::Value@ events = root["events"];
    if (events !is null && events.GetType() == Json::Type::Array) {
        g_liveFeed.Resize(0);
        for (uint i = 0; i < events.Length; i++) {
            Json::Value@ entry = events[i];
            if (entry is null || entry.GetType() != Json::Type::String) continue;
            string line = string(entry);
            if (line.Length > 0) g_liveFeed.InsertLast(line);
        }
        if (g_liveFeed.Length > 0 && g_liveFeed[0] != g_lastTopEvent) {
            g_lastTopEvent = g_liveFeed[0];
            ShowBanner(g_lastTopEvent);
        }
    }

    // Server-learned map UIDs: new maps work for everyone after the first run.
    Json::Value@ mapDays = root["mapDays"];    if (mapDays !is null && mapDays.GetType() == Json::Type::Object) {
        g_serverMapUids.Resize(0);
        g_serverMapDays.Resize(0);
        array<string>@ keys = mapDays.GetKeys();
        for (uint i = 0; i < keys.Length; i++) {
            int day = JsonIntOr(mapDays, keys[i], 0);
            if (day >= 1 && day <= DAY_COUNT) {
                g_serverMapUids.InsertLast(keys[i]);
                g_serverMapDays.InsertLast(day);
            }
        }
    }

    // A UID mapping may have just arrived for the map we are already on.
    if (g_activeDay <= 0) {
        int detected = DetectGoalHuntDay();
        if (detected > 0) {
            g_activeDay = detected;
            int bucketDay = CurrentEventDayUtc();
            if (bucketDay > 0) g_activeDay = bucketDay;
            g_selectedDay = g_activeDay;
            ResetRun();
        }
    }

    // A live sync may have overwritten the mock arrays; restore the preview.
    ApplyQaPreview();

    g_lastSyncStamp = int(Time::Stamp);
}

void SyncState() {
    if (g_syncing) return;
    if (S_SyncMode != 2) return;
    if (ApiUrl().Length == 0) return;

    g_syncing = true;
    string url = ApiUrl() + "/state?accountId=" + Net::UrlEncode(AccountId());
    Net::HttpRequest@ req = Net::HttpGet(url);
    if (req is null) {
        g_lastSyncOk = false;
        g_lastSyncHttp = 0;
        DebugError("sync", "could not create state request");
        g_syncing = false;
        return;
    }
    while (!req.Finished()) yield();

    int code = req.ResponseCode();
    g_lastSyncHttp = code;
    if (code == 200) {
        ApplyState(req.String());
        g_lastSyncOk = true;
        g_status = "Synced with the event server.";
    } else {
        g_lastSyncOk = false;
        g_status = "Sync failed (HTTP " + tostring(code) + ").";
        DebugError("sync", "HTTP " + tostring(code));
    }
    g_syncing = false;
}

// Admin self-test: one HTTP GET to the worker root, run as a coroutine so it
// can be started from the debug button without suspending the UI context.
void SelfTestServer() {
    g_selfTestResult = "running...";
    if (ApiUrl().Length == 0) {
        g_selfTestResult = "FAIL | no API URL";
        return;
    }
    Net::HttpRequest@ req = Net::HttpGet(ApiUrl() + "/");
    if (req is null) {
        g_selfTestResult = "FAIL | request not created";
        return;
    }
    while (!req.Finished()) yield();
    int code = req.ResponseCode();
    if (code == 200) g_selfTestResult = "OK (HTTP 200)";
    else g_selfTestResult = "FAIL (HTTP " + tostring(code) + ")";
}

void SyncNow() {
    if (g_syncing) return;   // guard also covers auto-refresh, not just the header button

    if (S_SyncMode == 1) {
        WriteFolderFile();
        RefreshFolderBoard();
    } else if (S_SyncMode == 2) {
        // SyncState() yields on the HTTP request. It must run in a coroutine:
        // calling it from Render()/UI throws "Attempted to suspend in script
        // context that does not support suspension".
        startnew(SyncState);
        g_status = "Asking the event server for the latest results.";
    } else {
        SaveProgress();
        g_status = "Offline mode | progress saved on this PC.";
    }
}
