# Slice report — c2_kimi_quota_fetcher

**Date:** 2026-09-15 · **Directive:** OWNER-DEC-CBE-20260915 §30–§33, §70
(`Kimi real quota fetch failure falls back safely`, `no secret leakage`).
**Audit basis:** `audit/kimi_quota_discovery.md`, `docs/ops/KIMI_INTEGRATION_ARCHITECTURE.md`,
`kimi_adapter.py`, `kimi_governor.py`, `config/kimi_adapter.v1.json`.

## What was built

A real Kimi subscription telemetry path that replaces the artificial local-ledger
ceiling with the actual usage the official CLI reads, while keeping the ledger as a
fail-closed fallback and a runaway guard.

1. **`tools/strategy_farm/kimi_quota_fetcher.py`** — one read-only
   `GET https://api.kimi.com/coding/v1/usages` (+ `GET /me` for the plan label only),
   Bearer OAuth token read at runtime from the *same* credential file the CLI uses
   (`.kimi-code/credentials/kimi-code.json`). Normalizes into
   `D:/QM/reports/state/kimi_quota_state.json` with the §32 fields: `plan`,
   `subscription_period`, `monthly`/`rolling_5h`/`rolling_7d` (each `used_ratio` +
   `reset_at`), Kimi-vs-Code `breakdown` (when present), `extra_quota_active` (booster),
   `source='api.kimi.com/coding/v1/usages'`, `source_timestamp`, `raw_schema_version`,
   `fetch_status ∈ {ok, auth_error, network_error, schema_error, disabled}`. Uses only
   stdlib `urllib` (no new deps). **Never logs/prints/persists the token**; debug output
   redacts `Authorization` to `Bearer <redacted>`; `/me` PII (email/phone/nickname/
   user_id/global_id/avatar) is discarded.
2. **`tools/strategy_farm/config/kimi_quota_fetcher.v1.json`** — all fetcher params;
   real-telemetry thresholds and the raised runaway guard (Fable-adjustable, §33).
3. **`tools/strategy_farm/kimi_governor.py`** — `compute_state` now accepts a
   `quota_state`: when it is a fresh `ok` fetch it drives NORMAL/CONSERVE/EXHAUSTED from
   the **real ratios** (CONSERVE ≥ 0.80 any window or ≥ 0.85 monthly; EXHAUSTED ≥ 0.98)
   and sets `usage_source='managed_usage_endpoint'`; on any failure/staleness it falls
   back to the ledger path and marks `usage_source='local_ledger_fallback'` + the failure
   class. The 40/200 call caps became `runaway_guard` (default 120/600) anomaly protection
   only — they still trip EXHAUSTED (never removed, §33). `evaluate()` calls the fetcher
   in-process (guarded by try/except + a 15 s timeout, no separate task); the `evaluate`
   subcommand fetches, `status` and adapter `record()` consume the last fetched state.

## Live endpoint verification (from the worktree)

`python -X utf8 tools/strategy_farm/kimi_quota_fetcher.py fetch --print-redacted` and the
in-process governor path both succeeded live 2026-09-15 (token refreshed via one minimal
`-p` call first, since the stored token was ~2 h expired). Redacted normalized output
(ratios only, no ids/tokens):

```json
{
  "schema": "qm.kimi-quota/v1",
  "fetch_status": "ok",
  "source": "api.kimi.com/coding/v1/usages",
  "raw_schema_version": "coding/v1/usages@2026-09-15",
  "observed_top_keys": ["limits", "usage", "usages"],
  "plan": "Allegro",
  "plan_status": "USER_STATUS_NORMAL",
  "plan_region": "REGION_OVERSEA",
  "subscription_period": {"start": "2026-09-15", "end": "2026-10-15"},
  "monthly": null,
  "rolling_5h": {"used_ratio": 0.0, "reset_at": "2026-09-15T14:31:53Z"},
  "rolling_7d": {"used_ratio": 0.0, "reset_at": "2026-09-22T09:31:53Z"},
  "breakdown": null,
  "extra_quota_active": false
}
```

Governor e2e (temp config, no live runtime state touched): `state=NORMAL`,
`usage_source=managed_usage_endpoint`, `quota_fetch_status=ok`, `runaway_guard 120/600`.
A token-leak scan of the written `kimi_quota_state.json`, `kimi_governor_state.json`, and
`kimi_governor.log` against both `access_token` and `refresh_token` = **clean**.

### Schema note (live truth vs the audit's binary prediction)

The live `/usages` response carries `usages.limit_5h`/`limit_7d` (`used_ratio`+`reset_time`),
plus top-level `usage` and `limits[]`. On this near-idle Allegro account it returns **no**
`limit_month_total`/`limit_month_code` and **no** `boosterWallet` (the binary defines them; they
appear only when populated). The normalizer parses `usages` primarily and tolerates the absent
monthly/booster/breakdown fields as `null`/`false` (honest, not invented).

### Token-refresh finding (design decision)

The 15-min OAuth token is refreshed by the CLI **only on a real authenticated model call**;
`kimi provider list` and `kimi doctor` do **not** refresh (both verified live). Re-implementing
the OAuth grant is a documented non-goal (auth-surface risk; `kimi_quota_discovery.md` risk 6).
So the fetcher's `refresh.via_cli` is **OFF by default**: a stale token short-circuits to
`auth_error` → ledger fallback (no wasted request). In production the frequent adapter research
calls keep the token fresh for the 15-min governor fetch. `refresh.via_cli=true` is available if
measured cadence proves insufficient (spends one model call per refresh).

## Contracts changed (directive §70 regression list)

- **`Kimi real quota fetch failure falls back safely`** — every failure class
  (`auth_error`/`network_error`/`schema_error`/`disabled`) and a stale `ok` state route to
  the local ledger path with `usage_source='local_ledger_fallback'`; the fetcher never raises;
  the in-process governor fetch is guarded + 15 s bounded. MT5 factory unaffected.
- **`no secret leakage`** — token read at runtime only, never logged/printed/persisted;
  Authorization redacted; `/me` PII discarded; `--print-redacted` asserts no token in output.
- **Runaway guard** — the renamed local caps still trip EXHAUSTED as anomaly protection,
  raised to 120/600 so they cannot bind before real telemetry.

New state contract: `D:/QM/reports/state/kimi_quota_state.json` (schema `qm.kimi-quota/v1`).
Governor `compute_state`/`evaluate` gained an optional `quota_state`/`fetch` (back-compatible;
legacy call sites and the ledger-only path are unchanged).

## Tests added + results

- `tools/strategy_farm/tests/test_kimi_quota_fetcher.py` (new): schema parse of a live-shaped
  fixture; Kimi-vs-Code breakdown; booster→extra_quota; `/me` PII discarded; happy-path write +
  **no token in state file**; bearer sent but redactor masks it; `401→auth_error`; stale token
  short-circuits to `auth_error` with **zero** requests; timeout→`network_error`;
  `404→network_error`; garbage JSON→`schema_error`; kill switch→`disabled` (no network); missing
  credential→`disabled`; freshness window. → **14 passed in 0.80s**.
- `tools/strategy_farm/tests/test_kimi_governor.py` (extended): real ratios drive
  NORMAL/CONSERVE(window)/CONSERVE(monthly)/EXHAUSTED; runaway guard still trips under NORMAL real
  ratios; stale state → fallback; `auth_error`/`network_error` → fallback (ledger still honoured);
  legacy path unchanged with no quota_state; `evaluate` prefers injected real quota; raised
  120/600 guard default with legacy `caps` alias. → **31 passed in 0.84s** (20 pre-existing + 11 new).
- Full Kimi suite (adapter/flag-contract/router-lane/chain/orchestration + the two above):
  **130 passed in 11.65s**.

## Docs updated

- `docs/ops/KIMI_INTEGRATION_ARCHITECTURE.md` — §1 usage-row + §7 corrected (endpoint exists;
  same call the CLI usage panel makes; ledger is now the fallback plane), §7.2 governor rules
  updated; superseded statements marked, not deleted.
- `tools/strategy_farm/config/kimi_adapter.v1.json` — governor `_doc` (the "no usage endpoint"
  line) corrected; `caps`→`runaway_guard` (120/600, `caps` kept as legacy alias);
  `quota_fetcher_config` pointer added.
- `docs/ops/evidence/2026-09-15_kimi_integration/audit/kimi_cli.md` — dated, append-only
  CORRECTION ANNEX (endpoint, live-verify, refresh finding).

## Rollback

- Feature kill switch (no code change): env `QM_KIMI_QUOTA_FETCH=0` → fetcher returns
  `disabled`, governor uses the ledger fallback everywhere. Or set
  `config/kimi_quota_fetcher.v1.json:"enabled": false`.
- Full revert: `git revert` this slice's commit. The governor then keeps working (fetcher import
  is guarded; absent fetcher → legacy ledger path). To restore the old binding ceiling, set the
  governor `runaway_guard` back to `{day:40, week:200}`.

## Not done / caveats

- **Automatic token refresh inside the fetcher is intentionally OFF** (design decision above).
  Consequence: if the 15-min governor fetch happens to run while the token is stale (no recent
  adapter call), that cycle records `auth_error` and falls back — self-heals on the next fetch
  after any Kimi call. This is the safe choice per the audit; `refresh.via_cli=true` is the
  documented lever if telemetry gaps prove material.
- **Monthly used-ratio + Kimi-vs-Code breakdown are `null` on the current account** because the
  live `/usages` omits `limit_month_*` for a near-idle subscription. The parser will populate them
  automatically if/when the endpoint returns them; no code change needed.
- The scheduled task itself (`QM_StrategyFarm_KimiGovernor_15min`) is unchanged — the fetch is
  wired into `evaluate()`, so the existing task now fetches first with no task edit (orchestrator
  need not reinstall it).
