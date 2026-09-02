---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-USDCHF-WW-SHIFT-20260902_S01
variant_id: AI-CODEX-USDCHF-WW-SHIFT-20260902_S01
source_id: AI-CODEX-USDCHF-WW-SHIFT-20260902
ea_id: QM5_41280
slug: usdchf-ww-shift-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41280_usdchf-ww-shift-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-02
created_by: Research+Development
last_updated: 2026-09-02
g0_status: APPROVED
g0_decision: decisions/2026-09-02_qm5_41280_usdchf_weekly_mann_whitney_shift_trend_g0.md
source_approval: decisions/2026-09-02_usdchf_weekly_mann_whitney_shift_trend_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; H. B. Mann; D. R. Whitney; R Core Team; OpenAI Codex"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; H. B. Mann; D. R. Whitney; R Core Team; OpenAI Codex"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003; Mann and Whitney (1947), On a Test of Whether one of Two Random Variables is Stochastically Larger than the Other, Annals of Mathematical Statistics 18(1), 50-60, DOI 10.1214/aoms/1177730491; R Core Team stats::wilcox.test source and manual; QuantMechanica bounded USDCHF weekly translation."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence under strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: broad_own_price_continuation_and_fixed_renewal_lineage
  - type: peer_reviewed_statistical_method_record
    citation: "Mann, H. B., and Whitney, D. R. (1947). On a Test of Whether one of Two Random Variables is Stochastically Larger than the Other. The Annals of Mathematical Statistics 18(1), 50-60."
    location: "DOI 10.1214/aoms/1177730491; Crossref metadata; article body not claimed completely read"
    quality_tier: A_record_only
    role: two_sample_ordinal_location_comparison_lineage
  - type: public_method_implementation
    citation: "R Core Team, stats::wilcox.test source and manual."
    location: "public wch/r-source mirror commit 7344a2d9d96b3c2b997535d3abc8c3a44af16e82; complete files bound in retrieval_route_20260902.json"
    quality_tier: A_method_implementation
    role: exact_two_sample_rank_sum_and_pair_count_definition
  - type: governed_composite_source
    citation: "QuantMechanica bounded USDCHF weekly fixed-block Mann-Whitney location-shift continuation packet."
    location: "strategy-seeds/sources/AI-CODEX-USDCHF-WW-SHIFT-20260902/source.md"
    quality_tier: internal_governed
    role: exact_carrier_clock_sample_threshold_risk_and_lifecycle
strategy_mechanic: weekly-usdchf-twelve-completed-d1-closes-fixed-six-older-six-newer-strict-no-tie-mann-whitney-u-location-shift-threshold-24-12-continuation-friday-flat
sources:
  - "[[sources/AI-CODEX-USDCHF-WW-SHIFT-20260902]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/nonparametric-location-shift]]"
  - "[[concepts/forex-weekly-continuation]]"
indicators:
  - "[[indicators/completed-d1-close]]"
  - "[[indicators/mann-whitney-u-pair-count]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [forex, swiss-franc, structural-trend, mann-whitney-location-shift, wilcoxon-rank-sum, fixed-block-rank-comparison, weekly-decision, friday-flat, atr-hard-stop, symmetric-long-short, low-frequency]
markets: [forex]
timeframes: [D1]
target_symbols: [USDCHF.DWX]
primary_target_symbols: [USDCHF.DWX]
single_symbol_only: true
logical_symbol: USDCHF.DWX
symbol: USDCHF.DWX
host_symbol: USDCHF.DWX
symbol_slot: 0
symbol_slots: [0]
magic: 412800000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: long_short
expected_trade_frequency: "About 10-25 completed USDCHF positions/year after warm-up; at most one consumed attempt per framework broker week."
expected_trades_per_year_per_symbol: 18
expected_hold_time: "first eligible weekly decision through mandatory Friday close; seven calendar days maximum"
expected_regime: "persistent short-horizon USDCHF price-level migration; vulnerable to range churn, regime reversal, and CHF discontinuities"
expected_pf: 1.01
expected_dd_pct: 20.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_METHOD_AND_CARRIER_CADENCE_TRANSLATION_RISK
r1_reasoning: "Complete-read peer-reviewed broad continuation evidence, named Mann-Whitney record, and complete pinned R Core method files; the exact USDCHF weekly conjunction is explicitly untested synthesis."
r2_mechanical: PASS
r2_reasoning: "Framework week clock, exact completed bars, fixed six/six blocks, strict ties, 36 pair counts, complement invariant, thresholds, side, consumed attempt, fixed risk, hard stop, Friday exit, and stale repair are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered USDCHF.DWX native D1 history and MT5/framework state supply every runtime input; no rate, futures-curve, macro, or external series is required."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, strict comparisons, integer arithmetic, ATR risk controls, and execution state; no trained signal, prohibited signal input, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: exact USDCHF.DWX D1; 12 completed bars; fixed block size 6; U lower/upper boundaries 12/24; 128-bar D1 history request; six-hour weekly entry grace; ATR(20)*3.0 hard stop; seven-day stale repair; 50-point spread ceiling; Friday 21:00 broker close."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: true
pipeline_phase: Q01
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED_Q01_PENDING
force_build: true
review_focus: "Falsify a direct USDCHF weekly ordinal location-shift continuation outside the certified index/metal/energy book. Verify the sanctioned framework W1 key, forming-bar exclusion, exact twelve D1 closes, fixed six/six membership, strict ties, all 36 comparisons, complementary U invariant, inclusive 12/24 boundaries, side, consumed attempt, fixed risk, hard stop, mandatory Friday flattening, and stale repair. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, sanctioned_framework_week_key, first_eligible_week_bar, forming_bar_excluded, twelve_completed_d1_closes, fixed_six_by_six_membership, strict_no_tie_combined_ranks, all_36_cross_block_pairs, complementary_u_invariant, inclusive_u_12_24_thresholds, weekly_attempt_state, fixed_risk, hard_stop_present, friday_close_enabled, seven_day_stale_repair, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-02 and decisions/2026-09-02_qm5_41280_usdchf_weekly_mann_whitney_shift_trend_g0.md: R1 PASS with complete-read peer-reviewed continuation evidence, named Mann-Whitney record, and complete pinned R Core method files while carrier/cadence translation remains explicit; R2 PASS locks week key, bars, blocks, ties, pair counts, thresholds, direction, attempt, risk, stop, Friday close, and repair; R3 PASS registered native USDCHF D1; R4 PASS deterministic native arithmetic only. Canonical dedup returned CLEAN and manual review separates monthly WTI rank shift, D1 mean-return sign, 12-month FX cross-sectional momentum, and USDCHF cointegration families."
---

# QM5_41280 USDCHF Weekly Mann-Whitney Location-Shift Trend

## Hypothesis

A broad ordinal migration of recent USDCHF D1 closing levels relative to the
immediately older block can identify short-horizon continuation without a
moving average, oscillator, fitted coefficient, or second instrument. The EA
continues the shift only once per broker week and is flat before the weekend.

This is a falsifiable direct-forex hypothesis. It is not evidence that USDCHF
is profitable, persistent, independent, or decorrelated. Q02 owns activity
and economics; Q04 owns temporal robustness; Q09 alone owns portfolio overlap.

## Source Traceability And Claim Boundary

The governed source is
`strategy-seeds/sources/AI-CODEX-USDCHF-WW-SHIFT-20260902/source.md`, approved
by
`decisions/2026-09-02_usdchf_weekly_mann_whitney_shift_trend_source_approval.md`
and committed as `cae9a7497d` before extraction.

Moskowitz, Ooi, and Pedersen supply complete-read peer-reviewed broad own-price
continuation lineage. Mann and Whitney supply the named peer-reviewed ordinal
method identity. Complete pinned R Core files define the no-tie statistic as a
rank sum or favorable-pair count. The original 1947 article body is not
represented as completely read. None of those records tests USDCHF, the weekly
clock, twelve daily levels, this split, these boundaries, CFD costs, or the
Friday lifecycle.

No source return, alpha, probability, significance, profit factor, drawdown,
trade count, cost, CFD equivalence, decorrelation, or portfolio statistic is
imported.

## Non-Duplicate Decision

The corrected-root fail-closed receipt
`artifacts/qm5_usdchf_ww_shift_tr_preallocation_dedup_20260902.json`, SHA-256
`E0FD0C192E36312BA520D214FF3A4A800A36E42B0CF4A6FD5C860A7050881741`,
found no exact or fuzzy identity across 4,779 registry rows, 1,415 card files,
and all 45 Strategy Wiki nodes.

- `QM5_41176_wti-mwilcoxon-shift-tr` uses completed monthly WTI levels and a
  next-month lifecycle; this card uses USDCHF D1 levels, a weekly opportunity
  set, native FX costs, and mandatory Friday flattening.
- `QM5_10145_tsm-meanret` trades a rolling endpoint/mean-return sign every D1
  bar across a broad universe; this card uses a fixed ordinal block statistic
  and one consumed weekly attempt.
- `QM5_1111_qp-fx-momentum-12m` ranks seven currencies cross-sectionally over
  252 D1 bars and owns a basket; this card is single-symbol own-history.
- USDCHF cointegration cards require a second tradable leg, fixed beta, and
  spread z-score; this card has none.

Verdict:
`DISTINCT_USDCHF_WEEKLY_FIXED_SIX_BY_SIX_D1_CLOSE_MANN_WHITNEY_U24_LOCATION_SHIFT_CONTINUATION_FRIDAY_FLAT`.

## Markets, Timeframe, And Cadence

- Exact traded/host symbol: `USDCHF.DWX`, slot 0, magic `412800000`.
- Exact signal and execution timeframe: D1.
- Decision clock: the first eligible D1 processing edge after
  `QM_CalendarPeriodKey(PERIOD_W1, USDCHF.DWX, 0)` advances, within six elapsed
  hours of the raw current D1 bar open.
- Formation: exactly twelve completed D1 closes, current/forming bar excluded;
  fixed older/newer blocks of six.
- Hold: framework Friday close at 21:00 broker time; seven elapsed calendar
  days is stale repair.
- Expected pre-result cadence: 10-25 completed positions per full post-warm-up
  year; retire below ten.

## Exact Formula

For chronological completed D1 prices `C[0..11]`:

```text
O = C[0..5]
N = C[6..11]

require C is positive, finite, chronological, and pairwise distinct

U_new = count(N[j] > O[i] for all i,j in 0..5)
U_old = count(O[i] > N[j] for all i,j in 0..5)

require U_new + U_old == 36

BUY  iff U_new >= 24
SELL iff U_new <= 12
FLAT otherwise
```

`U_new` equals the newer combined rank sum less 21. The thresholds are
inclusive and symmetric about 18. No tie averaging, p-value, variable split,
maximum search, endpoint direction, volatility signal, or fallback exists.
Signal magnitude never changes risk.

Exact enumeration of 924 no-tie six-rank assignments gives 364 qualifying
states, split 182/182. This is a market-free density design fact only.

## Rules

- Exact `ea_id=41280`, `USDCHF.DWX`, D1, slot 0, magic `412800000`.
- Consume the sanctioned framework week key before every fallible entry gate.
- Use shifts 1 through 12 from the exact D1 series; never read shift 0.
- Split only after observation six and count every strict cross-block pair.
- Buy at `U_new>=24`, sell at `U_new<=12`; central, tied, or invalid state is
  flat for the consumed week.
- Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Both news axes and legacy news mode are OFF. Friday close is ON.

## 4. Entry Rules

1. Require exact EA ID, magic slot, symbol, D1 period, risk mode, news mode,
   Friday mode, and locked strategy inputs.
2. Run position-integrity repair and stale handling before entry-only gates.
3. Detect the genuine current week with the framework calendar helper. Enter
   only within six elapsed hours of the raw current D1 bar open.
4. Persist the current week key before history, signal, spread, quote, ATR,
   sizing, margin, or order checks. No later tick retries that week.
5. Reject owned exposure or a same-magic entry deal already recorded in the
   current week.
6. Load exactly twelve completed D1 bars. Reject missing/duplicate/nonordered
   timestamps, nonpositive/nonfinite closes, shift-0 leakage, or any exact
   close tie.
7. Count all 36 comparisons both ways and require the complement invariant.
8. Continue only at the exact inclusive U boundaries. Central or invalid state
   consumes the week flat.
9. Require spread no more than 50 points, executable quote, completed-bar
   `ATR(20,D1)`, valid stop/volume metadata, fixed-risk sizing, and margin.
10. Open one position with a frozen normalized `3.0*ATR(20,D1)` hard stop, no
    target, no partial exposure, and no signal-strength sizing.

## 5. Exit Rules

1. Framework kill switch and broker hard stop are authoritative.
2. Framework Friday close at 21:00 broker time flattens before the weekend.
3. Close after seven elapsed calendar days as stale repair.
4. Close immediately on duplicate, wrong-symbol, wrong-magic, wrong-side,
   invalid-volume, or stopless owned exposure.
5. No intraday flip, target, trail, break-even, partial close, scale-in, grid,
   martingale, averaging, or pyramid is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside the exact symbol, period, identity, fixed-risk,
  news/Friday, or locked-input contract.
- Reject a consumed week, late weekly edge, owned exposure, same-week entry
  history, malformed D1 series, exact tie, bad U invariant, central signal,
  excessive spread, invalid quote, unavailable ATR, invalid stop/volume, or
  insufficient margin.
- Terminal-global state plus entry-deal history prevent restart retries.
  Tester initialization may clear only a future/prior-run marker.
- Runtime may not read rates, futures chains, volume, open interest, files,
  APIs, forecasts, trained outputs, optimizer results, or portfolio state.

## 7. Trade Management Rules

- Maintain zero or one valid USDCHF position and one attempt per week.
- Preserve the original hard stop; framework Friday close owns normal exit.
- Run malformed-position and seven-day stale repair before entry gates on
  every tick.
- Reconcile terminal-persistent attempt state with owned positions and entry
  deals after restart.
- No randomness, adaptation, external signal, partial close, scale-in,
  averaging, grid, martingale, or pyramid is allowed.

## 8. Parameters To Test

The Q02 baseline is locked; these inputs exist for auditability, not as an
optimization grant.

| Input | Value | Contract |
|---|---:|---|
| `strategy_endpoint_count` | 12 | locked |
| `strategy_block_size` | 6 | locked |
| `strategy_u_lower` | 12 | locked |
| `strategy_u_upper` | 24 | locked |
| `strategy_history_bars_d1` | 128 | locked |
| `strategy_entry_window_minutes` | 360 | locked |
| `strategy_atr_period_d1` | 20 | locked |
| `strategy_atr_sl_mult` | 3.0 | locked |
| `strategy_max_hold_days` | 7 | locked |
| `strategy_max_spread_points` | 50 | locked |
| `strategy_deviation_points` | 20 | locked |

No sweep, tie ranking, alternate sample/split, p-value, endpoint-direction
fallback, volatility filter, session filter, or ensemble is authorized.

## Source-Defined Rules

The peer-reviewed and official records define only the broad own-price
continuation family and the strict no-tie two-sample ordinal statistic. They
do not define a USDCHF trading rule, weekly clock, threshold, stop, or exit.

## QM Interpretations

Variant `AI-CODEX-USDCHF-WW-SHIFT-20260902_S01` fixes USDCHF, D1 levels,
twelve observations, a six/six split, inclusive U boundaries 12/24, one
weekly attempt, a 3.0-ATR hard stop, 50-point spread cap, Friday close, and
seven-day repair. Each is pre-result synthesis and cannot change after Q02.

## Framework Execution Overrides

- Friday close: enabled at Friday 21:00 broker time.
- News temporal mode: OFF.
- News compliance profile: NONE.
- Legacy framework news mode: OFF.
- Backtest risk: fixed 1,000 account-currency units; percentage risk zero.
- Stress rejection probability: zero in the canonical set.

## Exit Precedence

1. Framework kill switch and broker hard stop.
2. Lifecycle-integrity repair.
3. Framework Friday close.
4. Seven-calendar-day stale close.
5. Entry-only spread, quote, ATR, sizing, and margin gates.
6. New position entry.

## Runtime Data Dependencies

Exact `USDCHF.DWX` native D1 timestamps and closes, broker time, sanctioned
framework calendar keys, symbol metadata, quotes, completed-bar ATR,
position/deal state, and one terminal-persistent attempt marker. No external
runtime dataset exists.

## Risk

- Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- One position receives a frozen `3.0*ATR(20,D1)` normalized broker hard stop
  and no target.
- Entry spread is capped at 50 points.
- U magnitude never changes size; no second position is allowed.
- Principal risks are CHF discontinuities, short-horizon trend reversal,
  Friday liquidity, gaps, financing, rank instability near a boundary, and
  downstream portfolio overlap.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS | Complete-read peer-reviewed broad continuation evidence, named Mann-Whitney record, and complete pinned R Core method files; exact USDCHF weekly conjunction untested. |
| R2 | PASS | Week clock, bars, blocks, strict ties, U identity, boundaries, side, attempt, risk, stop, Friday exit, and repair are fixed. |
| R3 | PASS | Registered native USDCHF D1 supplies every runtime input. |
| R4 | PASS | Deterministic native comparisons and state only; no trained signal, prohibited indicator, external feed, grid, or martingale. |

## 9. Failure Modes And Kill Criteria

Retire or fail on any of the following:

- fewer than ten completed positions in any full post-warm-up Q02 year;
- zero trades, nonpositive governed economics, or a downstream gate failure;
- forming-bar leakage, missing/duplicate D1 bars, nonchronological timestamps,
  nonpositive/nonfinite prices, or accepted exact ties;
- endpoint count other than 12, split other than six/six, omitted/doubled
  comparison, `U_new+U_old!=36`, wrong inclusive boundary, or wrong side;
- same-week retry, non-framework week key, late entry, missing hard stop,
  wrong risk mode, missed Friday close, or stale exposure beyond seven days;
- nondeterministic output for identical history and inputs; or
- downstream portfolio-correlation rejection.

## Falsification And Requalification

Any change to the USDCHF carrier, D1 sampling, twelve-close formation, fixed
six/six membership, strict tie rule, pair-count formula, inclusive 12/24
boundaries, framework week normalization, consumed attempt, risk mode, stop,
Friday close, or stale repair creates a new execution contract and requires a
new binary, stream reconciliation, Q02 restart, and full portfolio
requalification. Unresolved bar, tie, comparison, threshold, attempt, or
lifecycle ambiguity is `BLOCKED`, never filled in by Development.

## 10. Execution And State Contract

- `ea_id=41280`, exact `USDCHF.DWX`, D1, slot 0, magic `412800000`.
- Persist `QM5_41280_WEEK_ATTEMPT_<magic>` before all fallible gates.
- Recover the marker across restarts and reconcile it with entry deals.
- A late restart consumes the current week flat; no catch-up entry.
- Exactly one active registry/magic row and resolver mapping are mandatory
  before compile.
- Logs expose week key, twelve timestamps/closes, block membership, `U_new`,
  `U_old`, invariant result, side, and lifecycle state.

## 11. Portfolio Interaction

This candidate adds direct forex exposure rather than another index, metal,
or energy rule. The ordinal two-regime state differs mechanically from the
certified XNG oscillator and directional index/metal sleeves. That is an
exposure hypothesis, not measured correlation. Q09 alone may establish
overlap; this card changes no portfolio gate, manifest, allocation, or waiver.

## 12. Validation Plan

1. Card schema lint and forbidden-token scan.
2. Canonical dedup receipt and functional-neighbor review.
3. Pure fixtures for strict ties, all 36 comparisons, rank-sum identity,
   complement invariant, inclusive boundaries, reflections, and central flat.
4. Strict MQL5 compile and framework build check.
5. One canonical `RISK_FIXED` USDCHF D1 backtest set only.
6. Independent source/card/build alignment review.
7. At most one paced Q02 enqueue; no manual tester dispatch above the CPU
   ceiling.

## 13. Framework Alignment

| Card rule | V5 location |
|---|---|
| Exact identity/symbol/period/risk/news/Friday/input locks | `OnInit` and no-trade filter |
| Framework W1 transition and durable consumed attempt | decision clock and terminal-global helper |
| Twelve completed D1 bars | bounded copy helper, shifts 1..12 |
| Fixed blocks, pair counts, invariant, boundaries, side | entry-signal helper |
| Frozen ATR stop and one market order | `Strategy_EntrySignal` plus transaction manager |
| Integrity repair, Friday close, seven-day repair | framework and `Strategy_ManageOpenPosition` |
| No discretionary alpha close | `Strategy_ExitSignal` returns `QM_EXIT_NONE` |

## 14. Safety Boundary

Authorized: one approved source/card, one registered V5 identity, one
branch-only non-live build, strict Q01 validation, independent review, and at
most one paced Q02 enqueue.

Forbidden: manual tester dispatch, optimization, live/demo/shadow/stress
sets, `T_Live`, AutoTrading, deploy/live manifests, portfolio-gate edits,
portfolio admission, correlation waivers, external runtime data, terminal
control, or claims of profitability or decorrelation before governed evidence.

## Revision History

| Date | Change |
|---|---|
| 2026-09-02 | Initial source-complete USDCHF weekly rank-shift card approved under the OWNER diversity/funnel mission; canonical dedup CLEAN; R1-R4 PASS. |

## Pipeline Phase Status

| Phase | Status | Evidence |
|---|---|---|
| G0 Source Approval | APPROVED | `decisions/2026-09-02_usdchf_weekly_mann_whitney_shift_trend_source_approval.md` |
| G0 Card Decision | APPROVED | `decisions/2026-09-02_qm5_41280_usdchf_weekly_mann_whitney_shift_trend_g0.md` |
| EA Identity | PENDING_GOVERNED_ALLOCATION | deterministic allocator after this approval |
| Magic | PENDING_GOVERNED_ALLOCATION | slot 0 requested for `USDCHF.DWX` |
| Q01 | NOT_BUILT | strict compile pending |
| Q02 | NOT_ENQUEUED_Q01_PENDING | one paced row only after current Q01/review PASS |
