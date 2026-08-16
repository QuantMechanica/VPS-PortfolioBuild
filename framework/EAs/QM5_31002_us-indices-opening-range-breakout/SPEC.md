# QM5_31002_us-indices-opening-range-breakout — Strategy Spec

**EA ID:** QM5_31002
**Slug:** `us-indices-opening-range-breakout`
**Source:** `us-indices-opening-range-breakout-official-source`
**Author of this spec:** Codex
**Last revised:** 2026-08-16

## 1. Strategy Logic

The EA builds the first 15-minute range beginning at 14:30 UTC from closed M5 bars. After the range closes and before 21:00 UTC, the first close above or below it may enter only when the signal bar's tick volume is at least 1.5 times the preceding 20-bar mean. The stop is the opening-range midpoint and the target is twice the resulting stop distance.

Only the first qualifying breakout attempt per UTC day is accepted. The entry path retains the card's spread, rollover, one-position, daily-loss and total-drawdown filters; the framework adds mandatory news and Friday-close handling.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `InpORBMinutes` | `15` | `5–30` | Opening-range duration from 14:30 UTC. |
| `InpVolMultiplier` | `1.50` | `1.2–2.5` | Signal volume divided by the prior 20-bar mean. |

The card's `InpRiskPercent` intent is implemented by the mandatory framework `RISK_PERCENT`/`RISK_FIXED` pair, not duplicated as an unwired strategy input.

## 3. Symbol Universe

- `WS30.DWX` — primary US cash-index proxy, slot 0.
- `NDX.DWX` — approved portable Nasdaq proxy, slot 1.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Opening-range source | Closed M5 bars from 14:30 through 14:45 UTC at defaults |
| Multi-timeframe refs | none |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 150 ordering prior |
| Frequency band | 80–160 high-conviction trades per year |
| Typical hold time | Intraday |
| Drawdown prior | Conservative card prior 12%; source claims are not evidence |
| Regime preference | Cash-open expansion with relative-volume confirmation |

## 6. Source Citation

**Source ID:** `us-indices-opening-range-breakout-official-source`

**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_31002_us-indices-opening-range-breakout.md`; citation: “Crabel, T. (1990). Day Trading with Short Term Price Patterns.”

R1 lineage is recorded and R2–R4 are marked PASS in the approved card.

## 7. Risk Model

| Environment | Active risk mode | Required value |
|---|---|---|
| Backtest | `RISK_FIXED` | Greater than zero; generated sets use 1000 |
| Demo / shadow / live | `RISK_PERCENT` | OWNER/deploy-manifest controlled |
| Inactive mode | The other risk input | Exactly zero |

The absolute midpoint stop feeds the central risk sizer. No pipeline or live verdict is inferred from build success.

## Revision History

| Version | Date | Reason | Task |
|---|---|---|---|
| v1 | 2026-08-16 | Initial build from approved card | b934613a-ae5d-4590-bd9d-c5ad4ab54801 |

