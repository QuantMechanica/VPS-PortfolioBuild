# QM5_13096_xti-nr7-brk - Strategy Spec

**EA ID:** QM5_13096
**Slug:** `xti-nr7-brk`
**Source:** `CRABEL-WTI-NR7-BRK-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-09

## 1. Strategy Logic

This EA implements a low-frequency structural WTI NR7 breakout on
`XTIUSD.DWX` D1. It waits for a completed D1 setup bar whose range is the
narrowest of the last seven completed D1 bars. The following completed D1 bar
must close beyond that NR7 bar in the direction of the broader SMA trend before
the EA opens a market position on the next D1 bar.

Runtime remains Darwinex-native: closed D1 OHLC, spread, ATR, SMA, broker
calendar, and V5 framework state only.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_nr_lookback` | 7 | 5-9 | Narrow-range lookback in completed D1 bars |
| `strategy_confirmation_min_dow` | 2 | 1-2 | First allowed confirmation day of week |
| `strategy_confirmation_max_dow` | 4 | 3-4 | Last allowed confirmation day of week |
| `strategy_atr_period` | 20 | 14-30 | ATR period for filters and stops |
| `strategy_trend_period` | 60 | 40-90 | SMA trend reference period |
| `strategy_slope_lag_days` | 5 | 3-10 | SMA slope comparison lag |
| `strategy_min_nr_range_atr` | 0.20 | 0.15-0.30 | Minimum NR7 range in ATR units |
| `strategy_max_nr_range_atr` | 1.20 | 0.90-1.60 | Maximum NR7 range in ATR units |
| `strategy_break_buffer_atr` | 0.10 | 0.05-0.18 | ATR buffer beyond NR7 high/low |
| `strategy_min_break_close_location` | 0.62 | 0.58-0.70 | Confirmation close-location threshold |
| `strategy_atr_sl_mult` | 2.40 | 1.80-3.00 | ATR hard-stop distance |
| `strategy_atr_tp_mult` | 3.00 | 2.20-3.80 | ATR target distance |
| `strategy_max_hold_days` | 12 | 7-18 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 8-20.
- Direction: symmetric long/short.
- Typical hold: several D1 bars, capped by ATR target, ATR stop, SMA trend
  failure, twelve-day time exit, or Friday close.
- Regime preference: WTI daily volatility contraction followed by trend-aligned
  range expansion.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Crabel, Toby. *Day Trading with Short-Term Price Patterns and Opening Range
Breakout*. Traders Press, 1990.

The source is used for structural lineage only. No external data feed, futures
curve, inventory feed, volume feed, open-interest feed, or API is used at
runtime.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Evidence

- Build result: `artifacts/qm5_13096_build_result.json`.
- Q02 enqueue: `artifacts/qm5_13096_q02_enqueue_20260709.json`.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-09 | Mission-directed WTI NR7 compression breakout build | Enqueue to Q02 |
