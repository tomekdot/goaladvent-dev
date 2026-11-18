// GoalEvent backend - free Cloudflare Worker.
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
const MAX_CP = 250;   // reject forged/huge values without imposing a real limit

// Older D1 databases had only (day, ms, holder). Add cp idempotently at runtime.
// Cache per isolate so /admin and /state do not re-run DDL on every request.
let schemaReady = null;
async function ensureSchema(env) {
  if (!schemaReady) {
    schemaReady = (async () => {
      await env.DB.prepare(
        "CREATE TABLE IF NOT EXISTS bounties (day INTEGER PRIMARY KEY, " +
        "cp INTEGER NOT NULL DEFAULT 0, ms INTEGER NOT NULL DEFAULT 0, holder TEXT NOT NULL)"
      ).run();
      const info = await env.DB.prepare("PRAGMA table_info(bounties)").all();
      if (!(info.results || []).some(col => col.name === "cp")) {
        await env.DB.prepare("ALTER TABLE bounties ADD COLUMN cp INTEGER NOT NULL DEFAULT 0").run();
      }
      await env.DB.prepare(
        "CREATE TABLE IF NOT EXISTS map_days (uid TEXT PRIMARY KEY, day INTEGER NOT NULL, " +
        "first_seen INTEGER NOT NULL)"
      ).run();
    })();
  }
  return schemaReady;
}

function normalizeBest(value) {
  if (!value) return { cp: 0, ms: 0, pts: 0, b: 0 };
  if (typeof value === "number") return { cp: 0, ms: value, pts: 0, b: 0 }; // legacy
  return {
    cp: Number(value.cp) || 0,
    ms: Number(value.ms) || 0,
    pts: Number(value.pts) || 0,
    b: value.b ? 1 : 0
  };
}

// Only the best 15 of days 1-24 count; the finale always counts. Keeps the
// server leaderboard identical to the plugin's local "BEST 15" number.
function scoreFromBests(bests) {
  const vals = [];
  for (let d = 1; d <= 24; d++) {
    const b = bests[d];
    if (b && (b.cp || 0) >= GOAL_CP && (b.pts || 0) > 0) vals.push(b.pts);
  }
  vals.sort((a, b) => b - a);
  let total = vals.slice(0, 15).reduce((a, b) => a + b, 0);
  const finale = bests[DAY_COUNT];
  if (finale && (finale.cp || 0) >= GOAL_CP) total += (finale.pts || FINALE_POINTS);
  return total;
}

function normalizeBests(raw) {
  const out = {};
  const src = raw && typeof raw === "object" ? raw : {};
  for (const key of Object.keys(src)) {
    const b = normalizeBest(src[key]);
    // Legacy rows had no per-day pts; reconstruct the base so a returning
    // player does not lose completed days when the best-15 rule takes over.
    if (!b.pts && b.cp >= GOAL_CP) {
      b.pts = (Number(key) === DAY_COUNT ? FINALE_POINTS : BASE_POINTS);
    }
    out[key] = b;
  }
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

async function pushEvent(env, msg, extra) {
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
    // A Discord embed reads better than a wall of bold text and lets the
    // bounty takeovers stand out in #goalmas-leaderboard.
    const embed = extra
      ? {
          title: extra.bounty
            ? "\uD83C\uDFAF Bounty taken - day " + extra.day
            : "\uD83C\uDF81 Day " + extra.day + " completed",
          description: msg,
          color: extra.bounty ? 0xd9a441 : 0x4fa3d1,
          fields: [
            { name: "Player", value: String(extra.name || "Player"), inline: true },
            { name: "Checkpoints", value: String(extra.cp || 0), inline: true },
            { name: "Points", value: "+" + String(extra.gained || 0), inline: true }
          ],
          footer: { text: "GoalEvent" },
          timestamp: new Date().toISOString()
        }
      : null;
    await fetch(hook, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(embed
        ? { embeds: [embed] }
        : { content: "\uD83C\uDF84 **" + msg + "**" })
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

    // Small read-only admin page. Requires the ADMIN_TOKEN secret as ?token=...
    // Without the secret the route does not exist, so the data stays private.
    if (request.method === "GET" && url.pathname === "/admin") {
      if (!env.ADMIN_TOKEN || url.searchParams.get("token") !== env.ADMIN_TOKEN) {
        return new Response("Not found", { status: 404 });
      }
      const [players, bounties, events, maps] = await Promise.all([
        env.DB.prepare("SELECT account_id, name, points, bounties, badges, bests FROM players ORDER BY points DESC LIMIT 50").all(),
        env.DB.prepare("SELECT day, cp, ms, holder FROM bounties ORDER BY day").all(),
        env.DB.prepare("SELECT msg, created_at FROM events ORDER BY id DESC LIMIT 15").all(),
        env.DB.prepare("SELECT uid, day, first_seen FROM map_days ORDER BY day").all()
      ]);
      const esc = (v) => String(v == null ? "" : v).replace(/[&<>\"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
      const rows = (items, cols) => (items.results || []).map(r =>
        "<tr>" + cols.map(c => "<td>" + esc(r[c]) + "</td>").join("") + "</tr>").join("");
      const html = `<!doctype html><html><head><meta charset="utf-8"><title>GoalEvent D1</title>
<style>body{background:#141519;color:#e8e9ee;font:13px monospace;margin:24px}
h1{color:#ffd166;font-size:20px}h2{color:#9fb4d0;font-size:14px;margin-top:28px}
table{border-collapse:collapse;width:100%}td,th{border:1px solid #333642;padding:4px 7px;text-align:left}
th{background:#242733}tr:nth-child(even){background:#1b1d24}a{color:#9ecbff}</style></head><body>
<h1>GoalEvent D1 | live data</h1>
<p><a href="/admin?token=${encodeURIComponent(env.ADMIN_TOKEN)}">Refresh</a> &middot;
<a href="https://dash.cloudflare.com/2975602b6ae7dc883884858d1b5ce4bf/database/d1">Cloudflare D1 dashboard</a></p>
<p>Discord webhook: <strong>${env.DISCORD_WEBHOOK_URL ? "configured" : "not set"}</strong></p>
<h2>Players (${(players.results || []).length} of ${(players.results || []).length})</h2>
<table><tr><th>account</th><th>name</th><th>pts</th><th>bounties</th><th>badges</th><th>bests</th></tr>
${rows(players, ["account_id", "name", "points", "bounties", "badges", "bests"])}</table>
<h2>Bounties</h2><table><tr><th>day</th><th>cp</th><th>ms</th><th>holder</th></tr>
${rows(bounties, ["day", "cp", "ms", "holder"])}</table>
<h2>Map UID -&gt; day (learned)</h2><table><tr><th>uid</th><th>day</th><th>first seen</th></tr>
${rows(maps, ["uid", "day", "first_seen"])}</table>
<h2>Recent events</h2><table><tr><th>time</th><th>message</th></tr>
${rows(events, ["created_at", "msg"])}</table></body></html>`;
      return new Response(html, {
        headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" }
      });
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
        "SELECT account_id, name, points, bounties, badges FROM players ORDER BY points DESC LIMIT 50"
      ).all();
      const leaderboard = (top.results || []).map((p) => ({
        accountId: p.account_id,
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

      const mapRows = await env.DB.prepare("SELECT uid, day FROM map_days").all();
      const mapDays = {};
      for (const row of (mapRows.results || [])) mapDays[row.uid] = row.day;

      return Response.json({
        points: me ? me.points : 0,
        bounties: me ? me.bounties : 0,
        badges: badgesFor(accountId, me ? safeParse(me.badges, []) : []),
        days,
        leaderboard,
        mapDays,
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

      const { accountId, name, mapUid = "" } = body;
      const day = Number(body.day);
      const cpCount = Number(body.cpCount);
      const timeMs = Number(body.timeMs) || 0;
      if (!accountId || !Number.isInteger(day) || day < 1 || day > DAY_COUNT ||
          !Number.isInteger(cpCount) || cpCount <= 0 || cpCount > MAX_CP) {
        return new Response("Bad Request", { status: 400 });
      }
      // Any day may be submitted. Tuesday nights are a Pursuit bonus in the
      // calendar UI, but when a Goal Hunt map is actually played on that day
      // the run must count - rejecting it here produced HTTP 403 in test runs.

      // Learn the UID<->day pair only from a completed run. Debug submits with
      // a handful of CP must not poison detection for every other player.
      if (mapUid && cpCount >= GOAL_CP) {
        await env.DB.prepare(
          "INSERT INTO map_days (uid, day, first_seen) VALUES (?, ?, ?) " +
          "ON CONFLICT(uid) DO UPDATE SET day = excluded.day"
        ).bind(mapUid, day, Date.now()).run();
      }

      const player = await env.DB.prepare("SELECT * FROM players WHERE account_id = ?")
        .bind(accountId)
        .first();
      const bests = player ? normalizeBests(safeParse(player.bests, {})) : {};
      const badges = new Set(badgesFor(accountId, player ? safeParse(player.badges, []) : []));

      const now = new Date();
      const mult = isPremiere(day, now) ? 2 : 1;
      const isFinale = day === DAY_COUNT;

      const prev = bests[day] || { cp: 0, ms: 0, pts: 0, b: 0 };
      let gained = 0;
      let dayPts = prev.pts || 0;

      // Day completed for the first time.
      if ((prev.cp || 0) < GOAL_CP && cpCount >= GOAL_CP) {
        gained += (isFinale ? FINALE_POINTS : BASE_POINTS) * mult;
        dayPts += gained;
        badges.add("GOALMAS-PLAYER");
      }

      // Personal best: more checkpoints, or the same count in less time.
      const betterPersonal =
        cpCount > (prev.cp || 0) ||
        (cpCount === (prev.cp || 0) && timeMs > 0 && (!prev.ms || timeMs < prev.ms));
      const bestCp = Math.max(prev.cp || 0, cpCount);
      const bestMs = betterPersonal ? timeMs : (prev.ms || 0);

      // Bounty: the player with the most checkpoints on that day. Bonus points
      // are granted at most once per day, so a player cannot farm the record.
      const bountyRow = await env.DB.prepare("SELECT * FROM bounties WHERE day = ?")
        .bind(day)
        .first();
      const currentCp = bountyRow ? bountyRow.cp || BASE_BOUNTY_CP : BASE_BOUNTY_CP;
      const currentMs = bountyRow ? bountyRow.ms || 0 : 0;
      const previousHolder = bountyRow ? bountyRow.holder || "GrinchBot" : "GrinchBot";
      const beatsBounty =
        cpCount > currentCp ||
        (cpCount === currentCp && timeMs > 0 && (!currentMs || timeMs < currentMs));

      let bountyWon = false;
      if (beatsBounty) {
        await env.DB.prepare(
          "INSERT INTO bounties (day, cp, ms, holder) VALUES (?, ?, ?, ?) " +
            "ON CONFLICT(day) DO UPDATE SET " +
            "cp = MAX(bounties.cp, excluded.cp), " +
            "ms = CASE WHEN excluded.cp > bounties.cp OR " +
            "(excluded.cp = bounties.cp AND excluded.ms < bounties.ms) " +
            "THEN excluded.ms ELSE bounties.ms END, " +
            "holder = CASE WHEN excluded.cp > bounties.cp OR " +
            "(excluded.cp = bounties.cp AND excluded.ms < bounties.ms) " +
            "THEN excluded.holder ELSE bounties.holder END"
        )
          .bind(day, cpCount, timeMs, name || "Player")
          .run();
        if (!prev.b) {
          gained += BASE_BOUNTY_POINTS * mult;
          dayPts += BASE_BOUNTY_POINTS * mult;
          bountyWon = true;
        }
        badges.add("BOUNTY-HUNTER");
      }

      bests[day] = {
        cp: bestCp,
        ms: bestMs,
        pts: dayPts,
        b: prev.b || bountyWon ? 1 : 0
      };

      const completedDays = Object.keys(bests).filter(
        (key) => (bests[key].cp || 0) >= GOAL_CP
      ).length;
      if (completedDays >= 10) badges.add("ELF-VETERAN");
      if (completedDays >= 24) badges.add("GOALMAS-24");
      if (completedDays >= DAY_COUNT) badges.add("FINALIST");

      // Legacy rows have no per-day pts; keep their old total until they next
      // submit, then the best-15 rule takes over.
      const hasDayPoints = Object.keys(bests).some(k => (bests[k].pts || 0) > 0);
      const totalPoints = hasDayPoints
        ? scoreFromBests(bests)
        : ((player ? player.points : 0) + gained);
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

      // Repeated +0 submits must not flood the 15-line feed or Discord.
      const timeInfo = timeMs > 0 ? " (" + (timeMs / 1000).toFixed(3) + "s)" : "";
      // Announce every takeover, not only the first bonus: the holder changes
      // several times per day and #goalmas-leaderboard should follow it.
      const bountyChanged = beatsBounty && (name || "Player") !== previousHolder;
      if (bountyChanged) {
        await pushEvent(
          env,
          (name || "Player") + " stole the day " + day + " bounty from " +
            previousHolder + " with " + cpCount + " CP" + timeInfo +
            (bountyWon ? " (+" + BASE_BOUNTY_POINTS * mult + " pts)" : ""),
          {
            bounty: true,
            day,
            name: name || "Player",
            cp: cpCount,
            gained: bountyWon ? BASE_BOUNTY_POINTS * mult : 0
          }
        );
      } else if (gained > 0) {
        await pushEvent(
          env,
          (name || "Player") + " reached " + cpCount + " CP on day " + day + " (+" + gained + " pts)",
          { bounty: false, day, name: name || "Player", cp: cpCount, gained }
        );
      }

      return Response.json({ ok: true, points: totalPoints, bountyWon, gained });
    }

    return new Response("Not Found", { status: 404 });
  }
};
