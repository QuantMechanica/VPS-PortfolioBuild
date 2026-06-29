# QM5_12771 WTI Thursday Premium Q02 Enqueue Evidence

Date: 2026-06-29

## Scope

- EA: `QM5_12771_wti-thu-prem`
- Edge: `XTIUSD.DWX` D1 Thursday calendar-premium sleeve.
- Source lineage: Quayyum, H. A., Khan, M. A. M. and Ali, S. M.,
  "Seasonality in crude oil returns", Soft Computing 24, 7857-7873 (2020),
  DOI https://doi.org/10.1007/s00500-019-04329-0.
- Runtime data: Darwinex MT5 OHLC and broker calendar only.
- Logic: buy the broker-calendar Thursday D1 bar; flatten on the first
  non-Thursday D1 bar or one-calendar-day stale-position guard; ATR hard stop.
- Dedup: not `QM5_12567` RSI commodity pullback, not `QM5_12596` Monday short,
  not `QM5_12610` Tuesday short, not `QM5_12597` Friday premium, and not
  `QM5_12753` conditional Thursday-pullback/Friday-bounce.

## Build Evidence

- Spec validation:
  - command: `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12771_wti-thu-prem`
  - result: PASS.
- Strict compile:
  - command: `framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12771_wti-thu-prem/QM5_12771_wti-thu-prem.mq5 -Strict`
  - result: PASS, 0 errors, 0 warnings.
  - log: `C:/QM/repo/framework/build/compile/20260629_091253/QM5_12771_wti-thu-prem.compile.log`
- EA-local build check:
  - command: `framework/scripts/build_check.ps1 -EALabel QM5_12771_wti-thu-prem -Strict -SkipCompile`
  - result: PASS, 0 failures.
  - warnings: 16 existing shared-framework DWX advisory warnings, no EA-local
    compile warning.
  - report: `D:/QM/reports/framework/21/build_check_20260629_091307.json`
- `.mq5` SHA256: `01b7301ca51a0014ddd6622c85442894c6fc98950cae46503f32345b008cbf5c`
- `.ex5` SHA256: `63f798e8bc263e57ae49bbd626d84a0ffcae993d40607ebb38d2138e2c417555`

## Q02 Queue Evidence

- Build task: `cb8d7d77-d3e5-4175-87b5-195a7dd28142`
- Q02 work item: `87297a1f-289e-4888-9964-0c8061751a20`
- Q02 status after enqueue: `pending`
- Symbol/timeframe: `XTIUSD.DWX` / D1
- Setfile:
  `C:/QM/repo/framework/EAs/QM5_12771_wti-thu-prem/sets/QM5_12771_wti-thu-prem_XTIUSD.DWX_D1_backtest.set`
- Backtest risk settings: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Safety

- No `T_Live` files were edited.
- AutoTrading was not touched.
- Portfolio gate, portfolio manifest, and live deploy artifacts were not
  edited.
- No manual MT5 backtest was launched from this session; Q02 remains queued for
  the paced farm.
