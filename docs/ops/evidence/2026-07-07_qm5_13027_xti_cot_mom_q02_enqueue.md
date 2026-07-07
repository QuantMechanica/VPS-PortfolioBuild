# QM5_13027 XTI COT Momentum Q02 Enqueue

## Scope

- Built new commodity/energy sleeve: `QM5_13027_xti-cot-mom`.
- Edge: `XTIUSD.DWX` D1 CFTC Commitments of Traders Friday release-cadence
  positioning momentum.
- Source lineage: official CFTC Commitments of Traders page and official COT
  release schedule, with CME COT context as supplement.
- Runtime data: broker D1 OHLC/spread, ATR, SMA, Donchian channel, and broker
  calendar only.

## Non-Duplicate Rationale

This is not the existing `QM5_13004_xti-cot-fade`: `QM5_13004` fades stretched
Friday COT-window extremes, while `QM5_13027` follows only trend-confirmed
Donchian breakouts in the Friday COT-window displacement direction.

It is also not an XAU/XAG ratio sleeve, not `QM5_12567` RSI commodity logic,
and not WPSR, import/export, PSM, DPR, STEO, SPR, Cushing, refinery,
hurricane, OPEC/IEA/MOMR, roll/expiry, rig-count, WTI/Brent, XTI/XNG,
oil/gold, oil/silver, weekday, or month-seasonality logic.

## Build Evidence

- Card schema lint: PASS.
- SPEC validator: PASS.
- Strict compile: PASS, 0 errors, 0 warnings.
- Direct build check: PASS, 0 failures, 0 warnings.
- Build-check report: `D:/QM/reports/framework/21/build_check_20260707_054226.json`.
- Compile log: `C:/QM/repo/framework/build/compile/20260707_054151/QM5_13027_xti-cot-mom.compile.log`.
- Compiled EX5: `C:/QM/repo/framework/EAs/QM5_13027_xti-cot-mom/QM5_13027_xti-cot-mom.ex5`.
- Setfile build hash:
  `1fd6fae40680c1384e00f17c26ed7ca76a99ad49f652671134c17de8982644de`.

## Q02 Queue Evidence

- Command:
  `python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_13027 --queue-ceiling 10000 --max-part2-per-run 0`
- Result: enqueued 1, skipped 0.
- Work item:
  `5edccdf5-a119-4944-b4c7-f7324feada5e`.
- Phase/status: `Q02` / `pending`.
- Symbol/setfile:
  `XTIUSD.DWX` /
  `QM5_13027_xti-cot-mom_XTIUSD.DWX_D1_backtest.set`.
- Canonical sweep evidence:
  `D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`.

No manual MT5 backtest was launched in this step.

## Constraints

- Backtest setfile uses `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- No `T_Live` manifest changed.
- No portfolio gate changed.
- No AutoTrading action taken.
