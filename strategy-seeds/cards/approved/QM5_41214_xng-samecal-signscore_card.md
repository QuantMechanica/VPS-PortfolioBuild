---
card_schema_version: 2
type: strategy
strategy_id: KELOHARJU-PAPAILIAS-RCORE-XNG-SAMECAL-SIGNSCORE-2026_S01
variant_id: KELOHARJU-PAPAILIAS-RCORE-XNG-SAMECAL-SIGNSCORE-2026_S01
source_id: KELOHARJU-PAPAILIAS-RCORE-XNG-SAMECAL-SIGNSCORE-2026
ea_id: QM5_41214
slug: xng-samecal-signscore
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41214_xng-samecal-signscore_card.md
execution_contract_status: APPROVED
created: 2026-08-30
created_by: Research+Development
last_updated: 2026-08-30
g0_status: APPROVED
g0_decision: decisions/2026-08-30_qm5_41214_xng_same_calendar_sign_score_g0.md
source_approval: decisions/2026-08-30_xng_same_calendar_sign_score_source_approval.md
source_author: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Fotis Papailias; Jiadong Liu; Dimitrios D. Thomakos; R Core Team"
source_authors: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Fotis Papailias; Jiadong Liu; Dimitrios D. Thomakos; R Core Team"
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), Return Seasonalities, Journal of Finance 71(4), DOI 10.1111/jofi.12398; Papailias, Liu, and Thomakos (2021), Return Signal Momentum, Journal of Banking & Finance 124, DOI 10.1016/j.jbankfin.2021.106063; R Core Team stats::prop.test pinned at wch/r-source commit 9deb2ebef8d0a2fe5cae965697ee4751af857bd1."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Keloharju, M., Linnainmaa, J. T., and Nyberg, P. (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590."
    location: "DOI 10.1111/jofi.12398; complete-read parent packet strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md"
    quality_tier: A
    role: same_calendar_month_commodity_information_explicit_natural_gas_membership_and_five_year_floor
  - type: peer_reviewed_trading_paper
    citation: "Papailias, F., Liu, J., and Thomakos, D. D. (2021). Return Signal Momentum. Journal of Banking & Finance 124, 106063."
    location: "DOI 10.1016/j.jbankfin.2021.106063; complete-read parent packet strategy-seeds/sources/PAPAILIAS-RSM-2021/source.md"
    quality_tier: A
    role: nonnegative_return_binary_map_equal_weighting_xng_membership_and_monthly_lifecycle
  - type: primary_statistical_software_source
    citation: "R Core Team, stats::prop.test implementation."
    location: "wch/r-source commit 9deb2ebef8d0a2fe5cae965697ee4751af857bd1; blob fc38bd4be1ba8630dbd224162ab5873ae6ac5261; complete public primary-source read"
    quality_tier: A_primary_software
    role: one_sample_null_probability_expected_counts_uncorrected_pearson_score_arithmetic
  - type: governed_composite_source
    citation: "QuantMechanica bounded XNG same-calendar Bernoulli sign-score extraction."
    location: "strategy-seeds/sources/KELOHARJU-PAPAILIAS-RCORE-XNG-SAMECAL-SIGNSCORE-2026/source.md"
    quality_tier: internal_governed
    role: exact_calendar_endpoints_score_threshold_risk_and_lifecycle
strategy_mechanic: exact-up-to-ten-prior-year-same-calendar-month-xng-log-return-nonnegative-sign-count-bernoulli-null-half-standard-error-score-strict-absolute-score-above-one-monthly-directional-renewal
sources:
  - "[[sources/KELOHARJU-PAPAILIAS-RCORE-XNG-SAMECAL-SIGNSCORE-2026]]"
concepts:
  - "[[concepts/return-seasonality]]"
  - "[[concepts/return-sign-momentum]]"
  - "[[concepts/bernoulli-score]]"
  - "[[concepts/calendar-month-renewal]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/binary-return-sign]]"
  - "[[indicators/proportion-score]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, natural-gas, calendar-seasonality, same-calendar-month, binary-return-sign, bernoulli-score, confidence-gate, monthly-renewal, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
host_symbol: XNGUSD.DWX
symbol_slot: 0
magic: 412140000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: long_short
expected_trade_frequency: "Approximately 5-8 completed XNG monthly positions per full post-warm-up year; months inside the strict one-standard-error sign band consume flat."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_STATISTIC_SINGLE_CARRIER_SMALL_SAMPLE_AND_CFD_TRANSLATION_RISK
r1_reasoning: "Two complete peer-reviewed sources explicitly cover same-calendar commodities, binary return signs, and XNG; complete pinned R Core primary software fixes the score arithmetic. The exact conjunction and threshold remain untested."
r2_mechanical: PASS
r2_reasoning: "Month clock, uniform normalized endpoints, exact Y-1..Y-10 bound, five-observation floor, nonnegative binary map, null 0.5, score denominator, strict band, side, consumed attempt, fixed risk, hard stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_qualification: LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK
r3_reasoning: "Registered XNGUSD.DWX D1 history and native MT5 state supply every runtime input; five-year warm-up, session labels, rolls, financing, and futures/CFD basis remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, integer counts, square root, comparisons, ATR risk controls, and execution state; no trained signal, banned signal indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: prior 10-year same-calendar search cap; minimum 5 observations; return>=0 binary success map; null p0=0.5; no continuity correction; strict abs(score)>1.0 plus 1e-10 tolerance; 3000 D1 history bars; ATR(20)*3.5 frozen stop; 40-day stale exit; 3000-point spread ceiling."
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
review_focus: "Falsify a confidence-gated monthly XNG same-calendar sign sleeve whose information clock and binary abstention rule differ from the certified daily cumulative-RSI pullback. Verify normalized completed endpoints, exact-year bounds, nonnegative sign map, null-half score, strict band, consumed month, fixed risk, frozen stop, and next-month exit. Q09 alone may establish realized independence."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xng_carrier, first_tradable_month_bar, uniform_energy_label_normalization, exact_prior_year_same_calendar_months, completed_month_endpoints, no_current_month_price, five_sample_floor, ten_year_cap, nonnegative_return_binary_map, bernoulli_null_half, no_continuity_correction, score_standardization, strict_absolute_score_band, sign_only_direction, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-30 and decisions/2026-08-30_qm5_41214_xng_same_calendar_sign_score_g0.md: R1 passes with two complete peer-reviewed XNG/commodity lineages plus commit-pinned primary-software arithmetic and explicit conjunction risk; R2 locks calendar, sample, binary map, null, denominator, score band, side, attempt, risk, stop, spread, and lifecycle; R3 uses registered native XNG D1 with warm-up/session/CFD risk; R4 is deterministic native arithmetic only. Corrected-root canonical dedup finds no exact identity; manual review and fixed disagreement fixtures separate the certified cumulative-RSI pullback, raw mean, Huber location, single-WTI score, and XAU/XAG relative score families."
---

# QM5_41214 XNG Same-Calendar Bernoulli Sign-Score Seasonality

## Hypothesis

XNG production, transport, storage, heating/cooling demand, hedging, and
capital-allocation pressures can recur in the same calendar month. Return magnitudes
can be dominated by a few extreme years, so this card discards magnitude and
tests only whether prior occurrences of the upcoming calendar month show a
sign imbalance exceeding one Bernoulli standard error from a 50/50 null.

The rule supplies a second XNG carrier only through a monthly information
clock, prior-year calendar sample, binary sign reduction, and symmetric
abstention gate that are absent from the certified daily cumulative-RSI
pullback. Mechanical difference does not prove low realized correlation. Q02
owns activity and baseline economics; unchanged Q09 alone owns portfolio
overlap.

## Source Traceability And Claim Boundary

The approved bounded packet is
`strategy-seeds/sources/KELOHARJU-PAPAILIAS-RCORE-XNG-SAMECAL-SIGNSCORE-2026/source.md`.
It was committed after the durable source approval
`decisions/2026-08-30_xng_same_calendar_sign_score_source_approval.md`.

Keloharju, Linnainmaa, and Nyberg supply recurring same-calendar commodity-
return information, explicit natural-gas membership, monthly renewal, and a
five-year history floor. Papailias, Liu, and Thomakos supply the nonnegative-
return binary map, equal weighting, XNG membership, and monthly lifecycle.
Commit-pinned R Core source supplies only the one-sample null and uncorrected
proportion-score arithmetic.

None tests the exact absolute-XNG CFD rule, `abs(score)>1` gate, Darwinex
history, fixed risk, ATR stop, spread cap, or current book. No source or
sibling return, alpha, significance, profit factor, drawdown, trade count,
cost, CFD equivalence, or correlation statistic transfers. The threshold is
a pre-result QM falsification choice, not a conventional significance claim;
runtime computes no p-value.

## Source-Defined Rules

- Keloharju, Linnainmaa, and Nyberg support recurring same-calendar commodity-
  return information, explicit natural-gas membership, monthly renewal, and at
  least five prior years.
- Papailias, Liu, and Thomakos map a nonnegative completed return to one and a
  negative return to zero, average signs equally, and renew monthly.
- Commit-pinned R Core source fixes a one-sample null probability of 0.5,
  success/failure expected counts, and uncorrected Pearson score arithmetic.
- No source defines this single-CFD absolute side, the `abs(score)>1`
  threshold, spread limit, fixed-risk sizing, ATR stop, or portfolio admission.

## QM Interpretations

- Apply the binary map to XNG's own earlier same-calendar log returns rather
  than to twelve contiguous recent months.
- Lock exact years `Y-1..Y-10`, skip missing valid years without substitution,
  and require at least five observations.
- Use the signed square root of the uncorrected one-sample Pearson statistic,
  algebraically reduced to `(2*x-n)/sqrt(n)` at `p0=0.5`.
- Treat `1.0+1e-10` as a pre-result confidence and abstention gate, not a
  p-value or conventional significance cutoff.
- Use one `RISK_FIXED=1000` budget, frozen ATR stop, durable monthly attempt,
  and next-month renewal as governed execution choices.
- Treat XNG diversification as an objective only; unchanged Q09 remains the
  sole realized-correlation authority.

## Formula

At normalized broker-month decision `(Y,M)`, reconstruct XNG calendar-month
`M` log returns in exact years `Y-1..Y-10`. Let the valid observations be
`r[0]..r[n-1]`, with `5<=n<=10`, and let `x=sum(1[r[i]>=0])`:

```text
p0          = 0.5
denominator = sqrt(n * p0 * (1-p0)) = 0.5*sqrt(n)
score       = (x - n*p0) / denominator = (2*x-n)/sqrt(n)

score > +1.0 + 1e-10 => BUY XNG
score < -1.0 - 1e-10 => SELL XNG
otherwise              => FLAT
```

The current month contributes no price. Require integer `0<=x<=n`, finite
positive denominator, and finite score. Continuity correction, exact-binomial
p-value, magnitude mean, sample variance, median, rank, robust location,
magnitude sizing, or a fallback estimator is not equivalent.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_xng_samecal_signscore_preallocation_dedup_20260830.json`,
SHA-256
`F6E5C50549A7A43C7BD047CAA44303A699F2DDF139ACD599EBD5090CFFD80AF4`,
found no exact identity across 4,713 registry rows, 1,359 cards, and 45
Strategy Wiki nodes. It returned three expected fuzzy neighbors.

- `QM5_20100_xng-samecal` follows the arithmetic mean of XNG return
  magnitudes and normally chooses a side. For
  `[0.09,-0.01,-0.01,-0.01,-0.01]`, it buys while this card has
  `z=-3/sqrt(5)<-1` and sells.
- `QM5_41205_xng-samecal-huber10` retains metric distances through an even
  median, MAD scale, and fixed-step Huber location. This card reduces every
  observation to an equal-weight Bernoulli outcome standardized against fixed
  null variance.
- `QM5_12567_cum-rsi2-commodity` uses a daily cumulative-RSI(2) pullback
  under long-trend context and a short hold. This card has no RSI, oscillator,
  contiguous pullback, or intramonth renewal.
- `QM5_41212_wti-samecal-signscore` uses the same transparent statistic but
  reads and owns WTI. It cannot read or trade XNG. This card is the explicitly
  permitted new XNG carrier/mechanic combination, not a claim to a globally
  new statistical family.
- `QM5_41213_xauxag-samecal-signscore` observes synchronized relative
  gold-minus-silver returns and owns two opposite metal legs. It cannot express
  a single-gas directional state.

The exact XNG information object, null variance, sample-size-aware score,
symmetric abstention band, durable monthly attempt state, and single-gas
position jointly change direction, participation, and exposure relative to
the incumbent XNG logic. They are load bearing rather than a threshold rename.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XNG_SAMECAL_BERNOULLI_SIGN_SCORE_GATE_MONTHLY_DIRECTIONAL_CARRIER`.

## Markets, Timeframe, And Cadence

- Host and traded symbol: exact `XNGUSD.DWX`, D1, slot 0.
- Magic: `412140000`.
- Decision clock: first executable D1 tick after a genuine normalized broker-
  month transition.
- Formation: exact same calendar month in up to ten earlier years; at least
  five valid observations.
- Hold: next broker-month boundary; 40 elapsed days is stale repair.
- Expected pre-result cadence: approximately five to eight positions per full
  post-warm-up year; Q02 retires below five in any full scored year.

## Rules

The entry, exit, filter, and lifecycle rules below are the complete authorized
baseline. There is no signal-parameter sweep or fallback estimator.

## 4. Entry Rules

1. Require exact EA ID `41214`, `XNGUSD.DWX` D1 host, slot 0, magic
   `412140000`, fixed-risk inputs, both news axes OFF, and Friday close OFF.
2. Process malformed exposure and prior-month liquidation before entry-only
   gates. Evaluate only after a genuine normalized broker-month transition.
3. Accept one uniform native or `+1` energy-D1 label convention. Require the
   normalized current D1 date to equal broker date and use that same offset
   for every historical endpoint.
4. Persist current broker `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, margin, or submission. Never retry after any outcome.
5. From at most 3,000 completed D1 bars, reconstruct exact calendar-month `M`
   endpoints in years `Y-1..Y-10`. Each return needs the immediately preceding
   month endpoint and a confirming following bar. No current-month OHLC enters.
6. Skip a missing older year without replacing it; require at least five valid
   observations. Map each finite return to one when nonnegative and zero when
   negative. Count `x`, compute the finite positive null-half denominator and
   signed score. Invalid state consumes flat.
7. Buy beyond `+1.0+1e-10`; sell below `-1.0-1e-10`; equality and the
   inclusive interior band consume flat. Score magnitude never changes risk.
8. Require no owned exposure or same-month entry deal, positive finite Bid and
   Ask, `Ask>=Bid`, modeled spread in `[0,3000]` points, completed ATR(20,D1),
   valid stop normalization, and valid symbol/volume metadata.
9. Submit one market position with `RISK_FIXED=1000` and a frozen
   `3.5*ATR(20,D1)` hard stop. Use no target or second attempt.

## 5. Exit Rules

1. Close on the first processed D1 bar of the next normalized broker month
   before considering a replacement position.
2. Close after 40 elapsed calendar days as final stale repair.
3. Immediately flatten duplicate, wrong-symbol, wrong-magic, invalid-side,
   missing-stop, invalid-volume, or invalid-open-time owned exposure.
4. The broker hard stop, framework kill switch, and framework close helper
   remain authoritative.
5. Friday close is disabled because the structural monthly hold spans
   weekends.
6. There is no intramonth signal exit, target, trail, break-even, partial
   close, scale-in, grid, martingale, pyramid, stop-and-reverse, or
   discretionary exit.

## 6. Filters (No-Trade Module)

- Wrong host, period, EA ID, slot, locked input, mid-month start, duplicate
  state, invalid label convention, endpoint, insufficient sample, invalid
  sign count/denominator, interior score, quote, spread, ATR, sizing, or order
  state consumes the persisted month.
- Both news axes and legacy news are OFF; no external calendar or feed is
  consulted.
- No continuity correction, p-value, magnitude mean, rank, robust location,
  recent momentum, selected-month, inventory, storage, weather, curve, volume,
  event, or price-action fallback is allowed.
- Score magnitude never changes fixed risk and equality stays flat.

## 7. Trade Management Rules

- Every tick begins with framework MAE tracking before any guard can return.
- Malformed, cross-month, and stale repair runs before every entry-only gate
  and remains retryable until owned exposure is flat.
- Own at most one position by exact EA ID, magic, and XNG symbol; never manage
  another EA's or manual trade.
- The entry hard stop is never moved. No score change alters an open position
  inside the month.
- Persist the consumed-month ledger in a terminal global variable so restart
  cannot generate a second attempt.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_years` | 10 | maximum exact earlier years |
| `strategy_min_observations` | 5 | minimum valid same-calendar returns |
| `strategy_null_probability` | 0.5 | fixed Bernoulli null |
| `strategy_score_threshold` | 1.0 | strict absolute score band |
| `strategy_signal_tolerance` | 1e-10 | equality buffer |
| `strategy_history_bars_d1` | 3000 | bounded endpoint scan |
| `strategy_entry_grace_minutes` | 180 | first normalized month-bar window |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale repair only |
| `strategy_max_spread_points` | 3000 | nonnegative XNG entry-cost guard |
| `qm_friday_close_enabled` | false | preserve monthly hold |

No sample, sign map, null, correction, threshold, month selection, direction,
stop, hold, spread, or lifecycle sweep is authorized.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5*ATR(20,D1)` from completed data.
- No target, score-magnitude sizing, risk renewal, or compounding override.
- Invalid price, stop distance, tick value, tick size, volume step, minimum
  volume, lot, margin, or owned-position state consumes the month.
- This card creates no live, demo, shadow, stress, or optimization preset.

The single-CFD translation, small binary sample, XNG gaps, roll/financing,
label mapping, threshold sparsity, and stop slippage can erase the premise.
The same underlying carrier can still overlap the incumbent despite the
different signal clock; Q09 alone may measure correlation with the certified
book.

## Runtime Data Dependencies

Native `XNGUSD.DWX` D1 OHLC/timestamps, broker clock, symbol quotes and
properties, positions, deal history, and terminal-global attempt state only.
No curve, inventory, storage data, weather, volume, open interest, event feed,
API, CSV, optimizer artifact, trained output, or manual signal input.

## Framework Execution Overrides

- `qm_news_temporal=QM_NEWS_TEMPORAL_OFF`.
- `qm_news_compliance=QM_NEWS_COMPLIANCE_NONE`.
- `qm_news_mode_legacy=QM_NEWS_OFF`.
- `qm_friday_close_enabled=false`.
- Framework kill switch, fixed-risk sizing, magic resolution, order services,
  MAE tracking, and exact owned-position isolation remain mandatory.

## Exit Precedence

1. Framework kill switch or close-only instruction.
2. Malformed, duplicate, invalid-side, stopless, or invalid-metadata repair.
3. Broker hard stop.
4. New normalized broker-month exit.
5. Forty-day stale repair.
6. New entry only when flat and current broker month is not consumed.

## Reputable-Source Gate Findings

- R1: `PASS_WITH_COMPOSITE_TRANSLATION_AND_SMALL_SAMPLE_RISK`.
- R2: `PASS` for the exact locked mechanical contract.
- R3: `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`.
- R4: `PASS`; structural arithmetic only, with no prohibited trained signal
  or external runtime feed.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period/identity, locked risk/news/Friday inputs | No Trade | `Strategy_NoTradeFilter` |
| month clock, consumed attempt, endpoints, sign map, null/score, side, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-month, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| monthly renewal and broker hard stop | Trade Close | lifecycle helper; `Strategy_ExitSignal` has no discretionary signal |
| news OFF | News hook | `Strategy_NewsFilterHook` returns false; both framework axes OFF |

## Kill Criteria

Retire rather than tune on zero positions; fewer than five completed positions
in any full post-warm-up year; nonpositive governed economics; wrong normalized
month, endpoint, sample membership, sign map, null, denominator, score, side,
attempt, risk, stop, spread, lifecycle, or determinism; current-month leakage;
retry; missing stop; or registry mismatch.

No weak result may be rescued by lowering or moving the band, adding continuity
correction or a p-value, adopting magnitude mean, rank, robust location, recent
momentum, selected months, storage, weather, volume, event, curve, or price-
action filters, changing carrier, or extending hold.

## Falsification And Requalification

A failure is evidence against this exact identity. A mechanically different
sample, binary map, null, score, threshold, direction, carrier, stop, spread,
or lifecycle requires a new card, dedup decision, and identity; it is not a
patch.

## Validation Plan

Q01 must prove:

1. native and uniform `+1` labels select the genuine broker-month boundary,
   exact historical calendar month, preceding endpoint, and year rollover;
2. a missing older year is skipped without neighboring-year substitution and
   no current-month price enters;
3. five through ten observations produce exact nonnegative count, null-half
   denominator, score, strict thresholds, and side;
4. fixed fixtures separate raw mean, 40-percent hit-rate, magnitude t-score,
   signed-rank, robust-location, and residual-momentum siblings;
5. durable `yyyymm` state prevents same-month retry after downstream failure
   and restart;
6. zero modeled spread remains reachable while crossed or excessive spread is
   rejected;
7. fixed-risk sizing uses one valid frozen completed-bar ATR stop; and
8. next-month close, malformed repair, stale guard, disabled Friday close,
   strict compile, schema lint, magic resolver, and setfile checks pass.

## Card History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-30 | initial XNG same-calendar Bernoulli sign-score card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-30 | APPROVED; R1-R4 PASS | `decisions/2026-08-30_qm5_41214_xng_same_calendar_sign_score_g0.md`; approved source packet |
| Q01 Build Validation | 2026-08-30 | NOT_BUILT | deterministic magic allocation and build pending |
| Q02 Baseline Screening | 2026-08-30 | NOT_ENQUEUED_Q01_PENDING | no work item before compile/review PASS |

## Safety Boundary

This card authorizes one branch-only non-live build, deterministic slot-0
magic allocation, strict Q01 validation, one `RISK_FIXED` D1 backtest setfile,
and one paced Q02 enqueue only after prerequisites and a non-binding CPU check.

It does not authorize a manual backtest, live/demo/shadow/stress/optimization
preset, terminal control, AutoTrading, `T_Live`, deploy or live manifest,
portfolio-gate change, portfolio admission, correlation waiver, or queue
deletion.

