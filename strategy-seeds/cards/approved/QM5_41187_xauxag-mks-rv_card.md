---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-NIST-KS2-CME-XAUXAG-MDIST-RV-2026_S01
variant_id: SCHWEIKERT-NIST-KS2-CME-XAUXAG-MDIST-RV-2026_S01
source_id: SCHWEIKERT-NIST-KS2-CME-XAUXAG-MDIST-RV-2026
ea_id: QM5_41187
slug: xauxag-mks-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41187_xauxag-mks-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-27
created_by: Research+Development
last_updated: 2026-08-27
g0_status: APPROVED
g0_decision: decisions/2026-08-27_qm5_41187_xauxag_monthly_ks_distribution_shift_reversion_g0.md
source_approval: decisions/2026-08-27_xauxag_monthly_ks_distribution_shift_reversion_source_approval.md
source_author: "Karsten Schweikert; CME Group; National Institute of Standards and Technology"
source_authors: "Karsten Schweikert; CME Group; National Institute of Standards and Technology"
source_citation: "Schweikert (2018), Are gold and silver cointegrated?, Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; CME Group Gold & Silver Ratio Spread research; NIST Dataplot Reference Manual, Kolmogorov-Smirnov Two-Sample Goodness of Fit Test."
source_citations:
  - type: peer_reviewed_relationship_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; complete author-preprint read preserved in the governed parent packet"
    quality_tier: A
    role: state_dependent_gold_silver_relation_and_adverse_evidence
  - type: official_exchange_carrier_research
    citation: "CME Group, Gold & Silver Ratio Spread."
    location: "official CME Group research preserved in strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: A_official
    role: intermarket_ratio_definition_and_distinct_metal_drivers
  - type: official_statistical_method_record
    citation: "NIST Dataplot Reference Manual, Kolmogorov-Smirnov Two-Sample Goodness of Fit Test."
    location: "complete official HTML method page and authenticated receipt preserved under the governed source packet"
    quality_tier: A_official
    role: two_sample_empirical_distribution_and_maximum_gap_method
  - type: governed_composite_source
    citation: "QuantMechanica bounded XAU/XAG fixed-block signed-ECDF distribution-shift reversion packet."
    location: "strategy-seeds/sources/SCHWEIKERT-NIST-KS2-CME-XAUXAG-MDIST-RV-2026/source.md"
    quality_tier: internal_governed
    role: exact_sample_boundary_direction_calendar_risk_atomicity_and_lifecycle
strategy_mechanic: monthly-xauxag-twelve-synchronized-completed-month-end-gold-minus-silver-log-ratio-fixed-six-older-six-newer-strict-no-tie-signed-ecdf-gap-count-three-contrarian-equal-notional-basket
sources:
  - "[[sources/SCHWEIKERT-NIST-KS2-CME-XAUXAG-MDIST-RV-2026]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/nonparametric-distribution-shift]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/synchronized-completed-month-log-ratio]]"
  - "[[indicators/two-sample-signed-ecdf-gap]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, market-neutral-style, relative-value, structural-reversion, nonparametric, distribution-shift, signed-ecdf-gap, fixed-block, monthly-rebalance, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals, gold_silver_relative_value]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41187_XAU_XAG_MKS_RV_D1
symbol: XAUUSD.DWX
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 411870000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 5-8 completed XAU/XAG packages per full post-warm-up year after twelve synchronized completed month ends; one consumed attempt per broker month. Exact random-rank directional qualification is 109/231, about 5.662 decisions/year, before market data."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK
r1_reasoning: "Complete peer-reviewed gold/silver relationship evidence with adverse findings, official exchange carrier research, and a complete official NIST two-sample method page; the exact contrarian basket remains an untested QM hypothesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, synchronized endpoints, fixed blocks, strict ties, signed ECDF count maxima, inclusive boundary, contrarian sides, consumed attempt, aggregate fixed risk, atomicity, and lifecycle are deterministic and locked."
r3_data_available: PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered XAUUSD.DWX and XAGUSD.DWX D1 histories and native MT5 state supply every runtime input; synchronization, roll, financing, and continuous-CFD basis risks remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, strict comparisons, integer counts, ATR risk controls, and execution state; no trained signal or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 12 synchronized endpoints; fixed 6/6 blocks; inclusive dominant signed ECDF count gap 3; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/500-point spread ceilings."
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
review_focus: "Falsify a twelve-completed-month gold/silver fixed-block signed-ECDF distribution-shift reversion basket outside the directional XAU/SP500/NDX/XNG book. Verify exact synchronization, ratio orientation, fixed six/six membership, strict tie rejection, every cumulative label gap, inclusive dominant gap-three boundary, contrarian package sides, consumed attempt, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, twelve_consecutive_completed_months, synchronized_month_end_pairs, latest_pair_per_month, chronological_ratio_orientation, strict_no_tie_ratios, fixed_six_by_six_blocks, combined_order_scan, signed_ecdf_count_maxima, inclusive_gap_three_boundary, dominant_side_only, contrarian_pair_sides, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-27 and decisions/2026-08-27_qm5_41187_xauxag_monthly_ks_distribution_shift_reversion_g0.md: R1 PASS with complete peer-reviewed gold/silver evidence, official exchange carrier research, and the complete official NIST two-sample method page; R2 PASS locks synchronized endpoints, fixed blocks, ties, signed gap maxima, threshold, contrarian sides, attempt, aggregate risk, atomicity, and lifecycle; R3 PASS registered native XAU/XAG D1 with synchronization/CFD risk; R4 PASS deterministic native arithmetic only. Canonical exact dedup was clear and manual review resolved conservative shared-carrier fuzzy matches through fixed rank fixtures and load-bearing statistic, direction, and lifecycle differences."
---

# QM5_41187 XAU/XAG Fixed-Block Signed-ECDF Distribution-Shift Reversion

## Hypothesis

Gold and silver share precious-metal and USD drivers but differ materially in
monetary, safe-haven, industrial, and business-cycle exposure. Rather than fit
a permanent ratio center, scale, regression coefficient, or convergence
speed, this card asks whether the most recent six synchronized completed-
month gold-minus-silver log ratios are ordinally displaced from the prior six.
It fades only a dominant maximum empirical-distribution gap of at least one
half.

Opposite equal-target-notional legs are designed to reduce common outright-
metal direction and form a market-neutral-style stream different from the
directional XAU, SP500, NDX, and XNG book. They do not prove dollar, beta,
volatility, factor, market, or portfolio neutrality. Q02 owns activity and
economics; unchanged Q09 alone owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The governed source is
`strategy-seeds/sources/SCHWEIKERT-NIST-KS2-CME-XAUXAG-MDIST-RV-2026/source.md`,
SHA-256 `EFA401D3916AEBAE3403C9CD0C9D141FAB5492678EF52DA458D2F86BFAF7A396`,
authorized by
`decisions/2026-08-27_xauxag_monthly_ks_distribution_shift_reversion_source_approval.md`
at commit `673be5a44` before extraction.

Schweikert supplies complete-read, state-dependent gold/silver evidence and
binding adverse evidence. CME supplies the official ratio carrier and
distinct metal drivers. NIST supplies the complete operative two-sample ECDF
maximum-gap method. None tests this synchronized ratio threshold, contrarian
package, continuous CFDs, equal-target-notional construction, or fixed-dollar
execution contract.

No source alpha, return, probability, significance, density, profit factor,
drawdown, transaction cost, hedge ratio, neutrality, CFD equivalence,
decorrelation, or portfolio statistic is imported.

## Non-Duplicate Decision

Before allocation, the fail-closed checker scanned 4,686 registry identities,
1,337 card files, and the actual 45-node Strategy Wiki. It found no exact
identity and conservatively returned `FUZZY_MATCH` for the common XAU/XAG
carrier. Receipt:
`artifacts/qm5_xauxag_mks_rv_preallocation_dedup_20260827.json`, SHA-256
`C2DF4289E83E77847B7BDA7D2A6BA620A555E7846F91CAF1B3CC0EF44112FA7D`.

Manual review fixes a distinct state function:

- `QM5_41177_xauxag-mwilcoxon-shift-rv` sums all 36 cross-block ordinal wins;
  this card keeps only the largest vertical ECDF separation.
- `QM5_41183_wti-mks-shift-tr` applies the same ECDF functional to outright
  WTI and follows the displacement; this card applies it to synchronized
  gold-minus-silver ratios, reverses the side, and owns two atomic legs.
- `QM5_20263_xauxag-mad-rv` estimates a daily rolling median and MAD, requires
  a fresh standardized-score cross, and exits on convergence; this card fits
  no center or scale and uses fixed monthly blocks.
- `QM5_20161_xauxag-ols-rv` fits an OLS coefficient and residual; this card
  fits neither.
- `QM5_12724_cme-xauxag-brk` follows a D1 channel breakout; this card fades a
  monthly distribution displacement and has no channel.
- `QM5_20202_xauxag-rev18` ranks two separate 18-month leg returns; this card
  evaluates one synchronized ratio series.
- `QM5_20234_xauxag-rsj` ranks relative signed jumps from one completed month;
  this card uses no jump or cross-sectional moment.
- Fractional-difference, Spearman, Mann-Kendall, Pettitt, Cox-Stuart, LAD,
  Theil-Sen, repeated-median, variance-ratio, calendar, flow, and endpoint
  cards observe different state objects or statistics.

Path `[1,2,3,5,11,12,4,6,7,8,9,10]` produces a high-distribution fade here at
signed maxima `(3,2)` while Mann-Whitney is flat at `U_new=23`. Path
`[1,2,4,6,8,10,3,5,7,9,11,12]` stays flat here at `(2,0)` while
Mann-Whitney fades high at `U_new=26`. Reflections prove the symmetric low
cases.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_FIXED_SIX_BY_SIX_SIGNED_KS_GAP3_DISTRIBUTION_SHIFT_REVERSION_BASKET`.

## Markets, Timeframe, And Cadence

- Host/traded slot 0: exact `XAUUSD.DWX`; companion/traded slot 1: exact
  `XAGUSD.DWX`.
- Logical tester symbol: `QM5_41187_XAU_XAG_MKS_RV_D1` on the XAU host.
- Timeframe: D1; intended magics `411870000` and `411870001`.
- Decision: first synchronized executable tick after a genuine broker-month
  transition, within 180 elapsed minutes of the raw host D1 bar open.
- Formation: twelve consecutive synchronized completed broker-month ends;
  current month excluded; one fixed older/newer split.
- Hold: next broker-month boundary; forty calendar days is stale repair.
- Expected pre-result cadence: five to eight packages per full post-warm-up
  year; retire below five.

## Exact Formula

For chronological synchronized completed-month close pairs `i=0..11`:

```text
L[i] = ln(XAU_close[i]) - ln(XAG_close[i])
require every L[i] pairwise distinct

O = L[0..5]
N = L[6..11]
old_seen = new_seen = 0
Dplus = Dminus = 0

scan the combined ratios in strict ascending order:
    increment the fixed O/N membership count
    delta = old_seen - new_seen
    Dplus  = max(Dplus, delta)
    Dminus = max(Dminus, -delta)

SELL XAU / BUY XAG iff Dplus  >= 3 and Dplus  > Dminus
BUY XAU / SELL XAG iff Dminus >= 3 and Dminus > Dplus
FLAT otherwise
```

Counts divided by six are the two one-sided ECDF gaps. Count arithmetic is
authoritative. Equal signed maxima, central gaps, malformed values, or any tie
consume the month flat. No p-value, critical table, rank sum, pair-count
total, variable split, fitted location/scale, residual, endpoint return,
fallback, or signal-strength sizing exists.

Exact enumeration of 924 strict six/six assignments gives 218 high fades,
218 low fades, 486 weak flats, and two tied-extreme flats. Directional
qualification is `109/231`, approximately 5.662 monthly states per random-
rank year. This is a pre-market density design fact only.

## Rules

- `ea_id=41187`, exact XAU/XAG symbols, D1, slots 0/1, magics `411870000` /
  `411870001`.
- Consume normalized broker month before every fallible entry gate.
- Use exactly twelve immediately prior consecutive completed month keys and
  the latest exactly timestamp-matched close pair in each. The newest pair
  must be no more than ten calendar days stale.
- Preserve fixed old/new membership while sorting; require strict uniqueness,
  exactly twelve scanned values, exact six/six membership, and maxima in
  `0..6`.
- Trade only one dominant maximum at the inclusive boundary three and map it
  to the exact contrarian package sides.
- Both news axes, legacy news mode, and Friday close are OFF.

## 4. Entry Rules

1. Require `qm_ea_id=41187`, exact XAU host, XAG companion, D1 period, slots,
   fixed-risk framework inputs, OFF/NONE news, Friday close OFF, and every
   singleton strategy input.
2. Process package repair and prior-month/stale exits before entry-only gates.
3. Require a genuine new broker month no later than 180 elapsed minutes after
   the raw host D1 bar open.
4. Persist current `yyyymm` before history, signal, spread, quote, ATR,
   sizing, margin, or order checks. No flat, rejected, failed, partial,
   stopped, or restarted outcome retries that month.
5. Reject owned exposure or same-magic entry deals already recorded in the
   current broker month.
6. Reconstruct twelve consecutive synchronized completed month-end pairs;
   reject missing, duplicate, unmatched, current-month, nonchronological,
   nonpositive, nonfinite, or stale data.
7. Compute twelve log ratios, reject every exact tie, preserve fixed six/six
   labels through the combined-order scan, and prove the count invariants.
8. Consume flat unless exactly one signed maximum dominates at three or more.
   Map a high newer distribution to SELL XAU / BUY XAG and a low newer
   distribution to BUY XAU / SELL XAG.
9. Require both spreads in bounds, executable quotes, completed-bar
   `ATR(20,D1)`, valid metadata, fixed-risk sizing, and target absolute-
   notional mismatch no greater than 20%.
10. Split aggregate stop risk equally, reduce only to equalize target
    notionals, attach frozen `3.5*ATR(20,D1)` hard stops, and attach no
    targets.
11. Submit XAU first and XAG second. Keep only one correctly directed,
    registered, stopped position per slot; otherwise flatten all owned legs.

## 5. Exit Rules

1. Framework kill switch and broker hard stops remain authoritative.
2. Close both legs on the first processed tick whose normalized broker month
   differs from the persisted entry month before considering replacement.
3. Close after forty elapsed calendar days as stale repair.
4. Close all owned exposure immediately when the package is orphaned,
   duplicated, same-side, wrong-symbol, wrong-magic, wrong-direction,
   stopless, stale, or outside the 20% notional-mismatch tolerance.
5. No intramonth flip, convergence target, trail, break-even, partial close,
   Friday close, news exit, scale-in, grid, martingale, or pyramid is
   authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbols, D1 period, EA ID, slots, fixed-risk,
  news/Friday, or singleton-input contracts.
- Reject a consumed attempt, owned exposure, same-month entry history,
  malformed synchronization, invalid months, ratio tie, invalid block/count
  invariant, weak/tied signal, excessive spread, invalid quote, unavailable
  ATR, invalid stop/volume, or notional mismatch.
- Terminal-global state plus deal history prevent restart retries. Tester
  initialization clears only a future/prior-run marker so historical runs
  remain deterministic.
- Runtime may not read futures-chain, inventory, volume, open interest, file,
  API, forecast, trained-output, optimizer-result, or portfolio state.

## 7. Trade Management Rules

- Maintain either zero exposure or one valid opposite-side two-leg package
  and one consumed attempt per broker month.
- Preserve original hard stops; close both legs before monthly renewal or
  after forty elapsed calendar days.
- Run malformed-package repair before entry-only gates on every tick and
  flatten every owned leg when package validity fails.
- Restart recovery combines terminal-persistent month marker with owned
  positions and same-month deal history; no restart creates a second attempt.
- No randomness, adaptation, external state, partial close, scale-in, grid,
  martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_xag_symbol` | XAGUSD.DWX | [XAGUSD.DWX] | exact companion and slot 1 |
| `strategy_endpoint_count` | 12 | [12] | synchronized ratio observations |
| `strategy_block_size` | 6 | [6] | fixed older and newer block size |
| `strategy_min_gap_count` | 3 | [3] | inclusive dominant signed ECDF gap |
| `strategy_history_bars_d1` | 900 | [900] | bounded pair reconstruction |
| `strategy_entry_window_minutes` | 180 | [180] | new-month grace |
| `strategy_max_endpoint_gap_days` | 10 | [10] | newest endpoint age ceiling |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 risk estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | [1.0] | target absolute USD notional ratio |
| `strategy_max_notional_mismatch_fraction` | 0.20 | [0.20] | package balance tolerance |
| `strategy_max_hold_days` | 40 | [40] | stale guard |
| `strategy_xau_max_spread_points` | 1500 | [1500] | XAU spread ceiling |
| `strategy_xag_max_spread_points` | 500 | [500] | XAG spread ceiling |
| `strategy_deviation_points` | 20 | [20] | bounded order deviation |

Every value is a locked singleton. Changing carrier, sample, split, tie rule,
threshold, direction, clock, risk, stop, balance, hold, spread, order
sequence, or retry policy requires a new card and full pipeline run.

## Source-Defined Rules And QM Interpretations

Schweikert and CME supply state-dependent gold/silver relationship and
intermarket-carrier evidence. NIST supplies the two-sample ECDF maximum-gap
construction. QM fixes synchronized monthly endpoints, the ratio orientation,
no-tie rule, fixed split, signed integer boundary, contrarian direction,
continuous-CFD calendar, consumed attempt, equal-notional fixed risk, spread
caps, hard stops, atomicity, rollover, and stale repair.

## Runtime Data Dependencies

Exact `XAUUSD.DWX` and `XAGUSD.DWX` native D1 timestamps and closes, broker
time, symbol metadata, quotes, completed-bar ATR, framework position/deal
state, and a terminal-persistent attempt marker. No external runtime dataset
exists.

## Risk

Q02-Q10 presets use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` as one aggregate package budget. Each leg receives half
the frozen-stop risk budget before notional equalization. Both legs can gap,
a displaced ratio can trend further, volume rounding creates imbalance,
spread and financing can dominate a low-frequency edge, and atomic repair can
realize one-sided loss. Equal target notionals are market-neutral-style
construction, not proof of market or portfolio neutrality.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK | Complete peer-reviewed gold/silver evidence with adverse findings, official exchange carrier research, and complete official NIST method documentation; exact trading rule untested. |
| R2 | PASS | Clock, synchronization, endpoints, fixed blocks, strict ties, both signed count maxima, boundary, contrarian sides, attempt, aggregate risk, atomicity, and lifecycle are fixed. |
| R3 | PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK | Registered native XAU/XAG D1 routes supply every runtime input; Q02 owns density, costs, and CFD sufficiency. |
| R4 | PASS | Native deterministic comparisons and integer arithmetic only; no trained signal, prohibited runtime input, external feed, grid, or martingale. |

## Failure Modes And Kill Criteria

- Retire on zero trades, fewer than five completed packages in any full post-
  warm-up year, nonpositive governed economics, or downstream gate failure.
- Fail on current-month leakage, missing/duplicate month keys, nonlatest or
  unmatched pairs, wrong ratio orientation, stale endpoint,
  nonchronological data, endpoint count other than 12, accepted ratio tie,
  wrong split, lost membership, combined scan other than 12, block count
  other than six/six, count maximum outside `0..6`, entry below boundary
  three, tied-max entry, or wrong package sides.
- Fail on same-month retry, non-atomic package, notional imbalance, missing
  hard stop, wrong risk mode, wrong spread ceiling, late entry, missed month-
  boundary exit, or nondeterminism.
- Retire on later portfolio-correlation rejection; no waiver is implied.
- Do not rescue failure by changing formation, split, threshold, direction,
  carrier, risk, stop, balance, hold, spread, retry, or order sequence.

## Strategy Allowability Check

- [x] R1: PASS with method/carrier translation risk. Complete peer-reviewed
  gold/silver evidence, official exchange carrier evidence, and official
  method documentation; no efficacy is imported.
- [x] R2: PASS. Synchronized endpoints, fixed blocks, strict ties, signed
  count maxima, contrarian direction, attempt, aggregate risk, atomicity, and
  exits are fixed.
- [x] R3: PASS with synchronization/continuous-CFD basis risk. Registered XAU
  and XAG D1 histories plus native V5 state only.
- [x] R4: PASS. Deterministic timestamps, logarithms, comparisons, integer
  counts, calendar, and ATR risk; no trained output or external feed.
- [x] Dedup: no exact identity; conservative shared-carrier fuzzy matches are
  manually resolved by statistic, side, sample, and lifecycle fixtures.

## Framework Alignment

- no_trade: exact XAU/XAG/D1/EA/slots, locked inputs, fixed-risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: durable month attempt, synchronized endpoint reconstruction,
  fixed six/six blocks, combined-order count path, signed maxima, inclusive
  boundary, contrarian sides, spread/quote/ATR/stop checks, equal-notional
  sizing, and atomic validation.
- trade_management: package repair, prior-month exit, and stale exit before
  entry-only gates.
- trade_close: framework close helper per leg, broker hard stops, and kill
  switch.

## Validation Plan

1. Schema-lint canonical and EA-local card copies.
2. Independently reproduce all 924 fixed-block assignments, exact outcome
   counts, inclusive boundary, tied maxima, symmetry, strict-tie rejection,
   and Mann-Whitney separating fixtures.
3. Validate synchronization, twelve consecutive month keys, year rollover,
   latest-pair selection, current-month exclusion, staleness, logical label,
   grace, consume-first attempt order, and lifecycle repair.
4. Require strict zero-error/zero-warning compile, framework build checks,
   exact symbol scope, active identity, two active magic rows, and source-
   current EX5.
5. Enqueue exactly one logical-basket D1 Q02 row only if the fresh paced-fleet
   CPU/queue ceiling permits. Enqueue does not launch a manual tester.
6. Retire below the five-per-year floor or on nonpositive governed economics.

## Falsification And Requalification

Any change to the twelve-month formation, fixed block membership, strict tie
rule, combined-order scan, signed count definitions, inclusive boundary,
contrarian side mapping, broker-month normalization, consumed attempt, spread
ceilings, risk, stop, balance, or exit clock creates a new execution contract
and requires a new binary, Q02 restart, and full portfolio requalification.
Ambiguity is `BLOCKED`, never filled in by Development.

## Execution And State Contract

- `ea_id=41187`, exact XAU/XAG symbols, D1, slots 0/1, intended magics
  `411870000` and `411870001`.
- Persist `QM5_41187_MONTH_ATTEMPT_<slot0-magic>` before every fallible gate.
- Recover persisted attempt across restarts and reconcile it with entry deals.
- A late restart consumes the new month flat; no catch-up entry.
- Exactly two active magic-registry rows and resolver mappings are mandatory
  before compile.
- Logs expose month key, endpoint times/values, fixed labels, sorted label
  path, every cumulative delta, both maxima, direction, and package state.

## Portfolio Interaction

This candidate converts precious-metal exposure into an opposite-side
gold/silver relative-value stream rather than another outright index, gold,
or natural-gas rule. That is a construction hypothesis, not measured
decorrelation. Q09 alone may establish overlap with the stated book. No
portfolio gate, manifest, incumbent, threshold, allocation, or waiver changes
here.

## Safety Boundary

Authorized: one approved card, one registered V5 identity, one non-live source
build, strict Q01 validation, independent review, and at most one paced
logical-basket Q02 enqueue below the CPU ceiling.

Forbidden: manual backtests outside the farm; live, demo, shadow, stress, or
optimization setfiles; `T_Live`; AutoTrading; deploy or live manifests;
portfolio-gate edits; portfolio admission; correlation waivers; external
runtime data; terminal control; and component-leg Q02 rows.

## Revision History

| date | change |
|---|---|
| 2026-08-27 | Initial source-complete XAU/XAG signed-ECDF distribution-shift reversion card approved under the OWNER commodity/energy portfolio mission; exact dedup clear and shared-carrier fuzzy matches manually resolved. |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Source Approval | 2026-08-27 | APPROVED_SOURCE | `decisions/2026-08-27_xauxag_monthly_ks_distribution_shift_reversion_source_approval.md` |
| G0 Research Intake | 2026-08-27 | APPROVED | `decisions/2026-08-27_qm5_41187_xauxag_monthly_ks_distribution_shift_reversion_g0.md` |
| Q01 Build Validation | 2026-08-27 | NOT_BUILT | build pending |
| Q02 Baseline Screening | 2026-08-27 | NOT_ENQUEUED_Q01_PENDING | compile and Q01 pending |
