# QM5_13075_xti-inweek-brk - Strategy Spec

**EA ID:** QM5_13075
**Slug:** `xti-inweek-brk`
**Source:** `CRABEL-WTI-WEEK-ORB-2026_S02`
**Author of this spec:** Codex
**Last revised:** 2026-07-09

## 1. Strategy Logic

This EA implements a low-frequency structural WTI breakout sleeve on
`XTIUSD.DWX` D1. It waits for a completed broker week whose high-low range is
fully inside the prior broker week, then trades next-week D1 close expansion
beyond that inside-week high or low.

Entry requires a valid inside-week setup, an ATR-normalized range filter, SMA
trend confirmation, close-location confirmation, a spread cap, and one entry
per broker week. Runtime remains Darwinex-native: closed D1 OHLC, spread, ATR,
SMA, broker calendar, and V5 framework state only.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_min_week_bars` | 3 | 3-4 | Minimum completed D1 bars in inside and parent weeks |
| `strategy_signal_min_dow` | 1 | 1-2 | First allowed signal day of week |
| `strategy_signal_max_dow` | 4 | 3-4 | Last allowed signal day of week |
| `strategy_atr_period` | 20 | 14-30 | ATR period for range filters and stops |
| `strategy_trend_period` | 60 | 40-90 | SMA trend confirmation period |
| `strategy_min_inside_range_atr` | 0.60 | 0.40-0.80 | Minimum inside-week range in ATR units |
| `strategy_max_inside_range_atr` | 2.40 | 1.80-3.00 | Maximum inside-week range in ATR units |
| `strategy_min_parent_range_atr` | 1.20 | 0.90-1.60 | Minimum parent-week range in ATR units |
| `strategy_entry_buffer_atr` | 0.08 | 0.04-0.12 | Breakout buffer beyond inside-week high/low |
| `strategy_min_close_location` | 0.58 | 0.55-0.65 | Required signal-bar close location |
| `strategy_atr_sl_mult` | 2.60 | 2.00-3.20 | ATR hard-stop distance |
| `strategy_atr_tp_mult` | 3.20 | 2.50-4.00 | ATR target distance |
| `strategy_max_hold_days` | 8 | 5-12 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 8-18.
- Direction: symmetric long/short.
- Typical hold: several D1 bars, capped by ATR target, ATR stop, eight-day time
  exit, failed-breakout/SMA exit, or Friday close.
- Regime preference: WTI weekly range compression followed by trend-confirmed
  volatility expansion.
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

- Build result: `artifacts/qm5_13075_build_result.json`.
- Q02 enqueue: `artifacts/qm5_13075_q02_enqueue_20260709.json`.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-09 | Mission-directed WTI inside-week compression breakout build | Enqueue to Q02 |
