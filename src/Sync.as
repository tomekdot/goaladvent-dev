// Banner / feed helpers and the two free sync transports.

// ---------------------------------------------------------------------------
// Banner and feed
// ---------------------------------------------------------------------------
void ShowBanner(const string &in text) {
    g_bannerText = text;
    g_bannerTimer = 6.0f;
    if (S_Notifications) {
        UI::ShowNotification("Goalmas", text, 5000);
    }
}

void PushFeed(const string &in text) {
    string line = text;
    g_liveFeed.InsertAt(0, line);
    while (g_liveFeed.Length > 15) g_liveFeed.RemoveAt(g_liveFeed.Length - 1);
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

void AddBoardRow(const string &in name, int points, int bounties) {
    if (name.Length == 0) return;
    for (uint i = 0; i < g_boardNames.Length; i++) {
        if (g_boardNames[i] != name) continue;
        if (points > g_boardPoints[i]) {
            g_boardPoints[i] = points;
            g_boardBounties[i] = bounties;
        }
        return;
    }
    g_boardNames.InsertLast(name);
    g_boardPoints.InsertLast(points);
    g_boardBounties.InsertLast(bounties);
}

void SortBoard() {
    // Simple insertion sort - the board never holds more than ~50 players.
    for (int i = 1; i < int(g_boardPoints.Length); i++) {
        int points = g_boardPoints[i];
        int bounties = g_boardBounties[i];
        string name = g_boardNames[i];
        int j = i - 1;
        while (j >= 0 && g_boardPoints[j] < points) {
            g_boardPoints[j + 1] = g_boardPoints[j];
            g_boardBounties[j + 1] = g_boardBounties[j];
            g_boardNames[j + 1] = g_boardNames[j];
            j--;
        }
        g_boardPoints[j + 1] = points;
        g_boardBounties[j + 1] = bounties;
        g_boardNames[j + 1] = name;
    }
}

void RefreshFolderBoard() {
    string folder = SyncFolder();
    if (folder.Length == 0) return;
    if (!IO::FolderExists(folder)) return;

    g_boardNames.Resize(0);
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
        AddBoardRow(name, points, bounties);
    }
    SortBoard();
    g_lastSyncStamp = int(Time::Stamp);
}

// ---------------------------------------------------------------------------
// HTTP transport (free Cloudflare Worker + D1)
// ---------------------------------------------------------------------------
void ApplyState(const string &in body) {
    Json::Value@ root = Json::Parse(body);
    if (root is null || root.GetType() != Json::Type::Object) return;

    if (root.HasKey("badges")) {
        Json::Value@ badges = root["badges"];
        if (badges !is null && badges.GetType() == Json::Type::Array) {
            for (uint i = 0; i < badges.Length; i++) AddBadge(string(badges[i]));
        }
    }

    Json::Value@ days = root["days"];
    if (days !is null && days.GetType() == Json::Type::Array) {
        for (uint i = 0; i < days.Length; i++) {
            Json::Value@ dayObj = days[i];
            if (dayObj is null || dayObj.GetType() != Json::Type::Object) continue;
            if (!dayObj.HasKey("day")) continue;
            int day = int(dayObj["day"]);
            if (day < 1 || day > DAY_COUNT) continue;
            int idx = day - 1;

            if (dayObj.HasKey("bountyCp")) {
                int value = int(dayObj["bountyCp"]);
                if (value > g_bountyCp[idx]) g_bountyCp[idx] = value;
            }
            if (dayObj.HasKey("bountyHolder")) {
                string holder = string(dayObj["bountyHolder"]);
                if (holder.Length > 0) g_bountyHolder[idx] = holder;
            }
            if (dayObj.HasKey("myBestCp")) {
                int best = int(dayObj["myBestCp"]);
                if (best > g_bests[idx]) g_bests[idx] = best;
            }
        }
    }

    Json::Value@ board = root["leaderboard"];
    if (board !is null && board.GetType() == Json::Type::Array) {
        g_boardNames.Resize(0);
        g_boardPoints.Resize(0);
        g_boardBounties.Resize(0);
        for (uint i = 0; i < board.Length; i++) {
            Json::Value@ row = board[i];
            if (row is null || row.GetType() != Json::Type::Object) continue;
            string name = row.HasKey("name") ? string(row["name"]) : "";
            int points = row.HasKey("points") ? int(row["points"]) : 0;
            int bounties = row.HasKey("bounties") ? int(row["bounties"]) : 0;
            AddBoardRow(name, points, bounties);
        }
        SortBoard();
    }

    Json::Value@ events = root["events"];
    if (events !is null && events.GetType() == Json::Type::Array) {
        g_liveFeed.Resize(0);
        for (uint i = 0; i < events.Length; i++) {
            string line = string(events[i]);
            if (line.Length > 0) g_liveFeed.InsertLast(line);
        }
        if (g_liveFeed.Length > 0 && g_liveFeed[0] != g_lastTopEvent) {
            g_lastTopEvent = g_liveFeed[0];
            ShowBanner(g_lastTopEvent);
        }
    }

    g_lastSyncStamp = int(Time::Stamp);
}

void SyncState() {
    if (g_syncing) return;
    if (S_SyncMode != 2) return;
    if (ApiUrl().Length == 0) return;

    g_syncing = true;
    string url = ApiUrl() + "/state?accountId=" + Net::UrlEncode(AccountId());
    Net::HttpRequest@ req = Net::HttpGet(url);
    while (!req.Finished()) yield();

    if (req.ResponseCode() == 200) {
        ApplyState(req.String());
        g_status = "Synced with the event server.";
    } else {
        g_status = "Sync failed (HTTP " + tostring(req.ResponseCode()) + ").";
    }
    g_syncing = false;
}

void SyncNow() {
    if (S_SyncMode == 1) {
        WriteFolderFile();
        RefreshFolderBoard();
    } else if (S_SyncMode == 2) {
        SyncState();
        g_status = "Asking the event server for the latest results.";
    } else {
        SaveProgress();
        g_status = "Offline mode - progress saved on this PC.";
    }
}
