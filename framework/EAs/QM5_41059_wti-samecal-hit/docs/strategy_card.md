---
card_schema_version: 2
type: strategy
strategy_id: KELOHARJU-PAPAILIAS-WTI-SAMECALHIT-2026_S01
variant_id: KELOHARJU-PAPAILIAS-WTI-SAMECALHIT-2026_S01
source_id: KELOHARJU-PAPAILIAS-WTI-SAMECALHIT-2026
ea_id: QM5_41059
slug: wti-samecal-hit
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41059_wti-samecal-hit_card.md
execution_contract_status: APPROVED
created: 2026-08-18
created_by: Research+Development
last_updated: 2026-08-18
g0_status: APPROVED
g0_decision: decisions/2026-08-18_qm5_41059_q40_identity_amendment.md
source_approval: decisions/2026-08-18_wti_same_calendar_hit_rate_source_approval.md
source_author: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Fotis Papailias; Jiadong Liu; Dimitrios D. Thomakos"
source_authors: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Fotis Papailias; Jiadong Liu; Dimitrios D. Thomakos"
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), Return Seasonalities, The Journal of Finance 71(4), 1557-1590; Papailias, Liu, and Thomakos (2021), Return Signal Momentum, Journal of Banking & Finance 124, 106063."
source_citations:
  - type: peer_reviewed_paper
    citation: "Keloharju, M., Linnainmaa, J. T., and Nyberg, P. (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590."
    location: "DOI 10.1111/jofi.12398; complete-read record strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md"
    quality_tier: A
    role: same_calendar_month_return_seasonality_and_crude_oil_universe_lineage
  - type: peer_reviewed_paper
    citation: "Papailias, F., Liu, J., and Thomakos, D. D. (2021). Return Signal Momentum. Journal of Banking & Finance 124, 106063."
    location: "DOI 10.1016/j.jbankfin.2021.106063; complete accepted-manuscript record strategy-seeds/sources/PAPAILIAS-RSM-2021/source.md"
    quality_tier: A
    role: binary_return_sign_map_positive_frequency_and_explicit_wti_membership
strategy_mechanic: prior-ten-year-same-calendar-month-log-return-positive-frequency-q40-direction-monthly-wti-renewal
sources:
  - "[[sources/KELOHARJU-PAPAILIAS-WTI-SAMECALHIT-2026]]"
concepts:
  - "[[concepts/return-seasonality]]"
  - "[[concepts/return-sign-frequency]]"
  - "[[concepts/calendar-month-renewal]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/binary-sign-frequency]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, calendar-seasonality, same-calendar-month, binary-hit-rate, fixed-q40, monthly-renewal, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410590000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 12 completed XTI monthly positions per full post-warm-up year when matching-month history is valid; invalid-history months remain flat; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_HISTORY_AND_SESSION_LABEL_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED
review_focus: "Falsify a magnitude-free direct-WTI same-calendar-month sleeve outside the certified XAU/SP500/NDX/XNG book. Verify uniform D1-label normalization, exact historical month endpoints, five-to-ten binary observations, non-negative sign map, the source-defined fixed q=0.40 inequality, durable monthly attempt, monthly renewal, and absence of current-month leakage. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_month_bar_clock, uniform_energy_label_normalization, exact_prior_year_same_calendar_months, completed_month_endpoints, no_current_month_price, five_sample_floor, ten_year_cap, binary_nonnegative_map, equal_weight_frequency, fixed_q40_boundary, monthly_attempt_state, monthly_renewal, risk_mode_dual, hard_stop_present, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 joins two named-author peer-reviewed finance papers with DOI, complete-read records, explicit WTI membership, and the same-calendar/sign-frequency conjunction disclosed as an untested QM translation; R2 locks every endpoint, sample bound, binary map, frequency, source-defined q=0.40 boundary, attempt, risk, and lifecycle; R3 uses registered native XTI D1 with binding 2017-start warm-up and energy-label risks explicit; R4 is deterministic calendar, logarithm, count, and execution arithmetic without trained logic, banned signals, or an external feed; canonical dedup and the post-allocation q40 probe returned CLEAN, and manual family review separates the asymmetric q40 state from same-calendar mean, median, recent sign momentum, and fixed-month systems."
---

# QM5_41059 WTI Same-Calendar Hit-Rate Seasonality

## Hypothesis

WTI calendar-month returns may contain recurring information associated with
the same named month in prior years. Applying the source-defined return-sign
probability threshold to historical matching-month signs may preserve that
recurrence without allowing one oil-shock magnitude to determine the side. At
the first executable D1 bar of each broker month, the candidate counts up to
ten completed signs for that same calendar month, buys at positive frequency
`>= 0.40`, sells otherwise, and renews at the next month boundary.

This is a falsifiable direct-WTI calendar/sign-frequency translation. It is
not a replication of either source portfolio and does not establish standalone
profitability, continuous-CFD equivalence, or low portfolio correlation.

## Source Traceability And Claim Boundary

The governed joined packet is
`strategy-seeds/sources/KELOHARJU-PAPAILIAS-WTI-SAMECALHIT-2026/source.md`,
approved before extraction at
`decisions/2026-08-18_wti_same_calendar_hit_rate_source_approval.md`.

Keloharju, Linnainmaa, and Nyberg supply same-calendar-month return recurrence,
a five-year eligibility floor, and crude oil inside a 24-future commodity
universe. Their signal uses return magnitudes and cross-sectional ranking.
Papailias, Liu, and Thomakos supply the binary completed-return map, equal-
weight positive frequency, monthly renewal, and explicit WTI membership.
Their signal counts twelve consecutive recent months and uses a `0.4`
threshold.

The prior-year matching-month sample, fixed source-defined `0.40` boundary,
standalone continuous CFD, uniform D1-label normalization, fixed cash risk,
ATR stop, spread cap, durable attempt, and monthly lifecycle are disclosed QM
choices. No source return, Sharpe, coefficient, t-statistic, hit rate, trade
density, drawdown, cost, CFD equivalence, decorrelation, or portfolio result
transfers.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,546 registry rows and 625 root cards,
found no exact or fuzzy identity, and authorized allocation. Manual semantic
review fixes the load-bearing boundaries:

- `QM5_20099_wti-samecal` trades the sign of an arithmetic average of same-
  calendar return magnitudes. This card discards every magnitude and counts
  equal binary signs.
- `QM5_41055_wti-medcal` trades the sign of the central ordered return
  magnitude. With two small gains and three larger losses, this card buys at
  positive frequency `0.40` while both sample mean and median are negative.
- `QM5_20251_wti-cal-rsm` requires agreement between a same-calendar
  arithmetic mean and a separate recent twelve-month sign state. This card
  has one prior-year matching-month state and no recent-return confirmation.
- `QM5_13150_wti-signmom` uses the same source threshold on the twelve
  immediately preceding months. This card samples one named calendar month
  across prior years instead of contiguous recent history.
- `QM5_20136_wti-caltrend` and `QM5_20205_wti-calmom1` add contiguous trend or
  the immediately completed return to a magnitude-based seasonal mean. This
  card contains neither input.
- Fixed favorable-month systems do not recompute a prior-year binary sample.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG oscillator
  pullback rather than symmetric monthly WTI seasonality.

Verdict:
`CLEAN_WTI_SAME_CALENDAR_POSITIVE_RETURN_FREQUENCY_AFTER_FAMILY_REVIEW`.

## Markets, Clock, And Formula

- Exact host and traded symbol: `XTIUSD.DWX`.
- Exact period: D1; EA `41059`; slot `0`; magic `410590000`.
- Decision: first executable D1 tick of each genuine normalized broker month.
- Historical observation for decision year `Y`, month `M`, prior year `y`:
  `r_y = log(last_close(y,M) / last_close_before(y,M))`.
- Binary map: `v_y = 1` when `r_y >= 0`, else `v_y = 0`.
- State: `positive_frequency = sum(v_y) / n`, where `5 <= n <= 10`.
- BUY at or above `0.40`; SELL below `0.40`.
- Ordinary exit: first observed D1 boundary of the next normalized month.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Rules

The rules below are the complete authorized baseline. No return magnitude,
calendar-month selection, recency weight, trend, event, curve, volume,
volatility signal, range, breakout, oscillator, or fitted filter is authorized.

## 4. Entry Rules

1. Evaluate the entry path only on a new `XTIUSD.DWX` D1 bar.
2. Require exact chart symbol `XTIUSD.DWX` and exact D1 period.
3. Compare the current raw D1 date with the broker date. Select one uniform
   offset of zero days when they match or `+1` day when the governed energy
   label is exactly one day behind. Apply that one offset to all history used
   by the decision. Reject every other, mixed, or ambiguous convention.
4. Require the normalized current D1 date to equal the broker date and the
   normalized completed shift-1 bar to belong to the immediately preceding
   broker month. This is the genuine month-boundary identity.
5. Derive the attempt key as broker `yyyymm`. If not already consumed, persist
   it before history, signal, news, spread, quote, ATR, sizing, or order gates.
   A failed downstream gate never retries in the same month.
6. Require attachment within 180 minutes of the current raw D1 bar open.
   Late attachment consumes the month flat; it is not backfilled.
7. For each year `Y-1` through `Y-10`, scan only completed D1 bars to locate
   the final normalized close in calendar month `M` and the immediately prior
   completed close outside month `M`. Require the prior endpoint to precede
   the in-month endpoint and both adjacent normalized month identities to
   prove a complete month. Skip an invalid year without replacement.
8. Require positive finite endpoint prices and calculate the log return.
   Current-month OHLC, tick price, volume, or partial history may not enter.
9. Require five to ten valid historical returns. Map each non-negative return
   to one and each negative return to zero. Sum with equal weight; return
   magnitude and year recency never change a vote.
10. Divide the positive count by the valid count. BUY when the result is at
    least `0.40` and SELL below `0.40`. Invalid arithmetic consumes the month
    flat. The inclusive inequality is load-bearing.
11. Require valid completed-bar `ATR(20,D1)` and place one frozen hard stop at
    `3.5 * ATR`. Use no take-profit.
12. Require no owned position, a valid positive quote, and no genuinely
    positive spread wider than 1,500 points. A modeled zero `.DWX` spread is
    valid.
13. Submit one slot-0 market order once. No pending order, retry, scale-in,
    grid, martingale, pyramid, hedge, or second entry exists.

## 5. Exit Rules

1. At the first observed D1 bar in a later normalized broker `yyyymm`, close
   owned exposure before evaluating that month's new signal.
2. Close after 35 elapsed calendar days as a final stale guard.
3. Immediately flatten duplicate, wrong-symbol, wrong-magic, invalid-side,
   missing-stop, invalid-volume, or invalid-open-time exposure.
4. The frozen broker hard stop and framework kill switch remain authoritative.
5. Framework Friday close is disabled for this monthly identity.
6. No target, reversal, trailing stop, break-even move, partial exit, or
   discretionary close is authorized.

## 6. Filters (No-Trade Module)

- Exact host, D1, EA 41059, slot 0, and registered magic.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes are OFF; the signal uses completed native price history.
- Uniform label normalization, genuine month boundary, durable attempt, exact
  endpoint identity, sample floor, binary count, fixed `0.40` boundary, quote,
  spread, ATR, sizing, and stop geometry must all be valid.
- Failure after attempt persistence consumes the month.

## 7. Trade Management Rules

- Own at most one position under magic `410590000`.
- Freeze the original hard stop; never widen, trail, or remove it.
- Run malformed, later-month, and stale repair on every tick before entry.
- Persist the last attempted broker `yyyymm` so restart cannot create a
  second monthly attempt.
- Do not add, pyramid, grid, hedge, partially close, or reverse.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5 * ATR(20,D1)` from completed data.
- No take-profit and no signal-confidence sizing.
- Invalid stop distance, tick value, tick size, volume step, minimum volume,
  computed lot, or price consumes the month.
- This card creates no live, demo, shadow, stress, or optimization preset.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_lookback_years` | 10 | exact prior-year cap |
| `strategy_min_observations` | 5 | exact valid-sample floor |
| `strategy_positive_threshold` | 0.40 | source-defined binary boundary |
| `strategy_entry_grace_minutes` | 180 | restart-safe month boundary |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 35 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | preserve monthly hold |

No sweep, threshold change, mean or median fallback, month selection, endpoint
change, sample substitution, stop change, or lifecycle rescue is authorized.

## Data Requirements

- Native `XTIUSD.DWX` D1 OHLC and timestamps from the registered factory
  history route.
- Broker clock, symbol quotes/properties, positions, deal history, and
  terminal-global attempt state.
- No continuous-futures file, roll map, inventory, volume, open interest,
  futures curve, event calendar, API, CSV, optimizer artifact, or manual input.

## Source-Defined Rules

Keloharju et al. define recurring same-calendar-month return information,
explicitly include crude oil, and require at least five historical years.
Papailias et al. define the non-negative/negative binary map, equal-weight
positive frequency, explicit WTI membership, and monthly renewal. The sources
do not define this matching-month sign sample on a single CFD package.

## QM Interpretations

QM fixes uniform energy-label normalization, the ten-year cap, exact monthly
endpoints, matching-month binary sample, transfers the fixed source `0.40`
inequality without fitting, and fixes the direct CFD
carrier, durable attempt, fixed risk, ATR stop, spread ceiling, monthly
renewal, and stale guard. They are pre-result falsification choices.

## Framework Execution Overrides

The framework kill switch, ownership checks, fixed-risk sizing contract,
position/deal state, and order handling remain authoritative. Both news axes
and framework Friday close are OFF. This non-live card creates no live mapping,
deployment manifest, or promotion entitlement.

## Exit Precedence

1. Framework kill switch and broker hard stop remain authoritative.
2. Malformed, duplicate, wrong-side, or missing-stop exposure is flattened.
3. First observed D1 boundary in a later normalized month is ordinary exit.
4. The 35-day close repairs only a survivor.

## Runtime Data Dependencies

Runtime uses only native D1 OHLC/timestamps, broker time, current quotes,
symbol contract properties, positions, deals, and terminal-global attempt
state. It has no external feed, trained output, fitted artifact, optimizer
artifact, or manual signal input.

## Falsification And Requalification

Q02 retires on zero trades, fewer than five completed positions per full
post-warm-up year, nonpositive governed economics, wrong endpoint identity,
current-month leakage, fewer than five valid observations, wrong binary map,
wrong count or boundary, late/repeated entry, wrong monthly lifecycle,
nondeterminism, invalid risk mode, or insufficient local history. Any change
to estimator, endpoint, sample bounds, threshold, direction, stop, or hold
creates a new identity. Q09 alone may establish realized portfolio correlation.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, boundary, attempt, history, endpoints, signs, q40 boundary, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-month, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| monthly renewal and survivor repair | Trade Close | strategy lifecycle helper; Friday close disabled |
| kill switch, ownership, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | `Strategy_NewsFilterHook` returns false; both modes OFF |

## Kill Criteria

Retire rather than tune on fewer than five completed positions per full post-
warm-up year; zero trades; nonpositive governed economics; wrong or partial
monthly endpoints; current-month leakage; invalid sample count; wrong binary
map, count, or fixed `0.40` inequality; retry; missing stop; wrong monthly lifecycle;
nondeterminism; or registry/risk mismatch.

No weak result may be rescued by changing the `0.40` threshold, reverting
to mean or median magnitude, selecting months, adding recent trend, inventory,
event, curve, volume, volatility, or price-action filters, changing sample
bounds, or extending the hold.

## Validation Plan

Q01 must prove:

1. native and uniform `+1` label conventions select only a genuine normalized
   month boundary, and matching-month returns use only completed endpoints for
   years `Y-1` through `Y-10`, including December/January wrapping;
2. five-to-ten sample bounds, non-negative binary mapping, equal-weight count,
   inclusive `>= 0.40` long and `< 0.40` short sides are correct, including a
   two-of-five case that is long while mean and median magnitude are negative;
3. no current-month OHLC, volume, or tick price enters the signal;
4. persistent `yyyymm` attempts prevent same-month retry after downstream
   failure and restart;
5. fixed-risk sizing uses a valid frozen completed-bar ATR stop;
6. next-month close, malformed repair, stale guard, and disabled Friday close
   remain reachable; and
7. strict compile, card lint, build checks, setfile schema, magic resolver, and
   static Q01 validation pass.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-18 | initial WTI same-calendar hit-rate extraction | G0 | APPROVED |
| v1-q40 | 2026-08-18 | pre-build semantic review replaced median-equivalent majority with source-defined q40 boundary | G0 | APPROVED |
| v1-build | 2026-08-18 | deterministic V5 implementation and strict validation | Q01 | PASS |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-18 | APPROVED | `decisions/2026-08-18_qm5_41059_q40_identity_amendment.md` |
| Q01 Build Validation | 2026-08-18 | PASS | `D:/QM/reports/framework/21/build_check_20260818_042436.json`; `D:/QM/reports/pipeline/QM5_41059/P1/P1_QM5_41059_result.json` |
| Q02 Baseline Screening | - | NOT_ENQUEUED | - |

## Safety Boundary

This card authorizes a non-live build, Q01 validation, one D1 backtest setfile,
and one paced target-only Q02 enqueue only below tester and host-CPU ceilings.
It does not authorize a manual backtest, tester control, live/demo/shadow/
stress/optimization preset, AutoTrading, `T_Live`, deploy or T_Live manifest,
portfolio-gate change, portfolio admission, decorrelation claim, or
correlation waiver.
