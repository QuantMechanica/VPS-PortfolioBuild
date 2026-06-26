# QM5_12584_eia-xng-storage - Strategy Spec

**EA ID:** QM5_12584
**Slug:** `eia-xng-storage`
**Source:** `EIA-XNG-STORAGE-AFTERSHOCK-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-26

## 1. Strategy Logic

This EA implements a low-frequency structural natural-gas sleeve on
`XNGUSD.DWX`. On each new D1 bar, it inspects the prior closed D1 bar only when
that bar was Wednesday, Thursday, or Friday. Thursday is the standard EIA
storage-report day; Wednesday and Friday tolerate holiday schedule shifts.

If the event-day range expands versus ATR(20), the body is directional, and the
close confirms versus SMA(40), the EA enters in the event-day direction. The
position has a fixed ATR stop and exits after a short calendar-day aftershock
window.

The strategy is intentionally not a duplicate of `QM5_12567`, `QM5_12575`, or
`QM5_12582`. It uses post-storage-report D1 reaction only and never trades
before the event bar has closed.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14-30 | ATR period for range filter and stop |
| `strategy_trend_period` | 40 | 34-63 | SMA confirmation period |
| `strategy_min_range_atr` | 1.25 | 1.0-1.75 | Minimum event-day range versus ATR |
| `strategy_min_body_ratio` | 0.30 | 0.25-0.50 | Minimum absolute body/range ratio |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.5 | Stop distance multiplier |
| `strategy_max_hold_days` | 2 | 1-5 | Calendar-day time exit |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 12.
- Typical hold: 1-3 D1 bars.
- Regime preference: natural-gas information-event range expansion.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Weekly Natural Gas Storage Report",
URL https://www.eia.gov/naturalgas/storage/. Release schedule URL
https://www.eia.gov/naturalgas/schedule/.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest or `T_Live` file is touched by this build.
