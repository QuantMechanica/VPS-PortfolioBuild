---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-XAUXAG-MSNDISP-RV-20260902_S01
variant_id: AI-CODEX-XAUXAG-MSNDISP-RV-20260902_S01
source_id: AI-CODEX-XAUXAG-MSNDISP-RV-20260902
ea_id: QM5_41318
slug: xauxag-msndisp-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41318_xauxag-msndisp-rv_card.md
execution_contract_status: APPROVED
created: 2026-09-02
created_by: Research+Development
last_updated: 2026-09-02
g0_status: APPROVED
g0_decision: decisions/2026-09-02_qm5_41318_xauxag_monthly_sn_dispersion_reversion_g0.md
source_approval: decisions/2026-09-02_xauxag_monthly_sn_dispersion_reversion_source_approval.md
source_author: OpenAI Codex
source_authors: OpenAI Codex; Karsten Schweikert; CME Group; Peter J. Rousseeuw; Christophe Croux; CRAN robustbase authors
source_citation: "OpenAI Codex (2026), XAU/XAG completed-month Sn-core displacement reversion; supporting records Schweikert (2018), Journal of Banking & Finance 88, DOI 10.1016/j.jbankfin.2017.11.010; CME Group Gold & Silver Ratio Spread; Rousseeuw and Croux (1993), JASA 88(424), DOI 10.1080/01621459.1993.10476408; CRAN robustbase 0.99-7 commit 54c5cc98e27050a78bbd03be15f07a7ba88de62a."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). XAU/XAG completed-month Sn-core displacement reversion."
    location: strategy-seeds/sources/AI-CODEX-XAUXAG-MSNDISP-RV-20260902/source.md
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_risk_and_lifecycle
  - type: peer_reviewed_carrier_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; complete-read packet strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md"
    quality_tier: A
    role: state_dependent_gold_silver_relationship_and_adverse_evidence_only
  - type: official_exchange_carrier
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md
    quality_tier: A
    role: ratio_definition_distinct_demand_drivers_and_opposed_leg_carrier_only
  - type: peer_reviewed_and_primary_software_statistical_method
    citation: "Rousseeuw and Croux (1993), JASA 88(424), 1273-1283; CRAN robustbase 0.99-7 pinned source."
    location: strategy-seeds/sources/AI-CODEX-XAUXAG-MSNDISP-RV-20260902/retrieval_route_20260902.json
    quality_tier: A
    role: raw_sn_functional_even_sample_lower_median_convention_and_multiplier_separation
strategy_mechanic: monthly-xauxag-immediately-completed-broker-month-seventeen-to-twenty-three-synchronized-d1-pairs-final-seventeen-log-ratio-closes-sixteen-adjacent-relative-changes-raw-sn-nested-lower-medians-inclusive-three-core-net-displacement-contrarian-equal-notional-basket
sources:
  - "[[sources/AI-CODEX-XAUXAG-MSNDISP-RV-20260902]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/robust-dispersion-normalization]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/synchronized-completed-month-daily-log-ratio-change]]"
  - "[[indicators/raw-sn-nested-lower-median-core]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, market-neutral-style, relative-value, structural-reversion, robust-dispersion-normalized, sn-core, monthly-rebalance, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals_relative_value]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41318_XAU_XAG_SN_RV_D1
symbol: XAUUSD.DWX
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 413180000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately six to eight completed XAU/XAG packages per full post-warm-up year is an uncalibrated planning prior; there is one consumed attempt per broker month and at most twelve. Q02 must prove at least five completed packages in every full scored year or retire."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_PEER_REVIEW_EXCHANGE_AND_PRIMARY_SOFTWARE_EVIDENCE
r1_reasoning: "One durable AI source binds complete governed peer-reviewed gold/silver and Sn evidence, official exchange carrier evidence, pinned primary software, immutable hashes, adverse findings, and an explicit no-performance boundary."
r2_mechanical: PASS
r2_reasoning: "Month clock, synchronization, session bounds, final seventeen pairs, ratio changes, endpoint identity, all 240 directed distances, exact nested lower medians, omitted multipliers, inclusive three-core boundary, contrarian side, consumed attempt, aggregate risk, atomicity, and lifecycle are locked."
r3_data_available: PASS
r3_qualification: SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered native XAUUSD.DWX and XAGUSD.DWX D1 histories and MT5 state supply every runtime input; session synchronization, roll, financing, calendar, spread, and legging risks remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, sorting, bounded arithmetic, comparisons, ATR risk controls, quotes, positions, deals, and persistent state; no trained output, random path, prohibited signal indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: immediately completed broker month; 17-23 synchronized D1 pairs; final 17 chronological pairs; 16 adjacent gold-minus-silver log-ratio changes; endpoint tolerance 1e-10; 16 leave-one-out arrays of 15 absolute distances; eighth one-based inner lower median; eighth one-based outer lower median; no 1.1926 or finite-sample multiplier; sn_core above 1e-12; inclusive abs(net)>=3*sn_core with contrarian sides; 120 D1 history bars; 180-minute month-entry grace; ATR(20)*3.5 stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/500-point spread ceilings."
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
review_focus: "Falsify a completed-month robustly normalized gold/silver relative-displacement fade outside the directional XAU/SP500/NDX/XNG book. Verify exact pair synchronization, month membership, final-seventeen selection, ratio orientation, endpoint identity, all 240 distances, inner/outer lower medians, absent multipliers, inclusive three-core contrarian sides, consumed month, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, immediately_completed_month_only, synchronized_d1_pairs, bounded_month_session_count, final_seventeen_pairs, no_current_month_price, gold_minus_silver_log_ratio_orientation, sixteen_relative_changes, endpoint_identity, sixteen_leave_one_out_distance_arrays, inner_lower_median_index_seven, outer_lower_median_index_seven, no_sn_consistency_multiplier, no_finite_sample_multiplier, sn_core_floor, inclusive_three_core_contrarian_sides, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-02 and decisions/2026-09-02_qm5_41318_xauxag_monthly_sn_dispersion_reversion_g0.md: R1 binds complete governed peer-reviewed, exchange, and primary-software records with transparent synthesis risk; R2 locks signal, attempt, risk, package, and lifecycle; R3 uses registered native XAU/XAG D1 with explicit basis and synchronization risk; R4 is deterministic native arithmetic only. Corrected-root dedup returned CLEAN across 4,803 registry rows, 1,432 cards, and 45 Wiki nodes; manual family review plus two-way fixtures separates the candidate from direct-WTI Sn, rolling median/MAD, monthly rank/scale, Qn, L1, RMS, and cross-horizon ratio relatives."
---

# QM5_41318 XAU/XAG Completed-Month Sn Reversion

## Hypothesis

Gold and silver share precious-metal and USD shocks but differ in monetary,
safe-haven, industrial, and business-cycle demand. When the immediately
completed broker month's gold-minus-silver log-ratio move is at least three
raw Sn dispersion cores, that unusually coherent relative displacement may
partially reverse during the next broker month.

The candidate expresses the hypothesis through opposed, equal-target-notional
XAU/XAG legs. This is a market-neutral-style construction intended to reduce
outright precious-metal direction relative to the certified XAU/SP500/NDX/XNG
book. It does not prove dollar, beta, volatility, factor, or portfolio
neutrality. Q09 alone may establish realized decorrelation.

## Source and claim boundary

The sole lineage source is
`strategy-seeds/sources/AI-CODEX-XAUXAG-MSNDISP-RV-20260902/source.md`,
approved before extraction at commit `0099cdf1e4`.

Schweikert supplies a state-dependent gold/silver relationship and binding
adverse evidence against one stable constant spread. CME supplies the ratio
definition, distinct demand drivers, and spread carrier. Rousseeuw-Croux and
pinned `robustbase` source supply only the raw Sn functional and even-sample
lower-median convention. No source tests this exact conjunction or supplies
its threshold, side, activity, return, profit factor, drawdown, costs, CFD
equivalence, neutrality, or correlation.

## Non-duplicate boundary

The canonical checker returned `CLEAN`; the evidence path is
`artifacts/qm5_xauxag_msndisp_rv_preallocation_dedup_20260902.json`.
The load-bearing identity is the conjunction of one immediately completed
month, synchronized XAU/XAG daily ratio changes, raw Sn nested lower medians,
an inclusive three-core boundary, and contrarian equal-notional paired payoff.

- `QM5_41277` uses Sn on direct WTI and continues rather than fades.
- `QM5_20263` uses a rolling ratio-level median/MAD fresh crossing.
- `QM5_41286` uses old/recent monthly blocks and Siegel-Tukey permutations.
- `QM5_20194` uses a 12/18-month cross-horizon rank disagreement.
- Qn, L1, RMS, and the other scale/rank baskets use different statistics and
  boundaries. The frozen synthetic vectors prove qualification disagreement.

Removing synchronization, Sn, the completed-month clock, the three-core gate,
or the opposed contrarian payoff collapses the card into an existing family
and is not authorized.

## Rules

### Instruments and clock

- Logical package: `QM5_41318_XAU_XAG_SN_RV_D1`.
- Host/traded slot zero: `XAUUSD.DWX`, D1, magic `413180000`.
- Traded slot one: `XAGUSD.DWX`, D1, magic `413180001`.
- Decide once on the first synchronized executable D1 bar after a genuine
  broker-month transition and only within a 180-minute grace window.
- Persist the normalized `yyyymm` attempt before history, signal, news,
  spread, quote, ATR, sizing, margin, or submission gates. Never retry it.

### Synchronized formation sample

1. From a bounded 120-D1 buffer, match XAU and XAG bars by exact timestamp.
2. Select only pairs whose normalized broker month is the immediately prior
   month; reject gaps, duplicate/out-of-order timestamps, or any current-month
   observation.
3. Require 17 through 23 matched sessions.
4. Keep exactly the final seventeen chronological pairs.
5. Require positive finite closes and a newest completed pair immediately
   preceding the current month.

### Signal arithmetic

For chronological pairs `i=0..16`:

```text
q[i] = ln(XAU_close[i]) - ln(XAG_close[i])
r[i] = q[i+1] - q[i], i=0..15
net  = sum(r)
endpoint = q[16] - q[0]
require abs(net-endpoint) <= 1e-10
```

For every `r[i]`, sort the fifteen values `abs(r[i]-r[j])`, `j!=i`, and take
zero-based index seven. Sort those sixteen inner values and again take
zero-based index seven as `sn_core`. Require exactly 240 directed distances,
finite arithmetic, and `sn_core>1e-12`. Do not multiply by `1.1926` or any
finite-sample factor.

```text
threshold = 3 * sn_core
net >=  threshold -> SELL XAU / BUY XAG
net <= -threshold -> BUY XAU / SELL XAG
otherwise         -> consume month flat
```

The comparisons are inclusive. Signal magnitude never changes size.

### Entry and atomic package

- Reject foreign exposure on either symbol, owned exposure, or an owned entry
  deal in the current broker month.
- Require finite nonnegative spreads at or below 1,500 XAU points and 500 XAG
  points, valid quotes, symbol metadata, ATR, risk sizing, and margin.
- Split one aggregate fixed stop-risk budget equally between legs.
- Attach each leg's frozen `3.5*ATR(20,D1)` broker hard stop; no target.
- Target `1.0:1.0` absolute USD notionals by reducing volume only. Reject a
  post-rounding notional mismatch above twenty percent.
- Submit XAU first and XAG second through governed basket order handling.
  Immediately flatten every owned leg if two opposed valid legs do not exist.

### Management and close

- Validate exactly two owned positions, expected symbols/magics, opposed
  sides, positive finite volumes/open prices/stops, no target, and acceptable
  notional mismatch on every management pass.
- Close both legs on the first synchronized processed tick in a broker month
  later than the entry month.
- Close defensively after forty elapsed calendar days or on malformed package,
  missing state, wrong direction, missing stop, or partial-leg failure.
- There is no intramonth signal exit or flip, convergence target, trail,
  break-even move, partial close, resize, scale-in, grid, martingale, pyramid,
  or same-month retry.

### Framework overrides

- `qm_news_temporal=QM_NEWS_TEMPORAL_OFF`.
- `qm_news_compliance=QM_NEWS_COMPLIANCE_NONE`.
- legacy news mode off.
- Friday close disabled because the package owns a month-spanning hold.
- stress rejection probability zero in the canonical baseline.
- Framework kill switch, weekend handling, broker disconnect handling, and
  broker hard stops remain active.

## Parameters to test

Q02 has exactly one locked baseline: 17-through-23 synchronized completed-
month sessions, final 17 pairs, 16 relative changes, 240 distances, eighth
one-based inner and outer lower medians, raw Sn, `1e-12` core floor, inclusive
three-core threshold, `1e-10` endpoint tolerance, 120 D1 history bars,
180-minute grace, `3.5*ATR(20)` stops, equal notionals, twenty-percent mismatch,
forty-day stale exit, and 1,500/500-point spread ceilings. Changing any value
creates a new variant and needs fresh evidence.

## Expected behavior and frequency

There is one consumed attempt per month and at most twelve completed packages
per full year. Six to eight is an explicitly uncalibrated planning prior, not
a source or fixture result. Q02 must measure completed packages and retire the
baseline below five in any full scored post-warm-up year.

The non-market receipt
`artifacts/qm5_xauxag_msndisp_rv_reference_fixture_20260902.json` proves both
directions, a flat state, raw Sn arithmetic, and disagreement with Qn/L1/RMS
neighbors. It supplies no frequency or performance evidence.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The amount is an aggregate package budget, split equally
across two frozen stop distances. Gaps and legging can exceed modeled risk.
Equal target notionals leave residual factor and volatility exposures.

Principal risks are failure of gold/silver convergence, regime-dependent
relationship, synchronized-history gaps, continuous-CFD roll/basis and
financing, wide silver spreads, unequal contract metadata, volume rounding,
asymmetric stop-outs, monthly overlap, and insufficient activity. No live risk
is authorized.

## Data requirements

Native `XAUUSD.DWX` and `XAGUSD.DWX` D1 time/close histories, closed D1 ATR,
broker time/month, quotes, spreads, symbol metadata, margin, positions, deals,
and terminal-persistent attempt state. No external runtime source, file,
forecast, futures curve, optimizer output, or trained artifact is allowed.

## Failure modes and kill criteria

Retire or fail closed on timestamp mismatch, wrong month/session membership,
current-month leakage, wrong ratio or return orientation, endpoint mismatch,
wrong distance count, inner/outer median error, multiplier leakage, wrong
inclusive boundary or side, zero packages, fewer than five packages in any
full post-warm-up year, nonpositive governed economics, missing stops, invalid
fixed-risk mode, malformed atomicity, nondeterminism, or any downstream gate
failure. No result-based repair is authorized.

## Framework alignment

| card rule | module |
|---|---|
| identity, risk/news/Friday locks, month attempt, synchronized history, Sn state | `Strategy_NoTradeFilter` and bounded helpers |
| quotes, spreads, ATR, aggregate sizing, equal-notional opposed orders | `Strategy_EntrySignal` and basket helpers |
| restart repair, direction/composition validation, next-month and forty-day exits | `Strategy_ManageOpenPosition` |
| framework exit mapping | `Strategy_ExitSignal` and governed basket close helper |

## Validation plan

1. Match independent fixtures for both directions and the neighbor-only flat
   state; prove pair synchronization, month membership, endpoint identity,
   240 distances, exact medians, omitted multipliers, and inclusive boundary.
2. Verify card/registry/magic/manifest/setfile binding and aggregate fixed risk.
3. Run card schema lint and strict Q01 compile/build checks.
4. Enqueue one canonical logical-basket Q02 item only below the measured CPU
   ceiling; do not enqueue component rows or launch a manual tester.
5. Preserve any activity, economic, or downstream failure without changing
   the locked rule.

## Safety boundary

Authorized: deterministic magic allocation, branch-only non-live build,
reference tests, strict Q01, one logical fixed-risk backtest set plus two
component validation sets, and one paced logical Q02 enqueue below the
whole-host CPU ceiling.

Forbidden: optimization, manual tester launch, live/demo/shadow/stress sets,
component Q02 rows, portfolio-gate edits, correlation waiver, portfolio
admission, deploy/live manifest, `T_Live`, AutoTrading, terminal control, or
live use.

## Revision history

| version | date | reason | gate | verdict |
|---|---|---|---|---|
| v1 | 2026-09-02 | initial XAU/XAG completed-month Sn reversion card | G0 | APPROVED; build pending |

## Pipeline phase status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Source Approval | 2026-09-02 | APPROVED_SOURCE | `decisions/2026-09-02_xauxag_monthly_sn_dispersion_reversion_source_approval.md` |
| G0 Research Intake | 2026-09-02 | APPROVED | `decisions/2026-09-02_qm5_41318_xauxag_monthly_sn_dispersion_reversion_g0.md` |
| Q01 Build & Spec | TBD | PENDING | TBD |
| Q02 Baseline | TBD | NOT_ENQUEUED | TBD |
