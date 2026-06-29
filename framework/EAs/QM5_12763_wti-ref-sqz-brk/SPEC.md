# QM5_12763_wti-ref-sqz-brk - Strategy Spec

**EA ID:** QM5_12763
**Slug:** `wti-ref-sqz-brk`
**Source:** `EIA-WTI-REFINERY-MAINT-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-29

## 1. Strategy Logic

This EA implements a low-frequency structural WTI sleeve on `XTIUSD.DWX`.
It uses EIA refinery outage and utilization research only as structural
lineage for the pre-summer refinery-utilization ramp. On each D1 bar it checks
whether the prior completed bar falls in May-July, whether D1 volatility has
compressed, whether the slow trend is rising, and whether price closed through
a prior D1 range high. If all gates pass it opens one long position.

This is not a duplicate of `QM5_12593_eia-wti-ref-fade`, which fades stretch
rejection bars during refinery shoulder windows. It is also not the gasoline
driving-season channel breakout in `QM5_12737`, because this EA requires ATR
compression and a rising trend gate in a narrower refinery-ramp window.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_start_month` | 5 | fixed | Ramp-window start month |
| `strategy_start_day` | 1 | 1-15 | Ramp-window start day |
| `strategy_end_month` | 7 | fixed | Ramp-window end month |
| `strategy_end_day` | 31 | 15-31 | Ramp-window end day |
| `strategy_trend_period` | 84 | 63-150 | Slow D1 SMA trend gate and exit |
| `strategy_sma_slope_shift` | 10 | 5-15 | Bars back for SMA slope comparison |
| `strategy_entry_channel` | 25 | 15-35 | Closed-bar high breakout lookback |
| `strategy_exit_channel` | 12 | 8-18 | Closed-bar low failure exit lookback |
| `strategy_atr_fast_period` | 10 | 7-14 | Fast ATR for compression ratio |
| `strategy_atr_slow_period` | 30 | 20-40 | Slow ATR for compression and stop |
| `strategy_compression_ratio` | 0.80 | 0.70-0.90 | Max fast/slow ATR ratio |
| `strategy_atr_sl_mult` | 3.00 | 2.0-4.0 | ATR hard-stop multiplier |
| `strategy_max_hold_days` | 18 | 10-28 | Calendar-day time exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: entry checks use prior completed D1 bars and `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4-8.
- Typical hold: several D1 bars to about three weeks, segmented by Friday close.
- Regime preference: pre-summer refinery-utilization ramp after volatility
  compression and rising slow trend.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Refinery outages: planned and
unplanned outages, 2007-2011", URL
https://www.eia.gov/petroleum/articles/refoutagesindex.php. Supplemental EIA
source: "U.S. refinery utilization rates slightly higher than last year heading
into summer", URL https://www.eia.gov/todayinenergy/detail.php?id=61543.
Sources are used only for structural lineage; the EA uses Darwinex MT5 OHLC at
runtime.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, AutoTrading setting, or portfolio gate is
touched by this build.

