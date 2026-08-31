---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-WALLIS-MOORE-CME-XAUXAG-MTURNPOINT-RV-2026_S01
variant_id: SCHWEIKERT-WALLIS-MOORE-CME-XAUXAG-MTURNPOINT-RV-2026_S01
source_id: SCHWEIKERT-WALLIS-MOORE-CME-XAUXAG-MTURNPOINT-RV-2026
ea_id: QM5_41246
slug: xauxag-mturnpoint-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41246_xauxag-mturnpoint-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-31
created_by: Research+Development
last_updated: 2026-08-31
g0_status: APPROVED
g0_decision: decisions/2026-08-31_qm5_41246_xauxag_monthly_turning_point_reversion_g0.md
source_approval: decisions/2026-08-31_xauxag_monthly_turning_point_reversion_source_approval.md
source_author: "Karsten Schweikert; W. Allen Wallis; Geoffrey H. Moore; CME Group"
source_authors: "Karsten Schweikert; W. Allen Wallis; Geoffrey H. Moore; CME Group"
source_citation: "Schweikert (2018), Are gold and silver cointegrated?, Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; CME Group Gold & Silver Ratio Spread research; Wallis and Moore (1941), A Significance Test for Time Series Analysis, JASA 36(215), 401-409, DOI 10.1080/01621459.1941.10500577; governed complete public turning-point method record."
source_citations:
  - type: peer_reviewed_relationship_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; governed parent packet"
    quality_tier: A
    role: state_dependent_gold_silver_relation_and_adverse_evidence
  - type: official_exchange_carrier_research
    citation: "CME Group, Gold & Silver Ratio Spread."
    location: "official CME Group research preserved in governed parent packet"
    quality_tier: A_official
    role: intermarket_ratio_carrier_and_distinct_metal_drivers
  - type: peer_reviewed_statistical_method_record
    citation: "Wallis, W. A., and Moore, G. H. (1941). A Significance Test for Time Series Analysis. JASA 36(215), 401-409."
    location: "DOI 10.1080/01621459.1941.10500577; bibliographic record only; body not claimed completely read"
    quality_tier: A_record_only
    role: phase_frequency_and_turning_point_lineage
  - type: public_method_implementation
    citation: "Hart, A., and Martinez, S. spgs 1.0-4. CRAN."
    location: "public mirror commit 987257510f8b2a7ffe903d6b840021befbb4de58; complete relevant files preserved by governed parent"
    quality_tier: A_method_implementation
    role: exact_strict_turning_point_count_and_iid_null_moments
  - type: governed_composite_source
    citation: "QuantMechanica bounded XAU/XAG thirteen-month turning-point persistence reversion packet."
    location: "strategy-seeds/sources/SCHWEIKERT-WALLIS-MOORE-CME-XAUXAG-MTURNPOINT-RV-2026/source.md"
    quality_tier: internal_governed
    role: exact_carrier_sample_count_boundary_direction_risk_atomicity_and_lifecycle
strategy_mechanic: monthly-xauxag-thirteen-synchronized-completed-month-log-ratio-endpoints-strict-local-extrema-count-below-iid-null-mean-contrarian-equal-notional-basket
sources:
  - "[[sources/SCHWEIKERT-WALLIS-MOORE-CME-XAUXAG-MTURNPOINT-RV-2026]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/nonparametric-path-persistence]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/synchronized-completed-month-log-ratio]]"
  - "[[indicators/strict-turning-point-count]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, market-neutral-style, relative-value, structural-reversion, turning-point-count, local-extrema, monthly-rebalance, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals, gold_silver_relative_value]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41246_XAU_XAG_MTURNPOINT_RV_D1
symbol: XAUUSD.DWX
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 412460000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 5-8 completed XAU/XAG packages per full post-warm-up year after thirteen synchronized completed month ends; one consumed attempt per broker month."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_CARRIER_STATISTIC_AND_DIRECTION_TRANSLATION_RISK
r1_reasoning: "Peer-reviewed state-dependent gold/silver relationship evidence, official exchange carrier research, named peer-reviewed turning-point lineage, and complete public method files; the exact contrarian basket is an untested QM translation."
r2_mechanical: PASS
r2_reasoning: "Exact symbols, synchronized month ends, log-ratio orientation, strict local extrema, integer boundary, contrarian sides, consumed attempt, equal notionals, aggregate fixed risk, atomicity, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered XAUUSD.DWX and XAGUSD.DWX D1 histories and native MT5 state supply every runtime input; synchronization, holiday, financing, and continuous-CFD basis risk remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, strict comparisons, integer arithmetic, ATR risk controls, and execution state; no trained signal or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 synchronized ratio endpoints; TP<=7; 1e-12 tie epsilon; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 hard stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/500-point spread ceilings."
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
review_focus: "Falsify a thirteen-completed-month strict-turning-point gold/silver ratio reversion basket outside the directional XAU/SP500/NDX/XNG book. Verify synchronization, ratio orientation, tie rejection, eleven local comparisons, TP range and 7/8 boundary, contrarian sides, consumed attempt, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, thirteen_consecutive_completed_months, synchronized_month_end_pairs, latest_pair_per_month, chronological_ratio_orientation, pairwise_ratio_distinction, eleven_local_triples, strict_turning_point_count, integer_boundary_7_8, contrarian_pair_sides, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-31 and decisions/2026-08-31_qm5_41246_xauxag_monthly_turning_point_reversion_g0.md: R1 PASS with peer-reviewed gold/silver evidence, official exchange carrier research, named peer-reviewed turning-point lineage, and complete public method files; R2 PASS locks synchronized endpoints, strict count, boundary, contrarian sides, attempt, risk, atomicity, and lifecycle; R3 PASS registered native XAU/XAG D1 with synchronization/CFD risk; R4 PASS deterministic native arithmetic only. The corrected canonical checker returned CLEAN and manual family review separates the outright WTI, global-rank, fixed-pair, distribution, and magnitude-retaining neighbors."
---

# QM5_41246 XAU/XAG Thirteen-Month Turning-Point Reversion

## Hypothesis

Gold and silver share precious-metal and USD drivers but differ in monetary,
safe-haven, industrial, and business-cycle exposure. When thirteen completed
monthly gold/silver log-ratio endpoints contain fewer strict local peaks and
troughs than the iid null mean, the relative path has been unusually
persistent. This card treats that persistent displacement as exhaustion and
fades its oldest-to-newest direction for one broker month.

Opposite equal-target-notional legs reduce common outright-metal direction and
form a market-neutral-style stream different from the directional XAU,
SP500, NDX, and XNG book. They do not prove neutrality or decorrelation. Q02
owns density and economics; unchanged Q09 owns realized overlap.

## Source Traceability And Claim Boundary

The single governed source ID resolves to
`strategy-seeds/sources/SCHWEIKERT-WALLIS-MOORE-CME-XAUXAG-MTURNPOINT-RV-2026/source.md`,
SHA-256 `F98EE783BB3AE74A357C7AD953A2F55EDCCAA75326B810B0F2402FE1A1440A2F`
at source approval commit `5149f5aec9`. It is authorized by
`decisions/2026-08-31_xauxag_monthly_turning_point_reversion_source_approval.md`.

Schweikert supplies related but state-dependent gold/silver evidence and
binding adverse evidence. CME supplies the intermarket carrier and distinct
metal drivers. The Wallis-Moore record and complete pinned public method files
supply strict local-extrema counting and its iid null mean. None tests this
sample, gate, contrarian package, continuous CFDs, or fixed-dollar execution
contract.

No source return, alpha, probability, p-value, significance, trade density,
profit factor, drawdown, transaction cost, hedge ratio, neutrality, CFD
equivalence, decorrelation, or portfolio-correlation statistic is imported.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_xauxag_mturnpoint_rv_preallocation_dedup_20260831.json`,
SHA-256 `B7839F5EC0EC0E9EF188908B0D168F600AB76E183D2D657EC1491AEE93812D18`,
scanned 4,745 registry identities, 1,383 cards, and all 45 Strategy Wiki nodes
and returned `CLEAN`.

The mechanic remains distinct:

- `QM5_41171_wti-mturnpoint-tr` applies the count to one outright WTI path
  and follows direction; this card fades a synchronized two-metal ratio.
- `QM5_41181_xauxag-mkendall-rv` votes all 78 chronological endpoint pairs;
  this card compares only eleven overlapping local triples.
- `QM5_41174_xauxag-mspearman-rv` ranks all levels against time,
  `QM5_41168_xauxag-mcoxstuart-rv` compares six fixed early/late pairs, and
  `QM5_41187_xauxag-mks-rv` compares fixed distributions. This card assigns
  no ranks and has no split or ECDF.
- `QM5_41123_xauxag-mpath-eff-rv` and RMS variants retain magnitudes; this
  card discards magnitude after strict comparisons.
- Ratio z-score, OLS, CADF, quantile, and MAD systems fit centers, betas,
  scales, or thresholds. This card fits none.
- Certified `QM5_12567` is a long-only two-day XNG oscillator pullback.

Verdict:
`CLEAN_XAUXAG_THIRTEEN_MONTH_STRICT_TURNING_POINT_PERSISTENCE_CONTRARIAN_EQUAL_NOTIONAL_REVERSION`.

## Markets, Timeframe, And Cadence

- Host/traded slot 0: exact `XAUUSD.DWX`; companion/traded slot 1: exact
  `XAGUSD.DWX`.
- Logical tester symbol: `QM5_41246_XAU_XAG_MTURNPOINT_RV_D1` on the XAU host.
- Timeframe: D1; intended magics `412460000` and `412460001`.
- Decision: first synchronized executable tick after a genuine broker-month
  transition, within 180 elapsed minutes of raw host D1 bar open.
- Formation: thirteen consecutive synchronized completed broker-month ends.
- Hold: first later broker month; forty days is stale repair.
- Expected pre-result cadence: five to eight packages/year, centered near six;
  Q02 retires below five in any full post-warm-up year.

## Formula

For chronological synchronized completed-month close pairs `i=0..12`:

```text
L[i] = ln(XAU_close[i]) - ln(XAG_close[i])
require abs(L[i] - L[j]) > 1e-12 for every i != j

TP = 0
for i = 1..11:
  peak   = L[i-1] < L[i] and L[i] > L[i+1]
  trough = L[i-1] > L[i] and L[i] < L[i+1]
  if peak or trough:
    TP += 1

require 0 <= TP <= 11
qualify iff 3*TP < 22            # exactly TP <= 7
delta = L[12] - L[0]

SELL XAU / BUY XAG iff qualify and delta >  1e-12
BUY XAU / SELL XAG iff qualify and delta < -1e-12
FLAT otherwise
```

The integer boundary is below `2*(13-2)/3=22/3`. It is not a significance
test. A p-value, normal approximation, continuity correction, rank transform,
alternate boundary, fitted value, magnitude fallback, or continuation side is
forbidden. The count never changes size.

## Rules

The EA implements one exact baseline. Invalid history, arithmetic, or state
consumes the current broker month flat after persisting the attempt key. The
current month never contributes a signal price. Lifecycle repair runs before
entry-only gates.

### Source-defined rules

- the gold/silver ratio is an intermarket relative-value carrier;
- a strict local peak or trough is a turning point;
- under an iid continuous null, expected count is `2*(n-2)/3`; and
- the count is an ordered-series diagnostic, not a sizing variable.

### QM interpretations

- use thirteen synchronized completed broker-month log-ratio endpoints;
- reject every ratio tie within `1e-12`;
- split at the iid null mean itself for density, not significance;
- fade the oldest-to-newest ratio displacement;
- consume the month before all fallible gates; and
- map to equal-notional Darwinex XAU/XAG CFDs with fixed risk and atomic repair.

## 4. Entry Rules

On every new D1 host bar, in this order:

1. Require exact EA ID, symbols, D1 period, slots, magics, fixed-risk
   framework inputs, and every locked strategy input.
2. Repair malformed owned exposure and process later-month/stale exits before
   entry gates.
3. Normalize the raw host-bar date under one uniform label convention and
   require a genuine new month within 180 elapsed minutes of raw bar open.
4. Persist current `yyyymm` before history, signal, news, spread, quote, ATR,
   sizing, margin, or order gates. Never retry that month.
5. Reject owned exposure or a same-magic current-month entry deal.
6. Reconstruct exactly thirteen consecutive synchronized completed month-end
   pairs from bounded D1 buffers. Reject missing, duplicate, unmatched,
   current, nonchronological, nonpositive, nonfinite, or stale data.
7. Compute thirteen gold-minus-silver log ratios. Reject any pairwise
   difference no greater than `1e-12`.
8. Count strict peaks/troughs across eleven interiors, require `0..11`, and
   qualify only at `3*TP<22` with endpoint displacement beyond `1e-12`.
9. Map a positive displacement to short XAU/long XAG and a negative
   displacement to long XAU/short XAG. Any other state consumes flat.
10. Require both spreads in bounds, executable quotes, completed-bar
    `ATR(20,D1)`, valid metadata, fixed-risk sizing, and target absolute-
    notional mismatch no greater than 20%.
11. Split aggregate stop risk equally, reduce only to equalize target
    notionals, attach frozen `3.5*ATR(20,D1)` hard stops, and no targets.
12. Submit XAU first and XAG second. Keep only one correctly directed,
    registered, stop-protected position per slot; otherwise flatten all owned
    legs immediately.

## 5. Exit Rules

1. Framework kill switch and broker hard stops remain authoritative.
2. Close both legs on the first processed tick in a later broker month before
   considering replacement risk, even if the signal is unchanged.
3. Close after forty elapsed calendar days as stale repair.
4. Close every owned leg if the package is orphaned, duplicated, same-side,
   wrong-symbol, wrong-magic, wrong-direction, stopless, stale, or outside the
   20% notional-mismatch tolerance.
5. No intramonth flip, target, trail, break-even, partial close, Friday close,
   news exit, scale-in, grid, martingale, or pyramid is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbols, D1, EA ID, slots, fixed-risk,
  news/Friday, stress, or locked-input contract.
- Reject consumed attempt, owned exposure, same-month entry history,
  malformed synchronization, invalid month selection, ratio tie, invalid
  count/boundary, zero displacement, excessive spread, invalid quote,
  unavailable ATR, invalid stop/volume, or notional mismatch.
- Runtime may not read futures-chain, volume, open-interest, file, API,
  forecast, trained-output, optimizer-result, portfolio, or prior-pipeline
  state.

## 7. Trade Management Rules

- Maintain either zero exposure or one valid opposite-side two-leg package
  and one consumed attempt per broker month.
- Preserve hard stops; close before monthly renewal or after forty days.
- Run malformed-package repair before entry gates on every tick.
- Restart recovery combines terminal-persistent month state with positions
  and same-month deal history; no restart creates a second attempt.
- Recompute the approved entry-month direction only from completed historical
  endpoints when validating open-state side; current-month price is excluded.
- No randomness, adaptation, external state, partial close, scale-in, grid,
  martingale, or pyramiding is allowed.

## 8. Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Parameter | Baseline | Range |
|---|---:|---|
| `strategy_xag_symbol` | XAGUSD.DWX | locked |
| `strategy_endpoint_count` | 13 | locked |
| `strategy_max_turning_points` | 7 | locked inclusive |
| `strategy_ratio_tie_epsilon` | 0.000000000001 | locked |
| `strategy_history_bars_d1` | 900 | locked |
| `strategy_entry_window_minutes` | 180 | locked |
| `strategy_max_endpoint_gap_days` | 10 | locked |
| `strategy_atr_period_d1` | 20 | locked |
| `strategy_atr_sl_mult` | 3.5 | locked |
| `strategy_notional_ratio` | 1.0 | locked |
| `strategy_max_notional_mismatch_fraction` | 0.20 | locked |
| `strategy_max_hold_days` | 40 | locked |
| `strategy_xau_max_spread_points` | 1500 | locked |
| `strategy_xag_max_spread_points` | 500 | locked |
| `strategy_deviation_points` | 20 | locked |

Changing carrier, sample, tie treatment, count, boundary, direction, clock,
risk, stop, balance, hold, spread, order sequence, or retry policy requires a
new card and full pipeline run.

## Framework Execution Overrides

- Friday close: disabled to preserve the approved full-month hold.
- News temporal mode: OFF.
- News compliance profile: NONE.
- Legacy news mode: OFF.
- Kill switch: framework-first and never bypassed.
- Forced session flatten: none beyond next-month and stale repair.

## Exit Precedence

1. Framework kill switch and broker hard stops.
2. Malformed/orphaned/duplicate/wrong-side package repair.
3. First later normalized broker month.
4. Forty-day stale repair.
5. No source signal reversal, target, Friday, or news exit exists.

## Runtime Data Dependencies

Exact XAU/XAG native D1 timestamps and closes, broker time, symbol metadata,
quotes, completed-bar ATR, framework position/deal state, and one terminal-
persistent attempt marker. No external runtime dataset exists.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1` as one aggregate package budget.
- Each leg begins with half the stop-risk allowance before notional
  equalization; realized absolute notionals must remain within 20%.
- Stop: frozen `3.5*ATR(20,D1)` on each leg from the last completed bar.
- Maximum entry spreads: 1,500 XAU points and 500 XAG points.
- One package and one attempt per broker month.
- Turning-point count never changes size.
- No live, demo, shadow, stress, or optimization preset is authorized.
- Principal risks are relation shift or break, silver volatility dominance,
  two-leg fill failure, hard-stop gap/slippage, volume-rounding imbalance,
  holiday synchronization loss, CFD financing/basis, density below floor,
  and realized overlap with the certified XAU sleeve.

Equal notionals are market-neutral-style, not proof of dollar, beta,
volatility, factor, or portfolio neutrality.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS_WITH_CARRIER_STATISTIC_AND_DIRECTION_TRANSLATION_RISK | Peer-reviewed gold/silver relation research, official exchange carrier evidence, named peer-reviewed turning-point lineage, and complete public method files; exact conjunction untested. |
| R2 | PASS | Clock, synchronization, ratio, strict count, boundary, sides, attempt, risk, atomicity, and lifecycle fixed. |
| R3 | PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK | Registered native XAU/XAG D1 routes supply every runtime input. |
| R4 | PASS | Deterministic native arithmetic and state only; no trained method or external feed. |

## 9. Failure Modes And Kill Criteria

- Retire on zero packages, fewer than five completed packages in any full
  post-warm-up year, nonpositive governed economics, or downstream failure.
- Fail on current-month leakage, missing/duplicate month keys, unmatched or
  stale pairs, wrong ratio orientation, nonchronology, accepted tie, wrong
  endpoint count, turning-point count outside `0..11`, entry at `TP>=8`,
  wrong contrarian sides, retry, non-atomic package, notional imbalance,
  missing stop, wrong risk mode, or missed month exit.
- Retire on later portfolio-correlation rejection; no waiver is implied.
- Do not rescue failure by changing formation, tie epsilon, count, boundary,
  direction, carrier, risk, stop, balance, hold, spread, retry, or order
  sequence.

## Falsification And Requalification

Any change to the thirteen-month formation, strict local-extrema definition,
`TP<=7` boundary, contrarian direction, broker-month normalization, consumed
attempt, spread ceilings, risk mode, stop, or exit clock creates a new
execution contract and requires a new binary, stream reconciliation, Q02
restart, and full portfolio requalification. Ambiguity is `BLOCKED`, never
filled from results.

## 10. Execution And State Contract

- The D1 decision clock supports only raw-current-date labels and a uniformly
  applied raw-plus-one-day convention; mixed offsets fail closed.
- A month is consumed before all fallible gates. Terminal global state and
  deal history prevent restart retry.
- Current-month prices never contribute to the signal.
- Position repair and month rollover run every tick before entry-only gates.
- Logs expose decision month, label offset, endpoint times, log-ratio path,
  turning-point count, displacement, intended sides, balance, and state
  without credentials.

## 11. Portfolio Interaction

This opposite-leg precious-metals carrier is intended to reduce the common
directional XAU beta of the stated XAU/SP500/NDX/XNG book. Its local-extrema
path-persistence exhaustion driver is mechanically different from the
incumbent XNG cumulative-RSI pullback and outright metal/index sleeves. Those
are design facts only. No ex-ante or realized correlation is claimed, and no
portfolio gate, threshold, incumbent, manifest, or admission state changes
under this card. Q09 owns the first realized overlap verdict.

## 12. Validation Plan

1. Schema-lint both canonical and EA card copies.
2. Independently reproduce log-ratio orientation, tie rejection, monotone
   `TP=0`, alternating `TP=11`, 7/8 boundary, both contrarian sides, and
   invalid arithmetic cases.
3. Validate thirteen consecutive synchronized month keys, year rollover,
   latest-pair selection, current-month exclusion, staleness, label
   conventions, grace, attempt order, atomic repair, and monthly exit.
4. Require zero-error/zero-warning compile, build guardrails, exact two-slot
   scope, active registry identity, active magic rows, and source-fresh EX5.
5. Validate `basket_manifest.json`, then enqueue exactly one logical D1 Q02
   row after fresh Q01. Enqueue does not launch a manual tester.
6. Retire below the five-per-year floor or on nonpositive governed economics.

## 13. Framework Alignment

- no_trade: exact XAU/XAG/D1/EA/slots, locked inputs, risk, news, Friday, and
  stress validation.
- trade_entry: consume-first month clock, synchronized endpoints, log ratios,
  tie rejection, strict local-extrema count, `3*TP<22`, contrarian sides,
  spreads, quotes, ATR/stops, equal-notional sizing, and atomic submission.
- trade_management: malformed/wrong-side package repair, later-month exit,
  and stale repair before entry-only gates.
- trade_close: framework close helper per leg, broker hard stops, and kill
  switch.

## 14. Safety Boundary

This card authorizes one branch-only non-live V5 build and one paced logical
Q02 enqueue after strict Q01. It does not authorize a manual backtest,
`T_Live`, AutoTrading, deploy or live manifest, live/demo/shadow/stress/
optimization preset, portfolio-gate change, portfolio admission, threshold
change, correlation waiver, terminal process control, or claim that the
strategy is certified.

## Revision History

| Version | Date | Reason | Phase | Verdict |
|---|---|---|---|---|
| v1 | 2026-08-31 | initial source-bounded XAU/XAG turning-point persistence reversion card | G0 | APPROVED |
