# QM5_13095_xti-outweek-fade - Strategy Spec

**EA ID:** QM5_13095
**Slug:** `xti-outweek-fade`
**Source:** `CRABEL-WTI-OUTWEEK-REV-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-09

## 1. Strategy Logic

This EA implements a low-frequency structural WTI outside-week exhaustion fade
on `XTIUSD.DWX` D1. It waits for a completed broker week whose high exceeds the
prior week high and whose low breaks the prior week low. If that outside week
closes in an extreme tail, the following week can enter only after a completed
D1 bar confirms reversal back toward the parent-week range.

Entry requires a valid outside-week setup, ATR-normalized range filters, SMA
stretch context, D1 close-location confirmation, a spread cap, and one entry
per broker week. Runtime remains Darwinex-native: closed D1 OHLC, spread, ATR,
SMA, broker calendar, and V5 framework state only.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_min_week_bars` | 3 | 3-4 | Minimum completed D1 bars in outside and parent weeks |
| `strategy_signal_min_dow` | 1 | 1-2 | First allowed signal day of week |
| `strategy_signal_max_dow` | 4 | 3-4 | Last allowed signal day of week |
| `strategy_atr_period` | 20 | 14-30 | ATR period for range filters and stops |
| `strategy_trend_period` | 60 | 40-90 | SMA mean-reversion reference period |
| `strategy_min_outside_range_atr` | 1.20 | 0.90-1.60 | Minimum outside-week range in ATR units |
| `strategy_max_outside_range_atr` | 4.50 | 3.50-5.50 | Maximum outside-week range in ATR units |
| `strategy_min_parent_range_atr` | 0.80 | 0.60-1.10 | Minimum parent-week range in ATR units |
| `strategy_reclaim_buffer_atr` | 0.15 | 0.08-0.25 | Reclaim buffer back inside the outside-week extreme |
| `strategy_extreme_close_location` | 0.65 | 0.60-0.72 | Outside-week tail close threshold |
| `strategy_min_reversal_close_location` | 0.58 | 0.55-0.65 | Signal-bar close-location threshold |
| `strategy_atr_sl_mult` | 2.80 | 2.20-3.40 | ATR hard-stop distance |
| `strategy_atr_tp_mult` | 2.20 | 1.80-2.80 | ATR target distance |
| `strategy_max_hold_days` | 10 | 6-15 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 8-16.
- Direction: symmetric long/short.
- Typical hold: several D1 bars, capped by ATR target, ATR stop, ten-day time
  exit, failed-fade/SMA exit, or Friday close.
- Regime preference: WTI weekly outside-range exhaustion followed by reversal
  evidence back toward the prior week range.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Crabel, Toby. *Day Trading with Short-Term Price Patterns and Opening Range
Breakout*. Traders Press, 1990.

U.S. Energy Information Administration, "What drives crude oil prices: Spot
Prices", URL https://www.eia.gov/finance/markets/crudeoil/spot_prices.php.

The sources are used for structural lineage and WTI market context only. No
external data feed, futures curve, inventory feed, volume feed, open-interest
feed, or API is used at runtime.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Evidence

- Build result: `artifacts/qm5_13095_build_result.json`.
- Q02 enqueue: `artifacts/qm5_13095_q02_enqueue_20260709.json`.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-09 | Mission-directed WTI outside-week exhaustion fade build | Enqueue to Q02 |
