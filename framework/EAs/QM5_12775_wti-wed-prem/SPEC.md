# QM5_12775_wti-wed-prem - Strategy Spec

**EA ID:** QM5_12775
**Slug:** `wti-wed-prem`
**Source:** `MEEK-HOELSCHER-WTI-DOW-2023`
**Author of this spec:** Codex
**Last revised:** 2026-06-29

## 1. Strategy Logic

This EA implements a low-frequency structural WTI weekday-seasonality sleeve on
`XTIUSD.DWX`. On each new D1 bar, it permits a long entry only when the current
broker-calendar day is Wednesday. The position is flattened on the first
subsequent non-Wednesday D1 bar or by a one-calendar-day stale-position guard.
The only price-derived input is ATR for the hard stop.

The strategy is intentionally not a duplicate of the existing WTI family:
Monday and Tuesday fades, Thursday premium, Friday premium, conditional
Thursday-pullback/Friday bounce, month-of-year seasonality, WPSR, refinery,
hurricane, OPEC, expiry, ETF-roll, CAD/oil, XTI/XNG, XAU/XAG, and medium-term
return reversal all use different timing or information sets. This EA is a pure
Wednesday calendar premium test.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14-30 | ATR period for the hard stop |
| `strategy_atr_sl_mult` | 2.25 | 1.5-3.0 | ATR stop distance multiplier |
| `strategy_max_hold_days` | 1 | 1-2 | Calendar-day stale-position guard |
| `strategy_entry_dow` | 3 | 3 | Broker-calendar Wednesday, where Sunday=0 |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 45-52.
- Typical hold: one D1 bar.
- Regime preference: WTI weekday calendar-premium seasonality.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Meek, H. and Hoelscher, S. A., "Day-of-the-week effect: Petroleum and
petroleum products", Cogent Economics and Finance 11(1), 2023, DOI
https://doi.org/10.1080/23322039.2023.2213876.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
