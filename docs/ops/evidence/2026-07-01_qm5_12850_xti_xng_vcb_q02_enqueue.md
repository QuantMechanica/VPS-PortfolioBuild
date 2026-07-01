# QM5_12850 XTI/XNG Ratio VCB Q02 Enqueue

Date: 2026-07-01
Branch: `agents/board-advisor`
Owner: Codex

## Edge Built

- EA: `QM5_12850_xti-xng-vcb`
- Strategy ID: `BOLLINGER-BB-SQUEEZE-2001_XTI_XNG_VCB`
- Logical basket: `QM5_12850_XTI_XNG_VCB_D1`
- Host: `XTIUSD.DWX` D1
- Basket legs: `XTIUSD.DWX`, `XNGUSD.DWX`
- Source lineage: `BOLLINGER-BB-SQUEEZE-2001`, Bollinger BandWidth
  volatility-contraction breakout.
- Runtime data: DWX/MT5 OHLC only.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Non-Duplicate Rationale

The selected sleeve is a D1 market-neutral energy ratio breakout:

`ln(XTIUSD) - beta * ln(XNGUSD)`

It trades only after low Bollinger BandWidth rank on the ratio and a completed
D1 close outside the ratio Bollinger envelope. It is distinct from:

- `QM5_12578_eia-oilgas-ratio`: price-level log-ratio z-score reversion.
- `QM5_12608_eia-oilgas-breakout`: raw price-level ratio channel breakout.
- `QM5_12733_xti-xng-xmom`: monthly cross-sectional momentum.
- `QM5_12813_eia-energy-switch`: fixed seasonal switch.
- `QM5_12840_xti-xng-rspread`: return-spread mean reversion.
- `QM5_12811_xti-vcb`: WTI-only squeeze breakout.
- `QM5_12567_cum-rsi2-commodity`: commodity RSI pullback.
- Existing XAU/XAG and gas-metal baskets: metal-hedged exposure, not pure
  XTI/XNG energy ratio compression breakout.

## Validation

- `powershell -NoProfile -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12850_xti-xng-vcb/QM5_12850_xti-xng-vcb.mq5 -Strict`
  - Result: PASS, 0 errors, 0 warnings.
- `powershell -NoProfile -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12850_xti-xng-vcb -Strict`
  - Result: PASS, 0 failures, 16 existing shared-framework DWX advisory warnings.
- Setfile hash: `918de8a7b9959ae2cc5c43d02db25f6b83d271025c492c92f37a929124f4feaf`.
- EX5: `framework/EAs/QM5_12850_xti-xng-vcb/QM5_12850_xti-xng-vcb.ex5`.

## Q02 Queue

- Build artifact: `artifacts/qm5_12850_build_result.json`
- Q02 work item: `8e5ef3eb-76d6-4812-aa62-b23f086114b3`
- Queue DB: `D:\QM\strategy_farm\state\farm_state.sqlite`
- Status at enqueue: pending
- Created UTC: `2026-07-01T08:28:19+00:00`
- Queue method: `record_build_result.auto_q02` basket-manifest path.

## Safety

No MT5 live trading, AutoTrading toggle, `T_Live`, deploy manifest, portfolio
gate, portfolio admission, or portfolio KPI file was touched. No manual
backtest was launched from this session; the paced Q02 fleet owns the first MT5
run.
