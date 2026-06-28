# QM5_12753_wti-thu-pb-fri-bounce - Strategy Spec

**EA ID:** QM5_12753
**Slug:** `wti-thu-pb-fri-bounce`
**Source:** `MEEK-HOELSCHER-WTI-DOW-2023`
**Author of this spec:** Codex
**Last revised:** 2026-06-28

## 1. Strategy Logic

This EA implements a low-frequency WTI day-of-week pullback sleeve on
`XTIUSD.DWX`. On each new D1 bar, it permits a long entry only when the current
broker-calendar bar is Friday, the previous completed D1 bar is Thursday, and
Thursday's close-to-close return is at or below
`-strategy_min_thu_drop_pct`. Positions are flattened by the framework Friday
close, on the first non-Friday D1 bar, or by a calendar-day stale-position
guard.

The strategy is intentionally not a duplicate of the existing WTI family:
`QM5_12597_wti-fri-prem` buys all Fridays, while this EA buys only after a
material Thursday decline. It is also not Monday/Tuesday fade, weekend-gap,
month-of-year, WPSR, hurricane, refinery, OPEC, expiry, roll, CAD, ratio, RSI,
Donchian, or long-horizon momentum logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_min_thu_drop_pct` | 1.00 | 0.50-1.50 | Minimum Thursday close-to-close decline in percent |
| `strategy_atr_period` | 20 | 14-30 | ATR period for the hard stop |
| `strategy_atr_sl_mult` | 2.25 | 1.5-3.0 | ATR stop distance multiplier |
| `strategy_max_hold_days` | 2 | 1-2 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 10-25.
- Typical hold: Friday session, capped by stale-position guard if Friday close
  is disabled or missed.
- Regime preference: WTI day-of-week pullback/rebound behavior.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Meek, H. and Hoelscher, S. A., "Day-of-the-week effect: Petroleum and
petroleum products", Cogent Economics and Finance, 11(1), 2023, DOI
https://doi.org/10.1080/23322039.2023.2213876.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
