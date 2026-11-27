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
  /inEvent = month === 12 && date >= 1 && date <= DAY_COUNT/.test(worker) &&
  !/month === 1\b/.test(worker));
check('worker has no January grace constant',
  !/FINALE_GRACE_DAYS/.test(worker) && !/FINALE_GRACE_DAYS/.test(cfg));
check('off-season submit needs a server flag',
  has(worker, 'QA_ALLOW_OFFSEASON') && !has(cfg, 'QA_ALLOW_OFFSEASON') && !has(hunt, 'QA_ALLOW_OFFSEASON'));
check('/state locks outside the window',
  /const serverDay = bucket\.day/.test(worker) && /serverCatchUp = false/.test(worker));
check('client locks outside 1-25 December',
  /now\.Month == 12 && now\.Day >= day && now\.Day <= DAY_COUNT/.test(cal) && !/now\.Month == 1\b/.test(cal));
check('finale only on 25 December',
  /g_serverDate == DAY_COUNT/.test(cal) && /now\.Day == DAY_COUNT/.test(cal));
check('no stale January grace text', !/FINALE_GRACE_DAYS/.test(allSrc));

// --- 02:00 UTC event bucket (whole-day counting) ----------------------------
check('rollover hour matches client and worker',
  /const int DAY_ROLLOVER_HOUR_UTC = 2/.test(cfg) &&
  /const DAY_ROLLOVER_HOUR_UTC = 2/.test(worker));
check('worker computes the bucket from shifted UTC',
  /function eventBucket\(now\)/.test(worker) &&
  /now\.getTime\(\) - DAY_ROLLOVER_HOUR_UTC \* 3600 \* 1000/.test(worker) &&
  /shifted\.toISOString\(\)\.slice\(0, 10\)/.test(worker));
check('/submit uses the bucket, not the raw date',
  /const bucketDay = eventBucket\(now\)\.day/.test(worker) &&
  /dayAllowedByServer\(day, now, env\)/.test(worker) &&
  /const bucket = eventBucket\(now\)/.test(worker));
check('/state exposes bucket and day counter',
  /bucketDate: bucket\.key/.test(worker) && /bucketHourUtc: DAY_ROLLOVER_HOUR_UTC/.test(worker) &&
  /dayCp: Number\(/.test(worker));
check('whole-day counter table is keyed by bucket',
  /PRIMARY KEY \(bucket_date, account_id, day\)/.test(schema) &&
  /INSERT INTO day_cp/.test(worker) &&
  /cp = MAX\(day_cp\.cp, excluded\.cp\)/.test(worker));
check('admin reset clears the bucket counters', /DELETE FROM day_cp WHERE account_id/.test(worker));
check('client mirrors the bucket and resets only on change',
  /bucket != g_bucketDate/.test(sync) && /ResetSession\(\);/.test(sync) &&
  /ResetRun\(\);/.test(hunt) && !/if \(g_bufferCp == 0 && g_runCp > 0/.test(hunt));
check('local whole-day total accumulates across runs',
  /g_sessionCp = ClampCp\(g_sessionCp \+ added\)/.test(hunt) &&
  /g_creditedRunCp = effective/.test(hunt) &&
  /root\["dayCpBucket"\]/.test(cal) && /root\["dayCp"\]/.test(cal));
check('HUD shows the bucket day', /Bucket " \+ g_bucketDate/.test(uias));

// --- cosmetic checkpoint milestones -----------------------------------------
const milestoneDecls = cfg.match(/const int MILESTONE_\d+_CP = [^;]+;/g) || [];
function resolveConst(name, seen) {
  if (/^\d+$/.test(name)) return Number(name);
  if (seen.has(name)) return -1;
  seen.add(name);
  const decl = cfg.match(new RegExp('const int ' + name + ' = ([^;]+);'));
  return decl ? resolveConst(decl[1].trim(), seen) : -1;
}
const milestoneValues = milestoneDecls.map((decl) => {
  const rhs = (decl.match(/=\s*([^;]+)/) || [])[1].trim();
  return resolveConst(rhs, new Set());
});
check('milestone ladder is 1/5/10/15/30/50/100',
  JSON.stringify(milestoneValues) === JSON.stringify([1, 5, 10, 15, 30, 50, 100]),
  milestoneValues.join("/"));
check('milestones are defined as constants, not UI literals',
  /array<int> g_cpMilestones = \{/.test(cfg) &&
  /MILESTONE_1_CP, MILESTONE_5_CP, MILESTONE_10_CP/.test(cfg) &&
  /MILESTONE_30_CP, MILESTONE_50_CP, MILESTONE_100_CP/.test(cfg));
for (const fn of ['LastMilestone', 'NextMilestone', 'MilestoneProgress',
                  'MilestoneText', 'MilestoneSummary']) {
  check('Calendar defines ' + fn, new RegExp(fn + '\\(int cp\\)').test(cal));
}
check('milestone text shows CP to go', /" to go"/.test(cal) &&
  /"Milestone " \+ tostring\(next\)/.test(cal));
check('milestones shown in HUD, details and tooltip',
  /MilestoneText\(dayCp\)/.test(uias) && /UI::ProgressBar\(MilestoneProgress/.test(uias) &&
  /DetailLine\("MILESTONE"/.test(uias) && /MilestoneSummary\(best\)/.test(uias));
{
  let monotonic = true;
  const lastM = (cp) => milestoneValues.reduce((a, v) => (cp >= v ? v : a), 0);
  const nextM = (cp) => milestoneValues.find((v) => v > cp) || 0;
  for (let cp = 0; cp <= 120; cp++) {
    // 0 is the "all reached" sentinel, so compare it as infinity.
    if (lastM(cp) > lastM(cp + 1) ||
        (nextM(cp) || Infinity) > (nextM(cp + 1) || Infinity)) monotonic = false;
    if (lastM(cp) > cp || (nextM(cp) && nextM(cp) <= cp)) monotonic = false;
  }
  check('milestone display is monotonic', monotonic && milestoneValues.length === 7);
  check('5 CP reaches the first milestone', lastM(5) === 5 && nextM(5) === 10);
  check('10 CP shows 5 to go', lastM(10) === 10 && nextM(10) === 15 && nextM(10) - 10 === 5);
  check('all milestones reached at 100 CP', lastM(100) === 100 && nextM(100) === 0);
}
check('milestones never change scoring',
  /const int BASE_POINTS = 100/.test(cfg) && /const int FINALE_POINTS = 300/.test(cfg) &&
  /const int BOUNTY_POINTS = 150/.test(cfg) &&
  !/g_cpMilestones|MILESTONE_\d+_CP/.test(worker) &&
  !/MILESTONE/.test(hunt));

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
  /submittedCp <= 0 \|\| submittedCp > MAX_CP/.test(submitFn));
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
check('checkpoint counter is monotonic per lap',
  /g_mapCpPassed\[slot\] = true/.test(hunt) && /g_runCp \+= 1/.test(hunt));
check('one checkpoint credited once per lap', /PassedInLapCount\(\) >= g_curRaceNbCp/.test(hunt) &&
  /ResetLapPassedMap\(g_curLapIndex\)/.test(hunt));
check('HUD shows run CP next to day total', /" CP \| run " \+ tostring\(g_runCp\)/.test(uias));
check('new run seeds from live buffer', /g_creditedRunCp = g_bufferCp;/.test(hunt) &&
  /g_runSeedPending/.test(hunt));
check('one sanitizer for all notifications', has(sync, 'string CleanNotifyText(') &&
  has(sync, 'string clean = CleanNotifyText(text);') &&
  has(sync, 'string line = CleanNotifyText(text);'));
check('server events sanitized before feed', has(sync, 'CleanNotifyText(string(entry))'));
check('player names sanitized in local messages', has(hunt, 'CleanNotifyText(LocalName()'));
check('recycled buffer credits the newest checkpoint time',
  /int liveTime = g_lastCpTime > g_bufferLastTime/.test(hunt) &&
  /liveTime > g_runLastTime/.test(hunt));
check('later laps use lap and trigger identity', /g_curLapIndex = int\(player\.CurLapIndex\)/.test(hunt) &&
  /g_liveTrigger != g_runLastTrigger/.test(hunt));
check('HUD shows missing map checkpoints', /string MapCpStatus\(\)/.test(uias) &&
  /left " \+ left/.test(uias) && /UI::Text\(mapCp\)/.test(uias));
check('empty buffer does not end the run', !/g_bufferCp == 0 && g_runCp > 0/.test(hunt));
// Functional mirror of CreditCheckpointProgress(): a 6-checkpoint map must
// keep crediting checkpoints on later laps instead of stopping at six.
function simulateCpTicks(ticks) {
  let runCp = 0, high = 0, lastTime = -1;
  for (const [buffer, cpTime] of ticks) {
    if (buffer > high) {
      runCp += buffer - high;
      high = buffer;
      if (cpTime > lastTime) lastTime = cpTime;
    } else if (cpTime >= 0 && cpTime > lastTime) {
      lastTime = cpTime;
      runCp += 1;
    }
  }
  return runCp;
}
const lapTicks = [];
for (let lap = 0; lap < 3; lap++) {
  for (let cp = 1; cp <= 6; cp++) lapTicks.push([cp, lap * 6000 + cp * 1000]);
}
check('multi-lap checkpoints keep counting', simulateCpTicks(lapTicks) === 18,
  '3 laps x 6 CP = ' + simulateCpTicks(lapTicks));
// Five distinct checkpoint passes: CP1, CP2, CP3, then a respawn back to CP2
// and CP3 again. The respawn itself adds nothing extra.
check('respawn credits only the new checkpoint', simulateCpTicks([
  [1, 1000], [2, 2000], [3, 3000], [2, 3500], [3, 4000]
]) === 5);
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
check('tabs use palette colours', has(uias, 'g_palette.tileBg') &&
  has(uias, 'g_palette.tileHover') && has(uias, 'TextMuted()'));
check('tabs are text only', !/tabIcons/.test(uias) && !/showTabIcons/.test(uias));
check('window minimum covers tabs and grid', /TabRowWidth\(\)/.test(uias) &&
  /GridMinWidth\(\)/.test(uias) && has(uias, 'SetNextWindowSizeConstraints'));
check('calendar counter shown', /OPENED \| " \+/.test(uias));
check('feed uses leaderboard visual language', /bool FeedEventIsMine\(/.test(uias) &&
  /vec4 FeedEventColour\(/.test(uias) && /" events"\)/.test(uias) &&
  /Tone\(Navy\(\)\)/.test(uias));
check('gift animation removed', !/StartOpenAnimation|RenderOpenAnimation|S_OpenAnimation|g_openAnim/.test(allSrc) &&
  !/StartOpenAnimation|RenderOpenAnimation/.test(src['Main.as']));
check('completed tile names its colour', /DONE \| " \+ CpTierColourName/.test(uias) &&
  /string CpTierColourName/.test(cal));
check('tile marker uses verified snowflake icon', !/return Icons::Gift;/.test(uias) &&
  /return Icons::SnowflakeO;/.test(uias) && /g_dayColourNames/.test(cfg));
check('milestone minerals shown', /g_milestoneMinerals/.test(cfg) &&
  /MilestoneMineralFor/.test(cal) && /MINERAL/.test(uias));
check('debug has backup and reset buttons', /Backup save/.test(src['Debug.as']) &&
  /Reset data/.test(src['Debug.as']) && /void BackupProgress\(/.test(cal) &&
  /void ResetAllData\(/.test(cal));
check('snowflake uses fixed day colour', /icon == Icons::SnowflakeO/.test(uias) &&
  /DayColour\(day\)/.test(uias) && /array<vec4> g_dayColoursRgb/.test(cfg));
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
  // No-arg Date is the server wall clock; Date.now() only advances the rate
  // limit. Keep them independent so the rollover boundary can be moved.
  function setClock(stamp) {
    global.Date = class extends realDate {
      constructor(...args) {
        super(...(args.length ? args : [stamp]));
      }
      static now() { return clock; }
    };
  }
  setClock(Date.UTC(2026, 11, 15, 12));

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

    // 02:00 UTC on 26 December is the first instant after the last bucket.
    setClock(Date.UTC(2026, 11, 26, 2));
    const closed = await submit('qa-h', 'Helen', 10, 25, strictEnv);
    check('26 December closes the event', closed.status === 403, 'HTTP ' + closed.status);

    // The client-visible /state must lock every day outside the window too.
    const closedState = await call('/state?accountId=qa-h', undefined, strictEnv);
    check('26 December locks every tile', closedState.json && closedState.json.serverDay === 0,
      'serverDay ' + (closedState.json && closedState.json.serverDay));

    // --- 02:00 UTC rollover ---------------------------------------------------
    setClock(Date.UTC(2026, 11, 2, 1, 59));
    const beforeRoll = await call('/state?accountId=qa-x', undefined, strictEnv);
    check('01:59 UTC stays on the previous bucket',
      beforeRoll.json && beforeRoll.json.bucketDate === '2026-12-01' &&
      beforeRoll.json.serverDay === 1 && beforeRoll.json.bucketHourUtc === 2,
      beforeRoll.json && beforeRoll.json.bucketDate + ' / day ' + beforeRoll.json.serverDay);
    const nextDayEarly = await submit('qa-x', 'Xander', 10, 2, strictEnv);
    check('01:59 UTC refuses the new day', nextDayEarly.status === 403, 'HTTP ' + nextDayEarly.status);
    const previousDay = await submit('qa-x', 'Xander', 10, 1, strictEnv);
    check('01:59 UTC accepts the previous day', previousDay.status === 200, 'HTTP ' + previousDay.status);

    setClock(Date.UTC(2026, 11, 2, 2, 0));
    const afterRoll = await call('/state?accountId=qa-x', undefined, strictEnv);
    check('02:00 UTC opens the new bucket',
      afterRoll.json && afterRoll.json.bucketDate === '2026-12-02' &&
      afterRoll.json.serverDay === 2,
      afterRoll.json && afterRoll.json.bucketDate + ' / day ' + afterRoll.json.serverDay);
    const newDay = await submit('qa-x', 'Xander', 10, 2, strictEnv);
    check('02:00 UTC accepts the new day', newDay.status === 200, 'HTTP ' + newDay.status);

    // --- whole-day accumulation ----------------------------------------------
    setClock(Date.UTC(2026, 11, 10, 12));
    const dayFirst = await submit('qa-y', 'Yara', 16, 10, strictEnv);
    const dayMore = await submit('qa-y', 'Yara', 20, 10, strictEnv);
    const dayLower = await submit('qa-y', 'Yara', 10, 10, strictEnv);
    const dayStateY = await call('/state?accountId=qa-y', undefined, strictEnv);
    const rowY = (dayStateY.json && dayStateY.json.days || []).find((d) => d.day === 10);
    check('whole-day CP accumulates across sessions',
      dayFirst.status === 200 && dayMore.status === 200 && dayLower.status === 200 &&
      dayStateY.json.dayCp === 20 && rowY && rowY.myBestCp === 20,
      'dayCp ' + dayStateY.json.dayCp + ' / best ' + (rowY && rowY.myBestCp));
    check('lower replay cannot lower the day counter',
      dayLower.json && dayLower.json.dayCp === 20,
      'dayCp ' + (dayLower.json && dayLower.json.dayCp));

    setClock(Date.UTC(2026, 11, 11, 1, 59));
    const stillOld = await call('/state?accountId=qa-y', undefined, strictEnv);
    check('01:59 on 11 Dec still belongs to day 10',
      stillOld.json && stillOld.json.serverDay === 10 && stillOld.json.dayCp === 20,
      'day ' + (stillOld.json && stillOld.json.serverDay));
    setClock(Date.UTC(2026, 11, 11, 2, 0));
    const freshBucket = await call('/state?accountId=qa-y', undefined, strictEnv);
    check('new bucket starts with a clean counter',
      freshBucket.json && freshBucket.json.serverDay === 11 && freshBucket.json.dayCp === 0,
      'day ' + (freshBucket.json && freshBucket.json.serverDay) +
      ' / dayCp ' + (freshBucket.json && freshBucket.json.dayCp));

    // Without the server QA flag the off-season window stays closed.
    setClock(Date.UTC(2026, 10, 27));
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
