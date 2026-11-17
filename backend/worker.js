// goalmas & Bounty - free Cloudflare Worker backend.
// Free tier: Cloudflare Workers + D1 (SQLite). No paid server, no card needed.
//
// SETUP (one time):
// 1. Cloudflare dashboard -> Workers & Pages -> D1 -> Create database (e.g. goalmas).
// 2. Run this schema in the D1 console:
//
//    CREATE TABLE IF NOT EXISTS players (
//      account_id TEXT PRIMARY KEY,
//      name TEXT NOT NULL,
//      points INTEGER NOT NULL DEFAULT 0,
//      bounties INTEGER NOT NULL DEFAULT 0,
//      badges TEXT NOT NULL DEFAULT '[]',
//      bests TEXT NOT NULL DEFAULT '{}'
//    );
//    CREATE TABLE IF NOT EXISTS bounties (
//      day INTEGER PRIMARY KEY,
//      cp INTEGER NOT NULL,
//      ms INTEGER NOT NULL DEFAULT 0,
//      holder TEXT NOT NULL
//    );
//    CREATE TABLE IF NOT EXISTS events (
//      id INTEGER PRIMARY KEY AUTOINCREMENT,
//      msg TEXT NOT NULL,
//      created_at INTEGER NOT NULL
//    );
//
// 3. Create a Worker, paste this file, add binding: D1 database -> variable name DB.
// 4. Optionally add a secret DISCORD_WEBHOOK_URL for live announcements.
// 5. Set the Worker URL in the plugin setting "Worker URL".

// Rest days: Tuesdays without a Goal Hunt (Pursuit on ManiaPlanet).
// Must match g_offDays in Calendar.as.
const TUESDAY_OFF_DAYS = [1, 8, 15, 22];

// Community badges by account id (MP4 player Login). Optional.
const COMMUNITY_BADGES = {
  // "player-login": ["PURSUIT", "MP-GALAXY", "DUMMY-CH"]
};

const DAY_COUNT = 25;
const GOAL_CP = 10;
const BASE_POINTS = 100;
const FINALE_POINTS = 300;
const BASE_BOUNTY_POINTS = 150;
const BASE_BOUNTY_CP = 15;
const STARTER_BADGE = "GOALMAS-2026";
const MAX_EVENTS = 15;

// Older D1 databases had only (day, ms, holder). Add cp idempotently at runtime.
async function ensureSchema(env) {
  await env.DB.prepare(
    "CREATE TABLE IF NOT EXISTS bounties (day INTEGER PRIMARY KEY, " +
    "cp INTEGER NOT NULL DEFAULT 0, ms INTEGER NOT NULL DEFAULT 0, holder TEXT NOT NULL)"
  ).run();
  const info = await env.DB.prepare("PRAGMA table_info(bounties)").all();
  if (!(info.results || []).some(col => col.name === "cp")) {
    await env.DB.prepare("ALTER TABLE bounties ADD COLUMN cp INTEGER NOT NULL DEFAULT 0").run();
  }
}

function normalizeBest(value) {
  if (!value) return { cp: 0, ms: 0 };
  if (typeof value === "number") return { cp: 0, ms: value }; // legacy time-only record
  return { cp: Number(value.cp) || 0, ms: Number(value.ms) || 0 };
}

function normalizeBests(raw) {
  const out = {};
  const src = raw && typeof raw === "object" ? raw : {};
  for (const key of Object.keys(src)) out[key] = normalizeBest(src[key]);
  return out;
}

function safeParse(text, fallback) {
  if (!text) return fallback;
  try {
    return JSON.parse(text);
  } catch (e) {
    return fallback;
  }
}

function badgesFor(id, stored) {
  const owned = Array.isArray(stored) ? stored : [];
  const extra = COMMUNITY_BADGES[id] || [];
  return Array.from(new Set([STARTER_BADGE, ...owned, ...extra]));
}

async function pushEvent(env, msg) {
  await env.DB.prepare("INSERT INTO events (msg, created_at) VALUES (?, ?)")
    .bind(msg, Date.now())
    .run();
  await env.DB.prepare(
    "DELETE FROM events WHERE id NOT IN (SELECT id FROM events ORDER BY id DESC LIMIT ?)"
  )
    .bind(MAX_EVENTS)
    .run();

  const hook = env.DISCORD_WEBHOOK_URL;
  if (!hook) return;
  try {
    await fetch(hook, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ content: "\uD83C\uDF84 **" + msg + "**" })
    });
  } catch (e) {
    // Discord is optional - never fail a result because of it.
  }
}

function isPremiere(day, now) {
  return now.getUTCMonth() + 1 === 12 && now.getUTCDate() === day;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    await ensureSchema(env);

    if (request.method === "GET" && url.pathname === "/") {
      return Response.json({ ok: true, service: "goalmas", goalCp: GOAL_CP, days: DAY_COUNT });
    }

    if (request.method === "GET" && url.pathname === "/state") {
      const accountId = url.searchParams.get("accountId") || "";
      const me = await env.DB.prepare("SELECT * FROM players WHERE account_id = ?")
        .bind(accountId)
        .first();

      const bountyRows = await env.DB.prepare("SELECT * FROM bounties").all();
      const bounties = {};
      for (const row of bountyRows.results || []) bounties[row.day] = row;

      const bests = me ? normalizeBests(safeParse(me.bests, {})) : {};
      const days = [];
      for (let d = 1; d <= DAY_COUNT; d++) {
        const bounty = bounties[d] || { cp: BASE_BOUNTY_CP, ms: 0, holder: "GrinchBot" };
        const best = bests[d] || { cp: 0, ms: 0 };
        days.push({
          day: d,
          isOffDay: TUESDAY_OFF_DAYS.includes(d) && d !== DAY_COUNT,
          goalCp: GOAL_CP,
          bountyCp: bounty.cp || BASE_BOUNTY_CP,
          bountyMs: bounty.ms || 0,
          bountyHolder: bounty.holder || "GrinchBot",
          completed: (best.cp || 0) >= GOAL_CP,
          myBestCp: best.cp || 0,
          myBestMs: best.ms || 0
        });
      }

      const top = await env.DB.prepare(
        "SELECT account_id, name, points, bounties, badges FROM players ORDER BY points DESC LIMIT 20"
      ).all();
      const leaderboard = (top.results || []).map((p) => ({
        name: p.name,
        points: p.points,
        bounties: p.bounties,
        badges: badgesFor(p.account_id, safeParse(p.badges, []))
      }));

      const events = await env.DB.prepare(
        "SELECT msg FROM events ORDER BY id DESC LIMIT ?"
      )
        .bind(MAX_EVENTS)
        .all();

      return Response.json({
        points: me ? me.points : 0,
        bounties: me ? me.bounties : 0,
        badges: badgesFor(accountId, me ? safeParse(me.badges, []) : []),
        days,
        leaderboard,
        events: (events.results || []).map((row) => row.msg)
      });
    }

    if (request.method === "POST" && url.pathname === "/submit") {
      let body;
      try {
        body = await request.json();
      } catch (e) {
        return new Response("Bad JSON", { status: 400 });
      }

      const { accountId, name, day, cpCount, timeMs = 0 } = body;
      if (!accountId || !day || !cpCount || cpCount <= 0 || day < 1 || day > DAY_COUNT) {
        return new Response("Bad Request", { status: 400 });
      }
      // Any day may be submitted. Tuesday nights are a Pursuit bonus in the
      // calendar UI, but when a Goal Hunt map is actually played on that day
      // the run must count - rejecting it here produced HTTP 403 in test runs.

      const player = await env.DB.prepare("SELECT * FROM players WHERE account_id = ?")
        .bind(accountId)
        .first();
      const bests = player ? normalizeBests(safeParse(player.bests, {})) : {};
      const badges = new Set(badgesFor(accountId, player ? safeParse(player.badges, []) : []));

      const now = new Date();
      const mult = isPremiere(day, now) ? 2 : 1;
      const isFinale = day === DAY_COUNT;

      const prev = bests[day] || { cp: 0, ms: 0 };
      let gained = 0;

      // Day completed for the first time.
      if ((prev.cp || 0) < GOAL_CP && cpCount >= GOAL_CP) {
        gained += (isFinale ? FINALE_POINTS : BASE_POINTS) * mult;
        badges.add("GOALMAS-PLAYER");
      }

      // Personal best: more checkpoints, or the same count in less time.
      const betterPersonal =
        cpCount > (prev.cp || 0) ||
        (cpCount === (prev.cp || 0) && timeMs > 0 && (!prev.ms || timeMs < prev.ms));
      if (betterPersonal) bests[day] = { cp: cpCount, ms: timeMs };

      // Bounty: the player with the most checkpoints on that day.
      const bountyRow = await env.DB.prepare("SELECT * FROM bounties WHERE day = ?")
        .bind(day)
        .first();
      const currentCp = bountyRow ? bountyRow.cp || BASE_BOUNTY_CP : BASE_BOUNTY_CP;
      const currentMs = bountyRow ? bountyRow.ms || 0 : 0;
      const beatsBounty =
        cpCount > currentCp ||
        (cpCount === currentCp && timeMs > 0 && (!currentMs || timeMs < currentMs));

      let bountyWon = false;
      if (beatsBounty) {
        await env.DB.prepare(
          "INSERT INTO bounties (day, cp, ms, holder) VALUES (?, ?, ?, ?) " +
            "ON CONFLICT(day) DO UPDATE SET cp = excluded.cp, ms = excluded.ms, holder = excluded.holder"
        )
          .bind(day, cpCount, timeMs, name || "Player")
          .run();
        gained += BASE_BOUNTY_POINTS * mult;
        bountyWon = true;
        badges.add("BOUNTY-HUNTER");
        bests[day] = { cp: cpCount, ms: timeMs };
      }

      const completedDays = Object.keys(bests).filter(
        (key) => (bests[key].cp || 0) >= GOAL_CP
      ).length;
      if (completedDays >= 10) badges.add("ELF-VETERAN");
      if (completedDays >= 24) badges.add("GOALMAS-24");
      if (completedDays >= DAY_COUNT) badges.add("FINALIST");

      const totalPoints = (player ? player.points : 0) + gained;
      const totalBounties = (player ? player.bounties : 0) + (bountyWon ? 1 : 0);

      await env.DB.prepare(
        "INSERT INTO players (account_id, name, points, bounties, badges, bests) " +
          "VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT(account_id) DO UPDATE SET " +
          "name = excluded.name, points = excluded.points, bounties = excluded.bounties, " +
          "badges = excluded.badges, bests = excluded.bests"
      )
        .bind(
          accountId,
          name || "Player",
          totalPoints,
          totalBounties,
          JSON.stringify(Array.from(badges)),
          JSON.stringify(bests)
        )
        .run();

      const timeInfo = timeMs > 0 ? " (" + (timeMs / 1000).toFixed(3) + "s)" : "";
      if (bountyWon) {
        await pushEvent(
          env,
          (name || "Player") + " stole the day " + day + " bounty with " + cpCount + " CP" + timeInfo + "!"
        );
      } else {
        await pushEvent(
          env,
          (name || "Player") + " reached " + cpCount + " CP on day " + day + " (+" + gained + " pts)"
        );
      }

      return Response.json({ ok: true, points: totalPoints, bountyWon, gained });
    }

    return new Response("Not Found", { status: 404 });
  }
};
