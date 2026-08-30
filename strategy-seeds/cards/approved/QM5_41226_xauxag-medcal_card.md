---
card_schema_version: 2
type: strategy
strategy_id: KELOHARJU-XAUXAG-MEDCAL-2026_S01
variant_id: KELOHARJU-XAUXAG-MEDCAL-2026_S01
source_id: KELOHARJU-FMR-XAUXAG-SAMECAL-2026
ea_id: QM5_41226
slug: xauxag-medcal
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41226_xauxag-medcal_card.md
execution_contract_status: APPROVED
created: 2026-08-30
created_by: Research+Development
last_updated: 2026-08-30
g0_status: APPROVED
g0_decision: decisions/2026-08-30_qm5_41226_xauxag_median_same_calendar_g0.md
source_approval: decisions/2026-08-30_xauxag_median_same_calendar_source_approval.md
source_author: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Ana-Maria Fuertes; Joelle Miffre; Georgios Rallis"
source_authors: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Ana-Maria Fuertes; Joelle Miffre; Georgios Rallis"
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), Return Seasonalities, The Journal of Finance 71(4), 1557-1590, DOI 10.1111/jofi.12398; Fuertes, Miffre, and Rallis (2010), Tactical Allocation in Commodity Futures Markets, Journal of Banking & Finance 34(10), 2530-2548, DOI 10.1016/j.jbankfin.2010.04.009."
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
  - type: governed_composite_source
    citation: "QuantMechanica bounded XAU/XAG same-calendar relative-seasonality extraction."
    location: "strategy-seeds/sources/KELOHARJU-FMR-XAUXAG-SAMECAL-2026/source.md"
    quality_tier: internal_governed
    role: synchronized_calendar_endpoints_relative_orientation_risk_atomicity_and_lifecycle
strategy_mechanic: synchronized-five-to-ten-prior-year-same-calendar-month-xau-minus-xag-relative-log-return-sample-median-sign-monthly-opposite-leg-basket-renewal
sources:
  - "[[sources/KELOHARJU-FMR-XAUXAG-SAMECAL-2026]]"
concepts:
  - "[[concepts/same-calendar-month-seasonality]]"
  - "[[concepts/robust-order-statistic]]"
  - "[[concepts/precious-metals-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/sample-median]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, calendar-seasonality, same-calendar-month, robust-median, relative-value, market-neutral-style, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals, gold_silver_relative_value]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41226_XAU_XAG_MEDCAL_D1
symbol: XAUUSD.DWX
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 412260000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 10-12 completed XAU/XAG packages per full post-warm-up year; an exact median inside the epsilon band consumes the month flat. Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_ROBUST_LOCATION_SMALL_SAMPLE_AND_CFD_TRANSLATION_RISK
r1_reasoning: "Two complete-read peer-reviewed lineages support recurring same-calendar commodity information and the governed XAU/XAG opposite-leg carrier. The ordinary sample median and exact two-CFD conjunction are disclosed untested robustness translations."
r2_mechanical: PASS
r2_reasoning: "Month clock, uniform D1-label normalization, synchronized exact-year endpoints, five-to-ten sample bound, odd/even median arithmetic, relative orientation, epsilon side map, consumed attempt, aggregate fixed risk, atomicity, stops, and lifecycle are deterministic and locked."
r3_data_available: PASS_WITH_LONG_WARMUP_SYNCHRONIZATION_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK
r3_reasoning: "Registered native XAUUSD.DWX and XAGUSD.DWX D1 histories plus broker time, quotes, symbol metadata, positions, deals, and terminal state supply every runtime field. Warm-up, label, roll, financing, fill, legging, and CFD-basis risks remain binding."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, sorting, comparisons, ATR risk controls, quotes, and execution state; no trained signal, banned signal indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: exact prior 10-year same-calendar search cap; minimum 5 synchronized XAU-minus-XAG returns; ordinary odd/even sample median; strict absolute median above 1e-12; 3000 D1 history bars per leg; ATR(20)*3.5 per-leg stops; 40-day stale repair; XAU/XAG spread ceilings 1500/3000 points; one shared RISK_FIXED budget."
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
review_focus: "Falsify a robust XAU/XAG recurring-calendar relative-value sleeve outside the directional XAU/SP500/NDX/XNG book. Verify synchronized normalized endpoints, exact-year bounds, XAU-minus-XAG orientation, ordinary median arithmetic, consumed month, aggregate fixed risk, atomic opposite legs, frozen stops, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, uniform_metal_label_normalization, exact_prior_year_same_calendar_months, synchronized_cross_leg_endpoints, completed_month_endpoints, no_current_month_price, paired_relative_return_orientation, five_sample_floor, ten_year_cap, even_odd_median, epsilon_side_map, paired_long_short_side, monthly_attempt_state, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, friday_close_disabled, next_month_exit, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-30 and decisions/2026-08-30_qm5_41226_xauxag_median_same_calendar_g0.md: R1 passes with two complete peer-reviewed lineages and explicit robust-location/CFD translation risk; R2 locks calendar, synchronization, exact years, sample, ordinary median, side, attempt, risk, atomicity, stops, and lifecycle; R3 uses registered native XAU/XAG D1 with warm-up/synchronization/CFD risks explicit; R4 is deterministic native arithmetic only. Canonical dedup returned CLEAN; fixed disagreement vectors separate the raw mean, Huber, sign-score, t-score, and signed-rank siblings."
---

# QM5_41226 XAU/XAG Median Same-Calendar Relative Seasonality

## Hypothesis

Recurring fabrication demand, monetary demand, hedging, production, and
capital-allocation pressures can make gold and silver returns differ by
calendar month. A metric historical mean can be controlled by one shock year.
This card instead asks whether the central synchronized XAU-minus-XAG return
for the upcoming named calendar month has a stable direction across five to
ten prior years, then holds an opposite-leg package through that month.

Opposite legs aim to suppress common precious-metal and USD direction while
retaining relative monetary-gold versus industrial-silver seasonality. That is
a construction objective, not proof of dollar, beta, volatility, or portfolio
neutrality. Q02 owns density and baseline economics; unchanged Q09 alone owns
realized portfolio overlap.

## Source Traceability And Claim Boundary

The approved bounded packet is
`strategy-seeds/sources/KELOHARJU-FMR-XAUXAG-SAMECAL-2026/source.md`, SHA-256
`9266E47C7F3235D900C9432FEAC33A417807AE1E2CC9685FF2FEADAB46DBF75E`, last
committed as `d3d5aa3a14fac157d97a96fc3c35f1662650dcb6`. The candidate-specific
source approval is
`decisions/2026-08-30_xauxag_median_same_calendar_source_approval.md`, commit
`01dd23e25`.

Keloharju, Linnainmaa, and Nyberg supply recurring same-calendar commodity
information, monthly renewal, and a five-year history floor. Fuertes, Miffre,
and Rallis supply the governed XAU/XAG cross-sectional carrier and one-month
opposite-leg translation. Neither supplies the ordinary-median estimator or
tests this narrow Darwinex CFD package.

No source or sibling return, alpha, significance, profit factor, drawdown,
trade count, cost, hedge, CFD equivalence, or correlation statistic transfers.
The median, epsilon, shared risk, spread caps, stops, and lifecycle are
pre-result QM falsification choices.

## Source-Defined Rules

- Recurring same-calendar commodity returns are estimated only from the same
  named month in prior years, with at least five observations and monthly
  renewal.
- The governed XAU/XAG carrier uses opposite commodity legs for one calendar
  month.
- No source defines the ordinary median, exact ten-year cap, CFD risk split,
  hard stops, spread limits, or portfolio admission.

## QM Interpretations

- Translate the lineages into an opposite-leg `XAUUSD.DWX` / `XAGUSD.DWX`
  basket so the signal targets relative metal performance.
- Lock exact years `Y-1..Y-10`, skip missing synchronized pairs without
  substitution, and require at least five observations.
- Use the ordinary sample median: the middle sorted value for odd `n`, and the
  arithmetic mean of the two middle sorted values for even `n`.
- Use one shared `RISK_FIXED=1000` budget, frozen per-leg ATR stops, atomic
  package handling, and next-month renewal as governed execution choices.
- Treat market neutrality and portfolio decorrelation as objectives only;
  unchanged Q09 remains the sole realized-correlation authority.

## Formula

At broker-month decision `(Y,M)`, reconstruct calendar-month `M` relative
returns in exact years `Y-1..Y-10`:

```text
d_i = ln(XAU_end_i / XAU_prior_end_i)
      - ln(XAG_end_i / XAG_prior_end_i)

ordered = sort_ascending(valid d_i), 5 <= n <= 10
median  = ordered[n/2]                         when n is odd
median  = (ordered[n/2-1] + ordered[n/2]) / 2 when n is even

median > +1e-12 => BUY XAU, SELL XAG
median < -1e-12 => SELL XAU, BUY XAG
otherwise        => FLAT
```

Require matching completed endpoints across both legs, positive finite
prices, finite relative returns, and a finite median. Raw mean, Huber
location, sample t-score, signed rank, Bernoulli sign score, ratio z-score,
current-month data, or contrarian side is not equivalent.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_xauxag_medcal_preallocation_dedup_20260830.json`, SHA-256
`3989F7EBA257EF1FEAD63D8A4ABCE61FDE6AA6F6B61BB8DFEC9067B5011024EB`, found
no exact or above-threshold fuzzy identity across 4,725 registry rows, 1,363
cards, and 45 Strategy Wiki nodes.

- `QM5_20186_xauxag-samecal` follows the metric mean. With
  `[+0.01,+0.01,+0.01,+0.01,-0.20]`, it sells XAU while this median buys XAU.
- `QM5_41206_xauxag-samecal-huber10` requires ten values, a positive robust
  scale, and iterative weighted location; this card directly selects the
  center of five to ten sorted observations.
- `QM5_41213_xauxag-samecal-signscore` discards magnitude and abstains inside
  a sample-size-aware sign band. With
  `[+0.001,-0.20,-0.20,+0.20,+0.20]`, this card buys XAU while that package is
  flat.
- `QM5_41210_xauxag-samecal-tstat` standardizes a metric mean by sample error;
  the same vector leaves its score near zero while this median is positive.
- `QM5_41203_xauxag-samecal-srank` weights observations by absolute rank.
- Ratio, OLS/CADF, recent-window momentum, channel, session, correlation-break,
  and within-month path baskets observe different state.

Verdict:
`CLEAN_AND_SEMANTICALLY_DISTINCT_XAUXAG_SAMECAL_RELATIVE_SAMPLE_MEDIAN_SIGN_MONTHLY_BASKET`.

## Markets, Timeframe, And Cadence

- Logical basket: `QM5_41226_XAU_XAG_MEDCAL_D1`.
- Host/slot 0: exact `XAUUSD.DWX`, D1, intended magic `412260000`.
- Companion/slot 1: exact `XAGUSD.DWX`, D1, intended magic `412260001`.
- Decision clock: first executable host D1 tick after a genuine normalized
  broker-month transition.
- Formation: exact matching calendar month in `Y-1..Y-10`; at least five
  synchronized relative returns.
- Hold: next genuine broker-month boundary; 40 days is stale repair.
- Expected pre-result cadence: approximately ten to twelve packages/year after
  warm-up; Q02 retires below five in any full scored year.

## Rules

The entry, exit, filter, and lifecycle rules below are the complete authorized
baseline. There is no signal-parameter sweep or fallback estimator.

### Entry Rules

1. Require exact EA ID `41226`, exact `XAUUSD.DWX` D1 host, slot 0, both
   registered symbols, locked inputs, fixed-risk mode, both news axes OFF,
   legacy news OFF, and Friday close OFF.
2. Process malformed exposure and prior-month liquidation before entry-only
   gates. Evaluate only after a genuine normalized broker-month transition.
3. Accept one uniform native or `+1` metal D1-label convention. Require the
   normalized current host D1 date to equal the broker date and apply the same
   offset to every historical endpoint on both legs.
4. Persist current broker `yyyymm` before history, signal, news, spread, quote,
   ATR, sizing, margin, or submission. Never retry after any outcome.
5. Scan exact years `Y-1..Y-10` for calendar month `M`. Require strict
   adjacent-month completed endpoints, confirming following bars, positive
   prices, and cross-leg endpoint timestamp identity. Skip a missing year
   without substitution; require at least five valid pairs.
6. Compute each `d_i=r_xau-r_xag`, sort ascending, and compute the locked
   ordinary median. Reject nonfinite input or output.
7. Buy XAU/sell XAG above `+1e-12`; sell XAU/buy XAG below `-1e-12`;
   equality inside the inclusive band consumes flat. Magnitude never changes
   risk.
8. Require no owned exposure or same-month entry deal, finite non-crossed
   quotes, nonnegative spread no greater than 1,500 XAU points and 3,000 XAG
   points, completed per-leg ATR(20,D1), normalized stops, valid volume
   metadata, and sufficient margin.
9. Split one `RISK_FIXED=1000` package budget into equal fixed-risk halves.
   Attach frozen `3.5*ATR(20,D1)` stops and no targets.
10. Prepare both orders before opening. If preparation, either submission, or
    final composition fails, immediately flatten every owned leg.

### Exit Rules

1. At the first processed host D1 bar of the next normalized broker month,
   close both old legs before evaluating a replacement.
2. Close both legs after 40 elapsed calendar days as final stale repair.
3. Immediately flatten an orphan, same-direction pair, duplicate leg,
   wrong-symbol or wrong-magic leg, invalid side, missing stop, invalid volume,
   or invalid open-time package.
4. Per-leg broker hard stops, framework kill switch, and framework close
   helper remain authoritative.
5. Friday close is disabled because the structural monthly package spans
   weekends.
6. There is no intramonth signal exit, target, trail, break-even, partial
   close, scale-in, grid, martingale, pyramid, stop-and-reverse, or
   discretionary exit.

### Filters And No-Trade Rules

- Wrong host, period, EA ID, slot, locked input, mid-month start, duplicate
  state, invalid label convention, endpoint mismatch, insufficient sample,
  invalid median, epsilon tie, quote, spread, ATR, sizing, or order state
  consumes the persisted month.
- Both news axes and legacy news are OFF; no external calendar or feed is
  consulted. Lifecycle and malformed-package repair are never delayed by
  entry gates.
- No mean, Huber, t-score, signed-rank, sign-score, ratio, trend, oscillator,
  event, volume, curve, inventory, or current-month fallback is allowed.

### Trade Management Rules

- Every tick begins with framework MAE tracking before any guard can return.
- Malformed, cross-month, and stale repair runs before every entry-only gate
  and remains retryable until owned exposure is flat.
- Maintain exactly one XAU and one oppositely directed XAG leg under the two
  registered magics; never manage another EA's or manual trade.
- Entry hard stops never move. Signal changes do not alter an open package
  inside the month.
- Persist the consumed-month ledger in a terminal global variable so restart
  cannot generate a second attempt.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_years` | 10 | maximum exact prior matching-calendar years |
| `strategy_min_observations` | 5 | minimum synchronized relative returns |
| `strategy_history_bars_d1` | 3000 | bounded endpoint scan per leg |
| `strategy_signal_epsilon` | 1e-12 | inclusive flat band around zero |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen per-leg hard-stop distance |
| `strategy_max_hold_days` | 40 | stale repair only |
| `strategy_xau_max_spread_points` | 1500 | nonnegative XAU entry-cost guard |
| `strategy_xag_max_spread_points` | 3000 | nonnegative XAG entry-cost guard |
| `strategy_deviation_points` | 20 | basket order deviation |
| `qm_friday_close_enabled` | false | preserve monthly hold |

No sample, median, epsilon, direction, stop, hold, spread, or lifecycle sweep
is authorized.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- One shared package budget, split into equal fixed-risk halves. This is not a
  claim of equal notional, beta, volatility, or dollar neutrality.
- Frozen per-leg hard stops: `3.5*ATR(20,D1)` from completed data.
- No target, signal-magnitude sizing, risk renewal, compounding override, or
  rescue entry.
- Invalid price, stop distance, tick value, tick size, volume step, minimum
  volume, lot, margin, or composition consumes the month.
- This card creates no live, demo, shadow, stress, or optimization preset.

The exact conjunction and narrow two-CFD carrier are untested. Long warm-up,
small samples, median instability, rolls, financing, gaps, asymmetric stops,
legging, and common-metal beta can erase the premise. Q09 alone may measure
correlation with the current book.

## Runtime Data Dependencies

Native synchronized `XAUUSD.DWX` and `XAGUSD.DWX` D1 OHLC/timestamps, broker
clock, symbol quotes and properties, positions, deals, and terminal-global
attempt state only. No curve, contract chain, inventory, volume, open
interest, event feed, API, CSV, optimizer artifact, trained output, or manual
signal input.

## Framework Execution Overrides

- `qm_news_temporal=QM_NEWS_TEMPORAL_OFF`.
- `qm_news_compliance=QM_NEWS_COMPLIANCE_NONE`.
- `qm_news_mode_legacy=QM_NEWS_OFF`.
- `qm_friday_close_enabled=false`.
- Framework kill switch, fixed-risk sizing, magic resolution, basket order
  services, MAE tracking, and exact owned-position isolation remain mandatory.

## Exit Precedence

1. Framework kill switch or close-only instruction.
2. Malformed, duplicate, same-direction, stopless, or invalid-metadata repair.
3. Per-leg broker hard stop.
4. New normalized broker-month exit.
5. Forty-day stale repair.
6. New entry only when flat and the current month is not already consumed.

## Framework Alignment

| Card rule | V5 module | Required implementation |
|---|---|---|
| exact host, D1, EA, slot, locked contract | no_trade | fail closed before signal entry |
| normalized month clock and persistent attempt | no_trade / trade_entry | consume once before fallible gates |
| synchronized exact-year endpoint reconstruction | trade_entry | bounded completed D1 history on both legs |
| relative sample median and epsilon side map | trade_entry | native deterministic sorting only |
| equal fixed-risk halves and frozen stops | trade_entry | framework sizing plus basket orders |
| package atomicity and composition | trade_entry / management | unwind partial or malformed package |
| month, stale, and malformed exits | management / close | close both owned legs only |
| no targets, trails, partials, or intramonth signal exit | management | no optional management path |
| news and Friday overrides | no_trade / close | both news axes OFF; Friday close OFF |

## Reputable-Source Gate Findings

- R1:
  `PASS_WITH_ROBUST_LOCATION_SMALL_SAMPLE_AND_CFD_TRANSLATION_RISK`.
- R2: `PASS` for the exact locked mechanical contract.
- R3:
  `PASS_WITH_LONG_WARMUP_SYNCHRONIZATION_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`.
- R4: `PASS`; structural arithmetic only, with no prohibited trained signal
  or external runtime feed.

## Falsification And Requalification

Retire or fail on wrong calendar endpoints, cross-leg desynchronization,
invalid sample, relative orientation, median arithmetic, side, same-month
retry, orphan persistence, missing stops, invalid fixed-risk mode, wrong
lifecycle, nondeterminism, fewer than five completed packages in any full
post-warm-up year, zero packages, nonpositive governed economics, or
downstream correlation rejection. No result may be rescued by changing the
sample, threshold, carrier, direction, risk, hold, spread caps, retry policy,
or by adding a filter.

## Card History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-30 | initial XAU/XAG same-calendar relative median card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| Source Approval | 2026-08-30 | APPROVED_SOURCE | `decisions/2026-08-30_xauxag_median_same_calendar_source_approval.md` |
| G0 Research Intake | 2026-08-30 | APPROVED | `decisions/2026-08-30_qm5_41226_xauxag_median_same_calendar_g0.md` |
| Q01 Build Validation | 2026-08-30 | NOT_BUILT | pending |
| Q02 Baseline Screening | 2026-08-30 | NOT_ENQUEUED_Q01_PENDING | pending |

## Safety Boundary

This card authorizes one branch-only non-live EA build, exact two-slot magic
allocation, strict compile/Q01 validation, one logical-basket `RISK_FIXED`
backtest setfile, and one paced Q02 enqueue if capacity permits.

It authorizes no manual backtest, component-leg Q02 row, live/demo/shadow/
stress/optimization setfile, terminal control, AutoTrading, `T_Live`, deploy
or live manifest, portfolio-gate mutation, portfolio admission, correlation
waiver, or certification claim.
