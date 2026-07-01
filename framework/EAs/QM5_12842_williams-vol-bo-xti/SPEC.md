# QM5_12842_williams-vol-bo-xti - Strategy Spec

**EA ID:** QM5_12842
**Slug:** `williams-vol-bo-xti`
**Source:** `SRC03`
**Author of this spec:** Codex
**Last revised:** 2026-07-01

## 1. Strategy Logic

This EA implements a low-frequency structural WTI volatility-expansion sleeve on
`XTIUSD.DWX`. On each new D1 bar, it reads the prior completed D1 range and
places one long buy-stop above the current D1 open by a fixed range multiple.
The position uses an ATR hard stop, optional fixed-R target, and a max-hold
stale exit.

The strategy is intentionally not a duplicate of the existing WTI family:
day-of-week, month-of-year, expiry, post-roll, WPSR, Cushing, refinery,
hurricane, OPEC, SPR, CAD/FX, XTI/XNG, oil/gold, oil/silver, 52-week-anchor,
return-reversal, and commodity-RSI sleeves all use different timing or signal
construction.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_range_mult` | 0.75 | 0.50-1.25 | Prior D1 range fraction added to the D1 open |
| `strategy_min_range_atr` | 0.35 | 0.00-0.50 | Minimum prior range as a fraction of ATR |
| `strategy_atr_period` | 20 | 14-30 | ATR period for range filter and hard stop |
| `strategy_atr_sl_mult` | 2.50 | 2.00-4.00 | ATR stop distance multiplier |
| `strategy_take_rr` | 2.00 | 0.00-3.00 | Optional fixed-R take-profit multiple |
| `strategy_order_expiry_hours` | 20 | 12-24 | Pending buy-stop expiry |
| `strategy_max_hold_days` | 5 | 3-8 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0. This is the Darwinex WTI CFD proxy and gives
  the book energy exposure distinct from the current XAU, index, and XNG book.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 12-30.
- Typical hold: intraday pending trigger through five calendar days after fill.
- Regime preference: WTI upside range-expansion/trend continuation after a
  sufficiently normal prior D1 range.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Source `SRC03`: Williams, Larry R. (1999). *Long-Term Secrets to Short-Term
Trading*. Wiley Trading. The local source packet documents the prior-day range
volatility-breakout rule. R1-R4 PASS is recorded in
`artifacts/cards_approved/QM5_12842_williams-vol-bo-xti_card.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Revision History

| Version | Date | Change | Task |
|---|---|---|---|
| v1 | 2026-07-01 | Initial build from card | 9d5be4c3-0e90-4886-91fd-10c835ec34e2 |
