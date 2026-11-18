# Cloudflare Worker deployment (free tier)

Already deployed for this project. The live endpoint is:

```
https://goalmas.tomekdot-goalmas.workers.dev
```

Read-only admin panel (requires the ADMIN_TOKEN secret in the query string):

```
https://goalmas.tomekdot-goalmas.workers.dev/admin?token=<ADMIN_TOKEN>
```

Raw D1 tables in the Cloudflare dashboard:

```
https://dash.cloudflare.com/2975602b6ae7dc883884858d1b5ce4bf/database/d1
```

It is baked into `src/Config.as` as `DEFAULT_API_URL`, so players need no
configuration. The D1 database ID is stored in `wrangler.toml`.

The steps below are only needed if you want to redeploy from scratch.
Run the commands below from this `backend/` folder (it holds `worker.js`,
`schema.sql` and `wrangler.toml`).

## 1. Install wrangler and log in

```bash
npm install -g wrangler
wrangler login
```

## 2. Create the D1 database

```bash
wrangler d1 create goalmas
```

Copy the `database_id` from the output into `wrangler.toml` (field `database_id`).

## 3. Create the tables

```bash
wrangler d1 execute goalmas --remote --file=schema.sql
```

## 4. Deploy

```bash
wrangler deploy
```

Wrangler prints the URL, for example `https://goalmas.<account>.workers.dev`.

## 5. Optional: Discord announcements

```bash
wrangler secret put DISCORD_WEBHOOK_URL
```

Paste the webhook URL when asked.

## 6. Admin page token

```bash
wrangler secret put ADMIN_TOKEN
```

Then open `/admin?token=<your-token>` on the worker URL. Without the token
the page returns 404. The token is never stored in the repository.

## 7. Point the plugin at the worker

In game: Openplanet -> Settings -> Plugins -> GoalEvent

- `Worker URL` = the URL from step 4 (no trailing slash)
- `Sync mode` = `2`

Then reload the plugin. The first `/state` call confirms the connection.

For a zero-setup release, paste the same URL into `DEFAULT_API_URL` in
`src/Config.as` before building the `.op`: every player then syncs automatically
with no settings to change.

## What ends up in the database

- `players` - one row per player, created automatically on the first submitted run.
  Stores nickname, total points, bounty count, badges and the per-day best
  checkpoint count (`bests` JSON, optional `ms` for tie-breaks).
- `bounties` - one row per day: current record (checkpoint count, holder, optional time).
- `events` - the last 15 feed lines shown in the plugin and pushed to Discord.

No passwords, no e-mail, no IP addresses. The key is the ManiaPlanet login.

## Health check

```bash
curl https://<your-worker-url>/
```

Expected: `{"ok":true,"service":"goalmas","goalCp":10,"days":25}`
