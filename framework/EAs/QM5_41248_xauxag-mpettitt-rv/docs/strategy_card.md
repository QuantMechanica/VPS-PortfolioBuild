---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-PETTITT-CME-XAUXAG-MSHIFT-RV-2026_S01
variant_id: SCHWEIKERT-PETTITT-CME-XAUXAG-MSHIFT-RV-2026_S01
source_id: SCHWEIKERT-PETTITT-CME-XAUXAG-MSHIFT-RV-2026
ea_id: QM5_41248
slug: xauxag-mpettitt-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41248_xauxag-mpettitt-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-31
created_by: Research+Development
last_updated: 2026-08-31
g0_status: APPROVED
g0_decision: decisions/2026-08-31_qm5_41248_xauxag_monthly_pettitt_ratio_reversion_g0.md
source_approval: decisions/2026-08-31_xauxag_monthly_pettitt_ratio_reversion_source_approval.md
source_author: "Karsten Schweikert; A. N. Pettitt; Thorsten Pohlert; CME Group"
source_authors: "Karsten Schweikert; A. N. Pettitt; Thorsten Pohlert; CME Group"
source_citation: "Schweikert (2018), Are gold and silver cointegrated?, Journal of Banking & Finance 88, DOI 10.1016/j.jbankfin.2017.11.010; CME Group, Gold & Silver Ratio Spread; Pettitt (1979), A Non-Parametric Approach to the Change-Point Problem, Applied Statistics 28(2), DOI 10.2307/2346729; Pohlert, trend 1.1.7, CRAN."
source_citations:
  - type: peer_reviewed_relationship_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; governed parent packet"
    quality_tier: A
    role: state_dependent_gold_silver_relation
  - type: official_exchange_carrier_research
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: "governed CME parent packet"
    quality_tier: A_official
    role: gold_silver_ratio_carrier_and_distinct_demand_drivers
  - type: peer_reviewed_statistical_method_record
    citation: "Pettitt, A. N. (1979). A Non-Parametric Approach to the Change-Point Problem. Applied Statistics 28(2), 126-135."
    location: "DOI 10.2307/2346729; metadata record; body not claimed completely read"
    quality_tier: A_record_only
    role: nonparametric_single_change_point_lineage
  - type: public_method_implementation
    citation: "Pohlert, T. trend 1.1.7. CRAN."
    location: "public mirror commit d0ec3cf8b99b4f3226f5211f592955b85565721d; complete relevant files in governed parent receipt"
    quality_tier: A_method_implementation
    role: exact_rank_sum_path_absolute_maximum_and_change_point_location
  - type: governed_composite_source
    citation: "QuantMechanica bounded XAU/XAG thirteen-month Pettitt ratio change-point reversion packet."
    location: "strategy-seeds/sources/SCHWEIKERT-PETTITT-CME-XAUXAG-MSHIFT-RV-2026/source.md"
    quality_tier: internal_governed
    role: exact_sample_central_band_direction_calendar_risk_atomicity_and_lifecycle
strategy_mechanic: monthly-xauxag-thirteen-synchronized-completed-month-end-gold-minus-silver-log-ratio-strict-rank-pettitt-unique-central-change-point-contrarian-equal-notional-basket
sources:
  - "[[sources/SCHWEIKERT-PETTITT-CME-XAUXAG-MSHIFT-RV-2026]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/nonparametric-change-point]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/synchronized-completed-month-log-ratio]]"
  - "[[indicators/pettitt-rank-sum-path]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, market-neutral-style, relative-value, structural-reversion, pettitt-change-point, rank-sum, monthly-rebalance, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals_relative_value]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41248_XAU_XAG_MPETTITT_RV_D1
symbol: XAUUSD.DWX
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 412480000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 4-8 completed XAU/XAG packages per full post-warm-up year after thirteen synchronized completed month ends; one consumed attempt per broker month."
expected_trades_per_year_per_symbol: 4
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_RELATION_AND_METHOD_TRANSLATION_RISK
r1_reasoning: "Peer-reviewed gold/silver relationship evidence, official exchange carrier research, named Pettitt record, complete pinned CRAN method files, and governed two-carrier arithmetic precedent; the exact contrarian basket remains an untested QM hypothesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, synchronized endpoints, strict ranks, every cumulative rank sum, unique central split, contrarian sides, consumed attempt, aggregate fixed risk, atomicity, and lifecycle are deterministic and locked."
r3_data_available: PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r3_reasoning: "Registered XAUUSD.DWX and XAGUSD.DWX D1 histories and native MT5 state supply every runtime input; synchronization and continuous-CFD basis risk remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, strict ranks, integer arithmetic, ATR risk controls, and execution state; no trained signal or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 synchronized endpoints; unique change index 4..9; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/500-point spread ceilings."
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
review_focus: "Falsify a thirteen-completed-month gold/silver Pettitt ratio-change reversion basket outside the directional XAU/SP500/NDX/XNG book. Verify exact synchronization, ratio orientation, strict rank permutation, every cumulative sum, unique central split, contrarian sides, consumed attempt, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, thirteen_consecutive_completed_months, synchronized_month_end_pairs, latest_pair_per_month, chronological_ratio_orientation, strict_no_tie_rank_permutation, pettitt_cumulative_rank_sums, unique_central_change_index, contrarian_pair_sides, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-31 and decisions/2026-08-31_qm5_41248_xauxag_monthly_pettitt_ratio_reversion_g0.md: R1 PASS with peer-reviewed gold/silver evidence, official CME carrier research, named Pettitt record, and complete pinned CRAN method files; R2 PASS locks synchronized endpoints, strict ranks, cumulative sums, central split, contrarian sides, attempt, aggregate risk, atomicity, and lifecycle; R3 PASS registered native XAU/XAG D1 with synchronization/CFD risk; R4 PASS deterministic native arithmetic only. Dedup found no exact identity and manual review separates the carrier and state object from both fuzzy neighbors."
---

# QM5_41248 XAU/XAG Thirteen-Month Pettitt Ratio Change-Point Reversion

## Hypothesis

Gold and silver share precious-metal and USD drivers but differ materially in
monetary, safe-haven, industrial, and business-cycle exposure. A fixed hedge
ratio or rolling z-score assumes a stable center and scale that the source
evidence does not grant. This card instead asks whether the strict rank path
of thirteen synchronized completed month-end gold-minus-silver log ratios
contains one dominant central level shift, then fades that shifted regime.

Opposite equal-target-notional legs are intended to reduce outright XAU
direction and form a market-neutral-style stream different from the
directional XAU/SP500/NDX/XNG book. They do not prove dollar, beta,
volatility, factor, market, or portfolio neutrality. Q02 owns density and
baseline economics; unchanged Q09 alone owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The single governed source ID resolves to
`strategy-seeds/sources/SCHWEIKERT-PETTITT-CME-XAUXAG-MSHIFT-RV-2026/source.md`,
SHA-256 `28F55B765CDD4B61E3F349C6CB4BCA280C23B0A38FEFDEE902B43431CC728BC5`,
authorized by
`decisions/2026-08-31_xauxag_monthly_pettitt_ratio_reversion_source_approval.md`
and committed as `f00319dfd0` before card extraction.

Schweikert and CME supply the state-dependent relation and economic carrier.
Pettitt supplies named peer-reviewed change-point lineage; the complete pinned
CRAN files define the operative rank-sum path and absolute maximum. The
original 1979 body is not represented as completely read. None tests this
synchronized XAU/XAG central band, contrarian package, continuous CFDs, or
fixed-dollar execution contract.

No source return, alpha, probability, density, profit factor, drawdown,
transaction cost, hedge ratio, neutrality, CFD equivalence, statistical
significance, decorrelation, or portfolio-correlation statistic is imported.

## Non-Duplicate Decision

Before allocation, the fail-closed checker scanned 4,747 registry identities,
1,385 cards, and 45 Strategy Wiki nodes. It found no exact identity and two
expected fuzzy matches. Receipt:
`artifacts/qm5_xauxag_mpettitt_rv_preallocation_dedup_20260831.json`, SHA-256
`86E98E01358C6CCA8B016DBDE45E4D206C49BEAB0A4672496E057321830E1FF9`.

- `QM5_41175_xtixng-mpettitt-rv` applies the same statistic to the
  economically different XTI/XNG carrier. This card owns the OWNER-named
  gold/silver monetary-versus-industrial spread.
- `QM5_41177_xauxag-mwilcoxon-shift-rv` fixes one six/six split and thresholds
  36 cross-block comparisons. This card searches all twelve Pettitt splits
  and requires one unique central absolute maximum.
- `QM5_41247_xauxag-mcusum-rv` mean-centers adjacent relative returns and
  retains magnitude. This card ranks thirteen ratio levels, uses no returns
  or center, and depends only on ordinal order.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback.

Verdict:
`CLEAN_XAUXAG_MONTHLY_PETTITT_UNIQUE_CENTRAL_RATIO_SHIFT_CONTRARIAN_BASKET`.

## Markets, Timeframe, And Cadence

- Host/traded slot 0: exact `XAUUSD.DWX`; companion/traded slot 1: exact
  `XAGUSD.DWX`.
- Logical tester symbol: `QM5_41248_XAU_XAG_MPETTITT_RV_D1` on the XAU host.
- Timeframe: D1; intended magics `412480000` and `412480001`.
- Decision: first synchronized executable tick after a genuine broker-month
  transition, within 180 elapsed minutes of raw host D1 bar open.
- Formation: thirteen consecutive synchronized completed broker-month ends;
  current month excluded.
- Hold: next broker-month boundary; forty calendar days is stale repair.
- Expected pre-result cadence: four to eight packages per full post-warm-up
  year; retire below four.

## Formula

For chronological synchronized completed-month close pairs `i=0..12`:

```text
s[i] = ln(XAU_close[i]) - ln(XAG_close[i])
require every s[i] pairwise distinct

R[i] = strict rank of s[i] from 1 to 13
require sorted(R) = [1,2,...,13]

for k = 1..12:
    U[k] = 2 * sum(R[0..k-1]) - 14*k

Ustar = max(abs(U[k]))
Kset  = { k : abs(U[k]) == Ustar }

require 0 < Ustar <= 42 and Ustar even
qualify iff size(Kset) == 1 and 4 <= K <= 9

SELL XAU / BUY XAG iff qualify and U[K] < 0
BUY XAU / SELL XAG iff qualify and U[K] > 0
FLAT otherwise
```

Negative `U[K]` means later ratios rank higher, so the card shorts the ratio.
Positive `U[K]` means later ratios rank lower, so the card buys the ratio.
Exact ties consume the month flat. There is no average-rank handling, p-value,
fitted hedge, center, scale, endpoint direction, or alternate split.
Statistic magnitude never changes direction or risk.

## Rules

- `ea_id=41248`, exact XAU/XAG symbols, D1, slots 0/1, magics `412480000` /
  `412480001`.
- Consume normalized broker month before every fallible entry gate.
- Use exactly thirteen immediately prior consecutive completed month keys and
  the latest exactly timestamp-matched pair in each. The newest pair must be
  no more than ten calendar days stale.
- Compute the exact strict-rank permutation, every cumulative rank sum, and
  maximum invariants. No tie deletion, fitted threshold, endpoint direction,
  center, scale, p-value, or fallback signal is permitted.
- Negative qualified shift maps to short ratio; positive qualified shift maps
  to long ratio. A tied or edge maximum consumes the month flat.
- Both news axes, legacy news mode, and Friday close are OFF.

## 4. Entry Rules

1. Require exact EA ID, host, companion, D1 period, slots, risk mode,
   framework inputs, and all locked strategy inputs.
2. Process package repair and prior-month/stale exits before entry-only gates.
3. Require a genuine new broker month no later than 180 elapsed minutes after
   raw host D1 bar open.
4. Persist current `yyyymm` before history, signal, news, spread, quote, ATR,
   sizing, margin, or order checks. No outcome retries that month.
5. Reject owned exposure or same-magic entry deals already recorded in the
   current broker month.
6. Reconstruct thirteen consecutive completed synchronized month-end pairs;
   reject missing, duplicate, unmatched, current-month, nonchronological,
   nonpositive, nonfinite, or stale data.
7. Compute thirteen log ratios and strict ranks. Reject any exact ratio tie,
   non-permutation, odd or out-of-range cumulative sum, nonpositive maximum,
   tied maximum, or edge split.
8. Map the signed central change point to the exact contrarian package sides.
   A tied, edge, or invalid result consumes the month flat.
9. Require both spreads in bounds, executable quotes, completed-bar
   `ATR(20,D1)`, valid metadata, fixed-risk sizing, and target absolute-
   notional mismatch no greater than 20%.
10. Split aggregate stop risk equally, reduce only to equalize target
    notionals, attach frozen `3.5*ATR(20,D1)` hard stops, and no targets.
11. Submit XAU first and XAG second. Keep only one correctly directed,
    correctly registered, stop-protected position per slot; otherwise flatten
    every owned leg immediately.

## 5. Exit Rules

1. Framework kill switch and broker hard stops remain authoritative.
2. Close both legs on the first processed tick in a later broker month before
   considering replacement risk, even if shift direction is unchanged.
3. Close after forty elapsed calendar days as stale repair.
4. Close every owned leg immediately if the package is orphaned, duplicated,
   same-side, wrong-symbol, wrong-magic, wrong-direction, stopless, stale, or
   outside the 20% notional mismatch tolerance.
5. No intramonth flip, target, trail, break-even, partial close, Friday close,
   news exit, scale-in, grid, martingale, or pyramid is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbols, period, EA ID, slots, fixed-risk,
  news/Friday, or locked-input contract.
- Reject consumed attempt, owned exposure, same-month entry history, malformed
  synchronization, invalid month selection, ratio tie, invalid rank
  permutation or cumulative-sum invariant, tied/edge maximum, excessive
  spread, invalid quote, unavailable ATR, invalid stop/volume, or notional
  mismatch.
- Terminal global state plus deal history prevent restart retries. Tester
  initialization clears only a future/prior-run marker so historical runs
  remain deterministic.
- Runtime may not read futures-chain, inventory, volume, open-interest, file,
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

## 8. Parameters To Test

The Q02 baseline is locked; this section names inputs for auditability, not an
optimization grant.

| Input | Value | Contract |
|---|---:|---|
| `strategy_xag_symbol` | XAGUSD.DWX | locked |
| `strategy_endpoint_count` | 13 | locked |
| `strategy_min_change_index` | 4 | locked |
| `strategy_max_change_index` | 9 | locked |
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

No parameter sweep, tie ranking, central-band change, alternate sample,
p-value gate, endpoint-direction fallback, volatility filter, seasonal
filter, or ensemble gate is authorized after results.

## Source-Defined Rules

- Gold/silver is a state-dependent relative-value relation rather than one
  guaranteed constant equilibrium.
- The Pettitt method ranks the complete sample, computes every cumulative
  rank sum, and identifies every split attaining the maximum absolute value.
- No source-defined performance, significance, hedge ratio, threshold,
  direction, density, CFD equivalence, or neutrality is imported.

## QM Interpretations

- Thirteen synchronized monthly ratio endpoints, `4..9` central band,
  unique-maximum requirement, contrarian direction, one-month hold,
  equal-target notionals, ATR stops, spread caps, and consumed attempt are
  transparent pre-result QM choices.
- Pairwise-equal ratios fail closed rather than receive average ranks.
- Equal target notionals reduce common outright-metal direction by design;
  they are not evidence of market or portfolio neutrality.

## Framework Execution Overrides

- Friday close: disabled to preserve the approved full-month hold.
- News temporal mode: OFF.
- News compliance profile: NONE.
- Legacy news mode passed to framework init: OFF.
- Backtest risk: fixed 1,000 account-currency units; percentage risk zero.
- Stress rejection probability: zero in the canonical set.

## Exit Precedence

1. Framework kill switch and hard-stop enforcement.
2. Lifecycle integrity repair.
3. New-broker-month close.
4. Forty-day stale close.
5. Entry-only news, spread, quote, ATR, sizing, and margin gates.
6. New package entry.

## Runtime Data Dependencies

Exact `XAUUSD.DWX` and `XAGUSD.DWX` native D1 timestamps and closes, broker
time, symbol metadata, quotes, completed-bar ATR, framework position/deal
state, and a terminal-persistent attempt marker. No external runtime dataset
exists.

## Risk

- Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1` as one aggregate package budget.
- Each leg receives half the stop-risk budget before notional equalization.
- Both legs receive a frozen `3.5*ATR(20,D1)` broker hard stop and no target.
- Entry spread caps are 1,500 XAU points and 500 XAG points.
- Realized absolute USD notionals must differ by no more than 20%.
- One package and one attempt per broker month; `Ustar` never alters size.
- Principal risks are relation shift or break, silver volatility dominance,
  two-leg fill failure, gap/slippage, volume-rounding imbalance, holiday
  synchronization loss, small-sample change-point instability, CFD
  financing/basis, low density, and overlap with the incumbent XAU sleeve.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS_WITH_RELATION_AND_METHOD_TRANSLATION_RISK | Peer-reviewed gold/silver relation evidence, official CME carrier research, named Pettitt record, complete pinned method files; exact conjunction untested. |
| R2 | PASS | Clock, synchronization, ranks, path, unique split, sides, attempt, risk, atomicity, and lifecycle fixed. |
| R3 | PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK | Registered native XAU/XAG D1 routes supply every runtime input. |
| R4 | PASS | Deterministic native arithmetic and state only; no trained method or external feed. |

## Failure Modes And Kill Criteria

- Retire on zero packages, fewer than four completed packages in any full
  post-warm-up year, nonpositive governed economics, or downstream failure.
- Fail on current-month leakage, missing/duplicate month keys, unmatched or
  stale pairs, wrong ratio orientation, rank tie, non-permutation, omitted
  split, tied/edge maximum entry, wrong contrarian side, retry, non-atomic
  exposure, notional imbalance, missing stop, wrong risk mode, or missed
  month exit.
- Retire on later portfolio-correlation rejection; no waiver is implied.
- Do not rescue failure by changing formation, ranks, band, direction,
  carrier, risk, stop, balance, hold, spread, retry, or order sequence.

## Falsification And Requalification

Any change to the thirteen-endpoint formation, strict ranks, all twelve
cumulative sums, unique maximum, `4..9` band, contrarian direction,
broker-month normalization, consumed attempt, spread ceilings, risk mode,
stop, or exit clock creates a new execution contract and requires a new
binary, stream reconciliation, Q02 restart, and full portfolio
requalification. Ambiguity is `BLOCKED`, never filled from results.

## Execution And State Contract

- The D1 decision clock supports only raw-current-date labels and a uniformly
  applied raw-plus-one-day convention; mixed offsets fail closed.
- A month is consumed before all fallible gates. Terminal global state and
  deal history prevent restart retry.
- Current-month prices never contribute to the signal.
- Position repair and month rollover run every tick before entry-only gates.
- Logs expose decision month, label offset, endpoint times, ratios, ranks,
  every cumulative sum, selected split, intended sides, notional balance, and
  lifecycle state without credentials.

## Portfolio Interaction

This opposite-leg precious-metals carrier is intended to reduce the common
directional XAU beta of the stated XAU/SP500/NDX/XNG book. Its ordinal
change-point exhaustion driver is mechanically different from the incumbent
XNG cumulative-RSI pullback and outright metal/index sleeves. Those are
design facts only. No ex-ante or realized correlation is claimed, and no
portfolio gate, threshold, incumbent, manifest, or admission state changes
under this card. Q09 owns the first realized overlap verdict.

## Validation Plan

1. Schema-lint both canonical and EA card copies.
2. Independently reproduce ratio orientation, strict rank permutation, all
   twelve sums, unique/tied maxima, 3/4 and 9/10 band boundaries, both
   contrarian sides, and invalid arithmetic cases.
3. Validate thirteen consecutive synchronized month keys, year rollover,
   latest-pair selection, current-month exclusion, staleness, label
   conventions, grace, attempt order, atomic repair, and monthly exit.
4. Require zero-error/zero-warning compile, build guardrails, exact two-slot
   scope, active registry identity, active magic rows, and source-fresh EX5.
5. Validate `basket_manifest.json`, then enqueue exactly one logical D1 Q02
   row after fresh Q01. Enqueue does not launch a manual tester.
6. Retire below the four-per-year floor or on nonpositive governed economics.

## Framework Alignment

- no_trade: exact XAU/XAG/D1/EA/slots, locked inputs, risk, news, Friday, and
  stress validation.
- trade_entry: consume-first month clock, synchronized endpoints, strict
  ranks, all Pettitt splits, uniqueness, central band, contrarian sides,
  spreads, quotes, ATR/stops, equal-notional sizing, and atomic submission.
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
| v1 | 2026-08-31 | initial source-bounded XAU/XAG Pettitt ratio-reversion card | G0 | APPROVED |
