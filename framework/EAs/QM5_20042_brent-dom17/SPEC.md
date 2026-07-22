# QM5_20042_brent-dom17 - Strategy Spec

**EA ID:** QM5_20042  
**Slug:** brent-dom17  
**Source:** BOROWSKI-XBR-DOM17-2016  
**Author of this spec:** Development  
**Last revised:** 2026-07-22

## 1. Strategy Logic

The EA tests one exact Brent day-of-month anomaly. At a new broker D1
bar whose timestamp is calendar day 17, it consumes one monthly decision and
attempts one short XBR position. A month without a D1 bar dated the 17th is
skipped; the signal never moves to a neighboring trading day.

The position closes at the first following D1 bar. A one-calendar-day stale
guard retries the close if the boundary close cannot execute. Friday close at
broker hour 21 preserves the one-session package when the 17th is a Friday.

## 2. Parameters

| Parameter | Default | Authorized value | Meaning |
|---|---:|---:|---|
| strategy_entry_day | 17 | 17 | Exact broker calendar date; no shift |
| strategy_atr_period | 20 | 20 | Completed D1 ATR hard-stop period |
| strategy_atr_sl_mult | 2.75 | 2.75 | Frozen ATR stop multiple |
| strategy_max_hold_days | 1 | 1 | Calendar-day stale close guard |
| strategy_max_spread_points | 2500 | 2500 | XBR entry spread cap |

All strategy parameters and the SELL direction are locked for Q02. A
five-minute execution-safety grace applies only when the EA initializes on an
already-open day-17 bar; it prevents a restart from manufacturing a mid-bar
entry. Once the EA is running, the first executable tick of a genuine new D1
event remains eligible regardless of the bar timestamp offset. The grace is
not a tunable signal window. A different date, date range, direction, hold,
stop, retry policy or price filter requires a new approved card.

## 3. Symbol Universe

**Designed for:**

- XBRUSD.DWX on magic slot 0, the registered Darwinex Brent CFD route.

**Explicitly not for:**

- WTI, metals, indices, FX, other XBR routes or other magic slots.
- A shifted substitute when calendar day 17 has no D1 bar.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Host and signal timeframe | D1 |
| Multi-timeframe references | none |
| Indicator data | completed-bar D1 ATR(20) only |
| Decision cadence | one consume on each new broker D1 bar |

The EA uses broker calendar timestamps, MT5 position/deal history and a
terminal-global monthly attempt marker. It needs no external runtime data.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 8-10; Q02 must verify at least 5 |
| Typical hold time | one D1 session |
| Direction | short only |
| Exit priority | next-D1 and stale management before entry-news gates |
| Drawdown profile | high XBR gap/basis risk, bounded by fixed risk and broker stop |

The month is marked attempted before news, spread, ATR, price and order
checks. A rejection, blocked signal, stop-out or restart therefore cannot
manufacture a later entry in that broker month.

## 6. Source Citation

**Source ID:** BOROWSKI-XBR-DOM17-2016  
**Source type:** named-author peer-reviewed full-text paper (tier B)  
**Pointer:** strategy-seeds/sources/BOROWSKI-XBR-DOM17-2016/source.md  
**Approved card:** strategy-seeds/cards/approved/QM5_20042_brent-dom17_card.md

Borowski, K. (2016), "Analysis of Selected Seasonality Effects in Markets of
Future Contracts with the Following Underlying Instruments: Crude Oil, Brent
Oil, Heating Oil, Gas Oil, Natural Gas, Feeder Cattle, Live Cattle, Lean Hogs
and Lumber," Journal of Management and Financial Sciences, issue 26, 27-44.

The paper reports its minimum Brent numbered-day mean, -0.6962%, on
calendar day 17 over its 1983-2016 futures sample, without reporting day 17 as
statistically significant. It searches many calendar partitions
without a reported multiple-comparison correction. Futures-to-CFD basis,
post-2016 decay and realized portfolio correlation remain falsification risks.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest | RISK_FIXED | 1000 per trade |
| Portfolio weight | fixed setfile value | 1 |
| Live | not authorized | no live setfile or manifest |

Each entry has a frozen 2.75 times completed-bar ATR(20) broker stop and no
take-profit. There is no trailing stop, break-even, partial close, scale-in,
pyramiding, grid, martingale, short leg or discretionary exit.

This build does not authorize T_Live, AutoTrading, a deploy/T_Live manifest,
portfolio admission or any portfolio-gate change.

## Q02 Handoff Status

Q01 passed strict compilation with zero errors and zero warnings, followed by
a strict build check with zero failures and zero warnings. The governed
`farmctl record-build` handoff created no Q02 work item: `XBRUSD.DWX` is absent
from `framework/registry/dwx_symbol_matrix.csv`. Classification is
`SETUP_DATA_MISMATCH`; the custom-symbol time/DST validation must PASS before
enqueue. No tester was launched and the matrix was not bypassed.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-22 | Initial source-backed XBR day-17 build | Q02 candidate |
