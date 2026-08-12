---
ea_id: QM5_20027
slug: wti-dom26-short
type: strategy
strategy_id: BOROWSKI-WTI-DOM26-2016_S01
source_id: BOROWSKI-WTI-DOM26-2016
status: APPROVED
created: 2026-07-21
created_by: Research+Development
last_updated: 2026-07-21
g0_status: APPROVED
g0_approval_reasoning: "OWNER commodity-sleeve mission: tier-B complete peer-reviewed source; reported significant negative WTI day-26 anomaly; exact-date short/next-D1-flat rule; registered XTIUSD D1 route; calendar/ATR only; exact-mechanic repository search CLEAN."
source_citations:
  - type: academic_paper
    citation: "Borowski, K. (2016). Analysis of Selected Seasonality Effects in Markets of Future Contracts with the Following Underlying Instruments: Crude Oil, Brent Oil, Heating Oil, Gas Oil, Natural Gas, Feeder Cattle, Live Cattle, Lean Hogs and Lumber. Journal of Management and Financial Sciences, issue 26, 27-44."
    location: "Section 4.3, pp. 36-37; day-26 test p=0.0424; conclusion; official SGH archive and complete author copy in source packet"
    quality_tier: B
    role: primary
strategy_type_flags: [calendar-seasonality, day-of-month, short-only, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
period: D1
primary_target_symbols: [XTIUSD.DWX]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
expected_trades_per_year_per_symbol: 9
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: TIER_B
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: BLOCKED_CPU_CEILING
q02_status: NOT_QUEUED
review_focus: "Falsify the source-significant WTI day-26 negative anomaly after costs and CFD/session basis; realized book correlation remains a downstream gate."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
---

# WTI Calendar-Day-26 One-Session Short

## Hypothesis and non-duplicate boundary

Borowski reports day 26 as one of two statistically detected crude-oil
day-of-month anomalies (`p=0.0424`) in NYMEX data through March 2016. This EA
tests the negative day-26 carrier on Darwinex WTI: short only at the opening of
an actual broker D1 bar dated 26 and flatten at the next D1 bar.

This differs from `QM5_20020` (non-significant day-17 extreme), `QM5_20021`
(every second half-month session), weekday systems, monthly regimes, momentum,
inventory events, and WTI spread baskets. Different logic does not assert low
correlation; Q09 remains authoritative.

## Frozen rules

- Host `XTIUSD.DWX` D1, slot 0. On an actual date 26 consume the monthly
  attempt before fallible gates; never shift an absent 26th or retry a block.
- SELL once with a hard stop `2.75 * ATR(20)` from the prior completed D1 bar,
  spread cap 2500 points, no take-profit.
- Close at the first following D1 bar; retry during that bar and use a one-day
  stale guard. Framework Friday close remains enabled at broker hour 21.
- No price filter, sweep, trailing, scale, grid, martingale, ML, or external
  runtime data.

## Risk and kill criteria

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, weight 1. Retire below five
completed packages/year, on wrong-date/duplicate entries, nondeterminism, or
failure of governed PF/DD criteria. Multiple testing, post-2016 decay,
continuous-future/CFD basis, broker date mapping, gaps, costs and financing are
explicit falsification risks.

## Framework alignment

- no_trade: exact symbol/D1/slot and locked inputs.
- trade_entry: restart-safe exact-date attempt, short, frozen ATR stop.
- trade_management: next-D1 and stale close before entry/news gates.
- trade_close: framework close API, Friday close, broker hard stop.

## Safety boundary

Backtest/Q02 only. No live setfile, T_Live access, AutoTrading, deploy manifest,
portfolio admission, or portfolio-gate modification is authorized.

## Pipeline history

| version | date | phase | verdict |
|---|---|---|---|
| v1 | 2026-07-21 | build | strict compile PASS, 0 errors/0 warnings |
| v1 | 2026-07-21 | Q01/Q02 | BLOCKED_CPU_CEILING; nine T-slots active, no manual smoke or Q02 enqueue |
