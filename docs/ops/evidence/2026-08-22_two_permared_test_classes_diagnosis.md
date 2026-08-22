# Two permanently-red test classes — root cause + fix

Task: `c90a4a18-13ee-40c2-8d19-31d41daf290a` (router, priority 55).
Context: Vault `12 ToDo/11_Systemanalyse_2026-08-22.md` §16.

## 1. `test_registry_rekey_12784.py::test_rekey_preserves_old_binary_and_binds_the_post_rekey_build` — FIXED

Root cause: the test pins `QM5_20007_intraday-config-engine.ex5` to a sha256 captured at the
2026-07-19 rekey. The binary was legitimately rebuilt on 2026-08-02
(`ec348e2b8 fix(strategy-farm): repair QM5_20007 Q02 infrastructure`, source `.mq5` +
compiled `.ex5` changed together, `health.py`/`terminal_worker.py` fixes in the same
commit). The worktree binary is byte-identical to what's committed at HEAD for that path
(`git status --porcelain` on the EA dir is clean) — this is a stale pin on a legitimate,
already-merged infra fix, not a live regression.

Fix applied: rebound the pinned sha256 in the test to the current committed binary
(`32e52b23b525f33bd693bf42bd3236ac66ee6b8405ca982521fd81eea2d2f74d`). This is a build
provenance pin, not gate/contract criteria — safe to rebind under GRÜN.

## 2. `test_execution_contract_lint.py` — 4 failures, ROOT CAUSE FOUND, FIX BLOCKED (ROT)

All 4 failures trace to one cause: `D:/QM/data/news_calendar/news_calendar_2015_2025.csv`
is refreshed **daily** (05:30 scheduled task; file mtime observed 2026-08-22 04:48), but
`framework/registry/dxz23_execution_contracts.json` pins that file's sha256 from the last
manual reconciliation on **2026-07-30** (`19a31245e ops: publish reconciled calendar and
resolve test lane`, itself gated by an explicit OWNER decision —
`docs/ops/evidence/2026-07-30_factory_preparation_owner_decision.json`,
`owner_decision_id: FACTORY_PREPARATION_20260730_REPAIR_NO_WAIVER`).

```
registry-pinned sha256  16d95a7ca00de57accbb2bf7ad63418873c7c1afbffd58b8ec35136abb057ece
live file sha256 (now)  42b02ae062271b643a9039410617a4c246ebed62c9a77db2e8b610fee6ce82bc
```

There is no automation that re-pins the registry's calendar-dependency hash after a
refresh — the 2026-07-30 reconciliation was a one-off, OWNER-gated manual event, not a
recurring job. Consequence: every one of the 4 failing tests re-derives from this same
byte-exact hash check (`_lint_ftmo_news_file_calendar` / `_dependency_hash_matches` in
`execution_contract_lint.py`), so the test class is red again the morning after any
calendar refresh and stays red until someone re-runs a reconciliation.

`tools/strategy_farm/test_lanes.py` / `config/test_lanes.v2.json` even encodes this: 3 of
the 4 failing node IDs are declared `external_residual_lane.state: RESOLVED_PASS` with
exit condition "PASS without skip, xfail, assertion weakening or silent rebinding" — a
declaration the live state no longer satisfies. This explains the "2 vs 4 depending on
selection" symptom in the task brief: running just `test_execution_contract_lint.py`
directly surfaces 4 reds (includes `test_20009_ftmo_news_calendar_expires_fail_closed`,
which isn't in the 5-sentinel residual list); running only the `external-residual` lane
surfaces the 3 sentinel node IDs from this file.

**Why this is not fixed here:** re-pinning `dxz23_execution_contracts.json`'s calendar
hash is a change to contract/gate criteria data (`framework/registry/...`), which is ROT
under the Stehende Vollmacht — "gate thresholds & contract criteria" are never
autonomous, and the only precedent for this exact change (2026-07-30) required an
explicit OWNER decision record. Rebinding it here without that would be silent
contract-criteria rebinding — exactly what the lane's own exit condition forbids.

## Recommendation (Entscheidungsschlange)

The daily calendar refresh and the registry's pinned dependency hash are structurally
out of sync: as built, this test class cannot stay green longer than one refresh cycle
without a recurring manual reconciliation. OWNER decision needed on one of:
- (a) automate a reconciliation step (re-pin + re-qualify) as part of the existing
  `refresh_news_calendar.ps1` pipeline, or
- (b) change what the test verifies (e.g. coverage-window/freshness rather than byte-exact
  hash-of-live-file) — itself a contract-criteria change needing sign-off.

No pipeline gate, verdict, or registry data was touched by this pass.

## Evidence

- Before: `1 failed→registry_rekey, 4 failed→execution_contract_lint` (5 failed, 53 passed)
- After rebind: `test_registry_rekey_12784.py` 3 passed; `test_execution_contract_lint.py`
  4 failed, 54 passed (unchanged — root cause is ROT-blocked, not fixed)
