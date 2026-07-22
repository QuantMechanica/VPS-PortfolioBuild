---
ea_id: QM5_20035
slug: xng-dom27-short
strategy_id: BOROWSKI-XNG-DOM15-2016_S02
source_id: BOROWSKI-XNG-DOM15-2016
status: APPROVED
created: 2026-07-22
created_by: Research+Development
last_updated: 2026-07-22
strategy_type_flags: [calendar-seasonality, day-of-month, short-only, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XNGUSD.DWX]
timeframes: [D1]
ml_required: false
g0_status: APPROVED
q01_status: PENDING
pipeline_phase: Q02
q02_status: PENDING_ENQUEUE
---
# XNG Calendar-Day-27 One-Session Fade

## Hypothesis and source

Borowski (2016), *Journal of Management and Financial Sciences* issue 26,
reports day 27 as the minimum natural-gas numbered-day mean (`-0.7265%`) in
NYMEX futures from 1990-04-03 through 2016-03-31. Mechanize that weak negative
extreme as one exact-date short package and let Q02 falsify transfer to the
Darwinex CFD after costs.

Primary tier-B citation: Krzysztof Borowski (2016), "Analysis of Selected
Seasonality Effects in Markets of Future Contracts...", pp. 27-44, Section
4.3 day-of-month table. Official archive:
https://econjournals.sgh.waw.pl/JMFS/Archives_2015_2016. Complete author copy:
https://www.researchgate.net/publication/303285422_ANALYSIS_OF_SELECTED_SEASONALITY_EF-_FECTS_IN_MARKETS_OF_FUTURE_CONTRACTS_WITH_THE_FOLLOWING_UNDERLYING_INSTRUMENTS_CRUDE_OIL_BRENT_OIL_HEATING_OIL_GAS_OIL_NATURAL_GAS_FEEDER_CATTLE_LIVE_CATTLE_LEAN_HOGS_AND_LUMBER.

The paper does not report day 27 as statistically significant, searches many
calendar partitions without a multiple-comparison correction, ends in 2016,
and studies futures rather than `XNGUSD.DWX`. The source statistic is not a
performance claim.

## Locked rules

- On a genuine new `XNGUSD.DWX` D1 bar dated exactly the 27th, consume the
  broker-month attempt before gates and submit one SELL; never shift an absent
  27th and never retry within the month.
- Close at the first following D1 boundary or after one stale calendar day.
- Use completed-bar ATR(20), a frozen 2.75 ATR hard stop, 2500-point spread
  cap, framework news gate, Friday close at broker hour 21, and no take-profit.
- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, weight 1. No sweep.
- No ML, banned indicator, external feed, grid, martingale, scale or pyramid.

Expected cadence is roughly 8-10 packages/year; Q02 must reject below five
completed packages/year or for nondeterminism, shifted dates, duplicate
attempts, risk mismatch, or governed PF/DD failure.

## Non-duplicate and framework alignment

Repository-wide card/source/EA search found no XNG day-27 carrier.
`QM5_12567` is a cumulative-RSI2 price pullback; `QM5_20017` is the source's
statistically significant day-15 long; weekday, storage-event, momentum and
month-channel XNG sleeves use different triggers and holds. Different logic
does not prove low correlation; the downstream portfolio gate remains intact.

- no_trade: exact XNG/D1/slot and locked constants.
- trade_entry: exact day 27, monthly persistence/history guard, short with ATR stop.
- trade_management: next-D1 and stale-day close before entry-news gating.
- trade_close: framework close path, Friday close, and broker hard stop.

No live setfile, AutoTrading, T_Live, deploy manifest, portfolio admission, or
portfolio-gate change is authorized.
