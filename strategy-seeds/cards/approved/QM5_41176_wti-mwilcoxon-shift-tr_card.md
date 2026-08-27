---
card_schema_version: 2
type: strategy
strategy_id: MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026_S01
variant_id: MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026_S01
source_id: MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026
ea_id: QM5_41176
slug: wti-mwilcoxon-shift-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41176_wti-mwilcoxon-shift-tr_card.md
execution_contract_status: APPROVED
created: 2026-08-27
created_by: Research+Development
last_updated: 2026-08-27
g0_status: APPROVED
g0_decision: decisions/2026-08-27_qm5_41176_wti_monthly_mann_whitney_location_shift_trend_g0.md
source_approval: decisions/2026-08-27_wti_monthly_mann_whitney_location_shift_trend_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; H. B. Mann; D. R. Whitney; R Core Team"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; H. B. Mann; D. R. Whitney; R Core Team"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003; Mann and Whitney (1947), On a Test of Whether one of Two Random Variables is Stochastically Larger than the Other, Annals of Mathematical Statistics 18(1), 50-60, DOI 10.1214/aoms/1177730491; R Core Team stats::wilcox.test source and manual."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence under strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: own_price_direction_monthly_cadence_and_wti_membership
  - type: peer_reviewed_statistical_method_record
    citation: "Mann, H. B., and Whitney, D. R. (1947). On a Test of Whether one of Two Random Variables is Stochastically Larger than the Other. The Annals of Mathematical Statistics 18(1), 50-60."
    location: "DOI 10.1214/aoms/1177730491; Crossref metadata; body not claimed completely read"
    quality_tier: A_record_only
    role: two_sample_ordinal_location_comparison_lineage
  - type: public_method_implementation
    citation: "R Core Team, stats::wilcox.test source and manual."
    location: "public wch/r-source mirror commit 7344a2d9d96b3c2b997535d3abc8c3a44af16e82; complete relevant files in retrieval receipt"
    quality_tier: A_method_implementation
    role: exact_two_sample_rank_sum_and_pair_count_definition
  - type: governed_composite_source
    citation: "QuantMechanica bounded WTI twelve-month fixed-block Mann-Whitney location-shift source packet."
    location: "strategy-seeds/sources/MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026/source.md"
    quality_tier: internal_governed
    role: exact_sample_split_threshold_calendar_risk_and_lifecycle
strategy_mechanic: monthly-wti-twelve-completed-month-end-fixed-six-older-six-newer-strict-no-tie-mann-whitney-u-location-shift-threshold-24-12-continuation
sources:
  - "[[sources/MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/nonparametric-location-shift]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-price]]"
  - "[[indicators/mann-whitney-u-pair-count]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, mann-whitney-location-shift, wilcoxon-rank-sum, fixed-block-rank-comparison, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
symbol_slots: [0]
magic: 411760000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: long_short
expected_trade_frequency: "About 4-8 completed XTIUSD positions/year after warm-up; one consumed attempt per broker month."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.05
expected_dd_pct: 20.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK
r1_reasoning: "Complete-read peer-reviewed WTI continuation evidence, named original Mann-Whitney journal record, and complete pinned R Core method files; the exact WTI conjunction remains an untested QM hypothesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, endpoint reconstruction, fixed six/six blocks, strict tie rejection, 36 pair counts, complementary-count invariant, integer thresholds, direction, consumed attempt, fixed risk, stop, and lifecycle are deterministic and locked."
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered XTIUSD.DWX D1 history and native MT5 state supply every runtime input; continuous-CFD roll and basis risk remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, strict comparisons, integer arithmetic, ATR risk controls, and execution state; no trained signal, prohibited input, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 12 endpoints; fixed block size 6; U lower/upper boundaries 12/24; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI fixed-block monthly location-shift trend outside the stated XAU/SP500/NDX/XNG book. Verify twelve consecutive completed month ends, exact six/six membership, strict ties, all 36 cross-block comparisons, complementary U invariant, inclusive 12/24 boundaries, direction, consumed attempt, fixed risk, stop, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, first_tradable_month_bar, twelve_consecutive_completed_months, latest_close_per_month, fixed_six_by_six_membership, strict_no_tie_combined_ranks, all_36_cross_block_pairs, complementary_u_invariant, inclusive_u_12_24_thresholds, monthly_attempt_state, fixed_risk, hard_stop_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-27 and decisions/2026-08-27_qm5_41176_wti_monthly_mann_whitney_location_shift_trend_g0.md: R1 PASS with complete-read peer-reviewed WTI evidence, named Mann-Whitney record, and complete pinned R Core method files; R2 PASS locks twelve endpoints, fixed blocks, strict ties, pair counts, thresholds, direction, attempt, risk, stop, and lifecycle; R3 PASS registered native WTI D1 with continuous-CFD basis risk; R4 PASS deterministic native arithmetic only. Canonical dedup was CLEAN and fixed rank fixtures separate the rule from Mann-Kendall, Pettitt, Spearman, and daily median-shift neighbors."
---

# QM5_41176 WTI Twelve-Month Mann-Whitney Location-Shift Trend

## Hypothesis

WTI has a physical-energy return driver absent from the stated
XAU/SP500/NDX/XNG book. Production, capital investment, inventory, refining,
transport, hedging, and demand can adjust slowly enough for a broad shift in
the monthly price distribution to persist. This card continues WTI only when
the newer six of twelve completed month-end prices dominate or trail the older
six by a fixed ordinal boundary.

This is a falsifiable direct-crude structural-trend hypothesis. It is not
evidence that the stream is profitable, independent, or decorrelated. Q02 owns
activity and economics; downstream gates own robustness and realized
portfolio overlap.

## Source Traceability And Claim Boundary

The single governed source ID resolves to
`strategy-seeds/sources/MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026/source.md`,
authorized by
`decisions/2026-08-27_wti_monthly_mann_whitney_location_shift_trend_source_approval.md`
and committed as `38c2df295` before card extraction.

Moskowitz, Ooi, and Pedersen supply complete-read peer-reviewed WTI membership,
monthly own-price continuation lineage, and monthly renewal. Mann and Whitney
supply named peer-reviewed two-sample ordinal lineage. The complete pinned R
Core files define the operative statistic as combined rank sum less the
minimum possible rank sum and document its cross-sample pair-count identity.
The original 1947 body is not represented as completely read. None tests this
twelve-endpoint, fixed six/six, integer-boundary continuous-CFD rule.

No source return, alpha, probability, significance, density, profit factor,
drawdown, transaction cost, WTI-only result, CFD equivalence, decorrelation,
or portfolio-correlation statistic is imported.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker scanned 4,675 registry
identities, 1,326 card files, and 45 Strategy Wiki nodes. It found no exact or
fuzzy match. The receipt is
`artifacts/qm5_wti_mwilcoxon_shift_tr_preallocation_dedup_20260827.json`,
SHA-256
`C2F817B5CFAE47788BC8261553D32855191869912B8438858E90EB3CAEA17640`.

Manual review fixes a distinct sample partition and statistic:

- `QM5_20264_wti-rank-trend` compares all 78 ordered pairs over thirteen
  endpoints; this card counts only 36 pairs crossing one fixed six/six split
  among the latest twelve endpoints.
- `QM5_41172_wti-mpettitt-shift-tr` scans twelve possible splits and retains a
  unique dominant central maximum; this card never searches or maximizes.
- `QM5_41173_wti-mspearman-tr` weights squared displacement from calendar
  rank; this card is invariant to within-block order.
- `QM5_41137_wti-mmedian-shift-mom` compares all daily closes in two adjacent
  months; this card compares monthly endpoints across two six-month regimes.
- `QM5_20272_wti-qtrvote-tr` follows four return-block signs rather than a
  combined ordinal location statistic.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not a monthly WTI rank-location rule.

On thirteen-rank path `[11,13,2,4,6,1,3,10,5,7,8,9,12]`, this card uses the
latest twelve and buys at `U_new=29`, while Mann-Kendall is flat at `S=16`,
Spearman is flat at `T=52`, and Pettitt is flat at edge split `K=2`. Path
`[1,8,3,5,7,11,9,4,2,12,13,6,10]` is flat here at `U_new=20`, while all three
thirteen-endpoint neighbors buy. Path
`[11,10,9,8,3,2,1,13,4,5,6,12,7]` buys here at the inclusive `U_new=24`
boundary while Pettitt sells and Mann-Kendall/Spearman stay flat.

Verdict:
`CLEAN_WTI_MONTHLY_FIXED_SIX_BY_SIX_MANN_WHITNEY_U24_LOCATION_SHIFT_CONTINUATION`.

## Markets, Timeframe, And Cadence

- Traded symbol: exact `XTIUSD.DWX` only.
- Timeframe: exact D1; slot 0; intended magic `411760000`.
- Decision: first executable tick after a genuine broker-month transition,
  within 180 elapsed minutes of the raw current D1 bar open.
- Formation: latest close in each of twelve consecutive completed broker
  months; current month excluded; fixed older/newer blocks of six.
- Hold: next broker-month boundary; forty calendar days is stale repair.
- Expected pre-result cadence: four to eight positions per full post-warm-up
  year; retire below four.

## Exact Formula

For chronological completed-month prices `C[0..11]`:

```text
O = C[0..5]
N = C[6..11]

require C is positive, finite, and pairwise distinct

U_new = 0
U_old = 0
for i = 0..5:
    for j = 0..5:
        U_new += 1 iff N[j] > O[i]
        U_old += 1 iff O[i] > N[j]

require 0 <= U_new <= 36
require 0 <= U_old <= 36
require U_new + U_old == 36

BUY  iff U_new >= 24
SELL iff U_new <= 12
FLAT otherwise
```

With newer as the first sample, `U_new` equals its combined rank sum less 21.
The thresholds are inclusive and symmetric about 18. No tie averaging,
p-value, fitted location, variable split, maximum search, endpoint direction,
or fallback exists. Statistic magnitude never changes risk.

Exact enumeration of the 924 possible no-tie assignments of six combined
ranks to the newer block gives 364 qualifying assignments, or 4.727 decisions
per twelve opportunities. This is a locked density design fact only.

## Rules

- `ea_id=41176`, exact `XTIUSD.DWX`, D1, slot 0, magic `411760000`.
- Consume normalized broker month before every fallible entry gate.
- Use exactly twelve immediately prior consecutive completed month keys and
  the latest close in each; newest endpoint no more than ten days stale.
- Split only after endpoint six and count every strict cross-block pair.
- Buy at `U_new>=24`, sell at `U_new<=12`, central/tied/invalid state flat.
- Both news axes, legacy news mode, and Friday close are OFF.

## 4. Entry Rules

1. Require exact EA ID, symbol, D1 period, slot, fixed-risk mode, framework
   inputs, and all locked strategy inputs.
2. Process lifecycle repair and prior-month/stale exits before entry-only
   gates.
3. Require a genuine new broker month no later than 180 elapsed minutes after
   the raw host D1 bar open.
4. Persist current `yyyymm` before history, signal, news, spread, quote, ATR,
   sizing, margin, or order checks. No flat, rejected, failed, stopped, or
   restarted outcome retries that month.
5. Reject owned exposure or a same-magic entry deal already recorded in the
   current broker month.
6. Reconstruct exactly twelve consecutive completed month-end closes; reject
   missing/duplicate months, current-month data, nonchronological timestamps,
   nonpositive/nonfinite values, any exact price tie, or a stale newest
   endpoint.
7. Assign fixed older/newer blocks, count all 36 comparisons in both
   directions, and require the complementary-count invariant.
8. Continue only at the exact inclusive U boundaries. A central or invalid
   result consumes the month flat.
9. Require spread in bounds, executable quote, completed-bar `ATR(20,D1)`,
   valid symbol metadata, fixed-risk sizing, and sufficient margin.
10. Open one market position with a frozen `3.5*ATR(20,D1)` hard stop, no
    target, no partial initial exposure, and no signal-strength sizing.

## 5. Exit Rules

1. Framework kill switch and broker hard stop remain authoritative.
2. Close on the first processed tick in a later broker month before considering
   replacement risk, even if the U direction is unchanged.
3. Close after forty elapsed calendar days as stale repair.
4. Close immediately on duplicate, wrong-symbol, wrong-magic, wrong-side,
   invalid-volume, or stopless owned exposure.
5. No intramonth flip, target, trail, break-even, partial close, Friday close,
   news exit, scale-in, grid, martingale, or pyramid is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbol, period, EA ID, slot, fixed-risk,
  news/Friday, or locked-input contract.
- Reject consumed attempt, owned exposure, same-month entry history, malformed
  month selection, stale endpoint, any exact price tie, invalid pair-count
  invariant, central U, excessive spread, invalid quote, unavailable ATR,
  invalid stop/volume, or insufficient margin.
- Terminal global state plus deal history prevent restart retries. Tester
  initialization clears only a future/prior-run marker so historical runs
  remain deterministic.
- Runtime may not read futures-chain, inventory, volume, open-interest, file,
  API, forecast, trained-output, optimizer-result, or portfolio state.

## 7. Trade Management Rules

- Maintain zero or one valid WTI position and one consumed attempt per broker
  month.
- Preserve the original hard stop; close before monthly renewal or after
  forty elapsed calendar days.
- Run malformed-position repair before entry-only gates on every tick.
- Restart recovery combines the terminal-persistent month marker with owned
  positions and same-month deal history; no restart creates a second attempt.
- No randomness, adaptation, external state, partial close, scale-in, grid,
  martingale, or pyramiding is allowed.

## 8. Parameters To Test

The Q02 baseline is locked; this section names inputs for auditability, not an
optimization grant.

| Input | Value | Contract |
|---|---:|---|
| `strategy_endpoint_count` | 12 | locked |
| `strategy_block_size` | 6 | locked |
| `strategy_u_lower` | 12 | locked |
| `strategy_u_upper` | 24 | locked |
| `strategy_history_bars_d1` | 900 | locked |
| `strategy_entry_window_minutes` | 180 | locked |
| `strategy_max_endpoint_gap_days` | 10 | locked |
| `strategy_atr_period_d1` | 20 | locked |
| `strategy_atr_sl_mult` | 3.5 | locked |
| `strategy_max_hold_days` | 40 | locked |
| `strategy_max_spread_points` | 1500 | locked |
| `strategy_deviation_points` | 20 | locked |

No sweep, tie ranking, alternate split, alternate sample, p-value gate,
endpoint-direction fallback, volatility filter, seasonal filter, or ensemble
gate is authorized after results.

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
6. New position entry.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` native D1 timestamps and closes, broker time, symbol
metadata, quotes, completed-bar ATR, framework position/deal state, and a
terminal-persistent attempt marker. No external runtime dataset exists.

## Risk

- Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- One position receives a frozen `3.5*ATR(20,D1)` broker hard stop and no
  target.
- Entry spread is capped at 1,500 points.
- One position and one attempt per broker month; U magnitude never alters size.
- Principal risks are WTI trend failure/reversal, continuous-CFD roll and
  basis, financing, gaps, rank instability near the fixed boundary, sparse
  density, and downstream portfolio overlap.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS | Complete-read peer-reviewed WTI evidence, named Mann-Whitney record, and complete pinned R Core method files; exact conjunction untested. |
| R2 | PASS | Clock, endpoints, fixed blocks, strict ties, U identity, boundaries, side, attempt, risk, stop, and lifecycle are fixed. |
| R3 | PASS | Registered native WTI D1 supplies every runtime input; continuous-CFD basis risk remains explicit. |
| R4 | PASS | Native deterministic comparisons and state only; no trained signal, banned indicator, external feed, grid, or martingale. |

## 9. Failure Modes And Kill Criteria

Retire or fail the candidate on any of the following:

- fewer than four completed positions in any full post-warm-up Q02 year;
- zero trades, nonpositive governed economics, or a downstream gate failure;
- current-month leakage, missing/duplicate month keys, nonlatest close, stale
  newest endpoint, nonchronological timestamps, or mixed label offsets;
- endpoint count other than 12, block size other than 6, accepted equal price,
  omitted/doubled comparison, `U_new+U_old!=36`, wrong boundary, or wrong side;
- same-month retry, missing hard stop, wrong risk mode, late entry, or missed
  month-boundary exit;
- nondeterministic output for identical history and inputs;
- any post-result rescue change to formation, split, tie rule, threshold,
  side, risk, stop, hold, symbol, or carrier; or
- downstream portfolio-correlation rejection. No waiver is implied.

## Falsification And Requalification

Any change to the twelve-month formation, fixed six/six membership, strict
tie rule, pair-count formula, inclusive 12/24 boundaries, broker-month
normalization, consumed attempt, risk mode, stop, or exit clock creates a new
execution contract and requires a new binary, stream reconciliation, Q02
restart, and full portfolio requalification. Unresolved history-label,
pair-count, threshold, attempt, or lifecycle ambiguity is `BLOCKED`, never
filled in by Development.

## 10. Execution And State Contract

- `ea_id=41176`, exact `XTIUSD.DWX`, D1, slot 0, intended magic `411760000`.
- Persist `QM5_41176_MONTH_ATTEMPT_<magic>` before all fallible gates.
- Recover the persisted attempt across restarts and reconcile it with entry
  deals.
- A late restart consumes the new month flat; no catch-up entry.
- Exactly one active magic-registry row and resolver mapping is mandatory
  before compile.
- Logs expose month key, endpoint times/prices, block membership, `U_new`,
  `U_old`, invariant result, side, and state.

## 11. Portfolio Interaction

This candidate adds direct crude-oil exposure rather than another index, gold,
or natural-gas rule. The fixed two-regime rank location shift is mechanically
different from the certified XNG oscillator logic. That is an exposure
hypothesis, not a measured correlation result. Q09 alone may establish overlap
with the stated book. No portfolio gate, manifest, allocation, or correlation
waiver is changed by this card.

## 12. Validation Plan

1. Card schema lint and forbidden-token scan.
2. Canonical research dedup receipt and functional-neighbor review.
3. Pure reference checks for month keys, strict ties, all 36 comparisons,
   rank-sum identity, U complement, inclusive boundaries, side, and fixed
   counterexamples.
4. Strict MQL5 compile and framework build check.
5. Canonical `RISK_FIXED` XTIUSD D1 backtest set only.
6. Independent source/card/build alignment review.
7. At most one paced Q02 enqueue; no manual tester dispatch under a binding
   CPU ceiling.
8. Q02 owns activity/economics; subsequent automated gates own robustness and
   Q09 overlap. Failure retires the locked candidate.

## 13. Framework Alignment

| Card rule | V5 location |
|---|---|
| Exact symbol, period, risk/news/Friday/input locks | no-trade filter and `OnInit` |
| Month transition and durable consumed attempt | decision-clock and terminal-global state helpers |
| Twelve consecutive completed month ends | bounded D1 reconstruction helper |
| Fixed blocks, pair counts, U invariant, boundaries, side | entry signal helper |
| Frozen ATR stop and one market order | `Strategy_EntrySignal` plus framework transaction manager |
| Integrity repair, month close, forty-day stop | `Strategy_ManageOpenPosition` |
| No discretionary close signal | `Strategy_ExitSignal` returns `QM_EXIT_NONE` |
| Logging and equity stream | framework hooks on new bar/tick/transaction |

## 14. Safety Boundary

Authorized: one approved card, one registered V5 identity, one non-live source
build, strict Q01 validation, independent review, and at most one paced Q02
enqueue.

Forbidden: manual backtests outside the farm, live/demo/shadow/stress or
optimization setfiles, `T_Live`, AutoTrading, deploy or live manifests,
portfolio-gate edits, portfolio admission, correlation waivers, external
runtime data, terminal control, and claims of profitability, independence, or
decorrelation before governed evidence exists.

## Revision History

| Date | Change |
|---|---|
| 2026-08-27 | Initial source-complete card approved under the OWNER commodity/energy portfolio mission; canonical dedup CLEAN; R1-R4 PASS. |

## Pipeline Phase Status

| Phase | Status | Evidence |
|---|---|---|
| G0 Source Approval | APPROVED | `decisions/2026-08-27_wti_monthly_mann_whitney_location_shift_trend_source_approval.md` |
| G0 Card Decision | APPROVED | `decisions/2026-08-27_qm5_41176_wti_monthly_mann_whitney_location_shift_trend_g0.md` |
| EA Identity | ALLOCATED | `framework/registry/ea_id_registry.csv` |
| Magic | PENDING_BUILD_PREFLIGHT | governed allocator after EA directory creation |
| Q01 | NOT_BUILT | strict compile pending |
| Q02 | NOT_ENQUEUED_Q01_PENDING | one paced row only after current Q01/review PASS |
