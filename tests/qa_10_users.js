// Dependency-free QA: ten virtual players submitting to the worker with an
// in-memory D1 stand-in. Run: node tests/qa_10_users.js
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');
const workerSrc = fs.readFileSync(path.join(root, 'backend', 'worker.js'), 'utf8');
const schema = fs.readFileSync(path.join(root, 'backend', 'schema.sql'), 'utf8');

let DatabaseSync;
try {
  DatabaseSync = require('node:sqlite').DatabaseSync;
} catch (e) {
  console.log('SKIP: node:sqlite is unavailable (Node 22+ required)');
  process.exit(0);
}

const db = new DatabaseSync(':memory:');
db.exec(schema);
function prep(sql, params) {
  return {
    bind(...args) { return prep(sql, args); },
    run() { return { meta: { changes: Number(db.prepare(sql).run(...params).changes) } }; },
    all() { return { results: db.prepare(sql).all(...params) }; },
    first() { return db.prepare(sql).get(...params) || null; }
  };
}
const env = { DB: { prepare: (sql) => prep(sql, []), batch: (items) => items.map((s) => s.run()) } };
const moduleObj = { exports: {} };
new Function('module', 'exports', workerSrc.replace(/^export default/m, 'module.exports ='))(
  moduleObj, moduleObj.exports
);
const api = moduleObj.exports;

const realDate = global.Date;
let clock = Date.UTC(2026, 11, 15, 12, 0, 0);
let wall = clock;
global.Date = class extends realDate {
  constructor(...args) { super(...(args.length ? args : [wall])); }
  static now() { return clock; }
};

async function call(urlPath, body) {
  const req = body === undefined
    ? { method: 'GET', url: 'https://qa.local' + urlPath, json: async () => ({}) }
    : { method: 'POST', url: 'https://qa.local' + urlPath, json: async () => body };
  const res = await api.fetch(req, env);
  let json = null;
  try { json = await res.json(); } catch (e) {}
  return { status: res.status, json };
}

const results = [];
function check(name, ok, detail) {
  results.push({ name, ok: !!ok });
  console.log((ok ? 'PASS' : 'FAIL') + '  ' + name + (detail ? '  |  ' + detail : ''));
}

(async () => {
  const day = 15;
  const submits = [];
  for (let i = 1; i <= 10; i++) {
    const accountId = 'bot' + String(i).padStart(2, '0');
    clock += 2000;
    submits.push(await call('/submit', {
      accountId, name: 'Bot ' + i, day, cpCount: 9 + i, mapUid: 'P_QA_MULTI', timeMs: 0
    }));
  }
  check('ten bots submitted without rate limiting',
    submits.every((r) => r.status === 200),
    submits.map((r) => r.status).join(','));

  const state = await call('/state?accountId=bot01');
  const board = (state.json && state.json.leaderboard) || [];
  check('leaderboard contains all ten bots', board.length === 10, 'rows ' + board.length);
  check('leaderboard sorted by points desc',
    board.every((row, i) => i === 0 || board[i - 1].points >= row.points),
    board.map((r) => r.points).join(','));
  check('daily bounty goes to the highest CP',
    state.json && state.json.days[day - 1].bountyHolder === 'Bot 10',
    state.json && state.json.days[day - 1].bountyHolder);
  check('bounty owner id is canonical',
    state.json && state.json.days[day - 1].bountyHolderAccountId === 'bot10',
    state.json && state.json.days[day - 1].bountyHolderAccountId);

  const events = (state.json && state.json.events) || [];
  check('feed has events from the bots', events.length > 0, 'events ' + events.length);
  check('feed is capped at MAX_EVENTS', events.length <= 15, 'events ' + events.length);
  check('feed rows are plain text',
    events.every((line) => typeof line === 'string' && !line.includes('$')),
    events.slice(0, 2).join(' / '));
  check('feed contains bounty takeovers',
    events.some((line) => line.toLowerCase().includes('bounty') || line.toLowerCase().includes('stole')),
    events[0] || '');

  // More than 15 events from a second batch must not grow the feed beyond the cap.
  for (let i = 11; i <= 20; i++) {
    clock += 2000;
    await call('/submit', {
      accountId: 'bot' + String(i).padStart(2, '0'), name: 'Bot ' + i,
      day, cpCount: 9 + i, mapUid: 'P_QA_MULTI', timeMs: 0
    });
  }
  const afterMore = await call('/state?accountId=bot01');
  const moreEvents = (afterMore.json && afterMore.json.events) || [];
  check('feed stays capped after more submits', moreEvents.length <= 15, 'events ' + moreEvents.length);
  check('twenty players appear in leaderboard',
    ((afterMore.json && afterMore.json.leaderboard) || []).length === 20,
    'rows ' + ((afterMore.json && afterMore.json.leaderboard) || []).length);

  global.Date = realDate;
  const failed = results.filter((r) => !r.ok);
  console.log('\nRESULT: ' + (failed.length === 0 ? 'PASSED' : 'FAILED') +
    ' (' + (results.length - failed.length) + '/' + results.length + ')');
  process.exitCode = failed.length === 0 ? 0 : 1;
})();
