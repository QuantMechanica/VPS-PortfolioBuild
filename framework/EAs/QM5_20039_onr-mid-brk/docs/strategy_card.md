---
card_schema_version: 2
ea_id: QM5_20039
slug: onr-mid-brk
status: DRAFT
g0_status: APPROVED
symbol: SP500.DWX
timeframe: M5
variant_id: ONR_MID_BRK_BASELINE
execution_contract_ref: framework/registry/dxz23_execution_contracts.json#ea_id=20039
execution_contract_status: DRAFT
target_symbols: [SP500.DWX, NDX.DWX]
expected_trades_per_year_per_symbol: 200
g0_approval_reasoning: "R1 Zarattini-Aziz 2023 SSRN 4416622 DOI 10.2139/ssrn.4416622 with midpoint explicitly UNVERIFIED; R2 mechanical overnight-to-16:00 ET breakout window; R3 SP500.DWX and NDX.DWX M5 ticks; R4 deterministic hypothesis, no ML"
last_updated: 2026-07-22
expected_pf: 1.25
expected_dd_pct: 12.0
source_id: ZARATTINI-AZIZ-2023
ml_required: false
r1_track_record: PASS
r1_reasoning: "SSRN 4416622 (2023), DOI 10.2139/ssrn.4416622 provides transparent ORB lineage; quality tier C reflects that the overnight midpoint filter is an unverified QM repair hypothesis, not a paper result."
r2_mechanical: PASS
r2_reasoning: "Mechanical M5 overnight range, 09:30 midpoint side lock, closed-bar boundary break, next-bar entry, immutable midpoint stop, and official cash-close time exit."
r3_data_available: PASS
r3_reasoning: "SP500.DWX and NDX.DWX M5 real-tick histories and DST-aware US session calendars are available for DEV 2018-2023, OOS 2024, and sealed 2025."
r4_ml_forbidden: PASS
r4_reasoning: "Deterministic range/midpoint state with RISK_FIXED sizing, one position per magic, and no grid, martingale, adaptive side selection, or ML."
source_citations:
  - type: academic_paper
    citation: "Zarattini, C. & Aziz, A. (2023). Can Day Trading Really Be Profitable? Evidence of Sustainable Long-term Profits from Opening Range Breakout (ORB) Day Trading Strategy vs. Benchmark in the US Stock Market. SSRN 4416622. DOI 10.2139/ssrn.4416622."
    location: "First-five-minute opening-range breakout lineage; it does not establish the overnight range or midpoint side-filter edge."
    quality_tier: C
    role: primary
---

# Overnight-range breakout with midpoint side filter

## Source-defined rules

Zarattini and Aziz (2023), *Can Day Trading Really Be Profitable? Evidence of
Sustainable Long-term Profits from Opening Range Breakout (ORB) Day Trading
Strategy vs. Benchmark in the US Stock Market*, SSRN 4416622, DOI
https://doi.org/10.2139/ssrn.4416622, study a first-five-minute opening-range
breakout. The source does not document an overnight range, a 09:30 open versus
overnight-midpoint side filter, a midpoint stop, or an approximately 76%
first-break statistic.

The CME Micro E-mini equity-index FAQ documents the Sunday-Friday
18:00-17:00 ET Globex clock at
https://www.cmegroup.com/articles/faqs/micro-e-mini-equity-index-futures-frequently-asked-questions.html.
That URL anchors the overnight-start operationalization only; it does not
validate a midpoint edge on `SP500.DWX` or `NDX.DWX` CFDs.

**Midpoint side-filter is an UNVERIFIED hypothesis (tests Balke/ORB Q05-DD repair).**
It is a preregistered QM repair hypothesis, not an established source edge.

## QM interpretations

Every rule in this section belongs to variant `ONR_MID_BRK_BASELINE`.

- **Overnight range.** Use `America/New_York` and the official US trading
  calendar. For a cash date, collect valid quotes in `[18:00 previous US
  trading-session evening,09:30 current cash date)` ET; Monday begins Sunday
  18:00. Immediately before 09:30 freeze `ON_high`, `ON_low`, and
  `ON_mid=(ON_high+ON_low)/2`. Missing ticks, zero range, non-monotonic data,
  holiday ambiguity, or a clock error fails closed.
- **Side hypothesis.** Set `RTH_open` to the first valid executable midquote at
  or after 09:30. It must lie strictly inside `[ON_low,ON_high]`; a gap at or
  outside either boundary gives no trade. Arm LONG only when
  `RTH_open > ON_mid` and SHORT only when `RTH_open < ON_mid`. Equality after
  tick-size normalization gives no trade, and the side cannot flip intraday.
- **Entry.** Starting with the completed `[09:30,09:35)` `M5` bar, LONG
  requires the first close strictly above `ON_high`; SHORT requires the first
  close strictly below `ON_low`. Wicks do not qualify. A completed close
  through the unarmed boundary cancels the cash date. Enter at the next `M5`
  open only if it is strictly before the official 16:00 ET close or approved
  early close. Maximum one attempt per symbol/cash date; no re-entry.
- **Stop and time exit.** The immutable broker hard stop for both directions is
  `ON_mid`. If the actual fill is at or beyond the midpoint in the risk
  direction, or monetary risk is non-positive, do not enter. There is no profit
  target, trailing stop, breakeven move, scaling, averaging, or partial close.
  Force-flat at the first tradable quote at or after 16:00 ET; an official
  early close replaces it. Resolve stop/time collisions from executable
  bid/ask tick chronology.
- **Sizing and cost.** Size once from the setfile's locked `RISK_FIXED` amount
  and actual fill-to-`ON_mid` monetary distance; `RISK_PERCENT` is not
  authorized. Resolve current per-symbol commission, spread, tick value,
  conversion, lot step, and stop constraints from governed runtime data.
  Require `(commission + spread) / initial_monetary_risk <= 0.10R`; missing
  data or an unrepresentable volume blocks entry.
- **Density and risk family.** Approximately 200 trades/year/symbol is an
  honest, untested prior after the side, breakout, and cost gates. SP500 and
  NDX are one correlated US-index ORB family with a shared exposure cap; they
  are not independent portfolio credits.

## Framework execution overrides

- The framework emergency/account kill switch disables entries and may flatten
  an open position before the midpoint stop or card time exit.
- The default framework news pause remains active and may block an entry; it
  cannot delay-enter after the authorized next `M5` open.
- The official early-close calendar replaces the normal card exit and blocks
  any entry that cannot occur strictly before that close. The framework Friday
  safety close remains enabled after the same-day card exit.
- No two-sided OCO, first-five-minute candle-direction rule, volume rank, Balke
  trail, grid, martingale, pyramid, or loss-dependent sizing override is
  authorized.

## Exit precedence

1. Framework emergency/account kill-switch close.
2. Executed broker hard stop at frozen `ON_mid`.
3. Official US cash close at 16:00 ET or approved early close; after restart or
   rejected close, retry immediately before any entry evaluation.
4. Framework Friday safety close if a position somehow remains open.
5. Calendar expiry or overnight-data/hash failure blocks new entries only; it
   never removes the midpoint stop or deterministic close from an open trade.

## Runtime data dependencies

- Primary chart, signal, and order route: `SP500.DWX`, `M5`.
- Sibling symbol — **per-symbol setfile to generate at build**: `NDX.DWX`.
  Generate one setfile for each target. Each route owns its overnight range,
  side lock, attempt key, position, stop, and cost state; the portfolio applies
  the shared correlated-index cap.
- Synchronized real ticks must span the complete ET overnight interval as well
  as the US cash session. Runtime needs executable bid/ask, first 09:30
  midquote, tick value, account-currency conversion, volume step, stop level,
  commission schedule, and current spread per symbol.
- Pin an IANA timezone database covering `America/New_York` and a provenance-
  locked official US cash/holiday/early-close calendar with
  `valid_through=2025-12-31`. Ambiguous or nonexistent conversions fail closed.
- `SP500.DWX` and `NDX.DWX` real-tick datasets must cover DEV 2018-2023, OOS
  2024, and untouched sealed 2025, each with
  `valid_through=2025-12-31`. No external overnight statistic or ML service is
  required.

## Falsification and requalification

- Freeze DEV 2018-2023, OOS 2024, and untouched sealed 2025. Report each
  symbol, LONG/SHORT, inside-range exclusions, gap exclusions, and calendar
  year separately. Do not select the overnight start, side rule, or stop after
  observing OOS or sealed data.
- Compare the midpoint-filter baseline head-to-head on common dates with an
  otherwise identical unfiltered ORB and with the Balke/ORB Q05-DD sleeve.
  Reject if the midpoint-filter increment is not positive, if its drawdown
  repair fails in 2024/2025, or if the unsupported 76% statistic is needed.
- Apply governed nonzero commission and historical spread, then shift entry and
  exit one tick adversely. Reject if OOS or sealed expectancy is not positive
  or any admitted trade requires `cost_R > 0.10R`.
- Dedup boundary: unlike `QM5_13301_balke-minute-range-breakout`, this card uses
  the US Globex overnight range, permits only the side hypothesized by the
  09:30 open versus frozen midpoint, confirms on a closed `M5` bar, fixes the
  stop at that midpoint, exits at the cash close, and never trails. Changed
  hours alone do not create new density.
- Any change to overnight membership, clocks, range or midpoint calculation,
  09:30 open definition, side rule, boundary confirmation, entry time, stop,
  exit, cost model, risk mode, symbol route, or variant identity requires a new
  binary, tick/calendar reconciliation, head-to-head repair test, and full
  portfolio requalification. An unresolved item is `BLOCKED`; Development may
  not fill it in.
