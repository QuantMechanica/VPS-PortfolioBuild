# QM5_10571 Q02 stale-binary recovery — 2026-07-21

## Scope

- EA: `QM5_10571_mql5-pchan-stop`
- Diverse target: `EURJPY.DWX`, H4
- Failed Q02 work item: `646139ff-4534-424a-933e-927c43c7b8b6`
- Replacement Q02 work item: `e809c752-5e9b-42b9-bc53-a744b8a45007`

## Diagnosis

The failed row records `run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS`. Its payload also
records the earlier registry repair: the original package used magic slots 0–3 while
the active registry assigns slots 100–103. That repair produced a strict compile and
replacement Q02 rows on 2026-07-11, but the failed historical row remained visible as
stuck. The current source, registry, and setfiles are aligned; the binary was rebuilt
after the failed run.

## Verification and handoff

- `framework/scripts/build_check.ps1 -EALabel QM5_10571_mql5-pchan-stop`: PASS,
  0 errors, 0 warnings.
- Compile report: `D:/QM/reports/compile/20260721_070240/summary.csv`.
- Build-check report: `D:/QM/reports/framework/21/build_check_20260721_070240.json`.
- The canonical EURJPY backtest setfile remains `RISK_FIXED=1000` and
  `RISK_PERCENT=0`.
- The existing replacement row is `pending`; no duplicate Q02 row was created.
- The historical failed row is linked to the replacement in the farm DB and released
  from the manual recovery claim.

No T_Live path, deploy manifest, portfolio gate, or AutoTrading state was touched.
