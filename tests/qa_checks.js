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
  ['BEST_OF_DAYS', 15], ['FINALE_GRACE_DAYS', 5], ['ELF_VETERAN_DAYS', 10],
  ['MAX_FEED_EVENTS', 15]
];
for (const [name, expected] of pairs) {
  check('Config ' + name + ' = ' + expected, constValue(cfg, name) === expected);
}
check('SILVER_CP follows bounty record', /const int SILVER_CP\s*=\s*DEFAULT_BOUNTY_CP/.test(cfg));
for (const [name, expected] of [
  ['DAY_COUNT', 25], ['GOAL_CP', 10], ['MAX_CP', 250], ['BEST_OF_DAYS', 15],
  ['FINALE_GRACE_DAYS', 5], ['ELF_VETERAN_DAYS', 10], ['MAX_EVENTS', 15]
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
for (const needle of ['serverMonth', 'serverDate', 'serverDay', 'serverCatchUp', 'resetEpoch']) {
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
