# QM5_11904 diverse FX build and Q02 enqueue — 2026-08-10

## Scope

- Branch: `agents/board-advisor`
- Agent-router claim: `86a72f6f-fcc0-44b2-816c-f4f2956388df`
- Standard build task: `1c4e69ce-eb0d-44da-b15e-30d31698d5e8`
- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_11904_grimes-sperandeo-failure-test-2b-h1.md`
- Source lineage: Adam Grimes, *The Art and Science of Trading — Course Workbook*, Module 6; Victor Sperandeo, *Trader Vic: Methods of a Wall Street Master* (Wiley, 1991); Wyckoff spring/upthrust antecedent.

The build implements one structural, low-frequency H1 failure-test edge. A strict five-bars-per-side pivot is breached by at least three pips but no more than 1.5 ATR, then the closed signal bar must finish back inside the pivot. The stop is placed beyond the failure bar with a two-pip buffer; the target is the nearer of the prior counter-swing and 2R, with a 48-bar time exit. No ML, adaptive PnL logic, banned indicator, external feed, or discretionary scoring is present.

## Diversity and registrations

The full approved ten-symbol FX basket is registered and has one H1 backtest setfile per symbol:

`EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCAD.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`, `NZDUSD.DWX`, `EURJPY.DWX`, `GBPJPY.DWX`, `AUDJPY.DWX`.

Magic slots `0..9` map to `119040000..119040009`. The pre-existing active EA-ID row for `11904,grimes-sperandeo-failure-test-2b-h1` was retained. Every setfile declares `RISK_FIXED=1000` and `RISK_PERCENT=0` for backtest use.

## Build evidence

- SPEC validation: `PASS` (1 PASS, 0 FAIL).
- Final compile: `PASS`, 0 errors, 0 warnings.
- Final build check: `PASS`, 0 failures, 0 warnings.
- Compile summary: `D:\QM\reports\compile\20260810_160404\summary.csv`
- Compile log: `C:\QM\repo\framework\build\compile\20260810_160404\QM5_11904_grimes-sperandeo-failure-test-2b-h1.compile.log`
- Build-check report: `D:\QM\reports\framework\21\build_check_20260810_160404.json`
- MQ5 SHA-256: `1748EB75D9A9033A117AD1105F245A2A8D44887231F302FCF99B152C8ED5E7C4`
- EX5 SHA-256: `07A0B77E270BC966BC12FC0E7D26BC84104026BD1F4B6F638FC2DFBD06CA4C29`
- Build-result SHA-256: `B05BB819B7BD3145F8099E44B06CD9D1C441882C7DE1BB1DC0657A822671D467`
- Build result: `D:\QM\strategy_farm\artifacts\builds\1c4e69ce-eb0d-44da-b15e-30d31698d5e8.json`

## Smoke admission and Q02 handoff

The direct build smoke did not enter MT5. The `any` dispatcher first selected busy T10, and the custom-history isolation gate refused admission. An unchanged explicit-T1 admission check was also refused because active isolation permits only a worker-bound work item whose archives were privatized. No strategy result was fabricated and no third attempt was made.

`farmctl record-build` applied the standard clean-build infrastructure fallback: `smoke_result=deferred_p2_smoke`, `needs_p2_smoke_via_pump=true`, build task status `done`. It atomically created the priority-track Q02 stage-1 wave:

| Symbol | Q02 work item | State at enqueue |
|---|---|---|
| EURUSD.DWX | `c694d745-ae4c-4b45-b919-e44dbdbfc6bd` | pending |
| GBPUSD.DWX | `58ef9f09-0406-4677-a04e-f3f7ea52005f` | pending |
| USDJPY.DWX | `38c08150-b157-4de3-bba1-3e73e4a0e661` | pending |

The remaining seven setfiles are durably recorded in `D:\QM\strategy_farm\state\q02_deferred_symbols.json` for promotion after a stage-1 PASS or spare queue capacity. The cohort size recorded on each stage-1 row is 10.

Governed terminal usage was 4 before the admission attempt and 6 after enqueue, below the ceiling of 7. No additional tester was launched after that observation.

## Safety boundary

No T_Live file, AutoTrading setting, portfolio gate, deployment manifest, or live-trading state was readied or changed. Work was limited to the EA, its documentation/setfiles, deterministic magic registration/resolver, farm build result, and Q02 queue records.
