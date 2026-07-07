# QM5_13026 XTI Import-Flow Fade Q02 Enqueue

## Scope

- Built new commodity/energy sleeve: `QM5_13026_xti-import-flow-fade`.
- Edge: `XTIUSD.DWX` D1 monthly crude-import information-cycle absorption
  fade, symmetric long/short.
- Source lineage: official EIA U.S. crude-oil import data series, EIA
  Petroleum & Other Liquids data page, and EIA Weekly Petroleum Status Report
  import/export table lineage.
- Runtime data: broker D1 OHLC/spread, ATR, SMA, and broker calendar only.

## Non-Duplicate Rationale

This is not an XAU/XAG ratio sleeve and not a second `QM5_12567` commodity RSI
variant. It is also distinct from existing XTI weekly WPSR inventory,
export-flow breakout, PSM momentum, STEO, OPEC/IEA/MOMR, DPR, SPR, Cushing,
refinery, hurricane, rig-count, roll, expiry, weekday, weekend, month-of-year,
month-open ORB, turn-of-month, XTI/XNG, WTI/Brent, oil/gold, and oil/silver
sleeves.

The rule uses a first-business-days monthly import-flow proxy and fades only
ATR/SMA stretches that have not confirmed a prior-channel breakout.

## Build Evidence

- Card schema lint: PASS.
- SPEC validator: PASS.
- Symbol scope validator: `SINGLE_SYMBOL_OK`.
- Strict compile: PASS, 0 errors, 0 warnings.
- Strict build check: PASS, 0 failures.
- Build-check report: `D:/QM/reports/framework/21/build_check_20260707_041225.json`.
- Compile log: `C:/QM/repo/framework/build/compile/20260707_041225/QM5_13026_xti-import-flow-fade.compile.log`.
- Compiled EX5: `C:/QM/repo/framework/EAs/QM5_13026_xti-import-flow-fade/QM5_13026_xti-import-flow-fade.ex5`.
- Setfile build hash:
  `ab54e8e15e7bbf1efe30cbf3e6f52ea5c7349fd480e4954fdafc8e8d3c5f1005`.
- Shared-framework advisory warnings: 14 existing DWX advisory warnings in
  `framework/include/QM/*`; no new EA compile warnings.

## Q02 Queue Evidence

- Command:
  `python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_13026 --queue-ceiling 10000 --max-part2-per-run 0`
- Result: enqueued 1, skipped 0.
- Work item:
  `017936f0-cf78-4680-b22e-c6dda816b0be`.
- Phase/status: `Q02` / `pending`.
- Symbol/setfile:
  `XTIUSD.DWX` /
  `QM5_13026_xti-import-flow-fade_XTIUSD.DWX_D1_backtest.set`.
- Canonical sweep evidence:
  `D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`.

No manual MT5 backtest was launched in this step.

## Constraints

- Backtest setfile uses `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- No `T_Live` manifest changed.
- No portfolio gate changed.
- No AutoTrading action taken.
