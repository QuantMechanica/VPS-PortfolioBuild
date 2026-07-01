# QM5_12840 XTI/XNG Return-Spread Reversion Q02 Enqueue

Date: 2026-07-01
Branch: `agents/board-advisor`
Owner: Codex

## Edge Built

- EA: `QM5_12840_xti-xng-rspread`
- Strategy ID: `SRC05_S01_XTI_XNG_RSPREAD_2026`
- Logical basket: `QM5_12840_XTI_XNG_RSPREAD_D1`
- Host: `XTIUSD.DWX` D1
- Basket legs: `XTIUSD.DWX`, `XNGUSD.DWX`
- Source lineage: `SRC05`, Chan pair-spread Bollinger-style mean reversion,
  adapted to a deterministic D1 XTI/XNG return-spread z-score.
- Runtime data: DWX/MT5 OHLC only.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Non-Duplicate Rationale

The selected sleeve is a D1 return-spread reversion basket:

`log(XTI[t] / XTI[t-L]) - beta * log(XNG[t] / XNG[t-L])`

It is distinct from the existing XTI/XNG and commodity builds:

- `QM5_12578_eia-oilgas-ratio`: price-level log-ratio z-score reversion.
- `QM5_12608_eia-oilgas-breakout`: price-level ratio breakout.
- `QM5_12733_xti-xng-xmom`: monthly cross-sectional momentum.
- `QM5_12813_eia-energy-switch`: fixed seasonal energy switch.
- `QM5_12567_cum-rsi2-commodity`: commodity RSI pullback.
- Existing XAU/XAG baskets: metal exposure, not energy return spread.

## Validation

- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12840_xti-xng-rspread`
  - Result: PASS.
- `python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_12840_xti-xng-rspread --json`
  - Result: `BASKET_OK`.
- `python tools/strategy_farm/compile_ea.py --ea-label QM5_12840_xti-xng-rspread --force --json --fail-on-error`
  - Result: COMPILED, 0 errors, 0 warnings.
- `python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_12840_xti-xng-rspread`
  - Result: PASS.
- `powershell -NoProfile -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12840_xti-xng-rspread -Strict -SkipCompile`
  - Result: PASS, 0 failures, 16 existing shared-framework DWX advisory warnings.

## Q02 Queue

- Build task: `93d7ffa1-bd90-4948-9d5a-6ac65ad9c7e0`
- Build artifact: `artifacts/qm5_12840_build_result.json`
- Q02 work item: `bc623b84-ba53-4e54-964d-96932497bbd0`
- Queue DB: `D:\QM\strategy_farm\state\farm_state.sqlite`
- Status at enqueue: pending
- Created UTC: `2026-07-01T00:43:28+00:00`

## Safety

No MT5 live trading, AutoTrading toggle, `T_Live`, deploy manifest, portfolio
gate, portfolio admission, or portfolio KPI file was touched. No manual
backtest was launched from this session; the paced Q02 fleet owns the first MT5
run.
