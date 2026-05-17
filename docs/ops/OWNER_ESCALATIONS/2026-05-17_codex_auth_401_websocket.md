---
opened_utc: 2026-05-17T09:25Z
raised_by: Board Advisor (autonomous wake 09:17:01Z)
severity: high
class: codex-auth / pipeline-builds-blocked
blocks: build_ea throughput (17 build_ea tasks hit 401 since 08:29Z; pump auto-spawn keeps producing same failure)
---

# Codex `responses_websocket` returns 401 Unauthorized → all Codex spawns since 2026-05-17T08:29Z fail

## Pattern

Every Codex `exec` invocation since **08:29:19Z** errors out before
producing any output, with repeated:

```
ERROR codex_api::endpoint::responses_websocket: failed to connect to
websocket: HTTP error: 401 Unauthorized,
url: wss://api.openai.com/v1/responses
ERROR: unexpected status 401 Unauthorized: Missing bearer or basic
authentication in header, url: https://api.openai.com/v1/responses
```

`codex login status` still reports **"Logged in using ChatGPT"** and
`~/.codex/auth.json` shows `auth_mode: chatgpt`, `last_refresh:
2026-05-16T19:24:18Z` (≈14 h before the failures began). So the access
token is stale and the per-process refresh is not picking up new
credentials — or the server-side session was invalidated. Either way the
CLI presents to the server without a valid bearer.

## Impact

17 `build_ea` Codex spawns hit 401 between 08:29Z and 09:19Z (latest
hits attempt-cap retry of QM5_1086/1088/1096/1097 plus retries of
QM5_1044/1045/1048/1052/1053/1055/1059/1063/1064/1067/1069/1098).
Plus 4 `codex_review` spawns hit 401 at 09:09Z.

Current pending/blocked build_ea state:
- `eac66b59` QM5_1096 — blocked, attempt 2
- `5ee53d67` QM5_1086 — blocked
- `a26ef4aa` QM5_1088 — pending, attempt 1
- `d0f039fb` QM5_1069 — blocked, attempt 3 (at MAX_BUILD_RETRIES, will not auto-retry)
- `25f6cc2b` QM5_1097 — pending, attempt 2

The `QM_StrategyFarm_Tick_5min` pump keeps respawning Codex against
these tasks every 5 min; each respawn dies in ~15 s with the same 401,
incrementing `attempt_count` until MAX_BUILD_RETRIES (3) is hit, then
the task is parked `blocked` indefinitely. Three already at attempt 3.

Claude side (research / G0 / ea-review) is unaffected — only Codex is
blocked. So the queue cannot drain until OWNER re-authenticates Codex.

## Evidence

- `D:/QM/strategy_farm/logs/codex_build_eac66b59-*.live.log` — full 401
  storm tail.
- `D:/QM/strategy_farm/logs/codex_review_0c07844e-*.live.log`,
  `D:/QM/strategy_farm/logs/codex_review_385bf15a-*.live.log` — review
  logs with same 401 pattern at 09:09Z.
- `grep -l "401 Unauthorized" D:/QM/strategy_farm/logs/codex_*.live.log`
  → 17 build logs + 4 review logs.
- Earliest 401: `2026-05-17T08:29:19Z` (build `b914cd0f`).
- Latest 401: `2026-05-17T09:19:29Z` (builds `eac66b59`, `df0a8798`,
  `5ee53d67`, `25f6cc2b`).
- Last *successful* Codex run: `codex_review_d05900a7` started 09:04:00Z,
  finished ~09:09Z, wrote verdict FAIL for QM5_1044 with 64,926 tokens.

## OWNER actions required (one of these)

Pick whichever is easiest:

1. **Re-login Codex** (recommended — clears any stale OAuth state):
   ```powershell
   codex logout
   codex login
   ```
   Then trigger one pump cycle to verify Codex spawns succeed:
   ```powershell
   python C:/QM/repo/tools/strategy_farm/farmctl.py tick
   ```

2. **Restart codex auth refresh** (if the daemon is somehow corrupted):
   inspect `~/.codex/auth.json`, delete it, re-run `codex login`.

3. **If the ChatGPT subscription is at quota**, switch to API key path:
   set `OPENAI_API_KEY` env var, restart pump scheduled task.

## Board-Advisor-side mitigation (already done)

- Wake 09:17:01Z does NOT respawn Codex (would just hit same 401 — Step
  0b's `cat prompt | codex exec` uses identical creds).
- Wake exits with `ESCALATE` log line; next wake at 10:17Z will re-check
  auth before deciding what to do.
- No state mutations to `tasks`/`sources` — pump's automatic retry-up-to-3
  flow will keep parking builds `blocked` until auth is restored; no manual
  intervention needed once Codex works again.

## What NOT to do

- Do **not** disable `QM_StrategyFarm_Tick_5min` — work-items dispatch
  (MT5 backtests on T1-T5) is independent of Codex and continues to
  drain backtest_p2 tasks. Stopping the pump would block backtest
  progress unrelated to this auth issue.
- Do **not** manually `record-build` against the stale Codex result
  files — they're empty / never-written. Let pump's retry logic re-run
  once auth works.

## Related

- The earlier escalation `2026-05-17_smoke_first_run_intermittent_report_missing.md`
  describes the smoke-runner flakiness *downstream* of a successful
  Codex build. That issue is unrelated to this auth failure but the
  same EAs (QM5_1045 etc.) appear in both — the smoke flake from
  yesterday is now buried under the auth break.
