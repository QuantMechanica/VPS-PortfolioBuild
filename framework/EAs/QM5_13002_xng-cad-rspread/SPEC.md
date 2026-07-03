# QM5_13002_xng-cad-rspread - Strategy Spec

**EA ID:** QM5_13002
**Slug:** `xng-cad-rspread`
**Source:** `EIA-CANADA-GAS-TRADE-2025`
**Author of this spec:** Codex
**Last revised:** 2026-07-03

## 1. Strategy Logic

This EA implements a low-frequency two-leg natural-gas/CAD relative-value basket
on `XNGUSD.DWX` and `USDCAD.DWX`. On each new D1 host bar it computes a rolling
CAD-denominated gas spread:

`spread = ln(XNGUSD.DWX) + beta * ln(USDCAD.DWX)`

The current spread is standardized against its recent D1 history. A high
positive z-score means natural gas is rich versus the CAD channel, so the basket
sells `XNGUSD.DWX` and sells `USDCAD.DWX`. A high negative z-score buys both
legs. The package exits when the z-score reverts toward zero, when max hold
expires, on Friday close, or through per-leg ATR stops.

This is not a duplicate of `QM5_12567_cum-rsi2-commodity`, existing XNG storage,
seasonality, weather, expiry, rig-count, oil/gas, gas/metal, or XTI/CAD sleeves.
It trades a gas/CAD cross-border trade linkage with a two-leg basket and no RSI,
calendar ownership, event-release, futures-curve, or external runtime data.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_z_lookback_d1` | 90 | 60-140 | History length for spread z-score |
| `strategy_beta` | 4.0 | 2.0-8.0 | USDCAD multiplier in the CAD-denominated gas spread |
| `strategy_entry_z` | 2.0 | 1.6-2.4 | Absolute z-score required for entry |
| `strategy_exit_z` | 0.5 | 0.2-0.8 | Mean-reversion exit band |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period for each leg |
| `strategy_atr_sl_mult` | 3.0 | 2.25-4.0 | Per-leg hard stop distance |
| `strategy_max_hold_days` | 45 | 25-60 | Calendar-day stale package exit |
| `strategy_xng_max_spread_pts` | 2500 | 1500-3500 | XNG entry spread cap |
| `strategy_usdcad_max_spread_pts` | 80 | 50-120 | USDCAD entry spread cap |

## 3. Symbol Universe

- Logical basket symbol: `QM5_13002_XNG_CAD_RSPREAD_D1`.
- Host symbol: `XNGUSD.DWX`, magic slot 0.
- Second leg: `USDCAD.DWX`, magic slot 1.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()` on the `XNGUSD.DWX` host chart.

## 5. Expected Behaviour

- Expected package frequency: about 6-14 paired packages/year before Q02 proves
  or rejects the hypothesis.
- Typical hold: several D1 bars to a few weeks.
- Regime preference: temporary dislocations between Henry-Hub-style natural gas
  pricing and the Canada/U.S. gas-trade FX channel.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Energy Information Administration, "Last year's U.S.-Canada energy trade
was valued around $150 billion", Today in Energy, 2025-07-30, updated
2025-08-04, https://www.eia.gov/todayinenergy/detail.php?id=65825.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, AutoTrading setting, portfolio admission file,
or portfolio gate file is touched by this build.
