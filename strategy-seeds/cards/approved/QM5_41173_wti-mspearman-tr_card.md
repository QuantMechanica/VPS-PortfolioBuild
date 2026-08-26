---
card_schema_version: 2
type: strategy
strategy_id: MOP-SPEARMAN-WTI-MRANK-TREND-2026_S01
variant_id: MOP-SPEARMAN-WTI-MRANK-TREND-2026_S01
source_id: MOP-SPEARMAN-WTI-MRANK-TREND-2026
ea_id: QM5_41173
slug: wti-mspearman-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41173_wti-mspearman-tr_card.md
execution_contract_status: APPROVED
created: 2026-08-26
created_by: Research+Development
last_updated: 2026-08-26
g0_status: APPROVED
g0_decision: decisions/2026-08-26_qm5_41173_wti_monthly_spearman_rank_trend_g0.md
source_approval: decisions/2026-08-26_wti_monthly_spearman_rank_trend_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; C. Spearman; R Core Team"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; C. Spearman; R Core Team"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003; Spearman (1904), The Proof and Measurement of Association between Two Things, The American Journal of Psychology 15(1), DOI 10.2307/1412159; R Core Team stats::cor source and manual."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence under strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: own_price_direction_monthly_cadence_and_wti_membership
  - type: peer_reviewed_statistical_method_record
    citation: "Spearman, C. (1904). The Proof and Measurement of Association between Two Things. The American Journal of Psychology 15(1)."
    location: "DOI 10.2307/1412159; Crossref metadata; body not claimed completely read"
    quality_tier: A_record_only
    role: rank_correlation_lineage
  - type: public_method_implementation
    citation: "R Core Team, stats::cor source and manual."
    location: "public wch/r-source mirror commit 7344a2d9d96b3c2b997535d3abc8c3a44af16e82; complete relevant files in retrieval receipt"
    quality_tier: A_method_implementation
    role: exact_rank_transform_then_correlation_definition
  - type: governed_composite_source
    citation: "QuantMechanica bounded WTI thirteen-month Spearman price-rank trend source packet."
    location: "strategy-seeds/sources/MOP-SPEARMAN-WTI-MRANK-TREND-2026/source.md"
    quality_tier: internal_governed
    role: exact_sample_integer_threshold_calendar_risk_and_lifecycle
strategy_mechanic: monthly-wti-thirteen-completed-month-end-spearman-price-rank-versus-time-rank-exact-integer-score-absolute-104-continuation
sources:
  - "[[sources/MOP-SPEARMAN-WTI-MRANK-TREND-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/nonparametric-rank-association]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-price]]"
  - "[[indicators/spearman-time-price-rank-score]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, spearman-rank-association, time-price-rank-displacement, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 411730000
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
r1_reasoning: "Complete-read peer-reviewed WTI continuation evidence, named original Spearman journal record, and complete pinned R Core method files; the exact WTI conjunction remains an untested QM hypothesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, endpoint reconstruction, strict ranks, displacement sum, integer threshold, direction, consumed attempt, fixed risk, stop, and lifecycle are deterministic and locked."
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered XTIUSD.DWX D1 history and native MT5 state supply every runtime input; continuous-CFD roll and basis risk remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, strict ranks, integer arithmetic, ATR risk controls, and execution state; no trained signal, prohibited input, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 endpoints; abs integer score 104; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly price-rank/time-rank association trend outside the stated XAU/SP500/NDX/XNG book. Verify thirteen consecutive completed month ends, strict rank permutation, D/T identities, abs(T)>=104, direction, consumed attempt, fixed risk, stop, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, first_tradable_month_bar, thirteen_consecutive_completed_months, latest_close_per_month, strict_no_tie_rank_permutation, spearman_displacement_identity, integer_score_threshold_104, monthly_attempt_state, fixed_risk, hard_stop_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-26 and decisions/2026-08-26_qm5_41173_wti_monthly_spearman_rank_trend_g0.md: R1 PASS with complete-read peer-reviewed WTI evidence, named Spearman record, and complete pinned R Core method files; R2 PASS locks thirteen endpoints, strict ranks, integer displacement score, threshold, direction, attempt, risk, stop, and lifecycle; R3 PASS registered native WTI D1 with continuous-CFD basis risk; R4 PASS deterministic native arithmetic only. Canonical dedup was CLEAN and fixed rank fixtures separate the rule from Mann-Kendall and Pettitt neighbors."
---

# QM5_41173 WTI Thirteen-Month Spearman Price-Rank Trend

## Hypothesis

WTI has a physical-energy return driver absent from the stated
XAU/SP500/NDX/XNG book. Production, capital investment, inventory, refining,
transport, hedging, and demand can adjust slowly enough for a broad monthly
price ordering to persist. This card continues WTI only when the rank
association between thirteen completed month-end prices and their exact
calendar order reaches a fixed absolute strength.

This is a falsifiable direct-crude structural-trend hypothesis. It is not
evidence that the stream is profitable, independent, or decorrelated. Q02 owns
activity and economics; downstream gates own robustness and realized
portfolio overlap.

## Source Traceability And Claim Boundary

The single governed source ID resolves to
`strategy-seeds/sources/MOP-SPEARMAN-WTI-MRANK-TREND-2026/source.md`, authorized
by `decisions/2026-08-26_wti_monthly_spearman_rank_trend_source_approval.md`
and committed before card extraction.

Moskowitz, Ooi, and Pedersen supply complete-read peer-reviewed WTI membership,
own-price continuation, and monthly cadence. Spearman supplies the named
rank-correlation lineage. The complete pinned R Core source and manual define
the operative statistic as ordinary correlation after rank-transforming both
inputs. The original 1904 article body is not represented as completely read.
None of the sources tests this thirteen-endpoint WTI threshold, continuous CFD,
or fixed-dollar execution contract.

No source return, alpha, probability, profit factor, Sharpe ratio, drawdown,
trade count, cost, WTI-only result, CFD equivalence, significance,
decorrelation, or portfolio-correlation statistic is imported.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker scanned 4,672 registry
identities, 1,323 card files, and 45 Strategy Wiki nodes. It found no exact or
fuzzy match. The receipt is
`artifacts/qm5_wti_mspearman_tr_preallocation_dedup_20260826.json`, SHA-256
`B7296C4BDEEC4624F25909AD9AD48A1F0020D57955676B84819855373EAD91F8`.

Manual functional review fixes a new statistic:

- `QM5_20264_wti-rank-trend` counts all 78 concordant-minus-discordant pairs;
  this card sums squared displacement between each price rank and its exact
  time rank.
- `QM5_41167_wti-coxstuart-tr` uses seven fixed lag-seven comparisons among
  fourteen points; this card uses all thirteen joint ranks.
- `QM5_41169_wti-foster-record-tr` keeps only running record events;
  `QM5_41170_wti-bartels-rank-tr` keeps adjacent rank distances;
  `QM5_41171_wti-mturnpoint-tr` keeps local extrema; and
  `QM5_41172_wti-mpettitt-shift-tr` locates one central cumulative-rank split.
  None computes price-rank correlation with calendar order.
- `QM5_10473_mql5-spearman` is an H4 FX zero-crossing system with different
  inputs, clock, event, lifecycle, and exposure.
- Rank vector `[3,2,10,1,4,12,11,8,7,9,6,5,13]` buys here at `T=170` while
  Mann-Kendall is flat at `S=20`; vector
  `[13,1,4,12,5,2,3,6,7,8,9,10,11]` is flat here at `T=98` while
  Mann-Kendall buys at `S=28`.
- Rank vector `[1,11,3,5,7,12,4,8,10,2,13,9,6]` buys here at `T=106` while
  Pettitt is flat on a tied maximum; vector
  `[8,3,9,2,13,11,1,12,6,7,4,5,10]` is flat here at `T=8` while Pettitt buys
  from its unique central maximum.
- Certified `QM5_12567_cum-rsi2-commodity` is a two-day long-only XNG
  oscillator pullback, not monthly WTI rank continuation.

Verdict: `CLEAN_WTI_MONTHLY_SPEARMAN_TIME_PRICE_RANK_T104_CONTINUATION`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1; magic slot 0; intended magic `411730000`.
- Decision clock: first executable tick after a genuine broker-month change,
  no later than 180 minutes after the raw current D1 bar open.
- Formation: the latest D1 close in each of thirteen consecutive completed
  broker calendar months, ending with the immediately prior month.
- Hold: next broker-month boundary; forty calendar days is stale repair.
- One consumed attempt and at most one owned position per broker month.
- Expected pre-result cadence: four to eight completed positions per full
  post-warm-up year; retire below four.

## Exact Formula

Let `C[0]..C[12]` be completed month-end closes, oldest to newest. Require
positive finite pairwise-distinct values. Assign each price its strict rank
`R[i]` from 1 through 13. The calendar rank at index `i` is `i+1`.

```text
require sorted(R) = [1,2,...,13]

D = 0
for i = 0..12:
    delta = R[i] - (i + 1)
    D += delta * delta

T = 364 - D
rho = T / 364

require 0 <= D <= 728
require -364 <= T <= 364
require D % 2 == 0 and T % 2 == 0

BUY  iff T >= 104
SELL iff T <= -104
FLAT otherwise
```

For two no-tie rank permutations this is algebraically identical to Spearman
rho because `rho = 1 - D/364`. The gate is exactly `abs(rho)>=2/7`. No
p-value, tie averaging, floating threshold, signal-strength sizing, or
fallback is authorized.

The threshold was locked before WTI testing. Exact enumeration of every 13!
rank permutation gives a random-order qualification rate of
`0.3436382463986631`, symmetrically split by side, or about 4.12 qualified
months per year. That is a density design fact, not a significance or WTI
performance claim.

## Rules

These are the complete authorized baseline. There is no parameter sweep and no
fallback to endpoint return, Mann-Kendall, slope, moving average, oscillator,
seasonality, volatility state, external series, or previous pipeline result.

## 4. Entry Rules

1. Require exact EA ID `41173`, exact `XTIUSD.DWX`, D1, magic slot 0, and every
   baseline input locked to its declared value.
2. Process lifecycle repair before entry-only gates and evaluate only at a
   genuine broker-month transition within the 180-minute entry window.
3. Persist the current broker `yyyymm` as consumed before history, signal,
   news, spread, quote, ATR, sizing, margin, or order checks. No retry is
   allowed that month.
4. Reject an owned position or any same-month entry deal for the magic.
5. Reconstruct exactly thirteen completed month-end closes from at most 900
   D1 bars. Require the newest endpoint to belong to the immediately prior
   month, no more than ten calendar days before the current month boundary,
   and require every older month key to be consecutive.
6. Keep endpoints oldest to newest; require positive finite pairwise-distinct
   closes; assign strict ranks; prove the rank permutation, D/T range, parity,
   and algebraic identity.
7. Continue only when `abs(T)>=104`; BUY for positive T and SELL for negative
   T. A weak, tied, malformed, unavailable, or invariant-failing state consumes
   the month flat.
8. Require spread in `[0,1500]` points, executable quote, completed
   `ATR(20,D1)`, valid point/digit/volume metadata, and valid fixed-risk sizing.
9. Open at most one market position with a frozen `3.5*ATR(20,D1)` hard stop
   and no take-profit.

## 5. Exit Rules

1. Close prior owned exposure on the first tick in a later broker month before
   considering replacement risk.
2. Close after forty elapsed calendar days as a stale guard.
3. Close immediately on duplicate, wrong-symbol, wrong-magic, wrong-side,
   invalid-volume, or stopless owned exposure; retry required closes every tick.
4. Broker hard stops and the framework kill switch remain authoritative.
5. No intramonth signal flip, profit target, trail, break-even, partial close,
   scale-in, hedge, reverse, grid, martingale, pyramid, or discretionary exit
   is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbol, timeframe, EA ID, magic slot, fixed risk,
  news/Friday contract, or locked strategy inputs.
- Reject a consumed attempt, owned exposure, same-month entry history,
  malformed or nonconsecutive endpoints, current-month leakage, stale newest
  endpoint, nonpositive/nonfinite close, any exact tie, invalid rank
  permutation, odd/out-of-range D or T, weak score, excessive spread, invalid
  quote, unavailable ATR, invalid stop, or invalid volume metadata.
- Both news axes and legacy news mode are locked OFF for Q02. Friday close is
  disabled. Lifecycle repair runs before entry-only gates.
- Runtime may not read a futures chain, inventory release, volume, open
  interest, file, API, analyst forecast, trained output, portfolio result, or
  prior pipeline verdict.

## 7. Trade Management Rules

- Own at most one exact slot-zero WTI position and one consumed attempt per
  broker month.
- Preserve the initial broker hard stop; never widen, trail, or remove it.
- Reconstruct the current-month expected side for lifecycle validation without
  creating another attempt.
- Restart recovery combines a terminal-persistent month marker with owned
  position and deal history. Tester initialization clears a future/prior-run
  marker so historical runs remain deterministic.
- Retry mandatory repairs every tick until flat. Do not add, pyramid, hedge,
  reverse, or reopen during the consumed month.

## 8. Parameters To Test

The Q02 baseline is locked; this table names inputs for auditability, not an
optimization grant.

| Input | Value | Contract |
|---|---:|---|
| `strategy_endpoint_count` | 13 | locked |
| `strategy_min_abs_score` | 104 | locked |
| `strategy_history_bars_d1` | 900 | locked |
| `strategy_entry_grace_minutes` | 180 | locked |
| `strategy_endpoint_stale_days` | 10 | locked |
| `strategy_atr_period_d1` | 20 | locked |
| `strategy_atr_sl_mult` | 3.5 | locked |
| `strategy_max_hold_days` | 40 | locked |
| `strategy_max_spread_points` | 1500 | locked |

No lookback, rank rule, threshold, side, p-value, tie treatment, risk, stop,
hold, or filter sweep is authorized after results.

## Framework Execution Overrides

- Friday close: disabled to preserve the approved full-month hold.
- News temporal mode: OFF.
- News compliance profile: NONE.
- Legacy news mode passed to framework init: OFF.
- Backtest risk: fixed 1,000 account-currency units; percentage risk zero.
- Stress rejection probability: zero in the canonical set.

## Exit Precedence

1. Framework kill switch and broker hard-stop enforcement.
2. Lifecycle integrity repair.
3. New-broker-month close.
4. Forty-day stale close.
5. Entry-only news, spread, quote, ATR, sizing, and margin gates.
6. New entry.

## Runtime Data Dependencies

- `XTIUSD.DWX` native/custom D1 bars and symbol metadata;
- broker time, current quotes, positions, deals, account state, and terminal
  global variables;
- framework ATR, risk sizing, stop rules, transaction manager, logging, and
  equity stream;
- no external runtime data or network access.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Stop: frozen `3.5*ATR(20,D1)` from the last completed bar at entry.
- Maximum entry spread: 1,500 points.
- One position and one attempt per broker month.
- T magnitude never alters size.
- No live, demo, shadow, stress, or optimization preset is authorized.
- Principal risks are WTI gaps, continuous-CFD roll/basis and financing,
  sparse monthly density, path order becoming stale, abrupt reversals,
  hard-stop slippage, and realized overlap with natural gas or risk assets.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK | Complete-read peer-reviewed WTI evidence, named original Spearman record, and complete pinned R Core method files; exact trading conjunction untested. |
| R2 | PASS | Clock, endpoint order, strict ranks, D/T identities, threshold, side, attempt, risk, stop, and lifecycle are fixed. |
| R3 | PASS_WITH_CONTINUOUS_CFD_BASIS_RISK | Registered native WTI D1 supplies every runtime input; Q02 owns density, cost, and CFD sufficiency. |
| R4 | PASS | Native deterministic rank and integer arithmetic only; no trained signal, prohibited input, external feed, grid, or martingale. |

## 9. Failure Modes And Kill Criteria

Retire or fail the candidate on any of the following:

- fewer than four completed positions in any full post-warm-up Q02 year;
- zero trades, nonpositive governed economics, or a downstream gate failure;
- current-month leakage, missing/duplicate month keys, nonlatest close, stale
  newest endpoint, nonchronological timestamps, or mixed label offsets;
- endpoint count other than 13, an accepted equal close, wrong rank
  permutation, incorrect D/T value, odd/out-of-range invariant, entry with
  `abs(T)<104`, or wrong signed side;
- same-month retry, missing hard stop, wrong risk mode, wrong spread ceiling,
  late entry, or missed month-boundary exit;
- nondeterministic output for identical history and inputs;
- any post-result rescue change to formation, rank rule, threshold, side,
  risk, stop, hold, symbol, or carrier; or
- downstream portfolio-correlation rejection. No waiver is implied.

## Falsification And Requalification

Any change to the thirteen-month formation, strict rank definition,
displacement formula, score threshold, broker-month normalization, consumed
attempt, spread ceiling, risk mode, stop, or exit clock creates a new execution
contract and requires a new binary, stream reconciliation, Q02 restart, and
full portfolio requalification. Unresolved history-label, rank, arithmetic,
or lifecycle ambiguity is `BLOCKED`, never filled in by Development.

## 10. Execution And State Contract

- `ea_id=41173`, exact `XTIUSD.DWX`, D1, slot 0, intended magic `411730000`.
- Persist `QM5_41173_MONTH_ATTEMPT_<magic>` before all fallible gates.
- Recover the persisted attempt across restarts and reconcile it with entry
  deals.
- A late restart consumes the new month flat; no catch-up entry.
- Exactly one active magic-registry row and resolver mapping are mandatory
  before compile.
- Logs expose month key, endpoint times, price ranks, every displacement,
  D, T, rational rho components, direction, and state.

## 11. Portfolio Interaction

This candidate adds direct WTI exposure rather than another index, gold, or
natural-gas rule. That is an exposure hypothesis, not a measured correlation
result. Q09 alone may establish overlap with the stated book. No portfolio
gate, manifest, allocation, or correlation waiver is changed by this card.

## 12. Validation Plan

1. Card schema lint and prohibited-token scan.
2. Canonical research dedup receipt plus Mann-Kendall and Pettitt
   discriminating rank fixtures.
3. Pure reference checks for month reconstruction, strict rank permutation,
   D/T algebra, parity/range, threshold boundary, long/short symmetry, weak
   paths, ties, and invalid states.
4. Strict MQL5 compile and framework build check.
5. Canonical `RISK_FIXED` XTIUSD.DWX D1 backtest set only.
6. Independent source/card/build alignment review.
7. At most one paced Q02 enqueue; no manual tester dispatch under a binding
   CPU ceiling.
8. Q02 owns activity/economics; subsequent automated gates own robustness and
   Q09 overlap. Failure retires the locked candidate.

## 13. Framework Alignment

| Card rule | V5 location |
|---|---|
| Exact host, risk/news/Friday/input locks | no-trade filter and `OnInit` |
| Month transition and durable consumed attempt | decision-clock and terminal-global state helpers |
| Thirteen completed month endpoints | bounded D1 reconstruction helper |
| Strict ranks, D/T invariants, threshold, side | entry signal helper |
| Frozen ATR stop and one market order | `Strategy_EntrySignal` plus framework transaction manager |
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
or decorrelation before governed evidence exists.

## Revision History

| Date | Change |
|---|---|
| 2026-08-26 | Initial source-complete card approved under the OWNER commodity/energy portfolio mission; canonical dedup CLEAN; R1-R4 PASS. |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-26 | APPROVED | `decisions/2026-08-26_qm5_41173_wti_monthly_spearman_rank_trend_g0.md` |
| Q01 Build Validation | 2026-08-26 | NOT_BUILT | build pending |
| Q02 Baseline Screening | 2026-08-26 | NOT_ENQUEUED_Q01_PENDING | compile and Q01 pending |
