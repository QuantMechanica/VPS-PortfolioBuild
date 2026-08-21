# QM5_12920 Gemini build review

- Review task: `6aef6969-3431-4325-aea0-7371031f95a2`
- Source task: `19c8295f-c2aa-47b6-9e55-47e0fa465b0f` (Gemini, retained in `REVIEW`)
- Reviewed artifact: `artifacts/builds/19c8295f-c2aa-47b6-9e55-47e0fa465b0f.json`
- Reviewed card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12920_qp-pre-election-sp500.md`
- Verdict: **RECYCLE**

## Blocking findings

1. The current strict static check fails three framework-series guardrails. `D:/QM/reports/framework/21/build_check_20260821_152509.json` reports one direct `Bars` call and two direct `iTime` calls without an approved `perf-allowed` reviewer exception.
2. The EA never calls `QM_FrameworkTrackOpenPositionMae()`, so mandatory open-position MAE evidence is not captured.
3. The generated setfile omits `qm_ea_id=12920` and includes legacy `qm_filter_news_*` keys that the EA does not declare. The setfile therefore lacks the deterministic EA identity binding specified by `SPEC.md`.

These are build-contract defects; no pipeline verdict is inferred.

## Checks that passed

- The approved card exists and the implementation is restricted to `SP500.DWX`, D1, magic slot 2.
- The even-year US election-date and D-4/D0 state transitions are consistent with the card on direct inspection.
- Source SHA-256 matches the artifact: `f3c0161126e123ed18be09769a5ad5587da74a1015e7e1dc27b9747b19a75175`.
- EX5 SHA-256 matches the artifact: `784a937ef523bfff52bad0c03405842d0afbccc2e3b2c845e2c0893a156def03`.
- Build guardrails, symbol-scope validation, and SPEC validation pass.
- The setfile retains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `qm_news_stale_max_hours=336`.

## Focused verification

- Re-ran strict `build_check.ps1` static validation with compilation and set validation skipped; status `FAIL`, three failures.
- Re-ran build guardrails, symbol-scope validation, and SPEC validation; all passed.
- Recomputed MQ5/EX5 SHA-256 values and inspected the approved card, strategy state machine, and setfile.

No EA, setfile, registry, queue, terminal, or pipeline state was modified by this review.
