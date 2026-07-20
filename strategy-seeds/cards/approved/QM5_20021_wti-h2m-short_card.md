---
ea_id: QM5_20021
slug: wti-h2m-short
type: strategy
strategy_id: BOROWSKI-WTI-H2M-2016_S01
source_id: BOROWSKI-WTI-H2M-2016
status: APPROVED
created: 2026-07-20
created_by: Research+Development
last_updated: 2026-07-20
g0_status: APPROVED
g0_approval_reasoning: "OWNER commodity-sleeve mission: tier-B complete peer-reviewed source; exact WTI day-16 short/next-month flat rule; registered XTIUSD D1 route; calendar/ATR only; exact-mechanic repository search CLEAN. Source non-significance is disclosed as a binding Q02 kill risk."
source_citations:
  - type: academic_paper
    citation: "Borowski, K. (2016). Analysis of Selected Seasonality Effects in Markets of Future Contracts with the Following Underlying Instruments: Crude Oil, Brent Oil, Heating Oil, Gas Oil, Natural Gas, Feeder Cattle, Live Cattle, Lean Hogs and Lumber. Journal of Management and Financial Sciences, issue 26, 27-44."
    location: "Section 4.4, Table 2, pp. 37-38; official SGH archive and complete author copy linked in source packet"
    quality_tier: B
    role: primary
strategy_type_flags: [calendar-seasonality, within-month, short-only, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
period: D1
primary_target_symbols: [XTIUSD.DWX]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
expected_trade_frequency: "One package/month, about 12/year; Q02 must verify at least five completed packages/year."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: TIER_B
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: QUEUED
q02_work_item_id: 1768c5e9-180c-45af-92fe-915ddc1db6cc
review_focus: "Falsify a monthly WTI calendar carrier after costs; realized decorrelation remains exclusively for the governed downstream portfolio gate."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
---

# WTI Second-Half-of-Month Short

## Concept and evidence boundary

Borowski reports average NYMEX crude-oil daily returns of `-0.0148%` in days
1-15 and `-0.0824%` in days 16-month-end, but the difference is not
statistically significant (`p=0.5271`). This card tests the literal second-half
carrier on Darwinex WTI: short at the first executable D1 bar dated 16 and
flatten at the first D1 bar of the next broker month.

This is a deliberately weak falsification candidate, not certification or a
decorrelation claim. Multiple comparisons, post-2016 decay, futures/CFD basis,
rolls, financing, and broker D1 boundaries can erase it.

## Non-duplicate decision

Repository-wide exact-mechanic searches found no WTI day-16-to-next-month
short. It is not cumulative-RSI2 (`QM5_12567`), a weekday, numbered-session
one-bar trade, month-of-year sleeve, trend, inventory event, or spread basket.

## Locked rules

- On a new `XTIUSD.DWX` D1 bar dated exactly 16, consume the month decision.
- If day 16 is not tradable, skip; never shift to day 17.
- Sell once with `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
  `2.75 * ATR(20)` stop, no TP, and spread no greater than 2500 points.
- Flatten on the first D1 bar whose broker month differs from the entry month;
  retry during that bar if necessary. A 16-calendar-day stale guard applies.
- Friday close remains enabled at broker hour 21. A Friday flatten does not
  permit re-entry in the same month.
- No trail, break-even, partial, scale-in, grid, martingale, ML, adaptive fit,
  external feed, or parameter sweep.

## Framework alignment

- no_trade: exact XTIUSD.DWX/D1/slot and locked constants.
- trade_entry: exact day 16, restart-safe monthly attempt, short and ATR stop.
- trade_management: month-change close plus 16-day stale guard.
- trade_close: strategy close helper, Friday close, and broker hard stop.

Q02 retires below five completed packages/year, on nondeterminism, shifted-day
behavior, risk mismatch, or governed PF/DD failure. Portfolio admission and
correlation remain downstream; this card changes no gate.

## Pipeline history

| version | date | phase | verdict |
|---|---|---|---|
| v1 | 2026-07-20 | G0/Q01 | APPROVED/PASS |
| v1-q02 | 2026-07-20 | Q02 | PENDING `1768c5e9-180c-45af-92fe-915ddc1db6cc` |

## Safety boundary

Research/backtest only. No live setfile, AutoTrading, T_Live, deploy manifest,
portfolio admission, or portfolio-gate modification is authorized.
