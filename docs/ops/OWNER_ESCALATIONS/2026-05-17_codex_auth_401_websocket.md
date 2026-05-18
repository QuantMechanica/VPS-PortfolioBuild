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

## 2026-05-17T10:50Z update — Board Advisor observe wake

**Auth recovery is unstable — refresh-then-restale cycle observed.**

Timeline since original escalation:
- 09:25Z escalation opened (last successful Codex run 09:09Z).
- 10:20:28Z `~/.codex/auth.json` `last_refresh` bumped (token refresh fired).
- 10:23–10:28Z **window of recovery** — 5 Codex spawns succeeded
  (`codex_g0_20260517T102313`, `codex_review_842714c4`,
  `codex_review_48c3fe57`, `codex_build_a26ef4aa`, `codex_build_add6e569`).
- 10:17Z autonomous wake successfully completed REVIEW of QM5_1063 +
  chained enqueue_p2.
- **10:44:32Z — fresh 401 storm**: 10 Codex spawns (`codex_g0_20260517T104420`,
  research, review, 6× build) all 401, ~24 min after the refresh, against
  the same `auth.json` that just worked at 10:23Z.

Pattern implication: ChatGPT OAuth token TTL is shorter than the pump's
5-min spawn cadence × refresh interval. Each pump tick after the token
goes stale burns ~5 `attempt_count` slots across pending tasks until
either (a) `auth.json` refreshes again or (b) MAX_BUILD_RETRIES=3
parks them blocked.

OWNER actions from the original section remain valid. Additional
diagnostic to run when re-logging:
```powershell
# Check whether codex CLI auto-refresh is wired up at all
codex --version            # confirm v0.130.0+
type "$HOME\.codex\auth.json" | Select-String last_refresh
# If refresh interval looks long, force a fresh login (path 1)
```

The autonomous wake at 11:17Z will re-observe; if 401s have stopped by
then it will resume normal Codex spawns. If the cycle continues, the
next observe wake (12:17Z by the hourly task) will append again.

**Board-Advisor-side mitigation taken this wake: documentation update
only.** No state mutations, no pump changes, no agent lifecycle. The
pump's MAX_BUILD_RETRIES=3 cap remains the safety net.

## 2026-05-17T11:55Z update — Board Advisor observe wake

**Cycle still active — second refresh-then-restale observed; OWNER action
still required.**

Timeline since previous update:
- 10:50:35Z `~/.codex/auth.json` mtime bumped (second auto-refresh of the
  morning, ~30 min after the 10:20Z one).
- 11:17:01Z autonomous wake REVIEW of QM5_1064 succeeded → Codex working
  (single successful spawn ≈ 27 min after the refresh).
- **11:34Z — third 401 storm**: 6 Codex spawns
  (`codex_research_eb97a148`, `codex_g0_20260517T113419`,
  `codex_build_da29849a`, `codex_build_0eacd31d`, `codex_build_df0a8798`,
  `codex_build_6bfbea88`) all died with the same `responses_websocket
  401 Unauthorized` against `auth.json` that worked at 11:18Z. Each
  live log carries 9 occurrences of "401 Unauthorized" (retry loop
  inside a single spawn).

Two refresh-then-restale cycles in ~70 minutes (10:20→10:44, 10:50→11:34)
make the pattern definitive — this is not a one-off OAuth blip.
ChatGPT-mode token TTL on this Codex CLI build is consistently shorter
than the pump's effective spawn window. Each post-restale tick burns
~5 `attempt_count` slots before the auto-refresh fires again.

Downstream queue toll since the 10:50Z update: 4 new pending/failed
build_ea rows added (QM5_1069 → failed attempt=3 at 10:07Z; QM5_1087,
1090, 1091 → pending attempt=1; QM5_1090 hit the
`terminal-already-running` preflight class from the smoke-flake
escalation, others mix of auth-401 and framework_error from the
smoke-runner cluster). Cumulative blocked-or-blocked-equivalent count
across both escalations is now ~20 EAs.

OWNER actions from the original section remain unchanged. Strong
recommendation: pick **path 1 (codex logout / codex login)** at the
next interactive touch — both auto-refreshes today have produced only
a narrow working window before re-staling, suggesting the stored
OAuth refresh token itself is the broken piece.

**Board-Advisor-side mitigation taken this wake: documentation update
only.** No state mutations, no pump changes, no agent lifecycle, no
auth.json edits. Same envelope as the 10:50Z entry — this is the
escalation's third recurrence log line, not a new escalation.

## 2026-05-17T13:50Z update — Board Advisor observe wake

**Auto-refresh appears to have stopped entirely — escalates priority.**

State at this observe wake:
- `~/.codex/auth.json` mtime / `last_refresh` field both still
  `2026-05-17T10:50:35.405710600Z` — **no refresh in 3h 00m** (prior
  cycles refreshed every ~30 min).
- Most recent Codex spawn batch (~13:39Z local-15:39): 4 logs sampled
  (`codex_research_eb97a148`, `codex_review_d9576ad1`,
  `codex_g0_20260517T133919`, `codex_build_3655d246`) — each carries
  9× `responses_websocket 401 Unauthorized` with five reconnect
  attempts. Same pattern as 11:34Z storm but the post-storm refresh
  did not arrive.
- Recent autonomous wakes (10:20Z, 11:18Z, 12:19Z, 13:17Z) all
  succeeded on **Claude-only paths** (REVIEW, ENQUEUE_P4) — masking
  the fact that Codex remains 100% non-functional. Any wake that
  needs Codex (build / research / G0 / codex_review) will fail.
- Total filter of `failed/blocked build_ea` rows without a self-heal
  sibling: **13** (QM5_1045/1046/1050/1055/1060/1061/1062/1065/1066/
  1067/1068/1069/1070). All within the 09:07Z / 10:07Z creation
  window from the 401 cycle.

Pattern change versus the 11:55Z entry: the auto-refresh worked
twice (10:20Z, 10:50Z) and now appears to have stopped. Whatever
local daemon / refresh hook was firing has either died or its retry
budget is exhausted. This makes OWNER action (path 1 — `codex
logout && codex login`) the only remaining unblock.

OWNER actions from the original section remain unchanged. Same path
1 recommendation. Adding diagnostic to capture before relogging:
```powershell
# After 3h+ without refresh, capture last working state for forensics
Copy-Item "$HOME\.codex\auth.json" "$HOME\.codex\auth.json.stale-3h-20260517T1350Z"
codex logout
codex login
# verify
type "$HOME\.codex\auth.json" | Select-String last_refresh
python C:/QM/repo/tools/strategy_farm/farmctl.py tick
```

**Board-Advisor-side mitigation taken this wake: documentation update
only.** No state mutations, no pump changes, no agent lifecycle, no
auth.json edits. The 13 dead build_ea tasks remain parked; they will
re-attempt automatically once Codex auth is restored (pump tick
re-runs failed builds with attempt_count < 3, and the parked-blocked
ones can be hand-reset to pending after OWNER relogs).

## 2026-05-17T15:50Z update — Board Advisor observe wake

**Auto-refresh dead for 5h+; smoke-runner patch validation now cascade-blocked.**

State at this observe wake:
- `~/.codex/auth.json` `last_refresh` still `2026-05-17T10:50:35Z` —
  **no refresh in 5h 00m**, confirming the 13:50Z "auto-refresh stopped
  entirely" diagnosis. The two morning refreshes (10:20Z, 10:50Z) remain
  the only ones today.
- Sampled `codex_g0_20260517T154918.live.log` (15:49Z pump spawn):
  `OpenAI Codex v0.130.0`, 7× `responses_websocket 401 Unauthorized`,
  5/5 reconnect attempts exhausted, exit ~15s.
- 8 fresh Codex spawn logs in the last 3 minutes (research / g0 / 5×
  build) — pump tick still firing every 5 min, all 401.
- Autonomous wake 15:17Z handled REVIEW of QM5_1098 (Claude-only path)
  and explicitly skipped Codex retries:
  *"codex_auth_401 still OWNER-pending so Step 0b retries skipped to
  avoid attempt_count burn"* — pump short-circuit working as designed.
- Self-heal filter: **16 real `build_ea` failures** (QM5_1045, 1046,
  1050, 1055, 1060, 1061, 1062, 1065, 1066, 1067, 1068, 1069, 1070,
  1081, 1090, 1091). Net +3 since 13:50Z update (QM5_1081 just added at
  15:49:18Z from a pre-patch smoke at 14:30Z that pump finally classified).

Cascade impact (new this wake): the three smoke-runner patches that
landed at 14:04/14:11/14:45Z (bb09e964, 8deebf5c, be009931) are still
unvalidated. The pump cannot land a fresh post-patch `build_ea` because
every Codex compile spawn dies at 401 before producing an `.mq5`.
Result: **no progress possible on either escalation until OWNER relogs
Codex.** Smoke-runner escalation has no new data to log since 14:50Z.

OWNER actions from the original section unchanged. Strong recommendation
remains **path 1** (`codex logout && codex login`). The forensics copy
suggested in the 13:50Z update is the right pre-relog step:
```powershell
Copy-Item "$HOME\.codex\auth.json" "$HOME\.codex\auth.json.stale-5h-20260517T1550Z"
codex logout
codex login
type "$HOME\.codex\auth.json" | Select-String last_refresh
python C:/QM/repo/tools/strategy_farm/farmctl.py tick
```

**Board-Advisor-side mitigation taken this wake: documentation update
only.** No state mutations, no pump changes, no agent lifecycle, no
auth.json edits. Sixteen `build_ea` rows remain parked; identical
recovery path as prior entries (pump auto-retries those with
`attempt_count < 3`, OWNER can hand-reset the cap-3 parked rows).

## 2026-05-18T19:14Z update — Board Advisor observe wake (T+34h)

**Escalation 34 hours open; auth.json refreshed once overnight but
re-staled within 1h; no OWNER relogin yet.**

State at this observe wake:
- `~/.codex/auth.json` `last_refresh` = `2026-05-18T05:00:55Z` — exactly
  one auto-refresh fired between 2026-05-17T10:50Z and now (≈18h gap,
  then 14h+ stale since). JWT `exp` was `2026-05-18T06:00:54Z` per
  hourly autonomous wake summaries, i.e. token was only valid for 1h
  after refresh.
- Hourly autonomous wake summaries 2026-05-18T07:26Z–18:17Z all show the
  same `codex responses_websocket 401` cluster firing on every
  build_ea / codex_review / research / g0 spawn; pump short-circuits
  Codex retries each wake to avoid burning attempt_count.
- Self-heal filter now returns **38 real build_ea failures** (was 16 at
  2026-05-17T15:50Z, +22 in 28h). Dominant clusters: REPORT_MISSING +
  MODEL4_MARKER_REQUIRED (~20 rows, half overlap the smoke-runner
  escalation), `T1 terminal already running` preflight (~5 rows),
  smoke-runner parser empty-string crashes (~4 rows).
- 28 backtest_p2 tasks now pending against a single MT5 fleet — that
  queue is independent of Codex auth (Phase C dispatch is Python-only)
  but won't drain without sustained pump/dispatch progress.
- Approved-card backlog is at 171+ per the 17:23Z wake summary; Claude
  research/G0 paths keep adding ~5 cards/wake while Codex builds
  remain blocked. Backlog growth is asymmetric.

Auth auto-refresh remains effectively dead (1 refresh in 32 hours, 1h
useful window). Pattern matches the 2026-05-17T13:50Z "auto-refresh
appears to have stopped entirely" diagnosis — only OWNER `codex logout
&& codex login` will unblock the build leg.

OWNER actions from the original section unchanged. Same path-1
recommendation. Forensic snapshot suggestion updated for the longer
stale window:
```powershell
Copy-Item "$HOME\.codex\auth.json" "$HOME\.codex\auth.json.stale-34h-20260518T1914Z"
codex logout
codex login
type "$HOME\.codex\auth.json" | Select-String last_refresh
python C:/QM/repo/tools/strategy_farm/farmctl.py tick
```

**Board-Advisor-side mitigation taken this wake: documentation update
only.** No state mutations, no pump changes, no agent lifecycle, no
auth.json edits. The 38 parked build_ea rows recover via the same path
as prior entries once OWNER relogs Codex.
