# QM5_10184 Diverse Q02 Enqueue Evidence - 2026-06-27

## Scope

- EA: `QM5_10184_tv-atr-zigzag-break`
- Claimed farm task: `cf4dafbe-0938-4172-b4cf-baf0123601b5`
- Reason: high-diversity approved backlog item spanning `NDX.DWX`, `XAUUSD.DWX`, `XTIUSD.DWX`, `GDAXI.DWX`, and `EURUSD.DWX`
- Constraint respected: no `T_Live`, no portfolio gate or live manifest edits

## Repair

- Added current Q01 `SPEC.md`.
- Generated five `H1` backtest setfiles with `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Added three scoped `// perf-allowed` comments for ATR ZigZag structural closed-bar reads.

## Validation

- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_10184_tv-atr-zigzag-break` -> PASS
- `pwsh -File framework/scripts/build_check.ps1 -EALabel QM5_10184_tv-atr-zigzag-break` -> PASS
- `pwsh -File framework/scripts/compile_one.ps1 -EALabel QM5_10184_tv-atr-zigzag-break -Strict` -> PASS

## Smoke / CPU Ceiling

One bounded smoke was attempted:

```text
pwsh -File framework/scripts/run_smoke.ps1 -EALabel QM5_10184_tv-atr-zigzag-break -Symbol NDX.DWX -Year 2024 -Terminal any -Period H1 -SetFile C:\QM\repo\framework\EAs\QM5_10184_tv-atr-zigzag-break\sets\QM5_10184_tv-atr-zigzag-break_NDX.DWX_H1_backtest.set -MinTrades 1 -Runs 1 -TimeoutSeconds 1800
```

Result:

```text
run_smoke.result=FAIL
run_smoke.reason_classes=TIMEOUT;METATESTER_HUNG;INCOMPLETE_RUNS;MODEL4_MARKER_REQUIRED
run_smoke.summary=D:\QM\reports\smoke\QM5_10184\20260627_033408\summary.json
```

Per the one-pass build rule, no strategy iteration was done after the smoke timeout. The build result was recorded as a good build with `smoke_result=framework_error`; `farmctl record-build` converted it to deferred P2 smoke handling.

## Farm DB State

- Build task status: `done`
- Build result: `D:\QM\strategy_farm\artifacts\builds\cf4dafbe-0938-4172-b4cf-baf0123601b5.json`
- Q02 work items: 5 pending

```text
EURUSD.DWX pending
GDAXI.DWX pending
NDX.DWX pending
XAUUSD.DWX pending
XTIUSD.DWX pending
```

