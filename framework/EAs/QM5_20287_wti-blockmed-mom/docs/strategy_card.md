---
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_BLOCKMED12_S35
variant_id: MOP-TSMOM-2012_XTI_BLOCKMED12_S35
source_id: MOP-WTI-BLOCKMED-2026
ea_id: QM5_20287
slug: wti-blockmed-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20287_wti-blockmed-mom_card.md
execution_contract_status: DRAFT
created: 2026-08-12
created_by: Research+Development
last_updated: 2026-08-12
g0_status: APPROVED
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI https://doi.org/10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded extraction strategy-seeds/sources/MOP-WTI-BLOCKMED-2026/source.md"
    quality_tier: A
    role: primary_own_price_direction_and_monthly_cadence
strategy_mechanic: monthly-wti-even-median-of-four-chronological-three-month-mean-return-blocks
sources:
  - "[[sources/MOP-WTI-BLOCKMED-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/median-of-block-means]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/chronological-block-mean]]"
  - "[[indicators/atr]]"
strategy_type_flags: [atr-hard-stop, time-stop, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 202870000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eleven to twelve monthly WTI packages/year after thirteen completed month ends because only exact-zero or invalid block states stay flat; Q02 must prove at least five completed positions/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02_ENQUEUED
q01_status: PASS
q02_status: ENQUEUED
review_focus: "Falsify a direct WTI monthly trend whose even median of four chronological three-month mean-return blocks retains magnitude and resolves two-versus-two block splits, unlike sign consensus, raw-return median, trimmed-mean, cumulative, and iterative robust-location neighbors; Q09 alone may establish realized book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [completed_month_reconstruction, chronological_log_return_orientation, fixed_nonoverlapping_blocks, even_block_median, monthly_attempt_state, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 one complete-read peer-reviewed WTI source; R2 exact endpoints, four fixed three-return blocks, even block median, direction and lifecycle; R3 registered WTI D1 route; R4 deterministic native arithmetic with no trained output or prohibited signal indicator; canonical and manual dedup clean."
---

# QM5_20287 WTI Chronological Block Median-of-Means Trend

## Hypothesis

WTI can sustain slow directional regimes as production, capital investment,
inventories, transport, refining, hedging, and demand adjust. A cumulative
twelve-month return can be dominated by one oil shock, while a raw median of
twelve monthly returns discards their medium-horizon sequence. This card tests
whether the central direction of four consecutive three-month mean-return
blocks provides a more robust slow-trend state while retaining block magnitude.

The direct crude-oil carrier is economically different from the certified
XAU, SP500, NDX, and XNG book. That does not prove decorrelation,
profitability, or portfolio suitability. Q02 owns density and baseline
economics; unchanged downstream gates, including Q09, own robustness and
realized overlap.

## Source Traceability And Claim Boundary

The single trading source of record is the governed bounded packet
`strategy-seeds/sources/MOP-WTI-BLOCKMED-2026/source.md`. Its complete-read
parent is Moskowitz, Ooi, and Pedersen (2012), a peer-reviewed *Journal of
Financial Economics* paper documenting monthly own-return continuation over
the first twelve lags and including WTI among its commodity futures.

The block statistic is a transparent QM robust-aggregation hypothesis. The
paper does not test it. The block partition, even-median convention, Darwinex
continuous CFD, broker-month reconstruction, fixed-dollar sizing, ATR hard
stop, spread cap, attempt ledger, and lifecycle controls are QM
mechanizations. No source return, alpha, drawdown, WTI-specific result, trade
count, cost, CFD equivalence, or correlation statistic is imported.

## Non-Duplicate Decision

The canonical checker scanned 4,352 EA-registry rows and 464 root cards. It
found no exact identity and no fuzzy match above threshold. Manual family
review separated the closest neighbors:

- `QM5_20272_wti-qtrvote-tr` uses four non-overlapping three-month endpoint
  returns but requires at least three blocks of the same sign. It consumes
  every two-positive/two-negative split flat. This card retains block
  magnitude and resolves that split from the average of the two inner sorted
  block means.
- `QM5_20269_wti-medret-mom` sorts twelve individual monthly returns and
  averages indexes 5 and 6. It does not form or retain chronological blocks.
- `QM5_20270_wti-trimmean-mom` deletes two individual monthly returns per tail
  and averages the remaining eight. It does not form or select block means.
- Cap, Winsor, cumulative, sign/run/vote, iterative robust-location,
  recency-weighted, regression, rank, path-efficiency, and skip-month systems
  use different functionals or endpoint objects.

The four fixed chronological blocks, exact width three, equal within-block
magnitude weights, sorting of block means only, even median from indexes 1 and
2, and nonzero two-versus-two resolution are jointly load-bearing. Verdict:
`CLEAN_AFTER_MANUAL_BLOCK_NEIGHBOR_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1; magic slot 0; intended magic `202870000`.
- Decision clock: first processed D1 bar after a genuine broker-month change.
- Formation: thirteen consecutive completed broker-month closes forming
  twelve chronological adjacent monthly log returns.
- Aggregation: four non-overlapping chronological blocks of three returns;
  even median of the four block arithmetic means.
- Holding clock: next broker-month boundary, with a forty-calendar-day guard.
- Expected cadence: eleven to twelve positions per full post-warm-up year;
  retire below five observed positions.
- Runtime data: native MT5 D1 time/close, ATR, spread, quote, position, deal,
  broker calendar, and contract metadata only.

## Formula

At the start of month `t`, let `C[0]..C[12]` be completed month-end closes
from months `t-13..t-1`, ordered oldest to newest:

```text
r[i] = ln(C[i+1] / C[i]), i = 0..11
b[j] = (r[3j] + r[3j+1] + r[3j+2]) / 3, j = 0..3
s = sort_ascending(b)
block_median = (s[1] + s[2]) / 2
```

BUY when `block_median > 0`. SELL when `block_median < 0`. An exact-zero or
invalid state remains flat. The statistic's magnitude never scales risk.

## Rules

These are the complete authorized baseline. There is no signal-parameter
sweep and no fallback to a cumulative return, raw-return median, trimmed mean,
Winsorized mean, capped mean, quartile statistic, pseudomedian, robust
iteration, sign vote, regression, rank score, moving average, oscillator,
calendar direction, external series, or previous pipeline result.

## 4. Entry Rules

1. Require exact EA ID `20287`, `XTIUSD.DWX` D1, magic slot 0, and every
   baseline input locked to its declared value.
2. Process lifecycle exits before entry-only gates and evaluate only at a
   genuine broker-month transition.
3. Persist the current month as consumed before history, signal, spread,
   quote, news, stop, sizing, or order checks. No outcome may retry that month.
4. Reject owned exposure or any same-month entry deal for the magic.
5. Reconstruct exactly thirteen completed month-end closes from bounded D1
   history; require the newest endpoint to be the immediately prior month and
   every older month key to be consecutive.
6. Keep endpoints oldest to newest; require positive finite closes and
   strictly increasing timestamps. Compute exactly twelve adjacent finite log
   returns from pairs `(0,1)` through `(11,12)`.
7. Form exactly four chronological non-overlapping blocks. Block zero contains
   returns 0-2, block one 3-5, block two 6-8, and block three 9-11. Divide
   each block sum by exactly three.
8. Sort only a copy of the four block means. Set the even block median to the
   arithmetic mean of sorted zero-based indexes 1 and 2. Do not convert block
   means to signs.
9. Buy when the block median is positive and sell when negative; exact zero
   stays flat. No alternate center or fallback is allowed.
10. Require spread in `[0,1500]` points, executable quote, completed
    `ATR(20,D1)`, valid point/digit/volume metadata, and fixed-risk sizing.
11. Open at most one market position with a frozen `3.5 * ATR(20,D1)` broker
    hard stop and no take-profit.

## 5. Exit Rules

1. Close the prior position on the first processed D1 bar of every new broker
   month before considering replacement risk, even if direction is unchanged.
2. Close after forty elapsed calendar days as a stale guard.
3. Close duplicate, wrong-symbol, invalid-type, or missing-stop exposure owned
   by this EA's magic.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the source-aligned hold spans weekends.
6. No intramonth signal flip, target, trail, break-even, partial close,
   scale-in, grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbol, timeframe, EA ID, slot, fixed risk,
  news/Friday contract, or locked strategy inputs.
- Reject a consumed attempt, owned exposure, same-month entry history,
  malformed or nonconsecutive endpoints, current-month leakage, nonpositive
  close, invalid return, wrong block membership/count/width/divisor, sorting
  individual returns, wrong even-median indexes, exact-zero signal, excessive
  spread, invalid quote, unavailable ATR, invalid stop, or invalid metadata.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  run before entry-only gates.
- Runtime may not read a futures chain, inventory release, volume, open
  interest, file, API, analyst forecast, trained output, optimizer result, or
  portfolio state.

## 7. Trade Management Rules

- Maintain at most one WTI position and one consumed attempt per broker month.
- Preserve the original hard stop; close before monthly renewal or after forty
  calendar days.
- Restart recovery combines a terminal-persistent month marker with owned
  position and deal history; tester initialization clears a prior-run marker
  so historical runs remain deterministic.
- Lifecycle repair closes duplicate, wrong-symbol, invalid-type, or missing-
  stop exposure before any new entry logic.
- No randomness, adaptive fitting, external state, partial close, scale-in,
  grid, martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_return_months` | 12 | [12] | adjacent completed monthly returns |
| `strategy_block_months` | 3 | [3] | returns per chronological block |
| `strategy_block_count` | 4 | [4] | fixed non-overlapping block count |
| `strategy_history_bars_d1` | 800 | [800] | bounded D1 endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen broker hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

All values and the endpoint/return counts, block membership, block arithmetic,
sort target, median convention, direction, entry clock, risk, stop, hold, and
no-retry policy are locked. Any change requires a new card and pipeline.

## Author Claims

Moskowitz, Ooi, and Pedersen document time-series momentum across liquid
futures, report continuation across the first twelve monthly lags, and identify
WTI in their commodity universe. They do not claim this exact block estimator
works, that a continuous CFD reproduces rolling futures, or that the candidate
diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: WTI gaps, CFD roll/basis and financing,
single-name concentration, stale historical trends, hard-stop slippage, small-
sample block instability, arbitrary calendar partition sensitivity, and
correlation with XNG or risk assets can dominate the premise. Robust block
aggregation does not guarantee edge or neutrality.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full post-
  warm-up year.
- Fail on wrong endpoint order, nonconsecutive months, current-month leakage,
  wrong adjacent pairs or orientation, overlapping or reordered blocks, block
  count other than four, block width/divisor other than three, sorting raw
  returns instead of block means, wrong even-median indexes, sign-only voting,
  exact-zero fallback, wrong-side entry, repeated attempt, hold beyond forty
  days, missing hard stop, invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing horizon, block layout, estimator,
  direction, entry clock, stop, hold, spread, retry, or carrier.

## Strategy Allowability Check

| gate | verdict | reasoning |
|---|---|---|
| R1 | PASS | One canonical Tier-A peer-reviewed trading source with DOI, complete-paper evidence, durable retrieval hash, and explicit WTI membership. |
| R2 | PASS | Fixed endpoints, returns, block partition, arithmetic means, even median, direction, attempt, hard stop, rollover, and stale exit. |
| R3 | PASS | Registered `XTIUSD.DWX` D1 plus native V5 execution state only. |
| R4 | PASS | Deterministic logarithm, addition, division, and sorting; no trained model, prohibited signal indicator, external feed, grid, or martingale. |

- [x] Dedup: no exact or fuzzy identity; quarterly sign-vote, raw-return median,
  trimmed-mean, and other WTI neighbors were manually resolved.

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, fixed risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: month-attempt persistence, endpoint reconstruction, adjacent
  returns, fixed block means, even block median, spread/quote/ATR/stop checks,
  and one fixed-risk order.
- trade_management: malformed-state repair, prior-month exit, and stale exit
  before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes only research, deterministic allocation, build, strict
compile/Q01, and one non-live paced Q02 handoff. It does not authorize a manual
backtest; live, demo, shadow, optimization, or stress setfile; AutoTrading;
`T_Live`; deploy or T_Live manifest; portfolio admission; portfolio-gate edit;
or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-12 | initial source-bounded WTI chronological block-median card | G0 | APPROVED |
| v1-q01 | 2026-08-12 | deterministic V5 build, strict compile, target validation, and block-statistic reference vectors | Q01 | PASS |
| v1-q02 | 2026-08-12 | one paced current-binary WTI handoff below the factory CPU ceiling | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-12 | APPROVED | `decisions/2026-08-12_qm5_20287_wti_blockmed_mom_g0.md` |
| Q01 Build Validation | 2026-08-12 | PASS | `D:/QM/reports/compile/20260812_041650/summary.csv`; `D:/QM/reports/framework/21/build_check_20260812_041650.json`; `D:/QM/reports/pipeline/QM5_20287/P1/P1_QM5_20287_result.json` |
| Q02 Baseline Screening | 2026-08-12 | ENQUEUED; pending at immediate readback, attempt 0, no verdict | work item `1e04556a-44ce-4eca-8c19-d8e9d3f9c7ee`; `docs/ops/evidence/2026-08-12_qm5_20287_wti_blockmed_mom_q01_q02_enqueue.md` |
