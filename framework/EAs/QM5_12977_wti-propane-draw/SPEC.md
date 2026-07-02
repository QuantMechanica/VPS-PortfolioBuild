# QM5_12977_wti-propane-draw - Strategy Spec

**EA ID:** QM5_12977
**Slug:** `wti-propane-draw`
**Source:** `EIA-PROPANE-DRAW-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-03

## 1. Strategy Logic

This EA implements a low-frequency WTI propane heating-season draw
displacement-continuation sleeve on `XTIUSD.DWX` D1. It trades only in the
October-March heating-season draw window described by the EIA propane source
packet. A long entry requires price above a rising SMA trend plus an
ATR-normalized upside close-to-close displacement, positive body displacement,
and an upper-range close on the prior completed D1 bar.

This is not a duplicate of `QM5_12583_eia-distillate-winter`, which is a
winter distillate Donchian breakout, or `QM5_12963_wti-winter-exhaust`, which
is a short heating-oil exhaustion fade. It is also separate from the May-July
refinery ramp and squeeze sleeves.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_start_month` | 10 | fixed | Draw-window start month |
| `strategy_start_day` | 1 | fixed | Draw-window start day |
| `strategy_end_month` | 3 | fixed | Draw-window end month |
| `strategy_end_day` | 31 | 15-31 | Draw-window end day |
| `strategy_trend_period` | 55 | 34-84 | D1 SMA trend period |
| `strategy_sma_slope_shift` | 5 | 3-10 | Bars back for SMA slope |
| `strategy_exit_channel` | 6 | 4-10 | Channel failure exit low |
| `strategy_atr_period` | 20 | 14-30 | ATR normalization and stop period |
| `strategy_min_return_atr` | 0.45 | 0.35-0.60 | Minimum close-to-close displacement |
| `strategy_min_body_atr` | 0.20 | 0.10-0.35 | Minimum positive real-body displacement |
| `strategy_min_close_location` | 0.70 | 0.60-0.80 | Minimum close location inside signal range |
| `strategy_atr_sl_mult` | 2.75 | 2.25-3.50 | Hard stop ATR multiple |
| `strategy_max_hold_days` | 10 | 6-15 | Calendar-day stale exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | XTI spread cap |

## 3. Symbol Universe

- Symbol: `XTIUSD.DWX`, magic slot 0.
- Logical symbol: `QM5_12977_XTI_PROPANE_DRAW_D1`.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()` on the `XTIUSD.DWX` host chart.

## 5. Expected Behaviour

- Expected frequency: about 6-12 trades/year before Q02 proves or rejects the
  hypothesis.
- Typical hold: several D1 bars to roughly two weeks.
- Regime preference: upside displacement during the propane heating-season
  draw window.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Energy Information Administration, "Prices for hydrocarbon gas liquids:
propane", URL
https://www.eia.gov/energyexplained/hydrocarbon-gas-liquids/prices-for-hydrocarbon-gas-liquids-propane.php.

U.S. Energy Information Administration, "Heating Oil and Propane Update", URL
https://www.eia.gov/petroleum/heatingoilpropane/.

The source is used for structural lineage only. The EA uses Darwinex OHLC and
broker calendar data only. No propane price, propane inventory, weather,
futures curve, product spread, CSV, API, or source performance claim is
imported.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, AutoTrading setting, portfolio admission file,
or portfolio gate file is touched by this build.
