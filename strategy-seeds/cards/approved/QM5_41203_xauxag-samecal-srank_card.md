---
card_schema_version: 2
type: strategy
strategy_id: KELOHARJU-WILCOXON-XAUXAG-SAMECAL-SR-2026_S01
variant_id: KELOHARJU-WILCOXON-XAUXAG-SAMECAL-SR-2026_S01
source_id: KELOHARJU-WILCOXON-XAUXAG-SAMECAL-SR-2026
ea_id: QM5_41203
slug: xauxag-samecal-srank
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41203_xauxag-samecal-srank_card.md
execution_contract_status: APPROVED
created: 2026-08-29
created_by: Research+Development
last_updated: 2026-08-29
g0_status: APPROVED
g0_decision: decisions/2026-08-29_qm5_41203_xauxag_same_calendar_signed_rank_g0.md
source_approval: decisions/2026-08-29_xauxag_same_calendar_signed_rank_source_approval.md
source_author: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Ana-Maria Fuertes; Joelle Miffre; Georgios Rallis; R Core Team"
source_authors: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Ana-Maria Fuertes; Joelle Miffre; Georgios Rallis; R Core Team"
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), Return Seasonalities, Journal of Finance 71(4), 1557-1590, DOI 10.1111/jofi.12398; Fuertes, Miffre, and Rallis (2010), Tactical Allocation in Commodity Futures Markets, Journal of Banking & Finance 34(10), 2530-2548, DOI 10.1016/j.jbankfin.2010.04.009; pinned R Core stats wilcox.test one-sample signed-rank arithmetic."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Keloharju, M., Linnainmaa, J. T., and Nyberg, P. (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590."
    location: "DOI 10.1111/jofi.12398; complete-read packet strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md"
    quality_tier: A
    role: same_calendar_month_commodity_return_information_and_five_year_floor
  - type: peer_reviewed_trading_paper
    citation: "Fuertes, A.-M., Miffre, J., and Rallis, G. (2010). Tactical Allocation in Commodity Futures Markets: Combining Momentum and Term Structure Signals. Journal of Banking & Finance 34(10), 2530-2548."
    location: "DOI 10.1016/j.jbankfin.2010.04.009; complete-read packet strategy-seeds/sources/FMR-MOMTS-2010/source.md"
    quality_tier: A
    role: xau_xag_cross_sectional_commodity_carrier_and_monthly_hold
  - type: primary_software
    citation: "R Core Team stats implementation and manual for wilcox.test, pinned at source commit bac583951b728e97b9786804d3b4081f0fe18df5."
    location: "complete-read evidence preserved in strategy-seeds/sources/KELOHARJU-WILCOXON-WTI-SAMECAL-SR-2026/source.md"
    quality_tier: A_primary_software
    role: one_sample_signed_absolute_rank_sum_arithmetic
  - type: governed_composite_source
    citation: "QuantMechanica bounded paired XAU/XAG same-calendar signed-rank extraction."
    location: "strategy-seeds/sources/KELOHARJU-WILCOXON-XAUXAG-SAMECAL-SR-2026/source.md"
    quality_tier: internal_governed
    role: exact_synchronized_calendar_endpoints_pair_difference_ties_score_risk_atomicity_and_lifecycle
strategy_mechanic: synchronized-prior-ten-year-same-calendar-month-xau-minus-xag-log-return-differences-strict-absolute-ranks-centered-signed-rank-direction-monthly-two-leg-basket-renewal
sources:
  - "[[sources/KELOHARJU-WILCOXON-XAUXAG-SAMECAL-SR-2026]]"
concepts:
  - "[[concepts/same-calendar-month-seasonality]]"
  - "[[concepts/nonparametric-signed-rank]]"
  - "[[concepts/precious-metals-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/signed-absolute-rank-sum]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, calendar-seasonality, same-calendar-month, signed-rank, relative-value, market-neutral-style, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals, gold_silver_relative_value]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41203_XAU_XAG_SAMECAL_SR_D1
symbol: XAUUSD.DWX
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 412030000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 10-12 completed XAU/XAG packages per full post-warm-up year; invalid synchronized history, epsilon-zero differences, absolute ties, or a centered-zero score consume the month flat."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_STATISTIC_PAIR_AND_CFD_TRANSLATION_RISK
r1_reasoning: "Two complete peer-reviewed trading lineages support same-calendar commodity information and the XAU/XAG carrier; complete pinned R Core source and manual fix the statistic. The exact paired CFD conjunction remains untested."
r2_mechanical: PASS
r2_reasoning: "Month clock, synchronized endpoint identity, exact Y-1..Y-10 bound, sample floor, epsilon, strict absolute ranks, centered score, pair side, consumed attempt, aggregate fixed risk, atomicity, stops, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_qualification: LONG_WARMUP_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered XAUUSD.DWX and XAGUSD.DWX D1 histories and native MT5 state supply every runtime input; synchronized warm-up, rolls, financing, and futures/CFD basis remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, sorting, comparisons, integer arithmetic, ATR risk controls, and execution state; no trained signal, banned signal indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: prior 10 exact same-calendar years; minimum 5 synchronized differences; return/tie epsilon 1e-12; 3000 D1 history bars; ATR(20)*3.5 per-leg stops; 40-day stale exit; XAU/XAG spread ceilings 1500/3000 points; one shared RISK_FIXED budget."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q01
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED_Q01_PENDING
force_build: true
review_focus: "Falsify a paired XAU/XAG same-calendar signed-rank relative-value sleeve outside the directional XAU/SP500/NDX/XNG book. Verify synchronized completed endpoints, exact Y-1..Y-10 samples, five-pair floor, difference orientation, zero/tie rejection, strict ranks, centered score side, consumed month, aggregate fixed risk, atomic opposite legs, frozen stops, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, exact_prior_year_same_calendar_months, synchronized_cross_leg_endpoints, completed_month_endpoints, no_current_month_price, paired_relative_return_orientation, five_sample_floor, ten_year_cap, return_zero_epsilon, strict_absolute_rank_ties, positive_rank_sum, centered_score_invariants, paired_long_short_side, monthly_attempt_state, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, friday_close_disabled, next_month_exit, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-29 and decisions/2026-08-29_qm5_41203_xauxag_same_calendar_signed_rank_g0.md: R1 passes with complete peer-reviewed same-calendar and XAU/XAG lineages plus complete pinned primary software arithmetic; R2 locks calendar, synchronized endpoints, samples, differences, strict ranks, score, pair side, attempt, risk, atomicity, stops, and lifecycle; R3 uses registered native XAU/XAG D1 with warm-up/synchronization/CFD risk; R4 is deterministic native arithmetic only. Canonical dedup found only the expected mean-carrier and WTI-statistic neighbors, and fixed fixtures plus load-bearing pair exposure resolve both."
---

# QM5_41203 XAU/XAG Paired Same-Calendar Signed-Rank Seasonality

## Hypothesis

Gold and silver share precious-metal and USD drivers but differ in monetary,
safe-haven, industrial, and business-cycle exposure. Those relative pressures
may recur in the same calendar month. Rather than let one extreme historical
year dominate the relative seasonal estimate, this card ranks the absolute
size of synchronized prior-year XAU-minus-XAG month returns and follows the
sign whose observations own the greater rank mass.

Opposite metal legs target the relative seasonal component while reducing
common outright-metal direction. They do not prove dollar, beta, volatility,
factor, market, or portfolio neutrality. Q02 owns activity and economics;
unchanged Q09 alone owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The approved bounded packet is
`strategy-seeds/sources/KELOHARJU-WILCOXON-XAUXAG-SAMECAL-SR-2026/source.md`,
SHA-256
`A4FB73EBF5AB394F64A6FCB0BA791FD10BD12496732AB7AE661068AC6A28486F`,
authorized by
`decisions/2026-08-29_xauxag_same_calendar_signed_rank_source_approval.md` at
commit `0ca4b819a` before extraction.

Keloharju, Linnainmaa, and Nyberg supply recurring same-calendar commodity
information and a five-year history floor. Fuertes, Miffre, and Rallis supply
the governed XAU/XAG cross-sectional carrier and monthly hold. The pinned R
Core implementation and manual supply one-sample signed absolute-rank
arithmetic. None tests this exact paired CFD basket.

No source return, alpha, probability, p-value, significance, density, profit
factor, drawdown, cost, hedge ratio, CFD equivalence, decorrelation, or
portfolio statistic transfers.

## Non-Duplicate Decision

The canonical checker scanned 4,702 registry identities, 1,348 cards, and 45
Strategy Wiki nodes. It found no exact collision and surfaced the expected
fuzzy neighbors `QM5_20186_xauxag-samecal` and
`QM5_41191_wti-samecal-srank`. Receipt:
`artifacts/qm5_xauxag_samecal_srank_preallocation_dedup_20260829.json`.

- `QM5_20186` follows the arithmetic mean of synchronized XAU-minus-XAG
  returns. On `[.01,.02,.03,.04,-.20]`, this card buys (`S=5`) while the mean
  rule sells.
- `QM5_41191` ranks one WTI return series and owns one oil position. This card
  ranks paired metal-return differences and owns two opposite metal legs.
- `QM5_41177` compares two independent recent-window samples with a
  Mann-Whitney/rank-sum state; it is not the paired one-sample signed-rank
  statistic and has no prior-year same-calendar sample.
- Ratio z-score, OLS/CADF residual, channel, current-month rank/shift,
  weekday, weekend, and contiguous-momentum XAU/XAG EAs use different state
  functions.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_PAIRED_SAMECAL_SIGNED_ABSOLUTE_RANK_SUM_MONTHLY_BASKET_RENEWAL`.

## Markets, Timeframe, And Cadence

- Logical basket: `QM5_41203_XAU_XAG_SAMECAL_SR_D1`.
- Host/slot 0: exact `XAUUSD.DWX`, D1, magic `412030000`.
- Companion/slot 1: exact `XAGUSD.DWX`, D1, magic `412030001`.
- Decision: first tradable host D1 bar after a genuine broker-month boundary.
- Formation: same target month in exact years `Y-1..Y-10`, minimum five
  synchronized paired observations.
- Hold: next broker-month boundary; 40 elapsed days is stale repair.
- Expected pre-result cadence: ten to twelve packages/year after warm-up;
  Q02 retires below five in any full post-warm-up year.

## Formula

For target month `M` in historical year `H`:

```text
r_xau(H,M) = ln(xau_month_end_close / xau_prior_month_end_close)
r_xag(H,M) = ln(xag_month_end_close / xag_prior_month_end_close)
d(H,M)     = r_xau(H,M) - r_xag(H,M)

collect valid synchronized d(Y-k,M), k=1..10
require 5 <= n <= 10
require abs(d[k]) > 1e-12
require abs(abs(d[i])-abs(d[j])) > 1e-12 for every i != j

rank abs(d[k]) strictly from 1 through n
V_plus = sum(rank[k] where d[k] > 0)
T      = n*(n+1)/2
S      = 2*V_plus-T

S > 0 => BUY XAU, SELL XAG
S < 0 => SELL XAU, BUY XAG
S = 0 => FLAT
```

Score magnitude never changes risk. Exact epsilon zeros and absolute ties
consume the month flat; no mean, median, hit-rate, average-rank, p-value, or
location fallback is authorized.

## Rules

These rules are the complete baseline. No ratio/residual fit, fixed favorable
month, recent-return confirmation, trend, breakout, oscillator, inventory,
event, curve, volume, volatility signal, optimizer artifact, or external-data
filter is authorized.

## 4. Entry Rules

1. Evaluate only on exact `XAUUSD.DWX`, D1, EA 41203, slot 0; select exact
   companion `XAGUSD.DWX` and both registered magic rows.
2. Process malformed and later-month owned exposure before every entry gate.
3. Enter only on the first host D1 bar after a genuine broker-month
   transition. Mid-month attachment remains flat until the next boundary.
4. Persist broker `yyyymm` before history, signal, news, spread, quote, ATR,
   sizing, margin, or submission. Never retry the month after any downstream
   outcome or restart.
5. Copy at most 3,000 completed D1 bars per leg. For each exact year
   `Y-1..Y-10`, select the final D1 close in target month `M`, its immediate
   prior D1 close in the adjacent preceding month, and a following D1 bar in
   the adjacent next month on both legs. Require matching endpoint timestamps.
6. Skip an invalid or unsynchronized year without substitution. Require five
   to ten finite paired relative returns.
7. Reject every epsilon-zero difference and every epsilon-level absolute
   difference tie. Sort observation indexes by absolute difference, assign
   strict ranks 1 through `n`, and prove the rank total is `n(n+1)/2`.
8. Sum positive-difference ranks and compute the centered score exactly.
   Positive buys XAU/sells XAG; negative sells XAU/buys XAG; zero consumes the
   month flat.
9. Require completed D1 ATR(20), valid executable quotes, and genuinely
   positive spreads no greater than 1,500 XAU points and 3,000 XAG points.
10. Split one aggregate fixed-risk budget equally by per-leg stop risk and
    attach frozen `3.5*ATR(20,D1)` hard stops. No target is authorized.
11. Prepare both legs before submission. Open the host leg first and the
    companion second. If either submission fails or final composition is not
    exactly two opposite legs, flatten the package immediately.
12. No retry, pending order, scale-in, grid, martingale, pyramid, same-side
    hedge, or third leg exists.

## 5. Exit Rules

1. At the first observed host D1 bar in a later broker month, close both old
   legs before evaluating the new month.
2. Close both legs after 40 elapsed calendar days as a final stale guard.
3. Immediately flatten an orphan, duplicate leg, same-direction pair,
   wrong-symbol, wrong-magic, invalid-volume, missing-stop, or invalid-open-
   time package.
4. Frozen per-leg broker hard stops and the framework kill switch remain
   authoritative.
5. Framework Friday close is disabled for the monthly hold.
6. No target, reversal, trailing stop, break-even move, partial exit, or
   discretionary close is authorized.

## 6. Filters (No-Trade Module)

- Exact host, D1, EA 41203, slot 0, companion symbol, and registered magics.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes are OFF; the signal uses completed native price history.
- Genuine month boundary, durable attempt, synchronized endpoint identity,
  sample floor, zero/tie checks, rank invariants, score, quote, spread, ATR,
  lot, and stop geometry must be valid.
- Failure after attempt persistence consumes the month.

## 7. Trade Management Rules

- Own exactly one XAU leg and one oppositely directed XAG leg under magics
  `412030000` and `412030001`.
- One aggregate `RISK_FIXED=1000` package budget is split equally by stop
  risk. No claim of exact dollar or beta neutrality is made.
- Freeze both hard stops; never widen, trail, remove, or re-size them.
- Run malformed, later-month, and 40-day survivor repair every tick before
  entry logic.
- Persist the last attempted broker `yyyymm` in terminal global state so a
  restart cannot create a second monthly attempt.
- Do not add, pyramid, grid, partially close, or reverse.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_xag_symbol` | XAGUSD.DWX | exact companion |
| `strategy_history_years` | 10 | exact prior-year cap |
| `strategy_min_observations` | 5 | synchronized sample floor |
| `strategy_signal_epsilon` | 1e-12 | difference-zero and absolute-tie boundary |
| `strategy_history_bars_d1` | 3000 | bounded endpoint reconstruction per leg |
| `strategy_atr_period_d1` | 20 | completed per-leg risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen per-leg hard-stop distance |
| `strategy_max_hold_days` | 40 | stale repair only |
| `strategy_xau_max_spread_points` | 1500 | XAU entry cost guard |
| `strategy_xag_max_spread_points` | 3000 | XAG entry cost guard |
| `strategy_deviation_points` | 20 | basket market-order deviation |
| `qm_friday_close_enabled` | false | preserve monthly hold |

No sweep, statistic fallback, month selection, endpoint, difference
orientation, direction, sample bound, epsilon, stop, or lifecycle change is
authorized.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Split the package budget equally by per-leg frozen stop risk.
- Per-leg hard stop: `3.5*ATR(20,D1)` from completed data; no take-profit.
- If either valid computed lot is below broker minimum, consume the month
  flat. Never inflate package risk to force a fill.
- Two-leg cost, legging, financing, gaps, stop asymmetry, narrow breadth,
  continuous-CFD basis, and common-metal beta can erase the premise.
- This card creates no live, demo, shadow, stress, or optimization preset.

## Data Requirements

Native synchronized `XAUUSD.DWX` and `XAGUSD.DWX` D1 OHLC/timestamps, broker
clock, symbol quotes/properties, positions, deal history, and terminal-global
attempt state only. No futures curve, inventory, volume, open interest, event
feed, API, CSV, optimizer artifact, trained output, or manual signal input.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS_WITH_STATISTIC_PAIR_AND_CFD_TRANSLATION_RISK | Complete peer-reviewed same-calendar and XAU/XAG carrier lineages plus complete pinned primary software for the statistic; exact conjunction untested. |
| R2 | PASS | Calendar, synchronized endpoints, difference orientation, sample, ties, ranks, score, pair side, attempt, aggregate risk, atomicity, and lifecycle locked. |
| R3 | PASS_WITH_LONG_WARMUP_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK | Registered native XAU/XAG D1 and MT5 state supply every runtime field. |
| R4 | PASS | Deterministic native arithmetic and state only; no trained signal, banned signal indicator, or external runtime feed. |

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, boundary, attempt, synchronized history, differences, ranks, score, pair side, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, orphaned, later-month, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus basket lifecycle helpers |
| monthly renewal and survivor repair | Trade Close | basket close helper; Friday close disabled |
| kill switch, ownership, aggregate fixed-risk mode | Framework No-Trade | standard framework orchestration plus registered basket magics |
| news OFF | News hooks | `Strategy_NewsFilterHook` returns false; both modes OFF |

## Kill Criteria

Retire rather than tune on fewer than five completed packages per full post-
warm-up year; zero trades; nonpositive governed economics; wrong or partial
monthly endpoints; current-month leakage; cross-leg timestamp mismatch;
invalid sample count; zero/tie contract breach; wrong rank, invariant, score,
or side; retry; orphan persistence; same-direction legs; missing stop; wrong
monthly lifecycle; nondeterminism; or registry/risk mismatch.

No weak result may be rescued by reverting to the mean, median, hit rate,
ratio or residual fit, selecting months, adding recent trend/return,
inventory, event, curve, volume, volatility, or price-action filters,
changing the sample, or extending the hold.

## Validation Plan

Q01 must prove:

1. only the genuine broker-month boundary may enter and same-calendar returns
   use completed adjacent-month endpoints for exact years `Y-1..Y-10`, with
   December/January wrapping and no current-month price;
2. both legs select identical endpoint timestamps and invalid years are
   skipped without substitution;
3. five-to-ten sample bounds, epsilon-zero rejection, absolute-tie rejection,
   strict rank assignment, rank-total invariant, centered score, and pair side;
4. the governed disagreement vector distinguishes the mean neighbor and the
   paired state/exposure distinguish the direct-WTI neighbor;
5. persistent `yyyymm` attempts prevent same-month retry after every
   downstream failure and restart;
6. aggregate fixed-risk sizing uses two valid frozen completed-bar ATR stops;
7. second-leg failure, orphan, same-side, missing-stop, later-month, and stale
   repair flatten the complete owned package;
8. the basket manifest routes one logical symbol to the XAU host and both
   traded symbols; and
9. strict compile, card lint, build checks, setfile schema, magic resolver,
   reference vectors, and static Q01 validation pass.

Q02 alone may measure density and baseline economics. Q09 alone may establish
realized portfolio correlation.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-29 | initial paired XAU/XAG same-calendar signed-rank card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-29 | APPROVED; R1-R4 PASS | `decisions/2026-08-29_qm5_41203_xauxag_same_calendar_signed_rank_g0.md`; approved source packet |
| Q01 Build Validation | 2026-08-29 | NOT_BUILT | deterministic magic allocation and build pending |
| Q02 Baseline Screening | 2026-08-29 | NOT_ENQUEUED_Q01_PENDING | no work item before compile/review PASS |

## Safety Boundary

This card authorizes one branch-only non-live build, deterministic two-slot
magic allocation, strict Q01 validation, one logical-basket `RISK_FIXED` D1
backtest setfile, and one paced Q02 enqueue only after prerequisites and a
non-binding CPU check. It does not authorize a manual backtest, live/demo/
shadow/stress/optimization preset, AutoTrading, `T_Live`, deploy or live
manifest, portfolio-gate change, portfolio admission, correlation waiver,
terminal control, or queue deletion.
