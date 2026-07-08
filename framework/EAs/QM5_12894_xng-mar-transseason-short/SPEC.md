# QM5_12894_xng-mar-transseason-short - Strategy Spec

**EA ID:** QM5_12894
**Slug:** `xng-mar-transseason-short`
**Source:** `EIA-XNG-SHOULDER-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-08

## 1. Strategy Logic

This EA implements a low-frequency natural-gas March-to-mid-April shoulder
transition short sleeve on `XNGUSD.DWX`. On the first tradable D1 bar of each
broker-calendar week from Mar 1 through Apr 15, it checks whether the prior
completed D1 bar confirms a failed transition rebound: price is below a medium
SMA, has drifted lower over the last few completed bars, and closes in the
lower portion of the bar after a brief rebound.

The strategy is intentionally not a duplicate of `QM5_12567`: that EA trades
short-horizon cumulative RSI commodity pullbacks, while this one trades an
EIA-sourced natural-gas shoulder-transition calendar structure using only OHLC,
SMA, ATR, and broker-calendar gates. It is also distinct from `QM5_12873`,
which uses Feb 15-Mar 31 winter-high decay and fast-SMA slope, and from broad
spring shoulder failed-rally/wick fades.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_start_month` | 3 | fixed | Season start month |
| `strategy_start_day` | 1 | fixed | Season start day |
| `strategy_end_month` | 4 | fixed | Season end month |
| `strategy_end_day` | 15 | 10-20 | Season end day |
| `strategy_sma_period` | 34 | 21-55 | Medium D1 SMA used for trend and exit recovery |
| `strategy_rebound_lookback` | 4 | 3-6 | Completed D1 bars used to identify a transition rebound |
| `strategy_drift_lookback` | 3 | 2-5 | Completed D1 bars used to measure downside drift |
| `strategy_min_rebound_atr` | 0.35 | 0.20-0.60 | Minimum rebound from the lookback base in ATR units |
| `strategy_min_down_drift_atr` | 0.55 | 0.35-0.90 | Minimum multi-day downside drift in ATR units |
| `strategy_min_sma_stretch_atr` | 0.10 | 0.00-0.30 | Minimum close below SMA in ATR units |
| `strategy_max_close_location` | 0.42 | 0.30-0.50 | Maximum signal-bar close location for short entry |
| `strategy_atr_period` | 20 | 14-30 | ATR period for signal normalization and hard stop |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | ATR hard-stop distance multiplier |
| `strategy_max_hold_days` | 7 | 5-10 | Stale-position time exit |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Bar gating: `QM_IsNewBar()`.
- Multi-timeframe references: none.

## 5. Expected Behaviour

- Expected trade attempts/year/symbol: about 5-8.
- Typical hold: multi-day, bounded by SMA recovery, season end, Friday close, or 7-day max hold.
- Risk mode for Q02 backtests: `RISK_FIXED`.
- Regime preference: March-to-mid-April lower-demand transition after a short rebound fails.

## 6. Source Citation

U.S. Energy Information Administration, "Natural gas consumption, production
respond to seasonal changes", Today in Energy, 2015-09-24.
URL: https://www.eia.gov/todayinenergy/detail.php?id=22892.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, portfolio admission file, or
AutoTrading setting is touched by this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-08 | Initial build from mission-directed card | Enqueue Q02 |
