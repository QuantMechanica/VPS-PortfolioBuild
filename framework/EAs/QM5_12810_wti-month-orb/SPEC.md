# QM5_12810_wti-month-orb - Strategy Spec

**EA ID:** QM5_12810
**Slug:** `wti-month-orb`
**Source:** `CME-WTI-MONTH-ORB-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-30

## 1. Strategy Logic

This EA implements a low-frequency WTI month-opening range breakout on
`XTIUSD.DWX`. On each new D1 bar, it uses the first five completed D1 bars of
the current calendar month as the opening range. A later close above that range
opens a long position; a later close below that range opens a short position.
Both sides require ATR-normalized range sanity, SMA trend confirmation, and a
strong close location.

The strategy is intentionally not a duplicate of the existing WTI family:
expiry-window, fixed weekday or month, WPSR, EIA event, OPEC, hurricane,
refinery, ratio, broad time-series-momentum, Donchian, and commodity RSI
pullback sleeves all use different timing or entry logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_opening_days` | 5 | 3-7 | First completed D1 bars used to define the monthly opening range |
| `strategy_atr_period` | 20 | 14-30 | ATR period for range filter, stop, and target |
| `strategy_trend_period` | 80 | 50-120 | SMA trend confirmation |
| `strategy_min_open_range_atr` | 0.60 | 0.45-0.80 | Minimum opening range as ATR multiple |
| `strategy_max_open_range_atr` | 4.00 | 3.00-5.00 | Maximum opening range as ATR multiple |
| `strategy_entry_buffer_atr` | 0.08 | 0.04-0.12 | ATR buffer beyond opening range for entry confirmation |
| `strategy_min_close_location` | 0.58 | 0.55-0.65 | Close-location threshold inside signal bar range |
| `strategy_atr_sl_mult` | 2.50 | 2.00-3.25 | ATR stop distance multiplier |
| `strategy_atr_tp_mult` | 4.00 | 3.00-5.00 | ATR target distance multiplier |
| `strategy_max_hold_days` | 15 | 10-20 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.
- Not designed for `XNGUSD.DWX`, `XAUUSD.DWX`, `XAGUSD.DWX`, index symbols, FX
  symbols, or commodity ratio baskets.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 6-10.
- Typical hold: several D1 bars; capped at 15 calendar days by default and
  closed on month change.
- Regime preference: monthly WTI volatility expansion after the opening range.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Crabel, Toby. *Day Trading with Short-Term Price Patterns and Opening Range
Breakout*. Traders Press, 1990. Supplements: CME Group Light Sweet Crude Oil
Futures contract specifications,
https://www.cmegroup.com/markets/energy/crude-oil/light-sweet-crude.contractSpecs.html,
and CME Group Chapter 200 Light Sweet Crude Oil Futures,
https://www.cmegroup.com/rulebook/NYMEX/2/200.pdf.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-06-30 | Initial WTI month-opening range breakout build |
