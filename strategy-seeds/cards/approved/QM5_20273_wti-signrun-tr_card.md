---
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_SIGNRUN12_S22
variant_id: MOP-TSMOM-2012_XTI_SIGNRUN12_S22
source_id: MOP-WTI-SIGNRUN-2026
ea_id: QM5_20273
slug: wti-signrun-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20273_wti-signrun-tr_card.md
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
    location: "DOI https://doi.org/10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded extraction strategy-seeds/sources/MOP-WTI-SIGNRUN-2026/source.md"
    quality_tier: A
    role: primary_own_price_direction_and_monthly_cadence
strategy_mechanic: monthly-wti-prior-twelve-adjacent-return-dominant-longest-four-sign-run-trend
sources:
  - "[[sources/MOP-WTI-SIGNRUN-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/path-persistence]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-return-sign]]"
  - "[[indicators/longest-sign-run]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, longest-sign-run, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 202730000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately six monthly WTI packages/year after thirteen completed month ends under an independent-sign reference process; Q02 must prove at least five completed positions/year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
q01_status: NOT_RUN
q02_status: NOT_ENQUEUED
review_focus: "Falsify a direct WTI monthly path-persistence trend based on the unique longest same-sign run among twelve chronological returns, distinct from cumulative returns, unordered sign breadth, fixed quarter votes, regressions, ranks, and robust return averages; Q09 alone may establish realized book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [completed_month_reconstruction, chronological_log_return_orientation, exact_zero_run_reset, longest_run_update, strict_four_month_threshold, unique_direction_tie_rule, monthly_attempt_state, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-10_qm5_20273_wti_signrun_tr_g0.md: R1 complete-read peer-reviewed WTI source; R2 fixed thirteen month ends, twelve adjacent log returns, exact signs, zero resets, longest-run state, strict four-month and unique-direction rules, and lifecycle; R3 registered WTI D1 route; R4 deterministic native arithmetic. The deterministic checker returned CLEAN and manual review separated cumulative-return, sign-count, fixed-block-vote, regression/rank, and robust-average mechanics."
---

# QM5_20273 WTI Dominant Sign-Run Trend

## Hypothesis

WTI can sustain slow directional regimes as production, investment,
inventories, transport, refining, hedging, and demand adjust. A cumulative
twelve-month return can be dominated by one shock, while an unordered sign
count ignores whether like-signed months occur consecutively. A uniquely
dominant same-sign run of at least four months tests whether the prior-year
path contains a sustained directional episode rather than scattered votes.

The direct crude-oil carrier is economically different from the certified
XAU, SP500, NDX, and XNG book. That does not prove decorrelation,
profitability, or portfolio suitability. Q02 owns density and baseline
economics; unchanged downstream gates, including Q09, own robustness and
realized overlap.

## Source Traceability And Claim Boundary

The sole source of record is the governed bounded packet
`strategy-seeds/sources/MOP-WTI-SIGNRUN-2026/source.md`. Its complete-read
parent is Moskowitz, Ooi, and Pedersen (2012), a peer-reviewed *Journal of
Financial Economics* paper documenting monthly own-return continuation over
the first twelve lags and including WTI among its commodity futures.

The source does not use a longest-sign-run estimator. The run scan, four-month
threshold, strict tie rule, Darwinex continuous CFD, broker-month
reconstruction, fixed-dollar sizing, ATR hard stop, spread cap, attempt ledger,
and lifecycle controls are transparent QM mechanizations. No source return,
alpha, Sharpe ratio, drawdown, WTI-specific result, trade count, cost, CFD
equivalence, or correlation statistic is imported.

## Non-Duplicate Decision

The canonical checker scanned 4,333 EA-registry rows and 446 cards. It found no
exact identity and no fuzzy match above threshold. Manual mechanic review
resolves the closest systems:

- pure one-, two-, three-, six-, nine-, and twelve-month WTI TSMOM uses one
  cumulative formation return;
- `QM5_13150_wti-signmom` and `QM5_20244_wti-trend-sign` count positive and
  negative months without retaining adjacency or a longest-run statistic;
- `QM5_20258_wti-mom-vote` votes nested cumulative one-, three-, and
  twelve-month returns, all ending at the newest endpoint;
- `QM5_20272_wti-qtrvote-tr` votes four fixed non-overlapping three-month
  blocks rather than finding a variable-location adjacent-month run;
- `QM5_20261`, `QM5_20264`, and `QM5_20271` use OLS, all-pairs ordinal, and
  all-pairs median-slope estimators over price levels; and
- `QM5_20269` and `QM5_20270` sort twelve adjacent returns and aggregate their
  magnitudes by a median or trimmed mean, losing chronology.

None scans the twelve chronological adjacent signs, resets both runs on zero,
retains the maximum run by direction, requires a four-month minimum, and stays
flat when the directional maxima tie. Endpoint count, orientation, zero rule,
run update, threshold, tie rule, symmetric mapping, consumed attempt, and
renewal lifecycle are jointly load-bearing. Verdict: `CLEAN`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1; magic slot 0; intended magic `202730000`.
- Decision clock: first processed D1 bar after a genuine broker-month change.
- Formation: thirteen consecutive completed broker-month closes forming
  twelve chronological adjacent monthly log returns.
- Signal state: the unique longest positive or negative run, with a locked
  minimum length of four and exact-zero resets.
- Holding clock: next broker-month boundary, with a forty-calendar-day stale
  guard.
- Expected cadence: about six positions per full post-warm-up year under the
  enumerated independent-sign reference; retire below five observed positions.
- Runtime data: native MT5 D1 time/close, ATR, spread, quote, position, deal,
  broker calendar, and contract metadata only.

## Formula

At the start of month `t`, let `C[0]..C[12]` be completed month-end closes from
months `t-13..t-1`, ordered oldest to newest. Define:

```text
r[i] = ln(C[i+1] / C[i]), i = 0..11

positive: current_positive += 1; current_negative = 0
negative: current_negative += 1; current_positive = 0
zero:     current_positive = 0; current_negative = 0

L+ = max(current_positive) across the chronological scan
L- = max(current_negative) across the chronological scan
```

BUY when `L+ >= 4` and `L+ > L-`. SELL when `L- >= 4` and `L- > L+`.
Anything else, including an equal longest run or an exact-zero interruption,
consumes the month flat. Return magnitude and run location do not scale risk.

## Rules

These are the complete authorized baseline. There is no signal-parameter sweep
and no fallback to a cumulative return, nested-horizon vote, unordered sign
count, fixed quarterly block vote, mean, median, trimmed mean, regression, rank
statistic, moving average, oscillator, calendar direction, external series, or
previous pipeline result.

## 4. Entry Rules

1. Require exact EA ID `20273`, `XTIUSD.DWX` D1, magic slot 0, and every
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
   through `(11,12)` in chronological order. No reverse or skipped pair is
   allowed.
8. Update positive and negative run counters exactly as declared, resetting
   both on zero, and retain both directional maxima.
9. Buy only when the positive maximum is at least four and strictly greater
   than the negative maximum. Sell only under the symmetric negative rule.
   Equal maxima and all below-threshold states remain flat for the consumed
   month.
10. Require spread in `[0,1500]` points, executable quote, completed
    `ATR(20,D1)`, valid point/digit/volume metadata, and valid fixed-risk
    sizing.
11. Open at most one market position with a frozen `3.5 * ATR(20,D1)` broker
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
  or nonfinite close, wrong adjacent pair or orientation, invalid logarithm,
  bad run state, a below-threshold or tied maximum, excessive spread, invalid
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
| `strategy_endpoint_count` | 13 | [13] | completed month-end observations |
| `strategy_min_run_months` | 4 | [4] | minimum unique longest sign run |
| `strategy_history_bars_d1` | 800 | [800] | bounded D1 endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen broker hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

The endpoint count, adjacent-pair definition, chronological orientation, exact
zero reset, longest-run update, threshold, unique-direction tie rule,
direction, entry clock, risk, stop, hold, and no-retry policy are locked.
Changing any of them requires a new card and full pipeline run.

## Author Claims

Moskowitz, Ooi, and Pedersen document time-series momentum across liquid
futures, report continuation across the first twelve monthly lags, and identify
WTI in their commodity universe. They do not claim that this longest-run rule
works, that a continuous CFD reproduces rolling futures, or that the candidate
diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: WTI gaps, CFD roll/basis and financing,
single-name concentration, stale historical runs, hard-stop slippage, and
correlation with XNG or risk assets can dominate the premise. Longest-run
selection discards return magnitude and location and can remain unchanged as
the window rolls. It is a descriptive path statistic, not a confidence
guarantee.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full post-
  warm-up year.
- Fail on wrong endpoint order, nonconsecutive months, current-month leakage,
  wrong adjacent pairs or log orientation, wrong zero reset, wrong run update,
  wrong four-month threshold, taking a tied state, wrong-side entry, repeated
  monthly attempt, hold beyond forty days, missing hard stop, invalid risk
  mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing lookback, run definition, threshold, tie
  rule, direction, entry clock, stop, hold, spread cap, retry policy, or
  carrier.

## Strategy Allowability Check

- [x] R1: PASS. One tier-A peer-reviewed source with DOI, complete-paper
  evidence, durable retrieval hash, and explicit WTI membership.
- [x] R2: PASS. Fixed endpoints, adjacent returns, chronological run scan,
  zero resets, threshold, tie rule, direction, attempt, hard stop, rollover,
  and stale exit.
- [x] R3: PASS. Registered `XTIUSD.DWX` D1 plus native V5 execution state only.
- [x] R4: PASS. Deterministic logarithm, sign comparison, counters, calendar,
  and ATR arithmetic; no trained model, prohibited signal indicator, external
  feed, grid, or martingale.
- [x] Dedup: deterministic checker CLEAN; cumulative-return, sign-count,
  fixed-block-vote, regression/rank, and robust-average systems were manually
  resolved.

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, fixed risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: month-attempt persistence, endpoint reconstruction, exact
  adjacent returns and chronological run scan, spread/quote/ATR/stop checks,
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
| v1 | 2026-08-10 | initial source-bounded WTI dominant sign-run card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-10 | APPROVED | `decisions/2026-08-10_qm5_20273_wti_signrun_tr_g0.md` |
| Q01 Build Validation | pending | NOT_RUN | pending |
| Q02 Baseline Screening | pending | NOT_ENQUEUED | pending |
