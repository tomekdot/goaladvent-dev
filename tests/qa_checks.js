// GoalAdvent 2026 QA gate. No dependencies: node tests/qa_checks.js [--live]
// Writes tests/qa-result.json, which the plugin shows in its debug panel.

const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const srcDir = path.join(root, 'src');
const files = fs.readdirSync(srcDir).filter((f) => f.endsWith('.as')).sort();
const src = Object.fromEntries(files.map((f) => [f, fs.readFileSync(path.join(srcDir, f), 'utf8')]));
const allSrc = Object.values(src).join('\n');
const workerPath = path.join(root, 'backend', 'worker.js');
const worker = fs.readFileSync(workerPath, 'utf8');
const schema = fs.readFileSync(path.join(root, 'backend', 'schema.sql'), 'utf8');

const results = [];
function check(name, ok, detail) {
  results.push({ name, ok: !!ok, detail: detail || '' });
  console.log((ok ? 'PASS' : 'FAIL') + '  ' + name + (detail ? '  |  ' + detail : ''));
}
function has(text, needle) { return text.includes(needle); }
function balanced(text, open, close) {
  const clean = text.replace(/"(?:\\.|[^"\\])*"/g, '""').replace(/\/\/.*$/gm, '');
  let n = 0;
  for (const ch of clean) {
    if (ch === open) n++;
    else if (ch === close) n--;
    if (n < 0) return false;
  }
  return n === 0;
}
function countPops(text, name) {
  let total = 0;
  for (const m of text.matchAll(new RegExp(name + '\\((\\d+)\\)', 'g'))) total += Number(m[1]);
  for (const m of text.matchAll(new RegExp(name + '\\(\\)', 'g'))) total += 1;
  return total;
}
function constValue(text, name) {
  const m = text.match(new RegExp('const\\s+\\w+\\s+' + name + '\\s*=\\s*([0-9]+)'));
  return m ? Number(m[1]) : null;
}

// --- source hygiene ---------------------------------------------------------
check('source files found', files.length >= 8, files.length + ' .as files');
check('sources are ASCII', !/[^\x00-\x7F]/.test(allSrc), 'non-ASCII count: ' + (allSrc.match(/[^\x00-\x7F]/g) || []).length);
check('backend sources are ASCII', !/[^\x00-\x7F]/.test(worker + schema));
check('no stale identifiers', !/goalmas-dev|I2S\(|TextColored\(/.test(allSrc));
for (const f of files) {
  const s = src[f];
  check('balanced ' + f, balanced(s, '{', '}') && balanced(s, '(', ')') && balanced(s, '[', ']'));
}
let pushColor = 0, pushVar = 0;
for (const s of Object.values(src)) {
  pushColor += (s.match(/UI::PushStyleColor\(/g) || []).length;
  pushVar += (s.match(/UI::PushStyleVar\(/g) || []).length;
}
const popColor = countPops(allSrc, 'UI::PopStyleColor');
const popVar = countPops(allSrc, 'UI::PopStyleVar');
check('style colour stack balanced', pushColor === popColor, pushColor + ' push / ' + popColor + ' pop');
check('style var stack balanced', pushVar === popVar, pushVar + ' push / ' + popVar + ' pop');

// --- scoring constants ------------------------------------------------------
const cfg = src['Config.as'];
const cal = src['Calendar.as'];
const uias = src['UI.as'];
const hunt = src['GoalHunt.as'];
const sync = src['Sync.as'];
const pairs = [
  ['DAY_COUNT', 25], ['GOAL_CP', 10], ['GOLD_CP', 30], ['MAX_CP', 250],
  ['BEST_OF_DAYS', 15], ['ELF_VETERAN_DAYS', 10],
  ['MAX_FEED_EVENTS', 15]
];
for (const [name, expected] of pairs) {
  check('Config ' + name + ' = ' + expected, constValue(cfg, name) === expected);
}
check('SILVER_CP follows bounty record', /const int SILVER_CP\s*=\s*DEFAULT_BOUNTY_CP/.test(cfg));
for (const [name, expected] of [
  ['DAY_COUNT', 25], ['GOAL_CP', 10], ['MAX_CP', 250], ['BEST_OF_DAYS', 15],
  ['ELF_VETERAN_DAYS', 10], ['MAX_EVENTS', 15]
]) {
  const m = worker.match(new RegExp('const ' + name + ' = ([0-9]+)'));
  check('worker ' + name + ' = ' + expected, m && Number(m[1]) === expected);
}
const offClient = (cal.match(/g_offDays\s*=\s*\{([^}]*)\}/) || [])[1] || '';
const offWorker = (worker.match(/TUESDAY_OFF_DAYS\s*=\s*\[([^\]]*)\]/) || [])[1] || '';
const nums = (s) => (s.match(/\d+/g) || []).join(',');
check('rest days aligned', nums(offClient) === nums(offWorker) && nums(offClient) === '1,8,15,22',
  nums(offClient) + ' / ' + nums(offWorker));

// --- checkpoint tiers -------------------------------------------------------
for (const fn of ['ClampCp', 'CpTier', 'CpTierLabel', 'BestCp']) {
  check('Calendar defines ' + fn, has(cal, fn + '('));
}
check('tiers used by tiles', has(uias, 'CpTierColour(cpTier)'));
check('tiers used by details', has(uias, 'RUN TIER') && has(uias, 'CpTierLabel(tier)'));
check('tiers used by HUD', has(uias, 'Best " + tostring(best)'));
check('tiers used by tooltip', has(uias, '"Best: " + tostring(best)'));

// --- server authority -------------------------------------------------------
for (const needle of ['serverMonth', 'serverDate', 'serverDay', 'resetEpoch']) {
  check('/state returns ' + needle, has(worker, needle) && has(sync, needle));
}
check('worker gates future days', has(worker, 'dayAllowedByServer') && has(worker, 'day-not-open'));
check('plugin handles HTTP 403', has(hunt, 'code == 403') && has(hunt, 'check the PC clock'));
check('worker tie-break by timeMs', has(worker, 'excluded.ms < bounties.ms'));
check('bounty bonus is unique per day', /PRIMARY KEY \(day, account_id\)/.test(worker) && /PRIMARY KEY \(day, account_id\)/.test(schema));
check('worker accepts CP above 30', has(worker, 'const MAX_CP = 250') && !/cpCount\s*>\s*(15|30)/.test(worker));
check('GoalHuntArena bypasses server gate', /bool arenaMap = IsGoalHuntMapType\(mapType\)/.test(hunt) && /if \(!arenaMap && !OnEventServer\(\)\) return 0;/.test(hunt));
check('arena map falls back to selected day', /return g_selectedDay;/.test(hunt));
check('titlepack strips author suffix', /int at = id\.IndexOf\("@"\)/.test(hunt) && /current\.StartsWith\(allowed\)/.test(hunt));

// --- strict event window (1-25 December UTC) --------------------------------
check('worker window is strict December 1-25',
  /month !== 12 \|\| date > DAY_COUNT/.test(worker) && !/month === 1/.test(worker));
check('worker has no January grace constant',
  !/FINALE_GRACE_DAYS/.test(worker) && !/FINALE_GRACE_DAYS/.test(cfg));
check('off-season submit needs a server flag',
  has(worker, 'QA_ALLOW_OFFSEASON') && !has(cfg, 'QA_ALLOW_OFFSEASON') && !has(hunt, 'QA_ALLOW_OFFSEASON'));
check('/state locks outside the window',
  /const serverDay = \(serverMonth === 12 && serverDate <= DAY_COUNT\)/.test(worker) &&
  /serverCatchUp = false/.test(worker));
check('client locks outside 1-25 December',
  /now\.Month == 12 && now\.Day >= day && now\.Day <= DAY_COUNT/.test(cal) && !/now\.Month == 1\b/.test(cal));
check('finale only on 25 December',
  /g_serverDate == DAY_COUNT/.test(cal) && /now\.Day == DAY_COUNT/.test(cal));
check('no stale January grace text', !/FINALE_GRACE_DAYS/.test(allSrc));

// --- anti-cheat / submit guards ---------------------------------------------
const submitFn = (worker.match(/if \(request\.method === "POST" && url\.pathname === "\/submit"\) \{[\s\S]*?\n    \}/) || [''])[0];
check('/submit rate limit returns 429', /status: 429/.test(submitFn) && /"rate-limited"/.test(submitFn));
check('rate limit is an atomic meta upsert',
  /ON CONFLICT\(key\) DO UPDATE SET value = excluded\.value/.test(submitFn) &&
  /CAST\(meta\.value AS INTEGER\) \+ \? <= \?/.test(submitFn));
const rateAt = submitFn.indexOf('rate-limited');
check('rate limit runs before state writes',
  rateAt > 0 && rateAt < submitFn.indexOf('INSERT INTO map_days') &&
  rateAt < submitFn.indexOf('INSERT INTO players') &&
  rateAt < submitFn.indexOf('INSERT INTO bounties'));
check('submit keeps day and CP bounds',
  /day < 1 \|\| day > DAY_COUNT/.test(submitFn) &&
  /cpCount <= 0 \|\| cpCount > MAX_CP/.test(submitFn));
check('submit validates account id type', /typeof accountId !== "string"/.test(submitFn));
check('bounty identity is the account id',
  /holder_id/.test(worker) && /bountyHolderAccountId/.test(worker) &&
  /excluded\.holder_id/.test(worker) && /\.bind\(day, cpCount, timeMs, displayName, accountId\)/.test(worker));
check('/state keeps display holder for old clients',
  /bountyHolder: bounty\.holder/.test(worker) && /bountyHolderAccountId:/.test(worker));
check('schema declares holder_id', /holder_id TEXT NOT NULL DEFAULT ''/.test(schema));
check('client reads canonical holder id',
  /bountyHolderAccountId/.test(sync) && /g_bountyHolderId\[idx\]/.test(sync) &&
  /holderId == AccountId\(\)/.test(uias) && /g_bountyHolderId\[idx\] = AccountId\(\)/.test(hunt));
check('holder id survives local save/load',
  /root\["bountyHolderId"\]/.test(cal) && /g_bountyHolderId\.Resize\(DAY_COUNT\)/.test(cal));
check('bot holder id matches worker', /const string BOT_HOLDER_ID = "grinchbot"/.test(cfg) &&
  /const BOT_HOLDER_ID = "grinchbot"/.test(worker));
check('admin reset clears holder id and cooldown',
  /holder_id = \?/.test(worker) && /DELETE FROM meta WHERE key = \?/.test(worker));

// --- admin reset ------------------------------------------------------------
check('admin reset route exists', has(worker, '"/admin/reset"'));
check('admin reset needs token', has(worker, 'url.searchParams.get("token") !== env.ADMIN_TOKEN'));
check('admin reset limited to owner', has(worker, 'OWNER_ACCOUNT_ID') && has(worker, 'accountId !== OWNER_ACCOUNT_ID'));
check('admin reset needs confirmation', has(worker, 'body.confirm !== "RESET"'));
check('reset epoch clears local save', has(sync, 'ResetProgress()') && has(cal, 'root["resetEpoch"]'));
check('QA clean slate marker exists', has(cfg, 'QA_CLEAN_MARKER') && has(cal, 'IO::FileExists(QA_CLEAN_MARKER)'));

// --- QA preview -------------------------------------------------------------
check('QA preview setting exists', /int S_QaPreview\s*=\s*0/.test(cfg) && has(cfg, 'QA preview'));
check('QA preview applied on load', has(cal, 'ApplyQaPreview();'));
check('QA preview restored after sync', has(sync, 'ApplyQaPreview();'));
check('QA preview never saves', /void SaveProgress\(\) \{\s*\n\s*if \(S_QaPreview > 0\) return;/.test(cal));
check('QA preview never submits', has(hunt, 'if (S_QaPreview > 0) return;'));
check('QA preview has three variants', has(cal, 'S_QaPreview == 1') || has(cal, 'S_QaPreview == 2') && has(cal, 'S_QaPreview == 3'));
check('sync mode setting bounded', /name="Sync mode"/.test(cfg) && /min=0 max=2/.test(cfg));
check('settings clamped at startup', /S_SyncMode < 0 \|\| S_SyncMode > 2/.test(src['Main.as']));
const settingProblems = [];
const cfgLines = cfg.split('\n');
for (let i = 0; i < cfgLines.length; i++) {
  const m = cfgLines[i].match(/^\[Setting ([^\]]*)\]/);
  if (!m) continue;
  const attrs = m[1];
  const decl = cfgLines[i + 1] || '';
  if (!/name="/.test(attrs) || !/description="/.test(attrs)) {
    settingProblems.push('line ' + (i + 1) + ' missing name/description');
  }
  if (/^(int|float)\s/.test(decl) && (!/min=/.test(attrs) || !/max=/.test(attrs))) {
    settingProblems.push('line ' + (i + 1) + ' numeric without min/max');
  }
}
check('settings metadata complete', settingProblems.length === 0, settingProblems.join('; '));
const submitSuccess = (hunt.match(/if \(code == 200\) \{[\s\S]*?\n    \} else if \(code == 403\)/) || [''])[0];
check('full CP run saved after upload', /SaveProgress\(\)/.test(submitSuccess));
check('live CP counts one buffer entry per checkpoint',
  /g_bufferCp = int\(script\.CurRace\.Checkpoints\.Length\)/.test(hunt) && /return g_bufferCp;/.test(hunt));
check('trigger index is debug only, never a count',
  /g_liveTrigger = int\(script\.CurTriggerIndex\)/.test(hunt) && !/g_liveTrigger\s*[<>]/.test(hunt));
check('respawn rewinds never reset the round',
  !/cp < g_lastCpBuffer/.test(hunt) && !/g_lastCpTime < g_prevCpTime/.test(hunt) &&
  !/g_liveTrigger < g_prevTrigger/.test(hunt));
check('round identity uses RaceStartTime',
  /g_raceStartTime = int\(script\.RaceStartTime\)/.test(hunt) &&
  /g_raceStartTime != g_runStartTime/.test(hunt));
check('checkpoint counter is monotonic',
  /g_runCp \+= grew/.test(hunt) && /g_runCp \+= 1/.test(hunt));
check('recycled buffer credits the newest checkpoint time',
  /g_bufferLastTime = int\(script\.CurRace\.Checkpoints\[uint\(g_bufferCp - 1\)\]\)/.test(hunt) &&
  /g_bufferLastTime > g_runLastTime/.test(hunt));
check('warmup checkpoints count', /int effective = cp;/.test(hunt) && !/g_warmupCpBaseline/.test(hunt));
check('final CP flushed on race finish', /bool justFinished = raceState == RACE_FINISHED/.test(hunt) && /if \(justFinished && g_sessionCp > g_lastSentCp\)/.test(hunt));
const detectFn = (hunt.match(/int DetectGoalHuntDay\(\) \{[\s\S]*?\n\}/) || [''])[0];
check('map name number beats UID mapping', detectFn.indexOf('ParseDayFromMapName(name)') > 0 &&
  detectFn.indexOf('ParseDayFromMapName(name)') < detectFn.indexOf('DayFromUidMapping('));

// --- UI / typography --------------------------------------------------------
for (const size of ['FS_LABEL', 'FS_BODY', 'FS_TITLE']) check('font size ' + size, has(uias, size));
check('window is resizable', !/WindowFlags::NoResize/.test((uias.match(/void RenderDashboard\(\)[\s\S]*?\n\}/) || [''])[0]));
check('window has minimum size', has(uias, 'SetNextWindowSizeConstraints'));
check('rest day text removed from day bar', !/status = "Pursuit night"/.test(uias));
check('button lifted to title line', has(uias, 'rowStart.y - 8.0f * UiK()'));
check('no corner checkmarks on tiles', !/AddCircleFilled\(cc, cr/.test(uias) && !/cpTier >= 2/.test(uias));
check('tabs use palette colours', has(uias, 'g_palette.tabActiveBg') && has(uias, 'g_palette.tabActiveText'));
const theme = src['Theme.as'];
check('grey obsidian tiles', /tileBg = vec4\(0\.095/.test(theme));
check('grey glass tiles', /vec4\(1\.000, 1\.000, 1\.000, 0\.09\)/.test(theme));
check('original muted text', /textMuted\s+= vec4\(1\.000, 1\.000, 1\.000, 0\.50\)/.test(theme));
check('no dark emerald DONE surface', !/em\.x \* 0\.14f/.test(uias));

// --- worker syntax ----------------------------------------------------------
try {
  new Function(worker.replace(/^export default/m, 'const worker ='));
  check('worker syntax', true);
} catch (e) {
  check('worker syntax', false, e.message);
}

// --- worker guards, exercised against an in-memory SQLite D1 stand-in -------
// Static checks prove the code exists; this proves the guards behave: a spam
// submit gets 429 without touching state, and the bounty owner follows the
// account id even when the display nickname is spoofed.
async function workerGuardChecks() {
  let DatabaseSync = null;
  try {
    DatabaseSync = require('node:sqlite').DatabaseSync;
  } catch (e) {
    console.log('SKIP  functional worker guards (node:sqlite unavailable)');
    return;
  }

  const db = new DatabaseSync(':memory:');
  // A provisioned D1 already has schema.sql applied; ensureSchema only adds
  // the migration columns, exactly like the live database.
  db.exec(fs.readFileSync(root + '/backend/schema.sql', 'utf8'));
  function prep(sql, params) {
    return {
      bind(...args) { return prep(sql, args); },
      run() {
        const r = db.prepare(sql).run(...params);
        return { meta: { changes: Number(r.changes) } };
      },
      all() { return { results: db.prepare(sql).all(...params) }; },
      first() {
        const row = db.prepare(sql).get(...params);
        return row || null;
      }
    };
  }
  const env = {
    DB: { prepare: (sql) => prep(sql, []), batch: (items) => items.map((s) => s.run()) },
    QA_ALLOW_OFFSEASON: '1'
  };

  const moduleObj = { exports: {} };
  try {
    const code = worker.replace(/^export default/m, 'module.exports =');
    new Function('module', 'exports', code)(moduleObj, moduleObj.exports);
  } catch (e) {
    check('functional worker loads', false, e.message);
    return;
  }
  const api = moduleObj.exports;

  const realDate = global.Date;
  let clock = 1800000000000;
  global.Date = class extends realDate {
    constructor(...args) {
      super(...(args.length ? args : [Date.UTC(2026, 11, 15)]));
    }
    static now() { return clock; }
  };

  async function call(path, body, useEnv) {
    const req = body === undefined
      ? { method: 'GET', url: 'https://qa.local' + path, json: async () => ({}) }
      : { method: 'POST', url: 'https://qa.local' + path, json: async () => body };
    const res = await api.fetch(req, useEnv || env);
    let json = null;
    try { json = await res.json(); } catch (e) {}
    return { status: res.status, json };
  }
  // Production-shaped env: no QA_ALLOW_OFFSEASON escape hatch.
  const strictEnv = { DB: env.DB };
  const submit = (accountId, name, cpCount, day, useEnv) => {
    clock += 2000;
    return call('/submit', { accountId, name, day: day || 15, cpCount, mapUid: 'P_QA', timeMs: 1000 }, useEnv);
  };
  const dayState = async (accountId, day) => {
    const state = await call('/state?accountId=' + encodeURIComponent(accountId));
    const row = (state.json && state.json.days || []).find((d) => d.day === (day || 15));
    return row || {};
  };

  try {
    const first = await submit('qa-a', 'Alice', 12);
    check('functional submit accepted', first.status === 200, 'HTTP ' + first.status);

    const spam = await call('/submit', {
      accountId: 'qa-a', name: 'Alice', day: 15, cpCount: 250, mapUid: 'P_QA', timeMs: 1000
    });
    check('functional spam submit is 429', spam.status === 429 && spam.json && spam.json.error === 'rate-limited',
      'HTTP ' + spam.status);

    const afterSpam = await dayState('qa-a', 15);
    check('429 leaves the stored run untouched', afterSpam.myBestCp === 12 && afterSpam.bountyCp === 15,
      'best ' + afterSpam.myBestCp + ' / bounty ' + afterSpam.bountyCp);

    const later = await submit('qa-a', 'Alice', 13, 15);
    check('submit accepted after cooldown', later.status === 200, 'HTTP ' + later.status);

    const holder = await submit('qa-b', 'Bob', 20, 15);
    const heldState = await dayState('qa-b', 15);
    check('bounty owner stores the account id',
      holder.status === 200 && heldState.bountyHolderAccountId === 'qa-b' && heldState.bountyHolder === 'Bob',
      heldState.bountyHolder + ' / ' + heldState.bountyHolderAccountId);

    // Same display name, different account: the holder id must change even
    // though the human-readable string is identical.
    const spoof = await submit('qa-c', 'Bob', 21, 15);
    const spoofState = await dayState('qa-c', 15);
    check('spoofed name cannot keep the bounty identity',
      spoof.status === 200 && spoofState.bountyHolder === 'Bob' &&
      spoofState.bountyHolderAccountId === 'qa-c' && spoofState.bountyCp === 21,
      spoofState.bountyHolder + ' / ' + spoofState.bountyHolderAccountId);

    const lower = await submit('qa-d', 'Bob', 5, 15);
    const lowerState = await dayState('qa-d', 15);
    check('lower run cannot steal the record identity',
      lower.status === 200 && lowerState.bountyHolderAccountId === 'qa-c',
      lowerState.bountyHolderAccountId);

    const tooMany = await submit('qa-e', 'Eve', 251, 15);
    check('functional CP ceiling is 250', tooMany.status === 400, 'HTTP ' + tooMany.status);

    // Future day is refused; a day already open is accepted. These use the
    // production env so the QA off-season flag cannot mask the calendar gate.
    const future = await submit('qa-f', 'Frank', 10, 16, strictEnv);
    check('future day is refused', future.status === 403, 'HTTP ' + future.status);
    const openDay = await submit('qa-g', 'Grace', 10, 14, strictEnv);
    check('open day is accepted', openDay.status === 200, 'HTTP ' + openDay.status);

    // 26 December is after the event: nothing is accepted even for day 25.
    global.Date = class extends realDate {
      constructor(...args) {
        super(...(args.length ? args : [Date.UTC(2026, 11, 26)]));
      }
      static now() { return clock; }
    };
    const closed = await submit('qa-h', 'Helen', 10, 25, strictEnv);
    check('26 December closes the event', closed.status === 403, 'HTTP ' + closed.status);

    // The client-visible /state must lock every day outside the window too.
    const closedState = await call('/state?accountId=qa-h', undefined, strictEnv);
    check('26 December locks every tile', closedState.json && closedState.json.serverDay === 0,
      'serverDay ' + (closedState.json && closedState.json.serverDay));

    // Without the server QA flag the off-season window stays closed.
    global.Date = class extends realDate {
      constructor(...args) {
        super(...(args.length ? args : [Date.UTC(2026, 10, 27)]));
      }
      static now() { return clock; }
    };
    const offSeason = await api.fetch(
      { method: 'POST', url: 'https://qa.local/submit', json: async () => ({
        accountId: 'qa-i', name: 'Ivy', day: 5, cpCount: 10, mapUid: 'P_QA', timeMs: 1000
      }) },
      { DB: env.DB }
    );
    check('off-season submit needs the server flag', offSeason.status === 403, 'HTTP ' + offSeason.status);
  } finally {
    global.Date = realDate;
  }
}

// --- optional live checks ---------------------------------------------------
async function liveChecks() {
  const base = 'https://goalmas.tomekdot-goalmas.workers.dev';
  try {
    const rootRes = await fetch(base + '/');
    const rootJson = await rootRes.json();
    check('live worker root', rootRes.status === 200 && rootJson.service === 'goalmas');
    const state = await (await fetch(base + '/state?accountId=qa-check')).json();
    check('live /state has 25 days', state.days && state.days.length === 25);
    check('live /state has server clock', typeof state.resetEpoch === 'number' && typeof state.serverDay === 'number');
    const noToken = await fetch(base + '/admin/reset', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ accountId: 'tomek_k.', confirm: 'RESET' })
    });
    check('live reset rejects missing token', noToken.status === 404, 'HTTP ' + noToken.status);
    const token = process.env.GOALMAS_ADMIN_TOKEN;
    if (!token) {
      console.log('SKIP  live reset with token (set GOALMAS_ADMIN_TOKEN)');
    } else {
      const other = await fetch(base + '/admin/reset?token=' + token, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ accountId: 'someone-else', confirm: 'RESET' })
      });
      check('live reset rejects other account', other.status === 403, 'HTTP ' + other.status);
    }
  } catch (e) {
    check('live worker reachable', false, e.message);
  }
}

(async () => {
  await workerGuardChecks();
  if (process.argv.includes('--live')) await liveChecks();
  const failed = results.filter((r) => !r.ok);
  const summary = {
    status: failed.length === 0 ? 'passed' : 'failed',
    date: new Date().toISOString(),
    total: results.length,
    failed: failed.length,
    failures: failed.map((r) => r.name)
  };
  fs.writeFileSync(path.join(__dirname, 'qa-result.json'), JSON.stringify(summary, null, 2) + '\n');
  console.log('\nRESULT: ' + summary.status.toUpperCase() + ' (' + (results.length - failed.length) + '/' + results.length + ')');
  process.exitCode = failed.length === 0 ? 0 : 1;
})();
