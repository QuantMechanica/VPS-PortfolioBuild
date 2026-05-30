# QM5_1193_qp-stress-usd-rebound SPEC

## Source

Approved Strategy Card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1193_qp-stress-usd-rebound.md`

## Framework Mapping

- Entry: on the first tick of a new D1 bar, read the completed D1 return of `SP500.DWX` and the oil proxy (`XTIUSD.DWX`, fallback `XBRUSD.DWX`). If both are below `strategy_stress_threshold_pct`, open the configured USD rebound leg.
- Legs: short `EURUSD.DWX`, `GBPUSD.DWX`, `AUDUSD.DWX`; long `USDJPY.DWX`, `USDCAD.DWX`.
- Slot mapping: slot 0 `EURUSD.DWX`, slot 1 `GBPUSD.DWX`, slot 2 `AUDUSD.DWX`, slot 3 `USDJPY.DWX`, slot 4 `USDCAD.DWX`.
- Risk: total basket risk is split via `PORTFOLIO_WEIGHT=0.20` per leg. Backtests use `RISK_FIXED=1000`; live templates use `RISK_PERCENT=0.25`.
- Stops: per-leg initial stop is `strategy_atr_sl_mult * ATR(20)` on D1.
- Spread gate: current spread must be no more than `strategy_spread_mult` times the median D1 spread over `strategy_spread_median_days`.
- Basket kill: all active `1193` magic slots are closed if combined floating P/L is less than `-strategy_basket_kill_mult * intended_basket_risk`.
- Exit: close the leg on the next D1 bar; safety exit after `strategy_safety_hold_days`.

## Boundaries

- No external market-data calls.
- No ML, adaptive model, grid, martingale, or web/API dependency.
- `SP500.DWX` is a signal source and remains a T6 live-promotion caveat from the card.
- No backtests or pipeline phases were run during build.
