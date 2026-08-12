---
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_TRIMEAN12_S31
variant_id: MOP-TSMOM-2012_XTI_TRIMEAN12_S31
source_id: MOP-WTI-TRIMEAN-2026
ea_id: QM5_20283
slug: wti-trimean-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20283_wti-trimean-mom_card.md
execution_contract_status: DRAFT
created: 2026-08-11
created_by: Research+Development
last_updated: 2026-08-11
g0_status: APPROVED
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI https://doi.org/10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded extraction strategy-seeds/sources/MOP-WTI-TRIMEAN-2026/source.md"
    quality_tier: A
    role: primary_own_price_direction_and_monthly_cadence
strategy_mechanic: monthly-wti-sign-of-tukey-trimean-of-twelve-completed-monthly-log-returns
sources:
  - "[[sources/MOP-WTI-TRIMEAN-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/robust-return-location]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/quartile-trimean]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, robust-location, order-statistics, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 202830000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eleven to twelve monthly WTI packages/year after thirteen completed month ends because only exact-zero or invalid trimean states stay flat; Q02 must prove at least five completed positions/year or retire."
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
review_focus: "Falsify a direct WTI monthly robust trend whose fixed quartile-trimean functional differs from cumulative, raw-median, middle-eight trim, fixed-tail Winsor, MAD-cap, pairwise-pseudomedian, sign-vote/run, recency-weighted, slope, rank, regression, and path-efficiency estimators; Q09 alone may establish realized book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [completed_month_reconstruction, chronological_log_return_orientation, ascending_sort, even_half_quartile_indexes, one_two_one_weights, divisor_four, monthly_attempt_state, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-11_qm5_20283_wti_trimean_mom_g0.md: R1 one complete-read peer-reviewed WTI source; R2 fixed thirteen endpoints, twelve adjacent returns, sort, quartile/median indexes, 1:2:1 weights, divisor, direction, and lifecycle; R3 registered WTI D1 route; R4 deterministic native arithmetic. The canonical checker found no exact identity and manual review separated four expected robust/weighted-return neighbors."
---

# QM5_20283 WTI Quartile-Trimean Return Trend

## Hypothesis

WTI can sustain slow directional regimes as production, investment,
inventories, transport, refining, hedging, and demand adjust. A cumulative
twelve-month return can be dominated by one shock, while the raw median uses
only the center pair and a conventional trimmed mean gives every retained
observation equal influence. This card summarizes twelve separate completed
monthly returns with a fixed quartile trimean: the center receives half the
total weight and the two quartiles split the other half.

The direct crude-oil carrier is economically different from the certified
XAU, SP500, NDX, and XNG book. That does not prove decorrelation,
profitability, or portfolio suitability. Q02 owns density and baseline
economics; unchanged downstream gates, including Q09, own robustness and
realized overlap.

## Source Traceability And Claim Boundary

The sole source of record is the governed bounded packet
`strategy-seeds/sources/MOP-WTI-TRIMEAN-2026/source.md`. Its complete-read
parent is Moskowitz, Ooi, and Pedersen (2012), a peer-reviewed *Journal of
Financial Economics* paper documenting monthly own-return continuation over
the first twelve lags and including WTI among its commodity futures.

The source does not use a quartile trimean. The statistic, exact index
convention, Darwinex continuous CFD, broker-month reconstruction, fixed-dollar
sizing, ATR hard stop, spread cap, attempt ledger, and lifecycle controls are
transparent QM mechanizations. No source return, alpha, Sharpe ratio,
drawdown, WTI-specific result, trade count, cost, CFD equivalence, or
correlation statistic is imported.

## Non-Duplicate Decision

The canonical checker scanned 4,348 EA-registry rows and 459 cards. It found
no exact identity and surfaced four expected same-source fuzzy matches. Manual
mechanic review resolves the closest systems:

- `QM5_20269_wti-medret-mom` uses only sorted indexes 5 and 6;
- `QM5_20270_wti-trimmean-mom` equally averages sorted indexes 2 through 9;
- `QM5_20277_wti-winsor-mom` replaces two observations in each tail and then
  equally averages all twelve terms;
- `QM5_20278_wti-linw-mom` weights unsorted returns by chronology; and
- cumulative, MAD-cap, pairwise-pseudomedian, sign/vote, rank/regression,
  slope, calendar, event, and path-efficiency systems estimate different
  functionals or state objects.

This rule ignores sorted indexes 0, 1, 4, 7, 10, and 11; weights indexes 2, 3,
8, and 9 by `1/8`; and weights indexes 5 and 6 by `1/4`. The sort, exact
indexes, `1:2:1` aggregation, divisor four, exact-zero rejection, consumed
attempt, and monthly renewal are jointly load-bearing. Verdict:
`CLEAN_AFTER_ROBUST_LOCATION_FUZZY_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1; magic slot 0; intended magic `202830000`.
- Decision clock: first processed D1 bar after a genuine broker-month change.
- Formation: thirteen consecutive completed broker-month closes forming
  twelve chronological adjacent monthly log returns.
- Signal state: sign of the fixed quartile trimean of those twelve returns.
- Holding clock: next broker-month boundary, with a forty-calendar-day stale
  guard.
- Expected cadence: eleven to twelve positions per full post-warm-up year;
  retire below five observed positions.
- Runtime data: native MT5 D1 time/close, ATR, spread, quote, position, deal,
  broker calendar, and contract metadata only.

## Formula

At the start of month `t`, let `C[0]..C[12]` be completed month-end closes from
months `t-13..t-1`, ordered oldest to newest:

```text
r[i] = ln(C[i+1] / C[i]), i = 0..11
s = sort_ascending(r)
Q1 = (s[2] + s[3]) / 2
M  = (s[5] + s[6]) / 2
Q3 = (s[8] + s[9]) / 2
T  = (Q1 + 2 * M + Q3) / 4
```

BUY when `T > 0`. SELL when `T < 0`. An exact-zero or invalid statistic
remains flat. The statistic's magnitude never scales risk.

## Rules

These are the complete authorized baseline. There is no signal-parameter
sweep and no fallback to a cumulative return, arithmetic mean, raw median,
middle-eight trimmed mean, fixed-tail Winsorized mean, MAD cap, pairwise
pseudomedian, sign statistic, vote, regression, rank statistic, moving
average, oscillator, calendar direction, external series, or previous
pipeline result.

## 4. Entry Rules

1. Require exact EA ID `20283`, `XTIUSD.DWX` D1, magic slot 0, and every
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
7. Calculate exactly twelve finite adjacent log returns from pairs `(0,1)`
   through `(11,12)` in chronological order.
8. Sort a copy ascending. Set `Q1=(s[2]+s[3])/2`,
   `M=(s[5]+s[6])/2`, and `Q3=(s[8]+s[9])/2` using zero-based indexes.
9. Set `T=(Q1+2*M+Q3)/4`. Buy when positive and sell when negative; exact
   zero remains flat. Do not interpolate, reuse another observation, or
   change an index, weight, or divisor.
10. Require spread in `[0,1500]` points, executable quote, completed
    `ATR(20,D1)`, valid point/digit/volume metadata, and valid fixed-risk
    sizing.
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
6. No intramonth signal flip, profit target, trail, break-even, partial close,
   scale-in, grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbol, timeframe, EA ID, magic slot, fixed risk,
  news/Friday contract, or locked strategy inputs.
- Reject a consumed attempt, owned exposure, same-month entry history,
  malformed or nonconsecutive endpoints, current-month leakage, nonpositive
  or nonfinite close, wrong adjacent pair or orientation, invalid logarithm,
  wrong sort, index, weight, divisor, zero signal, excessive spread, invalid
  quote, unavailable ATR, invalid stop, or invalid volume metadata.
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
| `strategy_return_months` | 12 | [12] | adjacent completed monthly log returns |
| `strategy_history_bars_d1` | 800 | [800] | bounded D1 endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen broker hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

The endpoint/return counts, adjacent-pair definition, return orientation,
sort, quartile/median indexes, `1:2:1` weights, divisor, direction, entry
clock, risk, stop, hold, and no-retry policy are locked. Changing any requires
a new card and full pipeline run.

## Author Claims

Moskowitz, Ooi, and Pedersen document time-series momentum across liquid
futures, report continuation across the first twelve monthly lags, and identify
WTI in their commodity universe. They do not claim this quartile-trimean
estimator works, that a continuous CFD reproduces rolling futures, or that the
candidate diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: WTI gaps, CFD roll/basis and financing,
single-name concentration, stale historical trends, hard-stop slippage,
quartile instability in a twelve-observation sample, and correlation with XNG
or risk assets can dominate the premise. Robust location is descriptive and
does not guarantee stable edge or neutrality.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full post-
  warm-up year.
- Fail on wrong endpoint order, nonconsecutive months, current-month leakage,
  wrong adjacent pairs or log orientation, wrong sort or selected indexes,
  wrong weights or divisor, fallback after exact zero, wrong-side entry,
  repeated monthly attempt, hold beyond forty days, missing hard stop, invalid
  risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing horizon, estimator, index convention,
  weights, direction, entry clock, stop, hold, spread cap, retry policy, or
  carrier.

## Strategy Allowability Check

- [x] R1: PASS. One tier-A peer-reviewed source with DOI, complete-paper
  evidence, durable retrieval hash, and explicit WTI membership.
- [x] R2: PASS. Fixed endpoints, returns, sort, quartile/median indexes,
  weights, divisor, direction, attempt, hard stop, rollover, and stale exit.
- [x] R3: PASS. Registered `XTIUSD.DWX` D1 plus native V5 execution state only.
- [x] R4: PASS. Deterministic logarithm, sorting, weighted arithmetic,
  calendar, and ATR arithmetic; no trained model, prohibited signal indicator,
  external feed, grid, or martingale.
- [x] Dedup: no exact identity; median, middle-eight trim, fixed-tail Winsor,
  weighted, cumulative, MAD-cap, sign/vote, rank/regression, slope, and path-
  efficiency systems were manually resolved.

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, fixed risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: month-attempt persistence, endpoint reconstruction, adjacent
  returns, sort, fixed quartile-trimean, spread/quote/ATR/stop checks, and one
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
| v1 | 2026-08-11 | initial source-bounded WTI quartile-trimean return card | G0 | APPROVED |
| v1-q01 | 2026-08-11 | deterministic V5 build, strict compile, target validation, quartile-trimean reference vectors, and P1 artifact validation | Q01 | PASS |
| v1-q02 | 2026-08-11 | one paced current-binary WTI handoff below the factory CPU ceiling | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-11 | APPROVED | `decisions/2026-08-11_qm5_20283_wti_trimean_mom_g0.md` |
| Q01 Build Validation | 2026-08-11 | PASS | `D:/QM/reports/compile/20260811_185111/summary.csv`; `D:/QM/reports/framework/21/build_check_20260811_184440.json`; `D:/QM/reports/pipeline/QM5_20283/P1/P1_QM5_20283_result.json` |
| Q02 Baseline Screening | 2026-08-11 | ENQUEUED; pending at immediate readback, attempt 0, no verdict | work item `2db5b53c-82d0-4856-a2b8-83f99307bce9`; `docs/ops/evidence/2026-08-11_qm5_20283_wti_trimean_mom_q01_q02_enqueue.md` |
