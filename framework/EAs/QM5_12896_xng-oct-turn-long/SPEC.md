# QM5_12896_xng-oct-turn-long - Strategy Spec

**EA ID:** QM5_12896
**Slug:** `xng-oct-turn-long`
**Source:** `706222b7-2d60-5fdb-8dab-d722d3c96f92`
**Author of this spec:** Codex
**Last revised:** 2026-07-02

## 1. Strategy Logic

This EA implements a low-frequency natural-gas seasonal transition sleeve on
`XNGUSD.DWX`. On the first D1 bar of each broker-calendar week in October or
November, it buys only if the prior completed close is above fast and slow
SMAs, the fast SMA is above the slow SMA, and the prior 10-D1 return confirms
an upside turn.

The strategy is intentionally not a duplicate of `QM5_12567`: that EA trades
short-horizon cumulative RSI2 pullbacks, while this one trades a calendar
transition into winter heating-demand conditions with SMA and return-turn
confirmation.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_turn_lookback_days` | 10 | 5-15 | Completed D1 return lookback for turn confirmation |
| `strategy_min_turn_return_pct` | 3.0 | 2-5 | Minimum positive turn return |
| `strategy_fast_sma_period` | 20 | 14-30 | Fast trend confirmation |
| `strategy_slow_sma_period` | 60 | 42-84 | Slow trend confirmation |
| `strategy_atr_period` | 20 | 14-30 | ATR period for stop calculations |
| `strategy_atr_sl_mult` | 3.0 | 2.5-3.5 | ATR hard-stop distance |
| `strategy_max_hold_days` | 6 | 5-10 | Stale-position time exit |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4-8.
- Typical hold: one broker week, bounded by SMA failure or six-day max hold.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Energy Information Administration. "Natural gas use features two seasonal
peaks per year." Today in Energy, 2015-09-11.
URL: https://www.eia.gov/todayinenergy/detail.php?id=22892.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-02 | Initial build from card | Enqueue Q02 |
