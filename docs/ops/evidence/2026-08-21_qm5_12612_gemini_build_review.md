# QM5_12612 Gemini build review

- Review task: `dae6e821-63d1-4809-ae21-d8c082164db8`
- Source task: `27fb255a-232e-4a06-9e12-f80e263f98e3` (Gemini, retained in `REVIEW`)
- Reviewed artifact: `artifacts/builds/27fb255a-232e-4a06-9e12-f80e263f98e3.json`
- Reviewed card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12612_tsmom-12m-vol-scaled-ndx.md`
- Verdict: **RECYCLE**

## Blocking findings

1. The current strict static check fails nine framework-series guardrails. `D:/QM/reports/framework/21/build_check_20260821_152457.json` reports direct `iTime`, `Bars`, and `iClose` calls without an approved `perf-allowed` reviewer exception.
2. The EA never calls `QM_FrameworkTrackOpenPositionMae()`, so mandatory open-position MAE evidence is not captured.
3. The only generated backtest setfile omits `qm_ea_id=12612`. It also carries legacy `qm_filter_news_*` keys that the EA does not declare. This is not a deterministic setfile-to-EA identity contract.

These are build-contract defects; no pipeline verdict is inferred.

## Checks that passed

- The approved card exists and the implementation is restricted to `NDX.DWX`, D1, magic slot 1.
- Source SHA-256 matches the build artifact: `a21444cf6daf3ff27bcfe96ce46ec5d9984a5900d01db63176fd40df352252d8`.
- EX5 SHA-256 matches the build artifact: `d1395e74301d98cd86ad1afa4b05ee64e3bae954806530e41619944e70749960`.
- Build guardrails, symbol-scope validation, and SPEC validation pass.
- The setfile retains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `qm_news_stale_max_hours=336`.

## Focused verification

- Re-ran strict `build_check.ps1` static validation with compilation and set validation skipped; status `FAIL`, nine failures.
- Re-ran build guardrails, symbol-scope validation, and SPEC validation; all passed.
- Recomputed the MQ5 and EX5 SHA-256 values and compared them to the Gemini artifact.
- Inspected the approved card, EA entry/management hooks, and generated setfile.

No EA, setfile, registry, queue, terminal, or pipeline state was modified by this review.
