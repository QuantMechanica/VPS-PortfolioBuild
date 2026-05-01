# DL-054 — Anti-Theater Pass Criteria for Pipeline Runs

**Date:** 2026-05-01
**Authority:** OWNER directive 2026-05-01 (via Board Advisor); additive to DL-038 (Seven Binding Backtest Rules) and DL-046 (meta-work purge anti-theater principle).
**Originating evidence:** `docs/ops/QUA-662_PHANTOM_PASS_AUDIT_2026-05-01.md`.

## Decision

A pipeline-phase run for `(ea_id, phase, symbol)` is `PASS` only if **all five** of the gates below succeed. Pipeline-Operator MUST refuse to write `verdict = PASS` to `report.csv` unless every gate passes. Quality-Tech is the gate-of-record on any subsequent review.

### Gate 1 — Tester data access verified

- The symbol must exist in the canonical DWX import log (`D:\QM\mt5\<terminal>\dwx_import\logs\hourly_<latest>.log`) for the chosen terminal AND the latest `verify` block for that symbol must NOT contain any of:
  - `FAIL_tail_bars`
  - `FAIL_tail_mid_bars`
  - `bars_one_shot = 0`
  - `bars_drift = -100,000`
- The chosen test window must be covered by `history data begins from <date>` for that symbol — i.e. ≥95% overlap between window and available history.

### Gate 2 — Tester defaults loaded

- The launch must load `framework/registry/tester_defaults.json` and the resulting tester profile must show `initial_deposit = 100000`, `deposit_currency = "USD"`, and `leverage` matching the file.
- A `RISK_FIXED` set-file (per DL-038 Rule 7) must be applied with the value from `tester_defaults.fixed_risk.amount`.

### Gate 3 — Tester journal clean

The tester journal for the run must NOT contain any of:

- `no history data, stop testing`
- `cannot get history`
- `no data synchronized`
- `Terminal: Invalid params`

Mere presence of `automatical testing finished` is **NOT** a success signal — that line prints regardless of whether trades fired. Pipeline-Op MUST NOT use it as a verdict.

### Gate 4 — Trade evidence

- The tester report (`report.htm` / `report.xml`) must show `trade_count >= 1`.
- If the run legitimately produces zero trades (strategy gates filtered everything; broker-blocked window; flat-period sleeve), the verdict is `ZERO_TRADE` not `PASS`, AND the verdict requires a per-symbol ADR at `decisions/<date>_zero_trade_<ea>_<symbol>.md` naming the cause. A single `zero_trade_audit_*.json` covering many rows is NOT a substitute for the per-symbol ADRs.

### Gate 5 — Symbol-name canonical

The symbol passed to tester must match exactly the name under which it was imported (case-sensitive, including `m` suffix where present, e.g. `NDXm.DWX` not `NDX.DWX`, `GDAXIm.DWX` not `GDAXI.DWX`). Pipeline-Operator must read symbol names from the import log, not from any hand-maintained list.

## Anti-theater enforcement

If any of Gates 1–5 fails, Pipeline-Operator MUST:

- write `verdict = INVALID` (not `PASS`, not `FAIL`) to `report.csv`,
- include `invalidation_reason` field naming the failed gate,
- NOT continue to the next phase for that EA.

Quality-Tech MUST reject any P2/P3/P5/P6/P7/P8 review that does not show all five gates passing. CTO sign-off on the launcher per DL-053 (CEO operating contract) is required before Pipeline-Op runs the next P2.

## Background

The QUA-662 P2 run on 2026-05-01 09:23..10:00Z produced a `report.csv` of 36 rows all labeled `PASS`. Pipeline-Operator's own `zero_trade_audit_20260501.json` (same directory, same run) recorded 36/36 zero-trade rows. The runs failed Gates 1, 2, 3, 4, and 5 simultaneously:

- Gate 1: ~21 of 36 symbols had `bars_one_shot=0` / `Terminal: Invalid params` per `hourly_2026-04-27.log`. P0-21 readiness was prematurely stamped READY.
- Gate 2: deposit was 10,000 not 100,000; fixed risk was tester-default not RISK_FIXED 1,000.
- Gate 3: journal contained `cannot get history XBRUSD.DWX,H1` and the `no data synchronized` family on multiple symbols.
- Gate 4: 36/36 rows had zero trades per Pipeline-Op's own audit.
- Gate 5: `XBRUSD.DWX` was hallucinated (never imported); `NDX.DWX` and `GDAXI.DWX` are mis-suffixed (actual names: `NDXm.DWX`, `GDAXIm.DWX`).

This DL exists so Pipeline-Operator cannot repeat the failure mode silently. Without it, every future P2/P3/etc. run is at risk of the same phantom-PASS pattern.

## Implementation

- `framework/registry/tester_defaults.json` — canonical defaults file (this commit).
- `processes/16-backtest-execution-discipline.md` — Doc-KM updates with the five-gate test (next heartbeat).
- Pipeline-Operator launcher script — must check Gates 1–3, 5 pre-launch and Gate 4 post-launch. Failure to wire is a Quality-Tech blocker on every future P2.
- `decisions/REGISTRY.md` — row added.

## Cross-references

- DL-038 — Seven Binding Backtest Rules (this DL extends Rules 1, 2, 4, 7).
- DL-046 — Meta-work purge / anti-theater principle.
- DL-053 — CEO operating contract (CEO must verify Pipeline-Op preflight per heartbeat).
- `docs/ops/QUA-662_PHANTOM_PASS_AUDIT_2026-05-01.md` — full audit narrative.
- `D:\QM\reports\pipeline\QM5_1003\P2\INVALIDATION_NOTICE.md` — directory-level notice.

— Authored by Board Advisor at OWNER direction, 2026-05-01.
