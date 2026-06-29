# QM5_12774_williams-8wk-xti - Strategy Spec

**EA ID:** QM5_12774
**Slug:** `williams-8wk-xti`
**Source:** `SRC03_S11_XTI`
**Author of this spec:** Codex
**Last revised:** 2026-06-29

## 1. Strategy Logic

This EA implements a low-frequency structural WTI congestion-breakout sleeve on
`XTIUSD.DWX`. On each new D1 bar, it builds a 40-bar box from the completed
bars before the signal bar, requires that box to be compressed relative to ATR,
then follows a close-confirmed breakout only when the pre-box trend points in
the same direction.

The strategy is intentionally not a duplicate of the existing WTI family:
calendar/weekday, WPSR, refinery, hurricane, OPEC, expiry, ETF-roll, CAD/oil,
XTI/XNG, oil/gold, oil/silver, medium-term reversal, RSI pullback, Donchian,
and Collins prior-day range sleeves use different timing or information sets.
This EA is a multi-week congestion breakout with a pre-box trend requirement.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_box_bars` | 40 | 30-50 | Completed D1 bars in the congestion box |
| `strategy_trend_lookback` | 20 | 10-30 | Bars before the box used to define pre-box trend |
| `strategy_atr_period` | 20 | 14-30 | ATR period for compression and hard stop |
| `strategy_box_atr_mult` | 8.0 | 6.0-10.0 | Maximum box width in ATR units |
| `strategy_min_trend_return_pct` | 1.0 | 0.5-2.0 | Minimum absolute pre-box trend return |
| `strategy_break_buffer_points` | 0 | 0-50 | Extra points beyond the box boundary |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 | ATR hard-stop distance multiplier |
| `strategy_max_hold_days` | 20 | 10-30 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4-12.
- Typical hold: several days to 20 calendar days.
- Regime preference: WTI breaks from multi-week congestion in the direction of
  the preceding trend.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Williams, Larry R. (1999). *Long-Term Secrets to Short-Term Trading*. Wiley
Trading. Local source registry: `strategy-seeds/sources/SRC03/source.md`, slot
S11, 8-Week Box Congestion Breakout.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
