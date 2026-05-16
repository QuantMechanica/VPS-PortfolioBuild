# QM Quota Scraper Userscripts

Scrape Chrome-rendered Codex + Claude usage dashboards and POST snapshots to the
local VPS receiver at `http://127.0.0.1:9090/quota`.

The receiver writes to `D:/QM/strategy_farm/state/quota_snapshot.json`.
`render_cockpit.py` reads that file to show real % of 5-hour / weekly limits
instead of stream-aggregated heuristics.

## One-time setup (per Chrome profile)

1. Install Tampermonkey (the same extension you already use for Claude inside Chrome).
2. Open Tampermonkey dashboard → **Utilities** → **Import from file** (or just
   open the `.user.js` directly in Chrome — Tampermonkey will prompt to install):
   - `codex_usage_scraper.user.js` → matches `chatgpt.com/codex/cloud/settings/analytics*`
   - `claude_usage_scraper.user.js` → matches `claude.ai/settings/usage*`
3. After installing, open `chrome://extensions` → Tampermonkey → **Details** →
   make sure both scripts show **Enabled**.

## How it works

- Each script runs at `document-idle`, then ticks every 60s.
- It scrapes the rendered DOM (`<main>` or `body`) — regex-matches common quota
  phrases (`X% of 5-hour`, `resets at HH:MM`, etc.) plus a structured dump of
  every `[role="progressbar"]` + interesting nearby text.
- POSTs `{source: "codex"|"claude", data: {...}, scraped_at: ...}` to
  `http://127.0.0.1:9090/quota`.
- `GM_xmlhttpRequest` is preferred (no CORS preflight); falls back to `fetch`.

## Running the receiver

```
python C:/QM/repo/tools/strategy_farm/quota_receiver.py
```

Or install as a startup scheduled task (TODO: `QM_StrategyFarm_QuotaReceiver`,
trigger `AT STARTUP`).

## Verifying

After installing the scripts and opening either page in Chrome:

```
curl -s http://127.0.0.1:9090/quota | jq .
```

You should see a `codex` and/or `claude` key with `data.matches` and recent
`received_at` timestamps.

## Privacy / scope

- Localhost-only POST. The receiver binds `127.0.0.1` — not reachable from the
  internet or LAN.
- No credentials are sent — only the rendered text of pages you already loaded.
- Userscripts run only on the two `@match` URLs above.
