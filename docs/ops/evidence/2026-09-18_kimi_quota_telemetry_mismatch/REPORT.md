# Kimi quota telemetry mismatch (task d797e68f-bd21-4e41-b500-c5f2e9ff3152)

## Trigger

`D:/QM/reports/ai_exchange/20260918_ftmo_gap_kimi/research.log` (2026-09-18T00:24Z):

```
error: failed to run prompt: provider.auth_error: 403 You've reached your weekly
(7-day) usage limit. Your quota will reset when the current 7-day window ends. To
continue now, purchase extra usage or upgrade your plan:
https://www.kimi.com/membership/subscription?tab=quota
```

Two minutes later, `D:/QM/reports/state/kimi_quota_state.json` (2026-09-18T00:26:01Z)
recorded a fresh, `fetch_status: "ok"` fetch of the *same managed usage endpoint the
CLI itself uses* with `rolling_7d.used_ratio = 1.1e-05` (essentially unused) and
`kimi_governor` status `NORMAL` (day 95/120, week 216/600 - the runaway guard, nowhere
near the real-telemetry thresholds). The account is unambiguously hard-blocked; the
telemetry the governor trusts says the opposite.

## (1) Raw `/usages` response - field mapping (no live call required)

A live network re-fetch was attempted first (`kimi_quota_fetcher.fetch()` called
in-process) and returned `auth_error`/`http_401` - the OAuth token was stale at the
moment of this run, and the bounded CLI refresh (`refresh.min_interval_s=21600`) was
correctly gated off because the last successful fetch (00:26:01Z) is still within the
6h window (see `refresh_allowed()`). Forcing an out-of-band refresh call against an
account already reporting a hard weekly cap would not produce new evidence and was not
attempted.

A live raw sample was not needed: `tools/strategy_farm/tests/test_kimi_quota_fetcher.py`
already carries `USAGES_FIXTURE`, captured 2026-09-15 and documented in-file as "shaped
exactly like the live response":

```python
USAGES_FIXTURE = {
    "usage": {"limit": "100", "remaining": "80", "resetTime": "2026-09-22T09:31:53.7Z"},
    "limits": [{"window": {"duration": 300, "timeUnit": "TIME_UNIT_MINUTE"},
                "detail": {"limit": "100", "remaining": "15", "resetTime": "2026-09-20T14:31:53Z"}}],
    "usages": {
        "limit_5h": {"used_ratio": 0.85, "reset_time": "2026-09-20T14:31:53Z"},
        "limit_7d": {"used_ratio": 0.10, "reset_time": "2026-09-22T09:31:53Z"},
    },
}
```

This matches the live `observed_top_keys` recorded in `kimi_quota_state.json` exactly:
`["limits", "usage", "usages"]`.

`kimi_quota_fetcher.normalize()` (`tools/strategy_farm/kimi_quota_fetcher.py:309-368`)
reads **only** `payload["usages"]` (`limit_5h` / `limit_7d` / `limit_month_total` /
`limit_month_code`) and `payload["boosterWallet"]`. It never reads `payload["usage"]`
(singular) or `payload["limits"]` (plural, a **list**) at all - those two keys are
silently discarded on every fetch, `ok` or not.

Field mapping, from the fixture:

| key | shape | notable value |
|---|---|---|
| `usages.limit_7d` | `{used_ratio, reset_time}` | the ratio the fetcher/governor consume today |
| `usage` (singular) | `{limit, remaining, resetTime}` | absolute counter; `resetTime` in the fixture is **the same timestamp as `usages.limit_7d.reset_time`** (`2026-09-22T09:31:53Z`) |
| `limits` (plural) | `[{window:{duration,timeUnit}, detail:{limit,remaining,resetTime}}, ...]` | a **list** of per-window buckets (fixture shows one 5-minute/300s window); the live payload's full list (not captured) plausibly also carries the weekly bucket that the CLI itself checks before returning 403 |

`usage.resetTime` aligning exactly with `usages.limit_7d.reset_time` is a strong,
code-verifiable signal that the two objects describe the *same* 7-day window through
two different lenses - a ratio (`usages`) the fetcher trusts, and an absolute
`limit`/`remaining` pair (`usage`) it never reads. If the CLI's own 403 check is driven
by the `remaining`-style counter (`usage` or an entry in `limits`) rather than the
possibly-lagging/differently-scoped `used_ratio`, that is sufficient to explain the
mismatch without invoking any other cause (account mismatch, stale cache, etc.) - and
does not require inventing values not present in either the fixture or the live state
file.

**Not fixed in this task:** re-pointing `normalize()` at `usage`/`limits` as the
primary telemetry source needs a live raw payload with the *full* `limits` list (the
fixture only samples one window) to confirm which entry is the weekly one, and a
verification cycle to confirm the new field tracks real exhaustion correctly before
swapping the primary signal. That live capture will happen naturally on the next
successful fetch (governor's own 15-min task); no dedicated action was needed here.

## (2) Governor now treats a CLI weekly/monthly 403 as EXHAUSTED, independent of the fetcher

Root cause of *why the governor never caught this via the existing consecutive-failure
path*: `kimi_adapter.classify_error()` matches the (stderr+stdout) blob against
`error_class_patterns` in `kimi_adapter.v1.json`. The live message text - `"403 You've
reached your weekly (7-day) usage limit"` - does not contain any `auth_expired` pattern
(`401`, `credential`, `/login`, ...) nor any `rate_limited` pattern (`rate limit`,
`429`, `quota exceeded`, ...). It fell through to the generic `error` class, which is
**not** in `consecutive_fail_statuses`, so `kimi_governor.compute_state`'s
`tail_fail_streak` escalation never fired - regardless of what the quota fetcher said.

Fix (`tools/strategy_farm/kimi_adapter.py`, `kimi_governor.py`,
`config/kimi_adapter.v1.json`):

* New status `quota_exhausted`, classified from CLI output patterns (`"weekly (7-day)
  usage limit"`, `"weekly usage limit"`, `"monthly usage limit"`, `"reached your
  weekly"`, `"reached your monthly"`, `"purchase extra usage"`), checked *before*
  `rate_limited` in the pattern list.
* `quota_exhausted` is **not** in `retry_statuses` - retrying a hard weekly cap within
  the 20-60s backoff window cannot help.
* `kimi_governor.compute_state` now escalates to `EXHAUSTED` on a **single** tail
  `quota_exhausted` ledger entry (mirrors the existing single-shot `cli_missing` rule -
  the CLI's own wording is unambiguous, unlike a possibly-transient `rate_limited`).
  This check sits in the "always active" block that runs before the
  real/fallback/legacy telemetry-mode branch, so it fires **even when the managed-usage
  fetch is fresh and `ok`** with a near-zero ratio - exactly today's mismatch.
* `quota_exhausted` was also added to the default `consecutive_fail_statuses` list, so
  the pre-existing two-consecutive-failure path also recognizes it (defense in depth).

## (3) Tests

* `tools/strategy_farm/tests/test_kimi_adapter.py`:
  `test_classify_error_weekly_cap_is_quota_exhausted_not_rate_limited`,
  `test_run_kimi_quota_exhausted_is_not_retried`.
* `tools/strategy_farm/tests/test_kimi_governor.py`:
  `test_state_exhausted_on_quota_exhausted_last`,
  `test_quota_exhausted_escalates_even_when_real_telemetry_says_normal` (the exact live
  mismatch, reproduced: fresh `ok` fetch, `rolling_7d.used_ratio=1.1e-05`, tail status
  `quota_exhausted` -> `EXHAUSTED`).

Full suite run (2026-09-18):

```
python -m pytest tools/strategy_farm/tests/test_kimi_adapter.py \
  tools/strategy_farm/tests/test_kimi_governor.py \
  tools/strategy_farm/tests/test_kimi_quota_fetcher.py \
  tools/strategy_farm/tests/test_kimi_quota_flag_contract.py \
  tools/strategy_farm/tests/test_agent_chain_kimi.py \
  tools/strategy_farm/tests/test_agent_router_kimi_lane.py \
  tools/strategy_farm/tests/test_kimi_interim_handoff.py \
  tools/strategy_farm/tests/test_run_agent_orchestration_kimi.py -q
```

148 passed, 0 failed, 0 regressions.

## Not done

* Backtests untouched (out of scope, per launcher hard rule).
* No live model call was spent (weekly cap already confirmed exhausted; the bounded
  refresh guard correctly blocked another network round-trip so soon after the last
  success).
* `normalize()` itself was not repointed at `usage`/`limits` - see "(1) Not fixed in
  this task" above.
