---
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_QTRVOTE12_S21
variant_id: MOP-TSMOM-2012_XTI_QTRVOTE12_S21
source_id: MOP-WTI-QTRVOTE-2026
ea_id: QM5_20272
slug: wti-qtrvote-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20272_wti-qtrvote-tr_card.md
execution_contract_status: DRAFT
created: 2026-08-10
created_by: Research+Development
last_updated: 2026-08-10
g0_status: APPROVED
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI https://doi.org/10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded extraction strategy-seeds/sources/MOP-WTI-QTRVOTE-2026/source.md"
    quality_tier: A
    role: primary_own_price_direction_and_monthly_cadence
strategy_mechanic: monthly-wti-four-nonoverlapping-quarter-return-three-of-four-sign-consensus
sources:
  - "[[sources/MOP-WTI-QTRVOTE-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/path-consensus]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-quarter-return]]"
  - "[[indicators/month-end-close]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, quarterly-block-consensus, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 202720000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately twelve monthly WTI decisions/year after thirteen completed month ends, less non-consensus months; Q02 must prove at least five completed positions/year or retire."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED
review_focus: "Falsify a direct WTI monthly path-consensus trend based on four disjoint quarterly blocks, distinct from nested cumulative votes, adjacent-month sign counts, regressions, ranks, and robust return averages; Q09 alone may establish realized book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [completed_month_reconstruction, chronological_log_return_orientation, exact_nonoverlapping_block_boundaries, neutral_zero_treatment, strict_three_of_four_threshold, monthly_attempt_state, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-10_qm5_20272_wti_qtrvote_tr_g0.md: R1 complete-read peer-reviewed WTI source; R2 fixed thirteen month ends, four disjoint three-month log returns, exact signs, neutral zeros, strict three-of-four vote, and lifecycle; R3 registered WTI D1 route; R4 deterministic native arithmetic. No exact dedup identity; expected shared-source cumulative-vote fuzzy neighbors and adjacent-sign/regression/rank/robust-average mechanics were manually resolved."
---

# QM5_20272 WTI Quarterly-Block Consensus Trend

## Hypothesis

WTI can sustain slow directional regimes as production, investment,
inventories, transport, refining, hedging, and demand adjust. A single
twelve-month endpoint return can be dominated by one interval. Requiring at
least three of four non-overlapping quarterly blocks to share a sign tests
whether direction persisted through most of the prior year rather than
arriving in one isolated move.

The direct crude-oil carrier is economically different from the certified
XAU, SP500, NDX, and XNG book. That does not prove decorrelation,
profitability, or portfolio suitability. Q02 owns density and baseline
economics; unchanged downstream gates, including Q09, own robustness and
realized overlap.

## Source Traceability And Claim Boundary

The sole source of record is the governed bounded packet
`strategy-seeds/sources/MOP-WTI-QTRVOTE-2026/source.md`. Its complete-read
parent is Moskowitz, Ooi, and Pedersen (2012), a peer-reviewed *Journal of
Financial Economics* paper documenting monthly own-return continuation over
the first twelve lags and including WTI among its commodity futures.

The source does not use a four-block sign-consensus estimator. The partition,
strict vote, Darwinex continuous CFD, broker-month reconstruction,
fixed-dollar sizing, ATR hard stop, spread cap, attempt ledger, and lifecycle
controls are transparent QM mechanizations. No source return, alpha, Sharpe
ratio, drawdown, WTI-specific result, trade count, cost, CFD equivalence, or
correlation statistic is imported.

## Non-Duplicate Decision

The canonical checker scanned 4,332 EA-registry rows and 445 cards. It found
no exact identity and two expected same-paper fuzzy hits. Manual mechanic
review resolves the closest systems:

- `QM5_20258_wti-mom-vote` votes nested cumulative one-, three-, and
  twelve-month returns, all ending at the newest month end; this card votes
  four non-overlapping three-month intervals that partition the prior year;
- `QM5_13150_wti-signmom` and `QM5_20244_wti-trend-sign` count or combine
  adjacent one-month signs, giving each month an individual vote rather than
  requiring quarter-block persistence;
- one-, two-, three-, six-, nine-, and twelve-month WTI TSMOM uses one
  cumulative formation return;
- `QM5_20261`, `QM5_20264`, and `QM5_20271` use OLS, all-pairs ordinal, and
  all-pairs median-slope estimators over price levels; and
- `QM5_20269` and `QM5_20270` sort twelve adjacent returns and aggregate their
  magnitudes by a median or trimmed mean.

None partitions the prior year at exact month indexes `0,3,6,9,12`, maps each
disjoint block only to a sign, treats zeros as neutral, and requires three of
four signs. Endpoint count, boundaries, orientation, zero rule, vote threshold,
symmetric mapping, consumed attempt, and renewal lifecycle are jointly
load-bearing. Verdict:
`CLEAN_AFTER_EXPECTED_SHARED_SOURCE_FUZZY_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1; magic slot 0; intended magic `202720000`.
- Decision clock: first processed D1 bar after a genuine broker-month change.
- Formation: thirteen consecutive completed broker-month closes forming four
  chronological, disjoint three-month log returns.
- Holding clock: next broker-month boundary, with a forty-calendar-day stale
  guard.
- Expected cadence: approximately ten completed positions per full post-
  warm-up year; retire below five.
- Runtime data: native MT5 D1 time/close, ATR, spread, quote, position, deal,
  broker calendar, and contract metadata only.

## Formula

At the start of month `t`, let `C[0]..C[12]` be completed month-end closes from
months `t-13..t-1`, ordered oldest to newest. Define:

```text
q[0] = ln(C[3]  / C[0])
q[1] = ln(C[6]  / C[3])
q[2] = ln(C[9]  / C[6])
q[3] = ln(C[12] / C[9])

positive_count = count(q[k] > 0)
negative_count = count(q[k] < 0)
```

BUY when `positive_count >= 3`; SELL when `negative_count >= 3`. A tie, fewer
than three signs in either direction, exact-zero block, malformed,
nonconsecutive, unavailable, or nonfinite state consumes the month flat.
Return magnitude does not scale risk.

## Rules

These are the complete authorized baseline. There is no signal-parameter sweep
and no fallback to a cumulative return, nested-horizon vote, adjacent-return
sign count, mean, median, trimmed mean, regression, rank statistic, moving
average, oscillator, calendar direction, external series, or previous pipeline
result.

## 4. Entry Rules

1. Require exact EA ID `20272`, `XTIUSD.DWX` D1, magic slot 0, and every
   baseline input locked to its declared value.
2. Process lifecycle exits before entry-only gates and evaluate only at a
   genuine broker-month transition.
3. Persist the current month as consumed before history, signal, spread,
   quote, news, stop, sizing, or order checks. A flat, rejected, failed,
   stopped, or blocked outcome cannot retry that month.
4. Reject owned exposure or any same-month entry deal for the magic.
5. Reconstruct exactly thirteen completed month-end closes from bounded D1
   history. Require the newest endpoint to be the immediately prior month and
   every older month key to be consecutive.
6. Keep endpoints oldest to newest; require positive finite closes and
   strictly increasing timestamps.
7. Calculate exactly four finite log returns from boundary pairs `(0,3)`,
   `(3,6)`, `(6,9)`, and `(9,12)`. No other pairing or overlap is allowed.
8. Count strict positive and negative returns. Buy only with at least three
   positives; sell only with at least three negatives. Zeros are neutral and
   all non-consensus states remain flat for the consumed month.
9. Require spread in `[0,1500]` points, executable quote, completed
   `ATR(20,D1)`, valid point/digit/volume metadata, and valid fixed-risk sizing.
10. Open at most one market position with a frozen `3.5 * ATR(20,D1)` broker
    hard stop and no take-profit.

## 5. Exit Rules

1. Close the prior position on the first processed D1 bar of every new broker
   month before considering replacement risk, even if the new direction is
   unchanged.
2. Close after forty elapsed calendar days as a stale guard.
3. Close duplicate, wrong-symbol, invalid-type, or missing-stop exposure owned
   by this EA's magic.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the source-aligned hold spans weekends.
6. No intramonth signal flip, profit target, trail, break-even, partial close,
   scale-in, grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbol, timeframe, EA ID, magic slot, fixed risk,
  news/Friday contract, or locked strategy inputs.
- Reject a consumed attempt, owned exposure, same-month entry history,
  malformed or nonconsecutive endpoints, current-month leakage, nonpositive
  or nonfinite close, wrong boundary pair, invalid logarithm, a non-consensus
  vote, excessive spread, invalid quote, unavailable ATR, invalid stop, or
  invalid volume metadata.
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
  position and deal history; tester initialization clears a future/prior-run
  marker so historical runs remain deterministic.
- Lifecycle repair closes duplicate, wrong-symbol, invalid-type, or missing-
  stop exposure before any new entry logic.
- No randomness, adaptive fitting, external state, partial close, scale-in,
  grid, martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_endpoint_count` | 13 | [13] | completed month-end observations |
| `strategy_block_months` | 3 | [3] | non-overlapping return width |
| `strategy_consensus_required` | 3 | [3] | strict same-sign blocks required |
| `strategy_history_bars_d1` | 800 | [800] | bounded D1 endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen broker hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

The endpoint count, block width and boundaries, log orientation, zero rule,
consensus threshold, direction, entry clock, risk, stop, hold, and no-retry
policy are locked. Changing any of them requires a new card and full pipeline
run.

## Author Claims

Moskowitz, Ooi, and Pedersen document time-series momentum across liquid
futures, report continuation across the first twelve monthly lags, and identify
WTI in their commodity universe. They do not claim that this four-block vote
works, that a continuous CFD reproduces rolling futures, or that the candidate
diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: WTI gaps, CFD roll/basis and financing,
single-name concentration, slow state reversal, hard-stop slippage, and
correlation with XNG or risk assets can dominate the premise. Shared boundary
endpoints make neighboring quarterly returns path-connected, and sign
consensus discards magnitude. It is a descriptive formation statistic, not a
confidence guarantee.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full post-
  warm-up year.
- Fail on wrong endpoint order, nonconsecutive months, current-month leakage,
  wrong block pairs, overlapping intervals, wrong log orientation, wrong zero
  treatment or vote threshold, wrong-side entry, repeated monthly attempt,
  hold beyond forty days, missing hard stop, invalid risk mode, or
  nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing lookback, partition, threshold, direction,
  entry clock, stop, hold, spread cap, retry policy, or carrier.

## Strategy Allowability Check

- [x] R1: PASS. One tier-A peer-reviewed source with DOI, complete-paper
  evidence, durable retrieval hash, and explicit WTI membership.
- [x] R2: PASS. Fixed endpoints, exact block returns and vote, direction,
  attempt, hard stop, rollover, and stale exit.
- [x] R3: PASS. Registered `XTIUSD.DWX` D1 plus native V5 execution state only.
- [x] R4: PASS. Deterministic logarithm, sign counting, calendar, and ATR
  arithmetic; no trained model, prohibited signal indicator, external feed,
  grid, or martingale.
- [x] Dedup: no exact identity; expected cumulative-vote fuzzy neighbors and
  adjacent-sign/regression/rank/robust-average systems were manually resolved.

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, fixed risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: month-attempt persistence, endpoint reconstruction, exact four
  block returns and strict sign vote, spread/quote/ATR/stop checks, and one
  fixed-risk order.
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
| v1 | 2026-08-10 | initial source-bounded WTI quarterly-block consensus card | G0 | APPROVED |
| v1-q01 | 2026-08-10 | deterministic V5 build, strict compile, and target build validation | Q01 | PASS |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-10 | APPROVED | `decisions/2026-08-10_qm5_20272_wti_qtrvote_tr_g0.md` |
| Q01 Build Validation | 2026-08-10 | PASS | `D:/QM/reports/compile/20260810_153630/summary.csv`; `D:/QM/reports/framework/21/build_check_20260810_153630.json`; `D:/QM/reports/pipeline/QM5_20272/P1/P1_QM5_20272_result.json` |
| Q02 Baseline Screening | - | NOT ENQUEUED | - |
