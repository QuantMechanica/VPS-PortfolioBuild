# QM5_12615 TSMOM 12M Cross-Asset Basket

**EA ID:** QM5_12615

## 1. Strategy Logic

The EA implements the approved Moskowitz, Ooi & Pedersen time-series momentum basket as a single pooled V5 EA. It runs on `EURUSD.DWX` D1 and manages four independent legs through `QM_BasketOrder`: `EURUSD.DWX`, `NDX.DWX`, `XAUUSD.DWX`, and `XTIUSD.DWX`.

On the first D1 bar of each calendar month, each leg computes a 252-D1 close-return sign from closed bars. A positive 12-month return maps to long; a negative 12-month return maps to short. Existing legs are closed and reopened only when direction reverses or when the realized-volatility scalar changes by more than the configured threshold.

## 2. Parameters

- `strategy_lookback_d1_bars=252`
- `strategy_vol_window_d1=63`
- `strategy_target_annual_vol=0.10`
- `strategy_max_vol_scale=2.0`
- `strategy_min_realized_vol=0.005`
- `strategy_atr_period=14`
- `strategy_atr_sl_mult=3.0`
- `strategy_vol_reopen_threshold=0.25`
- `strategy_leg_risk_fraction=0.25`
- `strategy_spread_days=20`
- `strategy_spread_mult=3.0`
- `strategy_max_family_positions=4`

## 3. Symbol Universe

The basket symbols are `EURUSD.DWX`, `NDX.DWX`, `XAUUSD.DWX`, and `XTIUSD.DWX`. The host chart is `EURUSD.DWX`; Q02 uses the logical basket symbol `QM5_12615_TSMOM_XASSET_D1` from `basket_manifest.json` so downstream gates evaluate the pooled sleeve.

The card prose labels slots 1-4, but V5 registry rows are zero-based: slot 0 EURUSD, slot 1 NDX, slot 2 XAUUSD, slot 3 XTIUSD.

## 4. Timeframe

All signal, volatility, stop, and spread reads are on D1. The EA should be attached to the `EURUSD.DWX` D1 host chart with `qm_magic_slot_offset=0`.

## 5. Expected Behaviour

The strategy is low frequency and structurally always active per leg after the first valid rebalance. It should generate roughly monthly basket-level activity, with slot-level trades from direction reversals, stop-outs, and deterministic volatility-resize reopens.

The EA has no ML, martingale, PnL-adaptive sizing, pyramiding, trailing stop, partial close, or discretionary state.

## 6. Source Citation

Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_12615_tsmom-12m-cross-asset-basket.md`.

Source id: `e5a3f925-5a9e-513d-9e70-5c7c70fa0e59`.

Paper: Moskowitz, Ooi & Pedersen (2012), "Time series momentum", Journal of Financial Economics, Section V cross-asset TSMOM portfolio.

## 7. Risk Model

Backtest setfiles use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1.0`. The EA derives a base lot from the framework fixed-risk sizer, multiplies it by `strategy_leg_risk_fraction=0.25`, then multiplies by the per-leg volatility scalar. Each leg uses a hard ATR(14,D1) times 3 stop.
