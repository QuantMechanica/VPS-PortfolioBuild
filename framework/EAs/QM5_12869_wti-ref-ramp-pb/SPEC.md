# QM5_12869_wti-ref-ramp-pb - Strategy Spec

**EA ID:** QM5_12869
**Slug:** `wti-ref-ramp-pb`
**Source:** `EIA-WTI-REFINERY-MAINT-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-02

## 1. Strategy Logic

This EA implements a low-frequency WTI refinery-utilization ramp pullback
continuation sleeve on `XTIUSD.DWX` D1. It trades only in the May-July ramp
window described by the EIA refinery source packet. A long entry requires a
rising slow SMA trend, an ATR-normalized pullback from a recent high, and a
short rebound close through the prior few D1 highs.

This is not a duplicate of `QM5_12593_eia-wti-ref-fade`, which is a two-sided
shoulder-month stretch fade, or `QM5_12763_wti-ref-sqz-brk`, which is a
compression-and-breakout continuation rule. This EA expresses a pullback
continuation pattern inside the refinery ramp window.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_start_month` | 5 | fixed | Ramp-window start month |
| `strategy_start_day` | 1 | fixed | Ramp-window start day |
| `strategy_end_month` | 7 | fixed | Ramp-window end month |
| `strategy_end_day` | 31 | 15-31 | Ramp-window end day |
| `strategy_trend_period` | 84 | 63-100 | Slow D1 SMA trend period |
| `strategy_sma_slope_shift` | 10 | 5-15 | Bars back for slow SMA slope |
| `strategy_pullback_lookback` | 20 | 15-30 | Recent high lookback |
| `strategy_rebound_lookback` | 3 | 2-5 | Short rebound trigger lookback |
| `strategy_exit_channel` | 12 | 8-18 | Channel failure exit low |
| `strategy_atr_period` | 20 | 14-30 | ATR normalization and stop period |
| `strategy_min_pullback_atr` | 0.75 | 0.50-1.00 | Minimum pullback from recent high |
| `strategy_max_pullback_atr` | 3.0 | 2.0-4.0 | Maximum allowed pullback depth |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 | Hard stop ATR multiple |
| `strategy_max_hold_days` | 20 | 12-30 | Calendar-day stale exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | XTI spread cap |

## 3. Symbol Universe

- Symbol: `XTIUSD.DWX`, magic slot 0.
- Logical symbol: `QM5_12869_XTI_REF_RAMP_PB_D1`.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()` on the `XTIUSD.DWX` host chart.

## 5. Expected Behaviour

- Expected frequency: about 4-9 trades/year before Q02 proves or rejects the
  hypothesis.
- Typical hold: several D1 bars to a few weeks.
- Regime preference: pullbacks that resume during the refinery-utilization
  ramp window.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Energy Information Administration, "Refinery outages: planned and
unplanned outages, 2007-2011", URL
https://www.eia.gov/petroleum/articles/refoutagesindex.php.

U.S. Energy Information Administration, "U.S. refinery utilization rates
slightly higher than last year heading into summer", URL
https://www.eia.gov/todayinenergy/detail.php?id=61543.

The source is used for structural lineage only. The EA uses Darwinex OHLC and
broker calendar data only. No EIA data feed, refinery feed, futures curve, CSV,
API, or source performance claim is imported.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, AutoTrading setting, portfolio admission file,
or portfolio gate file is touched by this build.
