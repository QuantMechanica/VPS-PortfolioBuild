# QM5_12874_xng-inject-slope-short - Strategy Spec

**EA ID:** QM5_12874
**Slug:** `xng-inject-slope-short`
**Source:** `EIA-XNG-SHOULDER-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-02

## 1. Strategy Logic

This EA implements a low-frequency natural-gas injection-season short sleeve on
`XNGUSD.DWX`. On the first D1 bar of each broker-calendar month from April
through October, it checks whether the prior completed D1 close is below a slow
SMA, the fast SMA is below the slow SMA, and both moving-average slopes point
down. If those conditions hold, it sells `XNGUSD.DWX` with an ATR hard stop.

The strategy is intentionally not a duplicate of `QM5_12567`: that EA trades
short-horizon cumulative RSI commodity pullbacks, while this one trades a
structural monthly injection-season trend-slope rule. It is also distinct from
`QM5_12587`, which uses Donchian breakdowns, and `QM5_12595`, which fades
failed-rally candles.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fast_period` | 21 | 14-34 | Fast D1 SMA used for alignment and exit recovery |
| `strategy_slow_period` | 63 | 42-84 | Slow D1 SMA used for trend confirmation |
| `strategy_slope_lookback_days` | 10 | 5-15 | D1 lookback used to measure SMA slope |
| `strategy_min_fast_slope_atr` | 0.20 | 0.10-0.35 | Minimum negative fast-SMA slope in ATR units |
| `strategy_atr_period` | 20 | 14-30 | ATR period for slope normalization and hard stop |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | ATR hard-stop distance multiplier |
| `strategy_max_hold_days` | 28 | 18-40 | Stale-position time exit |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Bar gating: `QM_IsNewBar()`.
- Multi-timeframe references: none.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 3-7.
- Typical hold: multi-day to multi-week, bounded by fast-SMA recovery, slope recovery, season end, Friday close, or 28-day max hold.
- Risk mode for Q02 backtests: `RISK_FIXED`.
- Regime preference: persistent downside pressure during the natural-gas injection season.

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
