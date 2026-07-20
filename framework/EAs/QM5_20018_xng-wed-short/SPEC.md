# QM5_20018_xng-wed-short - Strategy Spec

**EA ID:** QM5_20018  
**Slug:** xng-wed-short  
**Source:** BOROWSKI-COMM-DOW-2016  
**Author of this spec:** Development  
**Last revised:** 2026-07-20

## 1. Strategy Logic

The EA tests one exact natural-gas day-of-week anomaly. At a genuine new
broker D1 bar timestamped Wednesday (`day_of_week == 3`, Sunday=0), it consumes
one daily decision and attempts one short XNG position. The position closes at
the first following D1 bar. A one-calendar-day stale guard retries the close
if the boundary request cannot execute.

The Wednesday attempt is persisted before news, spread, ATR, price and order
checks. A rejection, stop, blocked signal or restart cannot manufacture a
later entry in the same broker day. Attaching more than five minutes after an
already-open Wednesday bar consumes the missed initialization edge instead of
creating a mid-session entry.

## 2. Parameters

| Parameter | Default | Authorized value | Meaning |
|---|---:|---:|---|
| strategy_entry_dow | 3 | 3 | Broker Wednesday; Sunday=0 |
| strategy_atr_period | 20 | 20 | Completed D1 ATR hard-stop period |
| strategy_atr_sl_mult | 2.75 | 2.75 | Frozen ATR stop multiple |
| strategy_max_hold_days | 1 | 1 | Calendar-day stale close guard |
| strategy_max_spread_points | 2500 | 2500 | XNG entry spread cap |

All strategy parameters and the SELL direction are locked for Q02. A
different weekday, direction, hold, stop, retry policy or price filter
requires a new approved card.

## 3. Symbol Universe

**Designed for:**

- XNGUSD.DWX on magic slot 0, the registered Darwinex natural-gas CFD route.

**Explicitly not for:**

- WTI, metals, indices, FX, other XNG routes or other magic slots.
- Storage/event timing or a shifted substitute after a blocked Wednesday.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Host and signal timeframe | D1 |
| Multi-timeframe references | none |
| Indicator data | completed-bar D1 ATR(20) only |
| Decision cadence | one consume on each new broker D1 bar |

The EA uses broker-calendar timestamps, MT5 position/deal history and a
terminal-global daily attempt marker. It needs no external runtime data.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 45-52; Q02 must verify at least 5 |
| Typical hold time | one D1 session |
| Direction | short only |
| Exit priority | next-D1 and stale management before entry-news gates |
| Drawdown profile | high XNG gap/basis risk, bounded by fixed risk and broker stop |

The first executable tick of Wednesday's D1 bar proxies the prior NYMEX close;
the next D1 boundary proxies Wednesday's close. Different broker/session
boundaries are an explicit falsification risk, not silently normalized.

## 6. Source Citation

**Source ID:** BOROWSKI-COMM-DOW-2016  
**Source type:** named-author peer-reviewed full-text paper (tier B)  
**Pointer:** strategy-seeds/sources/BOROWSKI-COMM-DOW-2016/source.md  
**Approved card:** strategy-seeds/cards/approved/QM5_20018_xng-wed-short_card.md

Borowski, K. (2016), "Analysis of Selected Seasonality Effects in Markets of
Future Contracts with the Following Underlying Instruments: Crude Oil, Brent
Oil, Heating Oil, Gas Oil, Natural Gas, Feeder Cattle, Live Cattle, Lean Hogs
and Lumber," *Journal of Management and Financial Sciences*, issue 26, 27-44.

The paper reports a `-0.2664%` Wednesday mean for natural-gas futures and
`p=0.0136` for equality against the other-weekday population over its
1990-2016 sample. It searches many calendar partitions without a reported
multiple-comparison correction. Futures-to-CFD and broker-session basis,
post-2016 decay and realized portfolio correlation remain falsification risks.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest | RISK_FIXED | 1000 per trade |
| Portfolio weight | fixed setfile value | 1 |
| Live | not authorized | no live setfile or manifest |

Each entry has a frozen `2.75 * ATR(20)` completed-bar broker stop and no
take-profit. There is no trailing stop, break-even, partial close, scale-in,
pyramiding, grid, martingale, long leg or discretionary exit.

This build does not authorize T_Live, AutoTrading, a deploy/T_Live manifest,
portfolio admission or any portfolio-gate change.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-20 | Initial source-backed XNG Wednesday build | Q02 candidate |
