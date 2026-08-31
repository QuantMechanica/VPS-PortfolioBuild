---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-XAUXAG-MCUSUM-RV-20260831_S01
variant_id: AI-CODEX-XAUXAG-MCUSUM-RV-20260831_S01
source_id: AI-CODEX-XAUXAG-MCUSUM-RV-20260831
ea_id: QM5_41247
slug: xauxag-mcusum-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41247_xauxag-mcusum-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-31
created_by: Research+Development
last_updated: 2026-08-31
g0_status: APPROVED
g0_decision: decisions/2026-08-31_qm5_41247_xauxag_monthly_centered_cusum_reversion_g0.md
source_approval: decisions/2026-08-31_xauxag_monthly_centered_cusum_reversion_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; Karsten Schweikert; E. S. Page; CME Group; NIST/SEMATECH"
source_citation: "OpenAI Codex (2026), XAU/XAG monthly centered-CUSUM relative-return reversion; supporting records Schweikert (2018), Journal of Banking & Finance 88, DOI 10.1016/j.jbankfin.2017.11.010; CME Group Gold & Silver Ratio Spread; Page (1954), Biometrika 41(1/2), DOI 10.1093/biomet/41.1-2.100; NIST/SEMATECH CUSUM Control Charts."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). XAU/XAG monthly centered-CUSUM relative-return reversion."
    location: "strategy-seeds/sources/AI-CODEX-XAUXAG-MCUSUM-RV-20260831/source.md"
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_thresholds_risk_atomicity_and_lifecycle
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
    citation: "Page, E. S. (1954). Continuous Inspection Schemes. Biometrika 41(1/2), 100-115."
    location: "DOI 10.1093/biomet/41.1-2.100; bibliographic metadata only"
    quality_tier: A_record_only
    role: cumulative_sum_shift_detection_lineage
  - type: official_statistical_method
    citation: "NIST/SEMATECH Engineering Statistics Handbook, CUSUM Control Charts."
    location: "complete public page read preserved by governed parent"
    quality_tier: A_official_method
    role: cumulative_deviation_formula_and_mean_shift_interpretation
strategy_mechanic: monthly-synchronized-xau-xag-relative-log-returns-mean-centered-cumulative-sum-unique-central-change-point-post-segment-mean-contrarian-equal-notional-basket
sources:
  - "[[sources/AI-CODEX-XAUXAG-MCUSUM-RV-20260831]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/cumulative-sum-change-point]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/synchronized-completed-month-log-ratio]]"
  - "[[indicators/mean-centered-cumulative-sum]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, market-neutral-style, relative-value, structural-reversion, return-regime-shift, centered-cusum, monthly-rebalance, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals, gold_silver_relative_value]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41247_XAU_XAG_MCUSUM_RV_D1
symbol: XAUUSD.DWX
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 412470000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 5-9 completed XAU/XAG packages per full post-warm-up year after thirteen synchronized completed month ends; one consumed attempt per broker month. Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_METHOD_TRANSLATION_RISK
r1_reasoning: "One durable AI-originated source ID; peer-reviewed state-dependent gold/silver evidence; official-exchange carrier evidence; named peer-reviewed CUSUM lineage; complete official NIST method-page record; exact trading conjunction disclosed as untested QM synthesis."
r2_mechanical: PASS
r2_reasoning: "Exact symbols, synchronized month ends, relative returns, centering, eleven path values, tie tolerance, central split, contrarian sides, consumed attempt, equal notionals, aggregate fixed risk, atomicity, and lifecycle are deterministic and locked."
r3_data_available: PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r3_reasoning: "Registered XAUUSD.DWX and XAGUSD.DWX D1 histories and native MT5 state supply every runtime input; synchronization, holiday, financing, and continuous-CFD basis risk remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, finite arithmetic, comparisons, ATR risk controls, and execution state; no trained signal or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 synchronized completed month-end pairs; 12 adjacent relative log returns; arithmetic centering; all k=1..11 path values; absolute tie epsilon 1e-12; unique k in 4..8; contrarian post-segment mean side; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/500-point spread ceilings."
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
review_focus: "Falsify a synchronized gold/silver relative-return regime-shift reversion basket outside the directional XAU/SP500/NDX/XNG book. Verify exact completed endpoints, ratio and return orientation, full-sample centering, every nonterminal CUSUM split, unique central maximum, contrarian post-segment side, consumed month, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, thirteen_consecutive_completed_months, synchronized_month_end_pairs, no_current_month_price, gold_minus_silver_log_ratio, twelve_adjacent_relative_returns, full_sample_mean_centering, all_eleven_nonterminal_cusums, absolute_tie_epsilon, unique_maximum, central_split_four_to_eight, contrarian_post_segment_mean_direction, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-31 and decisions/2026-08-31_qm5_41247_xauxag_monthly_centered_cusum_reversion_g0.md: R1 passes with one durable AI source, peer-reviewed gold/silver evidence, official exchange carrier research, named peer-reviewed CUSUM lineage, a complete official NIST method record, and explicit synthesis/access boundaries; R2 locks synchronization, relative returns, centering, path, split, contrarian sides, attempt, risk, atomicity, and lifecycle; R3 uses registered native XAU/XAG D1 with synchronization/CFD risk; R4 uses deterministic native arithmetic only. Corrected-root dedup found no exact identity and one disclosed fuzzy WTI method neighbor; manual review separates carrier, direction, position topology, and lifecycle."
---

# QM5_41247 XAU/XAG Monthly Centered-CUSUM Reversion

## Hypothesis

Gold and silver share precious-metal and USD drivers but differ in monetary,
safe-haven, industrial, and business-cycle exposure. A unique central maximum
in the mean-centered cumulative path of twelve completed monthly
gold-minus-silver returns can identify one dominant relative-regime shift.
This card treats the post-shift relative displacement as exhaustion and fades
its mean direction for one broker month.

Opposite equal-target-notional legs reduce common outright-metal direction and
form a market-neutral-style stream different from the directional XAU,
SP500, NDX, and XNG book. They do not prove neutrality or decorrelation. Q02
owns density and economics; unchanged Q09 owns realized overlap.

## Source Traceability And Claim Boundary

The single governed source ID resolves to
`strategy-seeds/sources/AI-CODEX-XAUXAG-MCUSUM-RV-20260831/source.md`,
authorized by
`decisions/2026-08-31_xauxag_monthly_centered_cusum_reversion_source_approval.md`.
Its reproducible parent-read evidence is
`strategy-seeds/sources/AI-CODEX-XAUXAG-MCUSUM-RV-20260831/retrieval_route_20260831.json`.

Schweikert supplies related but state-dependent gold/silver evidence and
binding adverse evidence. CME supplies the intermarket carrier and distinct
metal drivers. Page and NIST supply bounded centered cumulative-deviation
method evidence. None tests this sample, split band, contrarian package,
continuous CFDs, or fixed-dollar execution contract.

No source return, alpha, probability, p-value, significance, trade density,
profit factor, drawdown, transaction cost, hedge ratio, neutrality, CFD
equivalence, decorrelation, or portfolio-correlation statistic is imported.

## Non-Duplicate Decision

The corrected-root pre-allocation checker found no exact identity across
4,746 registry rows, 1,384 card files, and 45 Strategy Wiki nodes. Receipt:
`artifacts/qm5_xauxag_mcusum_rv_preallocation_dedup_20260831.json`.

It raised `QM5_41245_wti-mcusum-shift-tr` as a fuzzy method neighbor. That EA
follows an outright WTI post-shift mean with one position. This card fades a
synchronized gold-minus-silver post-shift mean with an atomic opposite-leg
equal-notional basket. Existing XAU/XAG rank, ECDF, pair-count, turning-point,
runs, regression, scale, z-score, and variance-ratio systems retain different
state objects and do not select this mean-centered endogenous split.

Verdict:
`DISTINCT_XAUXAG_MONTHLY_CENTERED_RELATIVE_RETURN_CUSUM_UNIQUE_CENTRAL_SHIFT_POST_MEAN_CONTRARIAN_EQUAL_NOTIONAL_REVERSION`.

## Markets, Timeframe, And Cadence

- Host/traded slot 0: exact `XAUUSD.DWX`; companion/traded slot 1: exact
  `XAGUSD.DWX`.
- Logical tester symbol: `QM5_41247_XAU_XAG_MCUSUM_RV_D1` on the XAU host.
- Timeframe: D1; intended magics `412470000` and `412470001`.
- Decision: first synchronized executable tick after a genuine broker-month
  transition, within 180 elapsed minutes of raw host D1 bar open.
- Formation: thirteen consecutive synchronized completed broker-month ends.
- Hold: first later broker month; forty days is stale repair.
- Expected pre-result cadence: five to nine packages/year; Q02 retires below
  five in any full post-warm-up year.

## Formula

For chronological synchronized completed-month close pairs `i=0..12`:

```text
L[i] = ln(XAU_close[i]) - ln(XAG_close[i])
r[i] = L[i+1] - L[i]                    for i=0..11
mean = sum(r[0..11]) / 12

running = 0
for k = 1..11:
  running += r[k-1]
  S[k] = running - k*mean

M = max(abs(S[k]))
K = { k : abs(abs(S[k]) - M) <= 1e-12 }

qualify iff M > 1e-12 and size(K) == 1 and 4 <= K[0] <= 8
post_mean = sum(r[K[0]..11]) / (12-K[0])

SELL XAU / BUY XAG iff qualify and post_mean >  1e-12
BUY XAU / SELL XAG iff qualify and post_mean < -1e-12
FLAT otherwise
```

The terminal sum is identically zero and excluded. This is not a significance
test. A p-value, control limit, standardization, rank transform, alternate
band, endpoint fallback, fitted value, continuation side, or size scaling is
forbidden.

## Rules

The EA implements one exact baseline. Invalid history, arithmetic, or state
consumes the current broker month flat after persisting the attempt key. The
current month never contributes a signal price. Lifecycle repair runs before
entry-only gates.

### Entry rules

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
7. Compute thirteen gold-minus-silver log ratios, twelve relative returns,
   the full mean, and all eleven nonterminal centered cumulative deviations.
8. Require one unique maximum beyond `1e-12` and its split in `4..8`; require
   a post-segment mean beyond `1e-12`.
9. Map a positive post mean to short XAU/long XAG and a negative post mean to
   long XAU/short XAG. Any other state consumes flat.
10. Require both spreads in bounds, executable quotes, completed-bar
    `ATR(20,D1)`, valid metadata, fixed-risk sizing, and target absolute-
    notional mismatch no greater than 20%.
11. Split aggregate stop risk equally, reduce only to equalize target
    notionals, attach frozen `3.5*ATR(20,D1)` hard stops, and no targets.
12. Submit XAU first and XAG second. Keep only one correctly directed,
    registered, stop-protected position per slot; otherwise flatten all owned
    legs immediately.

### Exit rules

1. Framework kill switch and broker hard stops remain authoritative.
2. Close both legs on the first processed tick in a later broker month before
   considering replacement risk, even if the signal is unchanged.
3. Close after forty elapsed calendar days as stale repair.
4. Close every owned leg if the package is orphaned, duplicated, same-side,
   wrong-symbol, wrong-magic, wrong-direction, stopless, stale, or outside the
   20% notional-mismatch tolerance.
5. No intramonth flip, target, trail, break-even, partial close, Friday close,
   news exit, scale-in, grid, martingale, or pyramid is authorized.

### No-trade filters

- Fail closed outside exact symbols, D1, EA ID, slots, fixed-risk,
  news/Friday, stress, or locked-input contract.
- Reject consumed attempt, owned exposure, same-month entry history,
  malformed synchronization, invalid month selection, invalid arithmetic,
  tied or edge maximum, zero post mean, excessive spread, invalid quote,
  unavailable ATR, invalid stop/volume, or notional mismatch.
- Runtime may not read futures-chain, volume, open-interest, file, API,
  forecast, trained-output, optimizer-result, portfolio, or prior-pipeline
  state.

### Trade management

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

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Parameter | Baseline | Range |
|---|---:|---|
| `strategy_xag_symbol` | XAGUSD.DWX | locked |
| `strategy_endpoint_count` | 13 | locked |
| `strategy_min_split` | 4 | locked inclusive |
| `strategy_max_split` | 8 | locked inclusive |
| `strategy_tie_epsilon` | 0.000000000001 | locked |
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

Changing carrier, sample, centering, candidate splits, tie treatment, band,
direction, clock, risk, stop, balance, hold, spread, order sequence, or retry
policy requires a new card and full pipeline run.

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
- CUSUM magnitude and post-mean magnitude never change size.
- No live, demo, shadow, stress, or optimization preset is authorized.
- Principal risks are relation shift or break, silver volatility dominance,
  two-leg fill failure, hard-stop gap/slippage, volume-rounding imbalance,
  holiday synchronization loss, small-sample split instability, CFD
  financing/basis, density below floor, and realized overlap with the
  certified XAU sleeve.

Equal notionals are market-neutral-style, not proof of dollar, beta,
volatility, factor, or portfolio neutrality.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS_WITH_AI_SYNTHESIS_AND_METHOD_TRANSLATION_RISK | One durable source ID; peer-reviewed gold/silver relation evidence; official exchange carrier; named peer-reviewed CUSUM lineage; complete official NIST method record; exact conjunction untested. |
| R2 | PASS | Clock, synchronization, returns, centering, path, unique split, sides, attempt, risk, atomicity, and lifecycle fixed. |
| R3 | PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK | Registered native XAU/XAG D1 routes supply every runtime input. |
| R4 | PASS | Deterministic native arithmetic and state only; no trained method or external feed. |

## Failure Modes And Kill Criteria

- Retire on zero packages, fewer than five completed packages in any full
  post-warm-up year, nonpositive governed economics, or downstream failure.
- Fail on current-month leakage, missing/duplicate month keys, unmatched or
  stale pairs, wrong ratio or return orientation, wrong mean, omitted split,
  inclusion of terminal zero, tied-maximum entry, edge-split entry, wrong
  contrarian sides, retry, non-atomic package, notional imbalance, missing
  stop, wrong risk mode, or missed month exit.
- Retire on later portfolio-correlation rejection; no waiver is implied.
- Do not rescue failure by changing formation, centering, tie epsilon, band,
  direction, carrier, risk, stop, balance, hold, spread, retry, or order
  sequence.

## Falsification And Requalification

Any change to the thirteen-endpoint formation, twelve relative returns,
full-sample centering, eleven candidate sums, unique maximum, `4..8` band,
contrarian direction, broker-month normalization, consumed attempt, spread
ceilings, risk mode, stop, or exit clock creates a new execution contract and
requires a new binary, stream reconciliation, Q02 restart, and full portfolio
requalification. Ambiguity is `BLOCKED`, never filled from results.

## Execution And State Contract

- The D1 decision clock supports only raw-current-date labels and a uniformly
  applied raw-plus-one-day convention; mixed offsets fail closed.
- A month is consumed before all fallible gates. Terminal global state and
  deal history prevent restart retry.
- Current-month prices never contribute to the signal.
- Position repair and month rollover run every tick before entry-only gates.
- Logs expose decision month, label offset, endpoint times, relative-return
  path, mean, every CUSUM, selected split, post mean, intended sides,
  balance, and state without credentials.

## Portfolio Interaction

This opposite-leg precious-metals carrier is intended to reduce the common
directional XAU beta of the stated XAU/SP500/NDX/XNG book. Its relative-return
regime-shift exhaustion driver is mechanically different from the incumbent
XNG cumulative-RSI pullback and outright metal/index sleeves. Those are
design facts only. No ex-ante or realized correlation is claimed, and no
portfolio gate, threshold, incumbent, manifest, or admission state changes
under this card. Q09 owns the first realized overlap verdict.

## Validation Plan

1. Schema-lint both canonical and EA card copies.
2. Independently reproduce ratio and return orientation, exact centering, all
   eleven sums, terminal-zero exclusion, unique/tied maxima, 3/4 and 8/9 band
   boundaries, both contrarian sides, and invalid arithmetic cases.
3. Validate thirteen consecutive synchronized month keys, year rollover,
   latest-pair selection, current-month exclusion, staleness, label
   conventions, grace, attempt order, atomic repair, and monthly exit.
4. Require zero-error/zero-warning compile, build guardrails, exact two-slot
   scope, active registry identity, active magic rows, and source-fresh EX5.
5. Validate `basket_manifest.json`, then enqueue exactly one logical D1 Q02
   row after fresh Q01. Enqueue does not launch a manual tester.
6. Retire below the five-per-year floor or on nonpositive governed economics.

## Framework Alignment

- no_trade: exact XAU/XAG/D1/EA/slots, locked inputs, risk, news, Friday, and
  stress validation.
- trade_entry: consume-first month clock, synchronized endpoints, relative
  returns, centering, all CUSUM splits, uniqueness, central band, contrarian
  sides, spreads, quotes, ATR/stops, equal-notional sizing, and atomic
  submission.
- trade_management: malformed/wrong-side package repair, later-month exit,
  and stale repair before entry-only gates.
- trade_close: framework close helper per leg, broker hard stops, and kill
  switch.

## Safety Boundary

This card authorizes one branch-only non-live V5 build and one paced logical
Q02 enqueue after strict Q01. It does not authorize a manual backtest,
`T_Live`, AutoTrading, deploy or live manifest, live/demo/shadow/stress/
optimization preset, portfolio-gate change, portfolio admission, threshold
change, correlation waiver, terminal process control, or claim that the
strategy is certified.

## Revision History

| Version | Date | Reason | Phase | Verdict |
|---|---|---|---|---|
| v1 | 2026-08-31 | initial source-bounded XAU/XAG centered-CUSUM reversion card | G0 | APPROVED |

