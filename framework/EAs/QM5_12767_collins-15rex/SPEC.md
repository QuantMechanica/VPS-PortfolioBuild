# QM5_12767_collins-15rex - Strategy Spec

**EA ID:** QM5_12767
**Slug:** `collins-15rex`
**Source:** `SRC08`
**Author of this spec:** Codex
**Last revised:** 2026-06-29

## 1. Strategy Logic

This EA implements Art Collins' 1.5 daily range expansion formula as a
low-frequency structural WTI sleeve on `XTIUSD.DWX`. On each new D1 bar it
uses the prior completed daily range and the prior close relative to SMA(25).
If the prior close is above the SMA it arms a buy stop at the current D1 open
plus 1.5 times the prior range. If the prior close is below the SMA it arms a
sell stop at the current D1 open minus 1.5 times the prior range. The opposite
range band is the hard protective stop.

Unfilled stop orders are repriced on the next D1 bar. The EA has no event
feed, no calendar trigger, no futures-curve input, no RSI oscillator, and no
adaptive or ML component. It is intentionally distinct from the existing WTI
refinery-ramp, roll, event, pullback, and month-effect EAs.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_range_mult` | 1.5 | 1.0-2.0 | Prior D1 range multiplier for stop-entry and hard stop |
| `strategy_sma_period` | 25 | 20-50 | SMA regime filter period |
| `strategy_atr_period` | 14 | 10-20 | ATR period for abnormal-range filter |
| `strategy_abnormal_range_atr_cap` | 5.0 | 3.0-8.0 | Skip if prior range is above this ATR multiple |
| `strategy_pending_expiry_hours` | 24 | 18-30 | Pending stop expiration window |
| `strategy_max_hold_days` | 10 | 5-20 | Calendar-day time exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |
| `strategy_min_stop_points` | 10 | 5-20 | Minimum entry distance guard |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: entries and pending-order repricing use `QM_IsNewBar()` on the
  host D1 chart.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 12-24.
- Typical hold: intraday fill to several D1 bars, capped at 10 calendar days.
- Regime preference: crude-oil volatility expansion in the direction of the
  prior close versus SMA(25).
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Collins, Art. *Beating the Financial Futures Market: Combining Small Biases
into Powerful Money Making Strategies*. John Wiley & Sons, 2006. Chapter 25
and Appendix Table 25.4 document the 1.5 Daily Range Expansion formula. The
book is used as reputable mechanical lineage only; the EA uses Darwinex MT5
OHLC at runtime.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, AutoTrading setting, or portfolio gate is
touched by this build.
