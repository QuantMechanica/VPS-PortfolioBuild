# QM5_12873_xng-latewinter-decay-short - Strategy Spec

**EA ID:** QM5_12873
**Slug:** `xng-latewinter-decay-short`
**Source:** `EIA-XNG-SHOULDER-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-02

## 1. Strategy Logic

This EA implements a low-frequency natural-gas late-winter decay short sleeve
on `XNGUSD.DWX`. On the first tradable D1 bar of each broker-calendar week from
Feb 15 through Mar 31, it checks whether the prior completed D1 close is below
the fast SMA, the fast SMA slope is negative in ATR-normalized units, and price
has fallen far enough from the recent winter high. If those conditions hold, it
sells `XNGUSD.DWX` with an ATR hard stop.

The strategy is intentionally not a duplicate of `QM5_12567`: that EA trades
short-horizon cumulative RSI commodity pullbacks, while this one trades a
structural late-winter natural-gas premium-decay rule. It is also distinct from
the April-October monthly injection-season sleeve `QM5_12874`, broad spring
shoulder shorts, freeze fades, Donchian breakdowns, and storage/weather events.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_start_month` | 2 | fixed | Season start month |
| `strategy_start_day` | 15 | 10-20 | Season start day |
| `strategy_end_month` | 3 | fixed | Season end month |
| `strategy_end_day` | 31 | 20-31 | Season end day |
| `strategy_fast_period` | 21 | 14-34 | Fast D1 SMA used for trend and exit recovery |
| `strategy_slope_lookback_days` | 5 | 3-10 | D1 lookback used to measure fast-SMA slope |
| `strategy_winter_high_lookback` | 45 | 30-60 | Completed D1 bars used to define the recent winter high |
| `strategy_min_drawdown_atr` | 1.20 | 0.80-1.80 | Minimum distance from recent high in ATR units |
| `strategy_min_decay_slope_atr` | 0.15 | 0.10-0.25 | Minimum negative fast-SMA slope in ATR units |
| `strategy_atr_period` | 20 | 14-30 | ATR period for slope normalization and hard stop |
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

- Expected trade attempts/year/symbol: about 4-9.
- Typical hold: multi-day, bounded by fast-SMA recovery, slope recovery, season end, Friday close, or 7-day max hold.
- Risk mode for Q02 backtests: `RISK_FIXED`.
- Regime preference: late-winter downside continuation after winter-risk premium begins to decay.

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
| v1 | 2026-07-02 | Initial build from card | Enqueue Q02 |
