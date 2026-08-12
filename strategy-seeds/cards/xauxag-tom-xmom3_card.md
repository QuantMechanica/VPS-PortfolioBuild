---
card_schema_version: 2
type: strategy
strategy_id: VANHEMERT-FMR-XAUXAG-TOMXMOM3-2026_S01
variant_id: VANHEMERT-FMR-XAUXAG-TOMXMOM3-2026_S01
source_id: VANHEMERT-FMR-XAUXAG-TOMXMOM3-2026
ea_id: QM5_20243
slug: xauxag-tom-xmom3
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20243_xauxag-tom-xmom3_card.md
execution_contract_status: DRAFT
created: 2026-08-06
created_by: Research+Development
last_updated: 2026-08-06
g0_status: APPROVED
source_authors: "Otto van Hemert; Ana-Maria Fuertes; Joelle Miffre; Georgios Rallis"
source_citation: "van Hemert (2014), SSRN 2515900; Fuertes, Miffre, and Rallis (2010), Journal of Banking & Finance 34(10), 2530-2548."
source_citations:
  - type: working_paper
    citation: "van Hemert, O. (2014). The MOM-TOM Effect: Detecting the Market Impact of CTA Trading."
    location: "SSRN https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2515900; governed packet strategy-seeds/sources/VANHEMERT-MOMTOM-2014/source.md"
    quality_tier: A-
    role: turn_of_month_flow_window
  - type: peer_reviewed_paper
    citation: "Fuertes, A.-M., Miffre, J., and Rallis, G. (2010). Tactical Allocation in Commodity Futures Markets: Combining Momentum and Term Structure Signals. Journal of Banking & Finance 34(10), 2530-2548."
    location: "DOI https://doi.org/10.1016/j.jbankfin.2010.04.009; complete governed packet strategy-seeds/sources/FMR-MOMTS-2010/source.md"
    quality_tier: A
    role: three_month_cross_sectional_momentum
strategy_mechanic: three-date-turn-of-month-cycle-frozen-three-completed-month-average-return-rank-xau-xag-two-leg-basket
sources:
  - "[[sources/VANHEMERT-FMR-XAUXAG-TOMXMOM3-2026]]"
concepts:
  - "[[concepts/turn-of-month]]"
  - "[[concepts/cross-sectional-commodity-momentum]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/completed-month-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, precious-metals, turn-of-month, cta-flow, cross-sectional-momentum, market-neutral-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_20243_XAU_XAG_TOM_XMOM3_D1
symbol: QM5_20243_XAU_XAG_TOM_XMOM3_D1
period: D1
timeframe: D1
expected_trade_frequency: "One two-leg package in each broker-calendar TOM cycle when synchronized history and execution gates pass; approximately 8-12 packages/year before Q02 validation."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED_CPU_CEILING
review_focus: "Falsify a source-bounded XAU/XAG relative-momentum package only during the CTA turn-of-month flow window; no source efficacy, neutrality, or book decorrelation transfers."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [tom_calendar_translation, cycle_frozen_signal, synchronized_month_ends, basket_atomicity, aggregate_fixed_risk, restart_attempt_state, magic_schema, cfd_futures_basis, narrow_cross_section, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-06_qm5_20243_xauxag_tom_xmom3_g0.md: R1 peer-reviewed complete-read commodity momentum plus governed public MOM-TOM lineage; R2 locked three-date cycle, synchronized three-month rank, shared risk, hard stops, persisted attempt, window exit, and repair; R3 registered XAU/XAG D1 basket route; R4 native deterministic arithmetic only. Exact dedup clean; expected one/three/twelve-month fuzzy siblings manually separated by the load-bearing TOM-only exposure and frozen pre-cycle signal."
---

# QM5_20243 XAU/XAG Turn-Of-Month Three-Month Momentum Basket

## Hypothesis

Trend-following CTA inflows can concentrate price pressure around month end.
Commodity winners and losers can separately exhibit medium-horizon relative
continuation. Holding a gold/silver winner-minus-loser package only during the
three-date turn-of-month window may isolate that flow-timing interaction while
suppressing much of the common USD and precious-metal direction in the
existing book.

The package is market-neutral only in the limited sense that it always owns
opposite XAU and XAG directions and splits hard-stop risk equally. It is not
proof of dollar, notional, beta, volatility, factor, or portfolio neutrality.
Q02 owns density and economics; Q09 alone owns realized correlation.

## Source Traceability And Claim Boundary

The governed composite packet is
`strategy-seeds/sources/VANHEMERT-FMR-XAUXAG-TOMXMOM3-2026/source.md`.
Van Hemert supplies the last-two/first-one turn-of-month flow hypothesis.
Fuertes, Miffre, and Rallis supply the source-declared three-month commodity
cross-sectional average-return rank.

Neither source tests this intersection, a two-metal cross-section, a cycle-
frozen signal, Darwinex CFDs, broker-date translation, fixed-dollar risk, ATR
stops, costs, financing, or this book. No source PF, return, drawdown, Sharpe,
trade-count, neutrality, or correlation claim transfers.

## Non-Duplicate Decision

The deterministic pre-allocation checker found no exact identity and only
three expected fuzzy XAU/XAG momentum siblings. Manual review resolves them:

- `QM5_20184_xauxag-xmom3` forms the three-month rank at a month boundary and
  holds for the entire following month. This EA freezes the rank before the
  cycle, holds only the last-two/first-one TOM dates, and is otherwise flat.
- `QM5_20057` and `QM5_20050` use one- and twelve-month ranks and full-month
  holds.
- Ratio, residual, quantile, breakout, weekend, weekday, same-calendar,
  skewness, expected-shortfall, and volatility-of-volatility XAU/XAG baskets
  use different information objects or decision clocks.
- WTI, XNG, and Brent TOM EAs are outright time-series systems, not an
  opposite-direction precious-metals rank.

The TOM-only exposure, signal frozen before the cycle, three-month average
rank, and atomic two-leg package are jointly load-bearing. A month-long hold is
prohibited because it recreates `QM5_20184`. Verdict:
`CLEAN_AFTER_EXPECTED_FUZZY_AND_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Logical basket: `QM5_20243_XAU_XAG_TOM_XMOM3_D1`.
- Host/slot 0: `XAUUSD.DWX`, D1, magic `202430000`.
- Companion/slot 1: `XAGUSD.DWX`, D1, magic `202430001`.
- Entry window: last two calendar dates of a cycle month and first calendar
  date of the next month.
- Formation: four synchronized completed month-end observations ending the
  month before the cycle, producing exactly three simple monthly returns per
  leg.
- Exit: first processed D1 bar outside the same cycle or six-calendar-day
  stale guard.
- Expected cadence: approximately 8-12 complete packages/year; retire below
  five/year after warm-up.

## Formula

For a cycle keyed to month `t`, let `C_i[0]` be the close of month `t-1` and
`C_i[1..3]` the three preceding synchronized month-end closes for leg `i`:

```text
r_i[k] = C_i[k] / C_i[k+1] - 1,  k = 0..2
avg3_i = (r_i[0] + r_i[1] + r_i[2]) / 3
```

- `avg3_XAU > avg3_XAG`: BUY XAU and SELL XAG.
- `avg3_XAU < avg3_XAG`: SELL XAU and BUY XAG.
- Difference within `1e-10`, missing/nonconsecutive endpoints, timestamp
  mismatch, nonpositive close, or invalid arithmetic: consume the cycle flat.

Ending formation at `t-1` keeps the signal identical whether the first
tradable TOM bar arrives before or just after the month boundary. There is no
ratio, z-score, regression, oscillator, moving average, breakout, external
series, trained state, or PnL-adaptive rule.

## Rules

The following is the complete frozen Q02 baseline. No window, horizon,
direction, endpoint, carrier, retry, stop, or hold sweep is authorized.

## 4. Entry Rules

1. Require exact EA ID `20243`, XAU D1 host, slot 0, and every strategy input
   locked to the declared baseline.
2. Evaluate only on a new host D1 bar whose broker date is one of the last two
   dates of a month or the first date of the next month. Map all three dates to
   one cycle key.
3. Persist the cycle attempt before history, signal, spread, quote, news,
   stop, risk, or order gates. A flat, blocked, rejected, stopped, partial, or
   restarted cycle cannot retry.
4. Reject any owned leg or entry deal already mapped to the same cycle.
5. Reconstruct four exact completed month ends for both legs, ending at the
   month immediately before the cycle month. Require consecutive keys and
   matching endpoint timestamps across XAU and XAG.
6. Compute exactly three simple monthly returns and their arithmetic average
   for each leg. Require the absolute difference above `1e-10`.
7. Buy the higher-average-return metal and sell the lower.
8. Require acceptable spreads, valid executable quotes, completed ATR(20),
   registered magics, and valid volume/contract metadata.
9. Split one package `RISK_FIXED` budget equally between the two
   ATR-normalized legs. Attach a frozen `3.5 * ATR(20,D1)` hard stop to each;
   there is no take-profit.
10. Open XAU then XAG. Keep the package only if exactly one correctly directed
    stopped position exists in each slot. On any failure, flatten all owned
    legs immediately.

## 5. Exit Rules

1. Close both legs on the first processed D1 bar outside the entry package's
   TOM cycle.
2. Close both legs after six elapsed calendar days as a stale guard.
3. Immediately flatten an orphan, duplicate, wrong-symbol, same-direction,
   wrong-magic, or missing-stop package.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the source window may span a month-end
   weekend.
6. No take-profit, trailing stop, break-even, partial close, scale-in, grid,
   martingale, pyramid, signal flip, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside `XAUUSD.DWX` D1 slot 0 or if any fixed strategy input is
  changed.
- Require synchronized, consecutive target-month endpoints and sufficient
  bounded D1 history on both legs.
- Require spreads in `[0,1500]` XAU points and `[0,3000]` XAG points.
- Require valid ATR, executable quotes, volume steps, contract metadata,
  magic rows, attempt state, and package state.
- Both news axes, legacy news, stress rejection, and Friday close are locked
  OFF in Q02. Runtime reads no external calendar, file, API, futures curve,
  volume, open interest, CTA holdings, analyst input, or trained output.

## 7. Trade Management Rules

The EA may own exactly two opposite-direction positions: XAU slot 0 and XAG
slot 1. One shared fixed budget is divided equally by stop risk; `RISK_FIXED`
is not applied independently to each full leg. Package composition is checked
every tick and invalid or partial state is flattened. There is at most one
attempted package per TOM cycle.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_tom_pre_days` | 2 | [2] | final calendar dates in cycle month |
| `strategy_tom_post_days` | 1 | [1] | first calendar date after month end |
| `strategy_return_window_months` | 3 | [3] | source formation horizon |
| `strategy_history_bars` | 500 | [500] | bounded endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | [20] | completed-bar stop volatility |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen per-leg hard-stop distance |
| `strategy_max_hold_days` | 6 | [6] | stale TOM package guard |
| `strategy_xau_max_spread_pts` | 1500 | [1500] | XAU entry spread ceiling |
| `strategy_xag_max_spread_pts` | 3000 | [3000] | XAG entry spread ceiling |
| `strategy_deviation_points` | 20 | [20] | order deviation |

## Risk And Kill Criteria

The canonical Q02 setfile uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both legs share that one budget equally. Q02 evaluates
the logical basket, never the legs as standalone strategies.

Retire below five complete packages/year, on nonpositive governed economics,
nondeterminism, wrong-cycle exposure, intracycle signal drift, mismatched
endpoints, repeated attempts, orphan persistence, aggregate-risk breach,
wrong magic/direction, or downstream correlation rejection. Financing,
legging, lot granularity, CFD basis, calendar-date proxy error, common-metal
beta, industrial-silver beta, and the two-name translation are binding risks.
Do not rescue failure by changing any frozen input or carrier.

## Strategy Allowability Check

- [x] R1: peer-reviewed JBF commodity-momentum source with DOI and complete
  manuscript review, plus named-author public SSRN MOM-TOM lineage.
- [x] R2: fixed TOM dates, synchronized three-month rank, direction, shared
  risk, hard stops, attempt state, window exit, and repair.
- [x] R3: registered XAUUSD.DWX and XAGUSD.DWX D1 routes with logical-basket
  tester support.
- [x] R4: deterministic native calendar/OHLC/ATR arithmetic only; no banned
  indicator, ML, external runtime feed, grid, martingale, or pyramiding.
- [x] Dedup: no exact identity; expected momentum siblings manually resolved
  by mutually exclusive lifecycle and signal-freeze rules.

## Framework Alignment

- no_trade: exact host/timeframe/slot, frozen inputs, history, spread, symbol,
  magic, package, and attempt guards.
- trade_entry: TOM cycle map, synchronized three-return rank, opposite orders,
  shared fixed-risk sizing, hard stops, and atomic repair.
- trade_management: same-cycle validation, window exit, stale exit, and orphan
  cleanup.
- trade_close: framework close helper, broker hard stops, and kill switch.

## Safety Boundary

This card authorizes branch-only research, deterministic allocation, strict
compile, one `RISK_FIXED` logical-basket setfile, one basket manifest, and one
paced Q02 enqueue. It does not authorize a manual backtest; live, demo,
shadow, optimization, or stress setfile; AutoTrading; `T_Live`; deploy or
T_Live manifest; portfolio admission; portfolio-gate change; or correlation
waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-06 | initial source-bounded XAU/XAG MOM-TOM basket | G0 | APPROVED |
| v1 | 2026-08-06 | V5 implementation and fixed-risk logical-basket set | Q01 | PASS: strict compile/build 0 errors, warnings, failures, or build warnings |
| v1 | 2026-08-06 | paced Q02 capacity preflight | Q01 | READY; Q02 NOT_ENQUEUED_CPU_CEILING at 9/7 exact factory terminals |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-06 | APPROVED | `decisions/2026-08-06_qm5_20243_xauxag_tom_xmom3_g0.md` |
| Q01 Build Validation | 2026-08-06 | PASS | strict compile `D:/QM/reports/compile/20260806_075246/summary.csv`; build check `D:/QM/reports/framework/21/build_check_20260806_075246.json` |
| Q02 Baseline Screening | 2026-08-06 | NOT_ENQUEUED_CPU_CEILING | `docs/ops/evidence/2026-08-06_qm5_20243_xauxag_tom_xmom3_q01_cpu_stop.md` |
