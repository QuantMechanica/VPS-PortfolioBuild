# QM5_12597_wti-fri-prem - Strategy Spec

**EA ID:** QM5_12597
**Slug:** `wti-fri-prem`
**Source:** `GORSKA-WTI-CAL-2015`
**Author of this spec:** Codex
**Last revised:** 2026-06-27

## 1. Strategy Logic

This EA implements a low-frequency structural WTI weekday-seasonality sleeve on
`XTIUSD.DWX`. On each new D1 bar, it permits a long entry only when the current
broker-calendar day is Friday. The position is flattened by the framework Friday
close before the weekend; if that is disabled or missed, the EA flattens on the
first subsequent non-Friday D1 bar or by a one-calendar-day stale-position
guard. The only price-derived input is ATR for the hard stop.

The strategy is intentionally not a duplicate of the existing WTI family:
`QM5_12596_wti-mon-fade` is the Monday short side, while this EA implements the
Friday long side. Monthly seasonality, WPSR continuation/fade/pre-event,
refinery maintenance, hurricane-season breakout, and medium-term return
reversal all use different information sets and entry logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14-30 | ATR period for the hard stop |
| `strategy_atr_sl_mult` | 2.25 | 1.5-3.0 | ATR stop distance multiplier |
| `strategy_max_hold_days` | 1 | 1-2 | Calendar-day stale-position guard |
| `strategy_entry_dow` | 5 | 5 | Broker-calendar Friday, where Sunday=0 |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 45-52.
- Typical hold: same Friday session via framework Friday close, with next-D1
  fallback if Friday close is disabled or missed.
- Regime preference: WTI weekday/weekend-effect seasonality.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Gorska, A. and Krawiec, M., "Calendar Effects in the Market of Crude Oil",
Quantitative Methods in Economics, 16(4), 2015, URL
https://ageconsearch.umn.edu/record/230857/files/2015_4_7.pdf.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
