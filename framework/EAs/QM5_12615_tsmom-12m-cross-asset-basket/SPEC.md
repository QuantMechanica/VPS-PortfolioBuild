# QM5_12615 TSMOM 12M Cross-Asset Basket

## Source

- Card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_12615_tsmom-12m-cross-asset-basket.md`
- Source id: `e5a3f925-5a9e-513d-9e70-5c7c70fa0e59`
- Source basis: Moskowitz, Ooi & Pedersen (2012), "Time series momentum", JFE; Section V cross-asset TSMOM portfolio.

## Contract

- Host chart: `EURUSD.DWX`, `D1`, `qm_magic_slot_offset=0`.
- Basket symbols: `EURUSD.DWX`, `NDX.DWX`, `XAUUSD.DWX`, `XTIUSD.DWX`.
- V5 magic slots are zero-based: slot 0 EURUSD, slot 1 NDX, slot 2 XAUUSD, slot 3 XTIUSD.
- The prose card lists slots 1-4; registry slots remain zero-based to match V5 magic resolver conventions.

## Mechanics

- Rebalance only on the first D1 bar of a new calendar month.
- Direction per symbol: `close[1] > close[1 + strategy_lookback_d1_bars] ? long : short`.
- Volatility scalar per symbol: `(strategy_target_annual_vol / 4) / max(realized_vol_63D, strategy_min_realized_vol)`, capped at `strategy_max_vol_scale`.
- Stop: `ATR(14,D1) * 3.0`.
- Backtest sizing: `RISK_FIXED=1000`, base per-leg risk fraction `0.25`, multiplied by vol scalar.
- Vol-resize exit: close and reopen when the monthly scalar changes by more than `strategy_vol_reopen_threshold`.
- No martingale, ML, PnL-adaptive sizing, pyramiding, trailing, or partial close.

## Files

- `QM5_12615_tsmom-12m-cross-asset-basket.mq5`: EA implementation.
- `basket_manifest.json`: pooled-basket manifest for the phase queue.
- `sets/QM5_12615_tsmom-12m-cross-asset-basket_EURUSD.DWX_D1_backtest.set`: host-chart backtest setfile.
- `docs/strategy_card.md`: approved card copy.
