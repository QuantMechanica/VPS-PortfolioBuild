# QM5_12733 XTI/XNG XMOM Q02 Enqueue - 2026-06-28

Scope: branch `agents/board-advisor`; no `T_Live`, deploy manifest, portfolio gate, or AutoTrading changes.

## Built

- `QM5_12733_xti-xng-xmom`
  - Edge: `XTIUSD.DWX` / `XNGUSD.DWX` D1 market-neutral energy relative momentum basket.
  - Source lineage: approved SRC05_S10 Chan/Daniel-Moskowitz cross-sectional commodity momentum card.
  - Runtime data: Darwinex MT5 OHLC and broker calendar only; no EIA feed, inventory feed, CFTC data, futures curve, CSV, API, ML, grid, or martingale.
  - Logic: monthly rank XTI and XNG by prior 126D log return; buy the stronger energy leg and short the weaker leg; flatten on next monthly rebalance, max-hold, Friday close, broken package, or ATR hard stop.
  - Dedup: not `QM5_12578` XTI/XNG z-score reversion, not `QM5_12608` XTI/XNG channel breakout, not WTI seasonality/news, not single-symbol WTI TSMOM, and not `QM5_12567` XNG RSI commodity pullback.
  - Risk: RISK_FIXED backtest setfile, `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Validation

- ID registry: `12733,xti-xng-xmom,SRC05_S10_XTI_XNG_XMOM_2026,active,Development,2026-06-28`.
- Magic registry:
  - `12733,xti-xng-xmom,0,XTIUSD.DWX,127330000,2026-06-28,Development,active`.
  - `12733,xti-xng-xmom,1,XNGUSD.DWX,127330001,2026-06-28,Development,active`.
- Logical basket symbol: `QM5_12733_XTI_XNG_XMOM_D1`.
- Setfile build hash: `2a6e5a36b35179d897be960de348a261a7f5761f90ba86ded58781934f3fa784`.
- Strict compile:
  - command: `framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12733_xti-xng-xmom/QM5_12733_xti-xng-xmom.mq5 -Strict`
  - result: PASS
  - errors: 0
  - warnings: 0
  - log: `C:/QM/repo/framework/build/compile/20260628_035251/QM5_12733_xti-xng-xmom.compile.log`
- EA-local build check:
  - command: `framework/scripts/build_check.ps1 -EALabel QM5_12733_xti-xng-xmom -RepoRoot C:/QM/repo -SkipCompile`
  - result: PASS
  - failures: 0
  - warnings: 16 existing shared-framework DWX advisory warnings, no EA-local failure.
  - report: `D:/QM/reports/framework/21/build_check_20260628_035327.json`

## Farm Queue

- Build result artifact: `artifacts/qm5_12733_build_result.json`
- Q02 work item: `099e941f-b16d-4f51-a594-ae4365c0a2ff`
- Symbol/timeframe: `QM5_12733_XTI_XNG_XMOM_D1` D1
- Host symbol/timeframe: `XTIUSD.DWX` D1
- Setfile: `framework/EAs/QM5_12733_xti-xng-xmom/sets/QM5_12733_xti-xng-xmom_QM5_12733_XTI_XNG_XMOM_D1_D1_backtest.set`
- Status after enqueue check: `pending`.

## Notes

- Full backtest results were not read or acted on in this build turn.
- The paced farm owns Q02 dispatch; no manual MT5 run was launched.
