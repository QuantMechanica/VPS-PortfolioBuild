# QM5_13025 XTI PSM Momentum Q02 Enqueue

## Scope

- Built new commodity/energy sleeve: `QM5_13025_xti-psm-mom`.
- Edge: `XTIUSD.DWX` D1 month-end EIA Petroleum Supply Monthly proxy
  momentum, symmetric long/short.
- Source lineage: official EIA Petroleum Supply Monthly and EIA petroleum data
  release pages.
- Runtime data: broker D1 OHLC/spread, ATR, SMA, and calendar day only.

## Non-Duplicate Rationale

This is not an XAU/XAG ratio sleeve and not a second `QM5_12567` commodity RSI
variant. It is distinct from existing XTI weekly inventory, DPR, STEO, OPEC,
IEA, MOMR, Cushing, refinery, hurricane, rig-count, roll, expiry, weekday,
weekend, month-of-year, carry, XTI/XNG, oil/gold, and oil/silver sleeves.

## Build Evidence

- Card schema lint: PASS.
- SPEC validator: PASS.
- Symbol scope validator: `SINGLE_SYMBOL_OK`.
- Build guardrails: PASS.
- Strict compile: PASS, 0 errors, 0 warnings.
- Strict build check: PASS, 0 failures.
- Build-check report: `D:/QM/reports/framework/21/build_check_20260707_021212.json`.
- Compile log: `C:/QM/repo/framework/build/compile/20260707_021200/QM5_13025_xti-psm-mom.compile.log`.
- Setfile build hash:
  `69a5027c57570019a8f5b171020f6dd75206721541c957a491b5398d1cfff96e`.

## Q02 Queue Evidence

- Command:
  `python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_13025 --queue-ceiling 10000 --max-part2-per-run 0`
- Result: enqueued 1, skipped 0.
- Work item:
  `a267ffe9-4f4f-4e84-a93d-7697e578ed42`.
- Phase/status: `Q02` / `pending`.
- Symbol/setfile:
  `XTIUSD.DWX` /
  `QM5_13025_xti-psm-mom_XTIUSD.DWX_D1_backtest.set`.
- Canonical sweep evidence:
  `D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`.

## Constraints

- Backtest setfile uses `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- No `T_Live` manifest changed.
- No portfolio gate changed.
- No AutoTrading action taken.
