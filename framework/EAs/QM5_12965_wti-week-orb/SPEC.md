# QM5_12965_wti-week-orb - Strategy Spec

**EA ID:** QM5_12965
**Slug:** `wti-week-orb`
**Source:** `CRABEL-WTI-WEEK-ORB-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-02

## 1. Strategy Logic

This EA implements a low-frequency WTI weekly opening-range breakout on
`XTIUSD.DWX`. On each new D1 bar, it uses the first completed D1 bar of the
current broker week as the opening range. A later Tuesday-through-Thursday
closed D1 breakout above or below that range opens a directional WTI position.

The strategy is intentionally not a duplicate of the existing WTI family:
month-opening range, weekend gap, fixed weekday/month, WPSR, EIA event, OPEC,
hurricane, refinery, ratio, broad time-series momentum, Donchian, and
commodity RSI pullback sleeves all use different timing or entry logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_opening_days` | 1 | 1-2 | First completed D1 bars used to define the weekly opening range |
| `strategy_signal_min_dow` | 2 | 2 | Earliest signal DOW; Tuesday in MT5 broker calendar |
| `strategy_signal_max_dow` | 4 | 3-4 | Latest signal DOW; Thursday in MT5 broker calendar |
| `strategy_atr_period` | 20 | 14-30 | ATR period for range filter, stop, and target |
| `strategy_trend_period` | 60 | 40-90 | SMA trend confirmation |
| `strategy_min_open_range_atr` | 0.45 | 0.30-0.65 | Minimum opening range as ATR multiple |
| `strategy_max_open_range_atr` | 2.75 | 2.25-3.50 | Maximum opening range as ATR multiple |
| `strategy_entry_buffer_atr` | 0.08 | 0.04-0.12 | ATR buffer beyond opening range for entry confirmation |
| `strategy_min_close_location` | 0.60 | 0.55-0.67 | Close-location threshold inside signal bar range |
| `strategy_atr_sl_mult` | 2.40 | 2.00-3.00 | ATR stop distance multiplier |
| `strategy_atr_tp_mult` | 3.50 | 3.00-4.50 | ATR target distance multiplier |
| `strategy_max_hold_days` | 4 | 3-5 | Calendar-day stale-position guard |
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

- Expected trades/year/symbol: about 16-32.
- Typical hold: one to several D1 bars; capped at four calendar days by default
  and closed by week change or Friday close.
- Regime preference: weekly WTI volatility expansion after the opening range.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Crabel, Toby. *Day Trading with Short-Term Price Patterns and Opening Range
Breakout*. Traders Press, 1990.

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
| v1 | 2026-07-02 | Initial WTI weekly opening-range breakout build |
