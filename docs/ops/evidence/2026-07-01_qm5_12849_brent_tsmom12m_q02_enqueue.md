# QM5_12849 Brent 12M TSMOM Q02 Enqueue

Date: 2026-07-01
Branch: `agents/board-advisor`
Owner: Codex

## Edge Built

- EA: `QM5_12849_brent-tsmom12m`
- Strategy ID: `MOP-TSMOM-2012_BRENT_S01`
- Symbol: `XBRUSD.DWX` D1
- Source lineage: Moskowitz, Ooi, and Pedersen, "Time Series Momentum",
  Journal of Financial Economics, 2012 / AQR article page.
- Runtime data: DWX/MT5 OHLC and broker calendar only.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Non-Duplicate Rationale

The selected sleeve is a single-symbol Brent directional trend package:

`ln(close[t-1] / close[t-1-252])`

It is distinct from the existing commodity/energy builds:

- `QM5_12841_brent-thu-prem`: Brent weekday seasonal, not 12-month momentum.
- `QM5_12843_wti-brent-spread`: Brent/WTI z-score basket reversion.
- `QM5_12848_wti-brent-brk`: Brent/WTI channel-breakout basket.
- `QM5_12603_wti-tsmom12m`, `QM5_12616_tsmom-9m-commodity-xtiusd`,
  `QM5_12844_commodity-trend-crude`, and WTI calendar/event sleeves:
  WTI crude proxy, not Brent.
- `QM5_12804_xng-tsmom12m-atr` and `QM5_12567_cum-rsi2-commodity`:
  natural gas or RSI commodity logic, not Brent.
- Existing XAU/XAG and gas-metal baskets: metal-hedged relative value, not
  pure Brent energy exposure.

## Validation

- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12849_brent-tsmom12m`
  - Result: PASS.
- `python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_12849_brent-tsmom12m --json`
  - Result: `SINGLE_SYMBOL_OK`.
- `python tools/strategy_farm/compile_ea.py --ea-label QM5_12849_brent-tsmom12m --force --json --fail-on-error`
  - Result: COMPILED, 0 errors, 0 warnings.
- `python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_12849_brent-tsmom12m`
  - Result: PASS.
- `powershell -NoProfile -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12849_brent-tsmom12m -Strict -SkipCompile`
  - Result: PASS, 0 failures, 16 existing shared-framework DWX advisory warnings.

## Q02 Queue

- Build artifact: `artifacts/qm5_12849_build_result.json`
- Q02 work item: `7cc296f9-9603-42a5-ba3e-cccbb8df7792`
- Queue DB: `D:\QM\strategy_farm\state\farm_state.sqlite`
- Status at enqueue: pending
- Created UTC: `2026-07-01T06:23:05+00:00`

## Safety

No MT5 live trading, AutoTrading toggle, `T_Live`, deploy manifest, portfolio
gate, portfolio admission, or portfolio KPI file was touched. No manual
backtest was launched from this session; the paced Q02 fleet owns the first MT5
run.
