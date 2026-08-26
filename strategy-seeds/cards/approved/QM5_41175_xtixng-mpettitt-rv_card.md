---
card_schema_version: 2
type: strategy
strategy_id: VILLAR-PETTITT-XTIXNG-MSHIFT-RV-2026_S01
variant_id: VILLAR-PETTITT-XTIXNG-MSHIFT-RV-2026_S01
source_id: VILLAR-PETTITT-XTIXNG-MSHIFT-RV-2026
ea_id: QM5_41175
slug: xtixng-mpettitt-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41175_xtixng-mpettitt-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-27
created_by: Research+Development
last_updated: 2026-08-27
g0_status: APPROVED
g0_decision: decisions/2026-08-27_qm5_41175_xtixng_monthly_pettitt_ratio_reversion_g0.md
source_approval: decisions/2026-08-27_xtixng_monthly_pettitt_ratio_reversion_source_approval.md
source_author: "Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons; A. N. Pettitt; Thorsten Pohlert"
source_authors: "Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons; A. N. Pettitt; Thorsten Pohlert"
source_citation: "Villar and Joutz (2006), The Relationship Between Crude Oil and Natural Gas Prices, U.S. EIA; Ramberg and Parsons (2012), The Weak Tie Between Natural Gas and Oil Prices, The Energy Journal 33(2), DOI 10.5547/01956574.33.2.2; Pettitt (1979), A Non-Parametric Approach to the Change-Point Problem, Applied Statistics 28(2), DOI 10.2307/2346729; Pohlert, trend 1.1.7, CRAN."
source_citations:
  - type: government_relationship_report
    citation: "Villar, J. A., and Joutz, F. L. (2006). The Relationship Between Crude Oil and Natural Gas Prices. U.S. Energy Information Administration."
    location: "complete 43-page report and hashes under strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md"
    quality_tier: A_official
    role: time_varying_oil_gas_relation_and_error_correction_context
  - type: peer_reviewed_relationship_paper
    citation: "Ramberg, D. J., and Parsons, J. E. (2012). The Weak Tie Between Natural Gas and Oil Prices. The Energy Journal 33(2), 13-35."
    location: "DOI 10.5547/01956574.33.2.2; complete author copy and adverse findings in governed parent packet"
    quality_tier: A
    role: weak_shifting_oil_gas_tie_and_adverse_evidence
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
    citation: "QuantMechanica bounded XTI/XNG thirteen-month Pettitt ratio change-point reversion packet."
    location: "strategy-seeds/sources/VILLAR-PETTITT-XTIXNG-MSHIFT-RV-2026/source.md"
    quality_tier: internal_governed
    role: exact_sample_central_band_direction_calendar_risk_atomicity_and_lifecycle
strategy_mechanic: monthly-xtixng-thirteen-synchronized-completed-month-end-oil-minus-gas-log-ratio-pettitt-unique-central-rank-sum-change-point-contrarian-equal-notional-basket
sources:
  - "[[sources/VILLAR-PETTITT-XTIXNG-MSHIFT-RV-2026]]"
concepts:
  - "[[concepts/oil-gas-relative-value]]"
  - "[[concepts/nonparametric-change-point]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/synchronized-completed-month-log-ratio]]"
  - "[[indicators/pettitt-rank-sum-path]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, natural-gas, market-neutral-style, relative-value, structural-reversion, pettitt-change-point, rank-sum, monthly-rebalance, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, oil_gas_relative_value]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41175_XTI_XNG_MPETTITT_RV_D1
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 411750000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 4-8 completed XTI/XNG packages per full post-warm-up year after thirteen synchronized completed month ends; one consumed attempt per broker month."
expected_trades_per_year_per_symbol: 4
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_RELATION_AND_METHOD_TRANSLATION_RISK
r1_reasoning: "Complete government and peer-reviewed oil/gas relationship evidence including adverse findings, named original Pettitt record, and complete pinned CRAN method files; the exact contrarian basket remains an untested QM hypothesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, synchronized endpoints, strict ranks, cumulative rank sums, unique central split, contrarian sides, consumed attempt, aggregate fixed risk, atomicity, and lifecycle are deterministic and locked."
r3_data_available: PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r3_reasoning: "Registered XTIUSD.DWX and XNGUSD.DWX D1 histories and native MT5 state supply every runtime input; synchronization, roll, and continuous-CFD basis risk remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, strict ranks, integer arithmetic, ATR risk controls, and execution state; no trained signal or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 synchronized endpoints; unique change index 4..9; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/3000-point spread ceilings."
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
review_focus: "Falsify a thirteen-completed-month oil/gas Pettitt ratio-change reversion basket outside the directional XAU/SP500/NDX/XNG book. Verify exact synchronization, ratio orientation, strict rank permutation, every cumulative sum, unique central split, contrarian sides, consumed attempt, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, thirteen_consecutive_completed_months, synchronized_month_end_pairs, latest_pair_per_month, chronological_ratio_orientation, strict_no_tie_rank_permutation, pettitt_cumulative_rank_sums, unique_central_change_index, contrarian_pair_sides, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-27 and decisions/2026-08-27_qm5_41175_xtixng_monthly_pettitt_ratio_reversion_g0.md: R1 PASS with complete government and peer-reviewed oil/gas evidence, named Pettitt record, and complete pinned CRAN method files; R2 PASS locks synchronized endpoints, strict ranks, cumulative sums, central split, contrarian sides, attempt, aggregate risk, atomicity, and lifecycle; R3 PASS registered native XTI/XNG D1 with synchronization/CFD risk; R4 PASS deterministic native arithmetic only. Canonical dedup was CLEAN; carrier, direction, and lifecycle separate it from the outright WTI Pettitt build, while the rank-change state separates it from every existing XTI/XNG basket."
---

# QM5_41175 XTI/XNG Thirteen-Month Pettitt Ratio Change-Point Reversion

## Hypothesis

Crude oil and natural gas are linked through substitution, co-production,
drilling inputs, finance, and some LNG contracts, while regional gas
fundamentals can materially decouple them. A fixed price ratio or rolling
z-score assumes a stable center and scale that the source evidence rejects.
This card instead asks whether the strict rank path of thirteen synchronized
completed month-end oil-minus-gas log ratios contains one dominant central
level shift, then fades the post-shift ratio regime.

Opposite equal-target-notional legs are designed to reduce outright energy
direction and create a market-neutral-style stream different from the
directional XAU, SP500, NDX, and XNG book. They do not prove dollar, beta,
volatility, factor, market, or portfolio neutrality. Q02 owns density and
baseline economics; unchanged Q09 alone owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The single governed source ID resolves to
`strategy-seeds/sources/VILLAR-PETTITT-XTIXNG-MSHIFT-RV-2026/source.md`,
SHA-256 `4919B9F71CEAA0D38FF22117A7E1AEBB419022B096FDFCD022D5311187A002B1`,
authorized by
`decisions/2026-08-27_xtixng_monthly_pettitt_ratio_reversion_source_approval.md`
and committed as `39aeee243` before card extraction.

Villar-Joutz and Ramberg-Parsons supply the time-varying weak oil/gas
relationship and binding adverse evidence. Pettitt supplies named
peer-reviewed change-point lineage; the complete pinned CRAN files define the
operative statistic as a rank-sum path and absolute maximum. The original
1979 body is not represented as completely read. None tests this synchronized
XTI/XNG central band, contrarian package, continuous CFDs, or fixed-dollar
execution contract.

No source return, alpha, probability, density, profit factor, drawdown,
transaction cost, hedge ratio, neutrality, CFD equivalence, statistical
significance, decorrelation, or portfolio-correlation statistic is imported.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker scanned 4,674 registry
identities, 1,325 cards, and 45 Strategy Wiki nodes. It found no exact or
fuzzy match. The receipt is
`artifacts/qm5_xtixng_mpettitt_rv_preallocation_dedup_20260827.json`, SHA-256
`03FECB559F3EC214799DDF8D7A570D7479B23A8C6C26C652EFDF1620174DBACB`.

Manual review fixes a new statistic and carrier conjunction:

- `QM5_41172_wti-mpettitt-shift-tr` follows the same rank statistic on one
  outright WTI position. This card constructs a synchronized oil-minus-gas
  ratio, fades the signed shift, and owns an atomic equal-notional package.
- `QM5_20237_xtixng-ecm-rv` fits a 252-D1 trend-augmented OLS residual and
  trades a z-score crossing. This card performs no regression, estimates no
  beta, and consumes thirteen completed monthly endpoints.
- Fixed oil/gas ratio, return-spread, channel, momentum, carry, same-calendar,
  tail, volatility, factor-rank, and weekday baskets observe different state
  objects or use different clocks.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not a monthly paired-energy rank-change basket.

Verdict:
`CLEAN_XTIXNG_MONTHLY_PETTITT_UNIQUE_CENTRAL_RATIO_SHIFT_CONTRARIAN_BASKET`.

## Markets, Timeframe, And Cadence

- Host/traded slot 0: exact `XTIUSD.DWX`; companion/traded slot 1: exact
  `XNGUSD.DWX`.
- Logical tester symbol: `QM5_41175_XTI_XNG_MPETTITT_RV_D1` on the XTI host.
- Timeframe: D1; intended magics `411750000` and `411750001`.
- Decision: first synchronized executable tick after a genuine broker-month
  transition, within 180 elapsed minutes of the raw host D1 bar open.
- Formation: thirteen consecutive synchronized completed broker-month ends;
  current month excluded.
- Hold: next broker-month boundary; forty calendar days is stale repair.
- Expected pre-result cadence: four to eight packages per full post-warm-up
  year; retire below four.

## Formula

For chronological synchronized completed-month close pairs `i=0..12`:

```text
s[i] = ln(XTI_close[i]) - ln(XNG_close[i])
require every s[i] pairwise distinct

R[i] = strict rank of s[i] from 1 to 13
require sorted(R) = [1,2,...,13]

for k = 1..12:
    U[k] = 2 * sum(R[0..k-1]) - 14*k

Ustar = max(abs(U[k]))
Kset  = { k : abs(U[k]) == Ustar }

require 0 < Ustar <= 42 and Ustar even
qualify iff size(Kset) == 1 and 4 <= K <= 9

SELL XTI / BUY XNG iff qualify and U[K] < 0
BUY XTI / SELL XNG iff qualify and U[K] > 0
FLAT otherwise
```

Negative `U[K]` means later ratios rank higher; the card shorts the ratio.
Positive `U[K]` means later ratios rank lower; the card buys the ratio. Exact
ties consume the month flat. There is no average-rank handling, p-value,
fitted hedge, center, scale, endpoint direction, or alternate split. Statistic
magnitude never changes direction or risk.

## Rules

- `ea_id=41175`, exact XTI/XNG symbols, D1, slots 0/1, magics `411750000` /
  `411750001`.
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
   sizing, margin, or order checks. No flat, rejected, partial, failed,
   stopped, or restarted outcome retries that month.
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
    notionals, attach frozen `3.5*ATR(20,D1)` hard stops, and attach no targets.
11. Submit XTI first and XNG second. Keep only one correctly directed,
    correctly registered, stop-protected position per slot; otherwise flatten
    every owned leg immediately.

## 5. Exit Rules

1. Framework kill switch and broker hard stops remain authoritative.
2. Close both legs on the first processed tick in a later broker month before
   considering replacement risk, even if the shift direction is unchanged.
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
| `strategy_xng_symbol` | XNGUSD.DWX | locked |
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
| `strategy_xti_max_spread_points` | 1500 | locked |
| `strategy_xng_max_spread_points` | 3000 | locked |
| `strategy_deviation_points` | 20 | locked |

No parameter sweep, tie ranking, central-band change, alternate sample,
p-value gate, endpoint-direction fallback, volatility filter, seasonal filter,
or ensemble gate is authorized after results.

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

Exact `XTIUSD.DWX` and `XNGUSD.DWX` native D1 timestamps and closes, broker
time, symbol metadata, quotes, completed-bar ATR, framework position/deal
state, and a terminal-persistent attempt marker. No external runtime dataset
exists.

## Risk

- Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1` as one aggregate package budget.
- Each leg receives half the stop-risk budget before notional equalization.
- Both legs receive a frozen `3.5*ATR(20,D1)` broker hard stop and no target.
- Entry spread caps are 1,500 XTI points and 3,000 XNG points.
- Realized absolute USD notionals must differ by no more than 20%.
- One package and one attempt per broker month; `Ustar` never alters size.
- Principal risks are weak/unstable oil-gas linkage, continuous-CFD roll and
  basis, financing, gaps, persistent ratio shifts, volume-rounding imbalance,
  partial-fill repair, sparse density, and downstream portfolio overlap.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS | Complete government and peer-reviewed oil/gas evidence, named Pettitt record, and complete pinned CRAN files; exact conjunction untested. |
| R2 | PASS | Clock, synchronization, ranks, cumulative sums, unique central split, side, attempt, aggregate risk, atomicity, and lifecycle are fixed. |
| R3 | PASS | Registered native XTI/XNG D1 supplies every runtime input; synchronization and CFD basis risks remain explicit. |
| R4 | PASS | Native deterministic ranks and state only; no trained signal, banned indicator, external feed, grid, or martingale. |

## 9. Failure Modes And Kill Criteria

Retire or fail the candidate on any of the following:

- fewer than four completed packages in any full post-warm-up Q02 year;
- zero trades, nonpositive governed economics, or a downstream gate failure;
- current-month leakage, missing/duplicate month keys, nonlatest or unmatched
  close, stale newest endpoint, nonchronological timestamps, or mixed label
  offsets;
- endpoint count other than 13, accepted equal ratio, wrong rank permutation,
  odd or out-of-bounds `U[k]`, wrong `Ustar`, accepted tied/edge maximum, or
  wrong contrarian side;
- same-month retry, non-atomic package, missing hard stop, wrong risk mode,
  wrong spread ceiling, late entry, or missed month-boundary exit;
- nondeterministic output for identical history and inputs;
- any post-result rescue change to formation, rank rule, central band, side,
  risk, stop, hold, symbol, or carrier; or
- downstream portfolio-correlation rejection. No waiver is implied.

## Falsification And Requalification

Any change to the thirteen-month formation, exact synchronization, ratio
orientation, strict ranks, cumulative-sum formula, unique-maximum rule,
`K=4..9` band, contrarian side, broker-month normalization, consumed attempt,
notional balance, risk mode, stop, or exit clock creates a new execution
contract and requires a new binary, stream reconciliation, Q02 restart, and
full portfolio requalification. Unresolved history-label, rank, split,
atomicity, or lifecycle ambiguity is `BLOCKED`, never filled in by Development.

## 10. Execution And State Contract

- `ea_id=41175`, exact `XTIUSD.DWX` / `XNGUSD.DWX`, D1, slots 0/1, intended
  magics `411750000` / `411750001`.
- Persist `QM5_41175_MONTH_ATTEMPT_<magic>` before all fallible gates.
- Recover the persisted attempt across restarts and reconcile it with entry
  deals on either slot.
- A late restart consumes the new month flat; no catch-up entry.
- Exactly two active magic-registry rows and resolver mappings are mandatory
  before compile.
- Logs expose month key, endpoint times, ratios, ranks, all `U[k]` invariants,
  `Ustar`, `K`, signed value, package sides, notionals, and state.

## 11. Portfolio Interaction

This candidate adds crude-oil exposure through an opposite-side energy pair
rather than another index, gold, or outright natural-gas rule. That is an
exposure hypothesis, not a measured correlation result. Q09 alone may
establish overlap with the stated book. No portfolio gate, manifest,
allocation, or correlation waiver is changed by this card.

## 12. Validation Plan

1. Card schema lint and forbidden-token scan.
2. Canonical research dedup receipt and functional neighbor review.
3. Pure reference checks for synchronization, rank permutation, every
   `U[k]`, parity/range, unique maximum, central band, side, ties, and invalid
   states.
4. Strict MQL5 compile and framework build check.
5. Canonical `RISK_FIXED` logical-basket D1 backtest set only, plus runner
   leg descriptors required by the basket manifest.
6. Independent source/card/build alignment review.
7. At most one paced Q02 enqueue; no manual tester dispatch under a binding
   CPU ceiling.
8. Q02 owns activity/economics; subsequent automated gates own robustness and
   Q09 overlap. Failure retires the locked candidate.

## 13. Framework Alignment

| Card rule | V5 location |
|---|---|
| Exact host, companion, risk/news/Friday/input locks | no-trade filter and `OnInit` |
| Month transition and durable consumed attempt | decision-clock and terminal-global state helpers |
| Thirteen synchronized completed month pairs | bounded dual-D1 reconstruction helper |
| Ratios, ranks, cumulative sums, maximum, band, side | entry signal helper |
| Frozen ATR stops and atomic two-leg entry | package helper plus framework transaction manager |
| Integrity repair, month close, forty-day stop | `Strategy_ManageOpenPosition` |
| No discretionary close signal | `Strategy_ExitSignal` returns false |
| Logging and equity stream | framework hooks on new bar/tick/transaction |

## 14. Safety Boundary

Authorized: one approved card, one registered V5 identity, one non-live source
build, strict Q01 validation, independent review, and at most one paced Q02
enqueue.

Forbidden: manual backtests outside the farm, live/demo/shadow/stress or
optimization setfiles, `T_Live`, AutoTrading, deploy or live manifests,
portfolio-gate edits, portfolio admission, correlation waivers, external
runtime data, terminal control, and claims of profitability, certification,
neutrality, or decorrelation before governed evidence exists.

## Revision History

| Date | Change |
|---|---|
| 2026-08-27 | Initial source-complete card approved under the OWNER commodity/energy portfolio mission; canonical dedup CLEAN; R1-R4 PASS. |
