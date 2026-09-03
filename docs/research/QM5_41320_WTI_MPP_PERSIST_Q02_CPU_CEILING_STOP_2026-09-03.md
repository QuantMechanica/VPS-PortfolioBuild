# QM5_41320 WTI PP Persistence — Q02 CPU-Ceiling Stop

**Date:** 2026-09-03  
**Branch:** `agents/board-advisor`  
**Outcome:** new edge built and governed-compile PASS; stopped before build-record/Q02 mutation

## New non-duplicate edge

`QM5_41320_wti-mpp-persist-tr` is a single-symbol, monthly WTI continuation
strategy on `XTIUSD.DWX`. It estimates an intercept AR(1) over 60 completed
broker-month log closes, applies the Phillips-Perron Z-tau correction with 11
Bartlett residual lags, and follows the newest 12-month return only when the
inclusive PP state threshold is at least `-2.594`. One attempt is consumed per
broker month. Risk is fixed at USD 1,000 in the sole Q02 preset, with an
ATR(20) x 3.5 frozen hard stop and no target.

The acknowledged nearest registry match is `QM5_41319`, whose ADF regression
uses first differences and a lagged-difference regressor. QM5_41320 instead
uses a level AR(1) and a Bartlett/Newey-West long-run variance correction. It
is therefore a distinct mechanism; only later Q09 evidence may establish its
realized portfolio correlation.

## Durable build evidence

- Source approval and retrieval evidence commit: `58d65c4a9f`
- Approved Strategy Card/G0 commit: `c1fc05d7a1`
- EA-ID reservation commit: `69f1f7cf60`
- Magic allocation/resolver commit: `42681413b1`
- Mechanical EA, SPEC, oracle, and fixed-risk set commit: `19e0d1bbe5`
- Q01 SPEC-schema correction commit: `30971e35e2`
- Governed EX5 and compiler-bound setfile commit: `3e4057409a`
- MQ5 SHA-256: `bb1bc9e7d88332bb43637e137a4128fe3f457da43044e73890eb68c49e6e65c7`
- EX5 SHA-256: `e4fe84d9dfe4ef4b25a182fd392d4ca19db974a3bdf7fa8824ec53a2b0ecaa76`
- Final setfile SHA-256: `1f9b2e96ae47114b7cdc05713db24eabe3623809c6985f4c633cea98bc94ccf8`
- Compile work item: `82cdf671-c9ef-428e-86f1-02d343787ad5`
- Compile verdict: `COMPILE_OK`; strict build check `PASS`; 0 errors, 0 warnings
- Compile evidence: `D:\QM\reports\work_items\82cdf671-c9ef-428e-86f1-02d343787ad5\QM5_41320\COMPILE_EA\compile_evidence.json`
- Independent PP oracle: 9/9 tests PASS
- `validate_spec_doc.py`: PASS

The required one-pass smoke request was made through `run_smoke.ps1` with
`-Terminal any`, `-SmokeMode`, year 2024, and the fixed-risk XTIUSD.DWX D1
setfile. The dispatcher refused before launching a tester:

`Terminal resolution returned no terminal. status=no_capacity error_code=none message=No message.`

No smoke retry was attempted.

## Binding CPU stop

The fresh five-sample measurement immediately before the intended
`record-build`/automatic Q02 insertion was:

`100.0000, 98.6698, 97.9504, 98.2449, 99.6095 percent`

- Average: `98.8949%`
- Maximum: `100.0000%`
- Binding ceiling: `97%`

Per the mission constraint, work stopped at that point. A read-only state
audit then showed build task `85b3f3e7-1d5e-49ba-8aa6-eefc1abac96e` still
`pending` and zero `QM5_41320 / Q02` rows. The unrecorded build-result object
was moved out of the controller's watched build directory to prevent an
asynchronous enqueue race and preserved at:

`D:\QM\strategy_farm\artifacts\builds_cpu_stopped\QM5_41320_85b3f3e7-1d5e-49ba-8aa6-eefc1abac96e.json`

Its SHA-256 is
`51889afd62e0d1461d6a86ef8ba3da2b0ca55a41ba135a9016cf3ccfc6a66dea`.

## Safe continuation boundary

After a new five-sample CPU check is strictly below the ceiling, restore the
preserved result to the build task's exact artifact target, run the canonical
`farmctl record-build` command once, and verify that exactly one
`QM5_41320 / XTIUSD.DWX / Q02` row is pending. Do not start a tester manually,
touch the portfolio gate, modify a live manifest, or interact with `T_Live`.
