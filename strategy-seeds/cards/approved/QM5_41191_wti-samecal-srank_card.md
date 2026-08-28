---
card_schema_version: 2
type: strategy
strategy_id: KELOHARJU-WILCOXON-WTI-SAMECAL-SR-2026_S01
variant_id: KELOHARJU-WILCOXON-WTI-SAMECAL-SR-2026_S01
source_id: KELOHARJU-WILCOXON-WTI-SAMECAL-SR-2026
ea_id: QM5_41191
slug: wti-samecal-srank
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41191_wti-samecal-srank_card.md
execution_contract_status: APPROVED
created: 2026-08-28
created_by: Research+Development
last_updated: 2026-08-28
g0_status: APPROVED
g0_decision: decisions/2026-08-28_qm5_41191_wti_same_calendar_signed_rank_g0.md
source_approval: decisions/2026-08-28_wti_same_calendar_signed_rank_source_approval.md
source_author: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; R Core Team"
source_authors: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; R Core Team"
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), Return Seasonalities, Journal of Finance 71(4), 1557-1590, DOI 10.1111/jofi.12398; R Core Team stats::wilcox.test pinned implementation and manual at wch/r-source commit bac583951b728e97b9786804d3b4081f0fe18df5."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Keloharju, M., Linnainmaa, J. T., and Nyberg, P. (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590."
    location: "DOI 10.1111/jofi.12398; complete-read parent packet strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md"
    quality_tier: A
    role: same_calendar_month_return_information_and_crude_oil_membership
  - type: primary_statistical_software_source
    citation: "R Core Team, stats::wilcox.test implementation and manual."
    location: "wch/r-source commit bac583951b728e97b9786804d3b4081f0fe18df5; complete public-API read and hashes in retrieval receipt"
    quality_tier: A_primary_software
    role: one_sample_signed_absolute_rank_sum_arithmetic
  - type: governed_composite_source
    citation: "QuantMechanica bounded WTI same-calendar signed absolute-rank extraction."
    location: "strategy-seeds/sources/KELOHARJU-WILCOXON-WTI-SAMECAL-SR-2026/source.md"
    quality_tier: internal_governed
    role: exact_calendar_endpoints_sample_zero_tie_score_risk_and_lifecycle
strategy_mechanic: prior-ten-year-same-calendar-month-wti-log-returns-strict-absolute-ranks-centered-signed-rank-sum-direction-monthly-renewal
sources:
  - "[[sources/KELOHARJU-WILCOXON-WTI-SAMECAL-SR-2026]]"
concepts:
  - "[[concepts/return-seasonality]]"
  - "[[concepts/nonparametric-signed-rank]]"
  - "[[concepts/calendar-month-renewal]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/signed-absolute-rank-sum]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, calendar-seasonality, same-calendar-month, signed-rank, monthly-renewal, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 411910000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: long_short
expected_trade_frequency: "Approximately 10-12 completed XTI monthly positions per full post-warm-up year; exact-zero and absolute-tie states consume the month flat."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_STATISTIC_AND_SINGLE_CFD_TRANSLATION_RISK
r1_reasoning: "Peer-reviewed same-calendar commodity evidence with explicit crude-oil membership plus complete pinned R Core code/manual for the signed-rank statistic; the exact single-WTI conjunction remains an untested QM hypothesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, normalized endpoints, year bounds, sample floor, epsilon, strict absolute ranks, centered integer score, side, consumed attempt, fixed risk, hard stop, and monthly lifecycle are deterministic and locked."
r3_data_available: PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered XTIUSD.DWX D1 history and native MT5 state supply every runtime input; five-year warm-up, D1 session labels, rolls, and futures/CFD basis remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, sorting, comparisons, integer arithmetic, ATR risk controls, and execution state; no trained signal or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: prior 10 exact same-calendar years; minimum 5 valid observations; return/tie epsilon 1e-12; 3000 D1 history bars; ATR(20)*3.5 stop; 35-day stale exit; 1500-point entry spread ceiling."
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
review_focus: "Falsify a direct-WTI signed-rank same-calendar sleeve outside the directional XAU/SP500/NDX/XNG book. Verify normalized completed endpoints, exact Y-1..Y-10 samples, five-observation floor, zero/tie rejection, strict absolute ranks, rank-sum invariants, centered score direction, consumed month, fixed risk, frozen stop, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_month_bar_clock, uniform_energy_label_normalization, exact_prior_year_same_calendar_months, completed_month_endpoints, no_current_month_price, five_sample_floor, ten_year_cap, return_zero_epsilon, strict_absolute_rank_ties, positive_rank_sum, centered_score_invariants, sign_only_direction, monthly_attempt_state, monthly_renewal, risk_mode_dual, hard_stop_present, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-28 and decisions/2026-08-28_qm5_41191_wti_same_calendar_signed_rank_g0.md: R1 PASS with peer-reviewed crude-oil seasonality lineage and complete pinned primary software arithmetic; R2 PASS locks calendar, endpoints, sample, strict ranks, score, side, attempt, risk, stop, and lifecycle; R3 PASS registered native XTI D1 with warm-up/session/CFD risk; R4 PASS deterministic native arithmetic only. Canonical dedup found the expected same-calendar mean and median fuzzy neighbors; fixed fixtures resolve the signed-rank state as distinct."
---

# QM5_41191 WTI Same-Calendar Signed-Rank Seasonality

## Hypothesis

WTI demand, storage, hedging, and capital-allocation pressures may recur in
the same calendar month. An arithmetic mean lets one oil-shock year dominate,
an ordinary median discards most magnitude ordering, and a hit rate ignores
magnitude altogether. This card instead ranks the absolute size of the prior
five-to-ten returns for the same upcoming calendar month and follows the sign
whose observations own the greater total rank.

Direct WTI supplies crude-oil exposure absent from the stated directional
XAU, SP500, NDX, and XNG book. That economic distinction does not prove low
realized correlation. Q02 owns density/economics and unchanged Q09 owns
portfolio overlap.

## Source Traceability And Claim Boundary

The bounded packet is
`strategy-seeds/sources/KELOHARJU-WILCOXON-WTI-SAMECAL-SR-2026/source.md`,
SHA-256 `57FF7096210C5E48A7236DAD6799A3E6CE706E726BD704416064D5A803D10B98`,
authorized by
`decisions/2026-08-28_wti_same_calendar_signed_rank_source_approval.md`
before extraction.

Keloharju, Linnainmaa, and Nyberg supply the same-calendar-month information
object, explicit crude-oil membership, and a five-year history floor. Their
paper uses a broad futures cross-section and arithmetic-average ranking. The
pinned R Core implementation and manual supply the one-sample signed-rank
arithmetic. Neither source tests this direct-WTI signed-rank position.

No source return, alpha, probability, p-value, significance, density, profit
factor, drawdown, transaction cost, CFD equivalence, decorrelation, or
portfolio statistic transfers.

## Non-Duplicate Decision

The fail-closed checker scanned 4,690 registry identities, 1,341 cards, and
45 Strategy Wiki nodes. It found no exact identity and surfaced expected
fuzzy neighbors `QM5_20099_wti-samecal` and `QM5_41055_wti-medcal`. Receipt:
`artifacts/qm5_wti_samecal_srank_preallocation_dedup_20260828.json`.

Manual review fixes distinct functions:

- `QM5_20099` follows the arithmetic mean. On
  `[.01,.02,.03,.04,-.20]`, this card buys (`S=5`) while the mean is negative.
- `QM5_41055` follows the ordinary median. On six small negatives and four
  larger positives, this card buys (`S=13`) while the median is negative.
- `QM5_41059_wti-samecal-hit` counts positive observations. On six small
  positives and four larger negatives, this card sells (`S=-13`) despite a
  positive-observation majority.
- Fixed-month WTI cards do not recompute ranks. Recent WTI rank, slope,
  change-point, and location systems use contiguous recent month ends rather
  than disjoint observations from this calendar month in prior years.
- Certified `QM5_12567` is a short-horizon long-only XNG oscillator pullback.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_SAMECAL_SIGNED_ABSOLUTE_RANK_SUM_MONTHLY_RENEWAL`.

## Markets, Timeframe, And Cadence

- Host/traded symbol: exact `XTIUSD.DWX`, D1, slot 0.
- Intended magic: `411910000`.
- Decision: first executable tick of the first normalized D1 bar after a
  genuine broker-month transition.
- Formation: same target calendar month in exact years `Y-1..Y-10`, minimum
  five valid observations.
- Hold: next broker-month boundary; 35 days is stale repair.
- Expected pre-result cadence: ten to twelve positions/year after warm-up;
  Q02 retires below five in any full post-warm-up year.

## Formula

For target calendar month `M` in historical year `H`:

```text
pre_close(H,M) = close of the immediately preceding D1 bar, normalized into
                 the immediately preceding calendar month
end_close(H,M) = close of the final normalized D1 bar in (H,M), confirmed by
                 a following D1 bar in the immediately following month
r(H,M)         = ln(end_close(H,M) / pre_close(H,M))

collect valid r(Y-k,M), k=1..10
require 5 <= n <= 10
require abs(r[k]) > 1e-12
require abs(abs(r[i])-abs(r[j])) > 1e-12 for every i != j

rank abs(r[k]) strictly from 1 through n
V_plus = sum(rank[k] where r[k] > 0)
T      = n*(n+1)/2
S      = 2*V_plus-T

BUY  iff S > 0
SELL iff S < 0
FLAT iff S == 0 or any contract check fails
```

Score magnitude never changes risk. There is no p-value or significance
claim. Epsilon zeros and absolute ties consume the month flat; no average
ranks or alternate zero convention exists.

## Rules

These rules are the complete baseline. No arithmetic-mean or median fallback,
hit-rate boundary, fixed month list, recent-return confirmation, trend,
inventory, event, curve, volume, range, breakout, oscillator, volatility
signal, optimizer artifact, or external-data filter is authorized.

## 4. Entry Rules

1. Evaluate only on exact `XTIUSD.DWX`, D1, EA ID 41191, slot 0.
2. Process malformed and later-month owned exposure before every entry gate.
3. Accept only a native same-day D1 label or one uniform `+1` calendar-day
   energy offset. Require the normalized current D1 date to equal the current
   broker date and apply the same offset to every historical endpoint.
4. Enter only on the first normalized D1 bar after a genuine broker-month
   transition. A mid-month initial attachment consumes no historical
   opportunity and must remain flat until the next genuine boundary.
5. Persist the broker `yyyymm` attempt before history, signal, news, spread,
   quote, ATR, sizing, margin, or submission. Never retry the month after any
   downstream outcome or restart.
6. Copy at most 3,000 completed D1 bars. For each exact year `Y-1..Y-10`,
   select the final normalized D1 close in the target month and its immediate
   prior D1 close. Confirm the prior and following bars belong to the adjacent
   calendar months. Skip an invalid year without substitution.
7. Require five to ten valid finite log returns, no epsilon-zero return, and
   no epsilon-level absolute-return tie.
8. Sort observation indexes by absolute return ascending, assign strict ranks
   1 through `n`, and prove the rank total equals `n(n+1)/2`. Sum ranks of
   positive returns and compute the centered integer score exactly.
9. Positive score buys WTI; negative score sells WTI; exact zero consumes the
   month flat. Magnitude never changes size.
10. Require valid completed-bar ATR(20,D1). Place one frozen hard stop at
    `3.5*ATR`; use no take-profit.
11. Require a valid quote and no genuinely positive spread above 1,500
    points. Modeled zero `.DWX` spread is valid.
12. Submit one market order once. No retry, pending order, scale-in, grid,
    martingale, pyramid, hedge, or companion leg exists.

## 5. Exit Rules

1. At the first observed D1 bar in a later broker `yyyymm`, close owned
   exposure before evaluating the new month.
2. Close after 35 elapsed calendar days as a final stale guard.
3. Immediately flatten duplicate, wrong-symbol, wrong-magic, invalid-side,
   missing-stop, invalid-volume, or invalid-open-time exposure.
4. The frozen broker hard stop and framework kill switch remain authoritative.
5. Framework Friday close is disabled for this monthly identity.
6. No target, reversal, trailing stop, break-even move, partial exit, or
   discretionary close is authorized.

## 6. Filters (No-Trade Module)

- Exact host, D1, EA 41191, slot 0, and registered magic.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes are OFF; the signal uses completed native price history.
- Uniform label normalization, genuine month boundary, durable attempt,
  endpoint identity, sample floor, zero/tie checks, rank invariants, score,
  quote, spread, ATR, sizing, and stop geometry must be valid.
- Failure after attempt persistence consumes the month.

## 7. Trade Management Rules

- Own at most one position under magic `411910000`.
- Freeze the original hard stop; never widen, trail, or remove it.
- Run malformed, later-month, and stale repair on every tick before entry
  logic.
- Persist the last attempted broker `yyyymm` in terminal global state so a
  restart cannot create a second monthly attempt.
- Do not add, pyramid, grid, hedge, partially close, or reverse.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5*ATR(20,D1)` from completed data.
- No take-profit and no signal-magnitude sizing.
- Invalid stop distance, tick value, tick size, volume step, minimum volume,
  computed lot, or price consumes the month.
- This card creates no live, demo, shadow, stress, or optimization preset.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_years` | 10 | exact prior-year cap |
| `strategy_min_observations` | 5 | exact valid-sample floor |
| `strategy_signal_epsilon` | 1e-12 | return-zero and absolute-tie boundary |
| `strategy_history_bars_d1` | 3000 | bounded endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 35 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | preserve monthly hold |

No sweep, statistic fallback, month selection, endpoint, direction, sample
bound, stop, or lifecycle change is authorized.

## Data Requirements

- Native `XTIUSD.DWX` D1 OHLC and timestamps from the registered factory
  history route.
- Broker clock, symbol quotes/properties, positions, deal history, and
  terminal global variables.
- No futures curve, inventory, volume, open interest, COT, event feed, API,
  CSV, optimizer artifact, or manual signal input.

## Source-Defined Rules

The trading source defines recurring same-calendar-month return information,
includes crude oil, and uses a five-year history floor. The pinned R Core
files define the one-sample positive absolute-rank sum. Neither defines this
single-CFD conjunction, strict zero/tie reduction, risk, stop, or lifecycle.

## QM Interpretations

QM fixes the uniform energy-label normalization, ten-year cap, exact
completed endpoints, strict epsilon zero/tie rule, centered integer score,
absolute sign, direct CFD carrier, durable attempt, fixed risk, ATR stop,
spread ceiling, monthly renewal, and stale guard. They are pre-result
falsification choices.

## Framework Execution Overrides

The framework kill switch, ownership checks, fixed-risk sizing contract,
position/deal state, and order handling remain authoritative. Both news axes
and framework Friday close are OFF. This non-live card creates no live
mapping, deployment manifest, execution-contract registry row, or promotion
entitlement.

## Exit Precedence

1. Framework kill switch and broker hard stop remain authoritative.
2. Malformed, duplicate, wrong-side, or missing-stop exposure is flattened.
3. First observed D1 boundary in a later broker month is the ordinary exit.
4. The 35-day close repairs only a survivor.

## Runtime Data Dependencies

Runtime uses only native D1 OHLC/timestamps, broker time, current quotes,
symbol contract properties, positions, deals, and terminal-global attempt
state. It has no external feed, fitted artifact, trained output, optimizer
artifact, or manual signal input.

## Falsification And Requalification

Q02 retires the identity on zero trades, fewer than five completed positions
per full post-warm-up year, nonpositive governed economics, wrong endpoint
identity, current-month leakage, fewer than five valid historical returns,
wrong zero/tie handling, incorrect rank or score, retry, missing stop, wrong
monthly lifecycle, nondeterminism, invalid risk mode, or insufficient local
history. Any change to estimator, endpoint, sample bounds, epsilon, direction,
stop, or hold creates a new identity.

No weak result may be rescued by reverting to the mean, median, hit rate,
selecting months, adding recent trend/return, inventory, event, curve, volume,
volatility, or price-action filters, changing the sample bounds, or extending
the hold.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, boundary, attempt, history, endpoints, ranks, score, side, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-month, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| monthly renewal and survivor repair | Trade Close | strategy lifecycle helper; Friday close disabled |
| kill switch, ownership, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | `Strategy_NewsFilterHook` returns false; both modes OFF |

## Kill Criteria

Retire rather than tune on fewer than five completed positions per full post-
warm-up year; zero trades; nonpositive governed economics; wrong or partial
monthly endpoints; current-month leakage; invalid sample count; zero/tie
contract breach; incorrect ranks, invariant, score, or side; retry; missing
stop; wrong monthly lifecycle; nondeterminism; or registry/risk mismatch.

## Validation Plan

Q01 must prove:

1. native and uniform `+1` labels select only the exact normalized month
   boundary and same-calendar returns use completed endpoints for exact years
   `Y-1..Y-10`, with December/January wrapping and invalid years skipped;
2. five-to-ten sample bounds, epsilon-zero rejection, absolute-tie rejection,
   strict rank assignment, rank-total invariant, centered score, and side;
3. governed fixtures distinguish mean, median, and hit-rate neighbors;
4. no current-month OHLC, volume, or tick price enters the signal;
5. persistent `yyyymm` attempts prevent same-month retry after every
   downstream failure and restart;
6. fixed-risk sizing uses a valid frozen completed-bar ATR stop;
7. next-month close, malformed repair, stale guard, and disabled Friday close
   remain reachable; and
8. strict compile, card lint, build checks, setfile schema, magic resolver,
   and static Q01 validation pass.

Q02 alone may measure density and baseline economics. Q09 alone may establish
realized portfolio correlation.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-28 | initial WTI same-calendar signed-rank card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-28 | APPROVED; R1-R4 PASS | `decisions/2026-08-28_qm5_41191_wti_same_calendar_signed_rank_g0.md`; approved source packet |
| Q01 Build Validation | 2026-08-28 | NOT_BUILT | deterministic allocation and build pending |
| Q02 Baseline Screening | 2026-08-28 | NOT_ENQUEUED_Q01_PENDING | no work item before compile/review PASS |

## Safety Boundary

This card authorizes one branch-only non-live build, deterministic allocation,
strict Q01 validation, one `RISK_FIXED` D1 backtest setfile, and one paced Q02
enqueue only after prerequisites and a non-binding CPU check. It does not
authorize a manual backtest, live/demo/shadow/stress/optimization preset,
AutoTrading, `T_Live`, deploy or live manifest, portfolio-gate change,
portfolio admission, correlation waiver, terminal control, or queue deletion.
