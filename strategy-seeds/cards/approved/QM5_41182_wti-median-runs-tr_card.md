---
card_schema_version: 2
type: strategy
strategy_id: MOP-NIST-WTI-MEDRUN-TREND-2026_S01
variant_id: MOP-NIST-WTI-MEDRUN-TREND-2026_S01
source_id: MOP-NIST-WTI-MEDRUN-TREND-2026
ea_id: QM5_41182
slug: wti-median-runs-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41182_wti-median-runs-tr_card.md
execution_contract_status: APPROVED
created: 2026-08-27
created_by: Research+Development
last_updated: 2026-08-27
g0_status: APPROVED
g0_decision: decisions/2026-08-27_qm5_41182_wti_monthly_median_runs_persistence_trend_g0.md
source_approval: decisions/2026-08-27_wti_monthly_median_runs_persistence_trend_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; NIST/SEMATECH"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; NIST/SEMATECH"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003; NIST/SEMATECH e-Handbook of Statistical Methods section 1.3.5.13, Runs Test for Detecting Non-randomness."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read governed packet strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_commodity_own_price_continuation_and_wti_carrier
  - type: official_statistical_method
    citation: "NIST/SEMATECH e-Handbook of Statistical Methods, section 1.3.5.13, Runs Test for Detecting Non-randomness."
    location: "https://www.itl.nist.gov/div898/handbook/eda/section3/eda35d.htm; complete-read retrieval receipt in the governed source packet"
    quality_tier: A_official
    role: median_dichotomy_run_definition_count_and_expected_count
  - type: governed_composite_source
    citation: "QuantMechanica bounded WTI thirteen-month median-runs persistence packet."
    location: "strategy-seeds/sources/MOP-NIST-WTI-MEDRUN-TREND-2026/source.md"
    quality_tier: internal_governed
    role: exact_sample_rank_omission_threshold_direction_calendar_risk_and_lifecycle
strategy_mechanic: monthly-wti-thirteen-completed-month-end-above-below-sample-median-run-count-at-most-seven-newest-nonmedian-regime-continuation
sources:
  - "[[sources/MOP-NIST-WTI-MEDRUN-TREND-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/nonparametric-runs-persistence]]"
  - "[[concepts/energy-sleeve]]"
indicators:
  - "[[indicators/completed-month-end-rank]]"
  - "[[indicators/above-below-median-runs]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti, structural-trend, nonparametric, median-dichotomy, runs-persistence, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
symbol_slots: [0]
magic: 411820000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 5-9 completed WTI positions per full post-warm-up year after thirteen completed month ends; one consumed attempt per broker month. Exact random-rank qualification density is 562/1001, about 6.737 decisions/year, before market data."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK
r1_reasoning: "Complete-read peer-reviewed monthly WTI trading evidence plus a complete official NIST runs-method page; the exact median-runs trading conjunction remains an untested QM hypothesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, endpoint reconstruction, strict ranks, median omission, six/six balance, run count, inclusive boundary, newest-regime side, consumed attempt, fixed risk, stop, and lifecycle are deterministic and locked."
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered native XTIUSD.DWX D1 history and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, and gap risks remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, comparisons, strict ranks, integer signs/counts, ATR risk controls, and execution state; no trained signal or prohibited runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 completed month ends; omit strict median rank 7; six lows/six highs; inclusive runs<=7; newest nonmedian regime direction; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly median-runs persistence stream outside the directional XAU/SP500/NDX/XNG book. Verify strict rank permutation, unique-median omission, exact six/six balance, chronological post-omission adjacency, inclusive R<=7, newest actual rank direction, median-newest flat state, consumed attempt, fixed-risk stop, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, first_tradable_month_bar, thirteen_consecutive_completed_months, latest_close_per_month, strict_rank_permutation, unique_median_rank_seven, omit_median_without_sign, six_low_six_high_balance, chronological_binary_sequence, exact_run_count_range, inclusive_seven_run_boundary, newest_actual_rank_direction, median_newest_flat, monthly_attempt_state, fixed_risk, hard_stop_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-27 and decisions/2026-08-27_qm5_41182_wti_monthly_median_runs_persistence_trend_g0.md: R1 PASS with complete-read peer-reviewed WTI evidence and the complete official NIST method page; R2 PASS locks endpoints, ranks, median omission, sign balance, run count, threshold, direction, attempt, risk, stop, and lifecycle; R3 PASS registered WTI D1 with continuous-CFD basis risk; R4 PASS deterministic native arithmetic only. The corrected canonical checker returned CLEAN, and fixed rank fixtures separate the function from return-sign runs, Mann-Kendall, Bartels, turning-point, and Spearman WTI neighbors."
---

# QM5_41182 WTI Thirteen-Month Median-Runs Persistence Trend

## Hypothesis

WTI has physical supply/demand, inventory, transport, geopolitical, and
seasonal drivers that differ from the stated XAU, SP500, NDX, and XNG book.
A monthly trend can persist as blocks of price levels above or below its own
formation median even when consecutive return signs alternate and magnitude-
weighted slope measures remain weak.

This card reduces thirteen completed monthly WTI closes to a chronological
six-low/six-high sequence around the unique sample median. It continues the
newest nonmedian regime only when the sequence contains no more runs than the
official expected count of seven. That adds direct crude-oil exposure; it does
not prove profitability, neutrality, or decorrelation. Q02 owns density and
economics, and unchanged Q09 owns overlap.

## Source Traceability And Claim Boundary

The single governed source ID resolves to
`strategy-seeds/sources/MOP-NIST-WTI-MEDRUN-TREND-2026/source.md`, SHA-256
`E1954B72A7E9F45BEA151DC1C18DFDA64C40D543C37CB22CF02E95F268147429`,
authorized by
`decisions/2026-08-27_wti_monthly_median_runs_persistence_trend_source_approval.md`
at commit `2ace42211` before card extraction.

Moskowitz, Ooi, and Pedersen supply monthly WTI continuation lineage. NIST
supplies above/below-median coding, the consecutive-sign run definition, and
the expected-run formula. Neither source tests thirteen WTI CFD endpoints,
the inclusive seven-run gate, newest-regime direction, fixed-dollar risk, or
this lifecycle.

No source alpha, return, probability, significance, density, Sharpe ratio,
drawdown, cost, CFD equivalence, decorrelation, or portfolio statistic is
imported.

## Non-Duplicate Decision

The initial checker invocation failed closed on its obsolete default Wiki
root and authorized nothing. The corrected fail-closed scan explicitly bound
the current Company Reference vault and returned `CLEAN` across 4,681
registry identities, 1,332 card files, and 45 Wiki nodes. Receipt:
`artifacts/qm5_wti_median_runs_tr_preallocation_dedup_20260827.json`, SHA-256
`7740FB213317764F76737EB97638FA3E6F5BCADC08CD8FE124708EAD6D6658B6`.

Manual review fixes distinct state functions:

- `QM5_20273` counts the longest consecutive same-sign monthly returns; this
  card counts every run in levels classified around the formation median.
- `QM5_20264` counts 78 pairwise order signs; this card retains only changes
  between six low and six high regimes after omitting the median.
- `QM5_41170` weights squared adjacent rank jumps; this card discards the
  magnitude of within-half rank movement.
- `QM5_41171` counts local extrema in all prices; this card counts regime
  transitions in a median-dichotomized sequence.
- `QM5_41173` weights time-rank displacement; this card has no time-rank
  displacement statistic.

Rank vector `[10,3,8,5,1,11,7,12,9,13,2,6,4]` sells here at six runs while
Mann-Kendall (`S=0`), Spearman (`T=-8`), return-sign run maxima `(1,2)`,
Bartels (`NM=406`), and turning points (`10`) all stay flat. Vector
`[5,6,9,12,4,8,3,11,2,1,7,13,10]` stays flat here at eight runs while
Bartels and turning-point persistence buy.

Verdict:
`CLEAN_WTI_MONTHLY_MEDIAN_DICHOTOMY_RUNCOUNT_LE7_NEWEST_REGIME_CONTINUATION`.

## Markets, Timeframe, And Cadence

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0.
- Intended magic: `411820000`.
- Decision: first executable D1 tick after a genuine broker-month transition,
  within 180 elapsed minutes of raw current-bar open.
- Formation: thirteen immediately prior consecutive completed broker-month
  endpoints.
- Hold: first later broker month; forty calendar days is stale repair.
- Expected pre-result cadence: five to nine positions/year; Q02 retires below
  five in any full post-warm-up year.

## Formula

For chronological strict ranks `rank[0..12]` of the thirteen closes:

```text
B = [sign(rank[i]-7) for i=0..12 if rank[i] != 7]
require len(B)=12, count(-1)=6, count(+1)=6

R = 1 + count(B[k] != B[k-1], k=1..11)
require 2 <= R <= 12

BUY  iff R <= 7 and rank[12] > 7
SELL iff R <= 7 and rank[12] < 7
FLAT otherwise
```

The median is omitted before adjacency is evaluated. A latest endpoint at
rank seven is flat, even if the twelve-sign sequence has at most seven runs.
For six lows and six highs the official expected-run formula gives seven;
the inclusive boundary is a density choice, not a significance test.

Exact enumeration gives 6,744 qualifying six/six-order-plus-median-position
representations of 12,012, equivalent to 3,496,089,600 of 13! strict rank
paths. The qualification rate is `562/1001 = 0.5614385614385614`, split
equally by side, or about 6.737 opportunities per random-order year. This is
pre-market arithmetic only.

## Rules

- Exact ID, symbol, D1 period, slot, risk/news/Friday contract, and all locked
  strategy inputs are mandatory.
- Consume the broker month before every fallible entry gate.
- Use the latest close in each of exactly thirteen immediately prior
  consecutive broker months. The current month never contributes.
- Reject missing/duplicate months, nonchronological timestamps, stale newest
  endpoint, nonpositive/nonfinite/equal closes, invalid rank permutation,
  missing/duplicated median, wrong six/six balance, or run count outside 2..12.
- Omit rank seven; do not assign it a sign or use it to split a run.
- Trade only the newest actual endpoint's median regime at inclusive `R<=7`.
- Both news axes, legacy news mode, and Friday close remain OFF.

## 4. Entry Rules

1. Require `qm_ea_id=41182`, exact `XTIUSD.DWX`, D1, slot offset zero,
   `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, OFF/NONE news,
   Friday close OFF, and every singleton strategy input.
2. On a genuine new broker month within the 180-minute grace window, write
   `QM5_41182_MONTH_ATTEMPT_<magic>=yyyymm` before history or execution gates.
3. If already consumed, late, or carrying owned exposure, do not enter.
4. Reconstruct exactly thirteen completed month-end closes with strict
   chronology and maximum ten-day newest-endpoint staleness.
5. Assign strict ranks and prove the 1..13 permutation. Omit rank seven,
   produce exactly six `-1` and six `+1` signs, then count chronological runs.
6. Consume flat for `R>7` or newest rank 7. Buy for `R<=7` with newest rank
   above seven; sell for `R<=7` with newest rank below seven.
7. Reject spread above 1,500 points, invalid quotes, invalid completed-bar
   ATR, nonpositive stop distance, invalid volume, or insufficient margin.
8. Submit one market request sized by the V5 risk helper against a frozen
   `3.5*ATR(20,D1)` hard stop. Attach no target and never retry the month.

## 5. Exit Rules

- Close on the first processed tick whose normalized broker month differs
  from the persisted entry month.
- Close after forty elapsed calendar days as stale repair.
- The broker hard stop and framework kill switch remain active.
- No profit target, signal flip, median cross, run recount, trail, break-even,
  partial exit, Friday close, or same-month re-entry is authorized.

## 6. Filters (No-Trade Module)

- Exact symbol/period/EA/slot and locked-input checks fail `OnInit` closed.
- Standard framework kill-switch, weekend/holiday, connection, margin, and
  session protections remain active.
- News temporal mode is OFF, compliance profile is NONE, and legacy news mode
  is OFF because the signal uses no event data.
- Friday close is OFF to preserve the approved month-long lifecycle.
- Entry-only gates never suppress lifecycle repair or mandatory exits.

## 7. Trade Management Rules

- Own at most one slot-zero WTI position with exact symbol and magic.
- Before considering entry, close duplicate, wrong-symbol, wrong-magic,
  wrong-side, invalid-volume, stopless, later-month, or stale owned exposure.
- Recover entry month and expected direction from terminal-global attempt
  state and deal history after restart; ambiguous state closes fail-safe.
- Stop distance and size are frozen at entry. No scale-in, averaging,
  pyramiding, grid, discretionary override, or signal-strength sizing exists.

## Risk Model

All backtest presets use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. One position is sized through the V5 fixed-risk helper
against a frozen `3.5*ATR(20,D1)` hard stop. Signal strength never changes
risk. No live, demo, shadow, stress, or optimization preset is authorized.

Principal risks are WTI gaps, continuous-CFD roll/basis and financing,
monthly formation staleness, median information loss, an inclusive density
boundary with weak selectivity, abrupt regime reversal, hard-stop slippage,
and realized correlation with XNG or risk assets.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK | Complete-read peer-reviewed WTI evidence and complete official NIST runs documentation; exact trading conjunction untested. |
| R2 | PASS | Clock, endpoints, ranks, median omission, balance, run count, threshold, side, attempt, risk, stop, and lifecycle are fixed. |
| R3 | PASS_WITH_CONTINUOUS_CFD_BASIS_RISK | Registered native WTI D1 supplies every runtime input; Q02 owns density, costs, and CFD sufficiency. |
| R4 | PASS | Native deterministic rank and integer arithmetic only; no trained signal, prohibited input, external feed, grid, or martingale. |

## Failure Modes And Kill Criteria

Retire or fail on any of the following:

- fewer than five completed positions in any full post-warm-up Q02 year;
- zero trades, nonpositive governed economics, or any downstream gate failure;
- current-month leakage, missing/duplicate month keys, nonlatest endpoint,
  stale newest endpoint, nonchronological timestamps, or mixed label offsets;
- endpoint count other than 13, accepted tie, invalid strict rank permutation,
  median count other than one, sign count other than six/six, run count outside
  2..12, entry at `R>7`, median-newest entry, or wrong side;
- same-month retry, missing hard stop, wrong risk mode, excessive spread, late
  entry, missed month exit, or nondeterministic output; or
- any post-result rescue change to formation, rank rule, threshold, side,
  risk, stop, hold, symbol, or carrier.

## Falsification And Requalification

Any change to the thirteen-month formation, median rule, omission behavior,
run definition, inclusive threshold, direction, broker-month normalization,
consumed attempt, spread ceiling, risk, stop, or exit clock creates a new
execution contract and requires a new binary, Q02 restart, and full portfolio
requalification. Ambiguity is `BLOCKED`, never filled in by Development.

## Execution And State Contract

- `ea_id=41182`, exact `XTIUSD.DWX`, D1, slot 0, intended magic `411820000`.
- Persist `QM5_41182_MONTH_ATTEMPT_<magic>` before all fallible gates.
- Recover persisted attempt across restarts and reconcile it with entry deals.
- A late restart consumes the new month flat; no catch-up entry.
- Exactly one active magic-registry row and resolver mapping are mandatory
  before compile.
- Logs expose month key, endpoint times, ranks, omitted index, twelve signs,
  low/high counts, run count, newest rank, direction, and state.

## Portfolio Interaction

This candidate adds direct WTI exposure rather than another index, gold, or
natural-gas rule. That is an exposure hypothesis, not a measured correlation
result. Q09 alone may establish overlap with the stated book. No portfolio
gate, manifest, allocation, incumbent, threshold, or waiver changes here.

## Validation Plan

1. Card schema lint and prohibited-token scan.
2. Canonical corrected-root dedup receipt and separating rank fixtures.
3. Pure reference checks for strict ranks, median omission, six/six balance,
   adjacency, run boundaries, latest-median flat, symmetry, ties, invalid
   states, exact density counts, and neighbor separation.
4. Strict MQL5 compile and framework build check.
5. Canonical `RISK_FIXED` XTIUSD.DWX D1 backtest set only.
6. Independent source/card/build alignment review.
7. At most one paced Q02 enqueue below both tester and host-CPU ceilings.
8. Q02 owns activity/economics; later automated gates own robustness and Q09
   overlap. Failure retires the locked candidate.

## Framework Alignment

| Card rule | V5 location |
|---|---|
| Exact host, risk/news/Friday/input locks | no-trade filter and `OnInit` |
| Month transition and durable consumed attempt | decision-clock and terminal-global state helpers |
| Thirteen completed month endpoints | bounded D1 reconstruction helper |
| Strict ranks, median omission, signs, runs, threshold, side | entry signal helper |
| Frozen ATR stop and fixed-risk market request | `Strategy_EntrySignal` plus framework transaction manager |
| Integrity repair, month close, forty-day stop | `Strategy_ManageOpenPosition` |
| No discretionary close signal | `Strategy_ExitSignal` returns false |
| Logging and equity stream | framework hooks on new bar/tick/transaction |

## Safety Boundary

Authorized: one approved card, one registered V5 identity, one non-live source
build, strict Q01 validation, independent review, and at most one paced Q02
enqueue.

Forbidden: manual backtests outside the farm; live/demo/shadow/stress or
optimization setfiles; `T_Live`; AutoTrading; deploy or live manifests;
portfolio-gate edits; portfolio admission; correlation waivers; external
runtime data; terminal control; and claims of profitability, certification,
or decorrelation before governed evidence exists.

## Revision History

| Date | Change |
|---|---|
| 2026-08-27 | Initial source-complete card approved under the OWNER commodity/energy portfolio mission; corrected-root canonical dedup CLEAN; R1-R4 PASS. |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Source Approval | 2026-08-27 | APPROVED_SOURCE | `decisions/2026-08-27_wti_monthly_median_runs_persistence_trend_source_approval.md` |
| G0 Research Intake | 2026-08-27 | APPROVED | `decisions/2026-08-27_qm5_41182_wti_monthly_median_runs_persistence_trend_g0.md` |
| Q01 Build Validation | 2026-08-27 | NOT_BUILT | build pending |
| Q02 Baseline Screening | 2026-08-27 | NOT_ENQUEUED_Q01_PENDING | compile and Q01 pending |
