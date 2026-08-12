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
source_citations:
  - type: academic_paper
    citation: "Borowski, K. (2016), Analysis of Selected Seasonality Effects in Markets of Future Contracts, Journal of Management and Financial Sciences 26, 27-44."
    location: "Section 4.3 natural-gas day-of-month table"
    quality_tier: B
    role: primary
markets: [commodities, energy, natural_gas]
primary_target_symbols: [XNGUSD.DWX]
target_symbols: [XNGUSD.DWX]
timeframes: [D1]
ml_required: false
g0_status: APPROVED
r1_track_record: TIER_B
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_trades_per_year_per_symbol: 9
expected_trade_frequency: "About 8-10 exact-date packages per year"
expected_pf: 1.01
expected_dd_pct: 40.0
risk_class: high
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, risk_mode_dual, low_frequency, cfd_source_basis, multiple_comparisons, portfolio_correlation]
q01_status: PASS
pipeline_phase: Q02
q02_status: INFRA_FAIL
q02_work_item_id: 85e22900-57bc-425c-8452-d665fc262cd5
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

## Rules

The following entry, exit, filter, and management rules are immutable for Q02.

## 4. Entry Rules

- On a genuine new `XNGUSD.DWX` D1 bar dated exactly the 27th, consume the
  broker-month attempt before gates and submit one SELL; never shift an absent
  27th and never retry within the month.
- Close at the first following D1 boundary or after one stale calendar day.
- Use completed-bar ATR(20), a frozen 2.75 ATR hard stop, 2500-point spread
  cap, framework news gate, Friday close at broker hour 21, and no take-profit.
- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, weight 1. No sweep.
- No ML, banned indicator, external feed, grid, martingale, scale or pyramid.

## 5. Exit Rules

- Flatten at the first D1 boundary after entry, retrying the close on later
  ticks if necessary; the one-calendar-day stale guard is the fallback.
- Retain the framework Friday close and entry-time broker hard stop.

## 6. Filters (No-Trade Module)

- Require exact `XNGUSD.DWX`, D1, magic slot 0, day 27, and locked parameters.
- Fail closed on invalid spread, ATR, price, stop arithmetic, or persisted state.

## 7. Trade Management Rules

- Manage only the registered symbol and magic, never move the frozen stop,
  and evaluate time exits before any new-entry news gate.

## Risk

This is a high-risk sparse calendar hypothesis with futures/CFD basis, gaps,
multiple-testing bias, post-publication decay, and low-sample uncertainty.

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
