---
card_schema_version: 2
ea_id: QM5_20136
slug: wti-caltrend
type: strategy
strategy_id: KELOHARJU-MOP-WTI-CALTREND-2026_S01
source_id: KELOHARJU-MOP-WTI-CALTREND-2026
status: APPROVED
g0_status: APPROVED
created: 2026-07-25
created_by: Research+Development
last_updated: 2026-07-25
symbol: XTIUSD.DWX
timeframe: D1
variant_id: KELOHARJU-MOP-WTI-CALTREND-2026_S01
execution_contract_ref: strategy-seeds/cards/approved/QM5_20136_wti-caltrend_card.md
execution_contract_status: APPROVED
source_citations:
  - type: peer_reviewed_paper
    citation: "Keloharju, Matti; Linnainmaa, Juhani T.; and Nyberg, Peter (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590."
    location: "Commodity construction in Sections 5.4.3-5.6 and Tables 8-9; DOI https://doi.org/10.1111/jofi.12398; complete NBER version https://www.nber.org/papers/w20815"
    quality_tier: A
    role: seasonal_state
  - type: peer_reviewed_paper
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI https://doi.org/10.1016/j.jfineco.2011.11.003; governed AQR/JFE source packet strategy-seeds/sources/MOP-TSMOM-2012"
    quality_tier: A
    role: trend_state
strategy_type_flags: [calendar-seasonality, same-calendar-month, time-series-momentum, agreement-filter, symmetric-long-short, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
period: D1
primary_target_symbols: [XTIUSD.DWX]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
expected_trade_frequency: "Monthly WTI decision after a five-year same-calendar warm-up; only matching seasonal and 63-D1 trend signs trade, with approximately 5-8 packages/year before Q02 validation."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: PENDING
q02_work_item_id: 1dc49254-5e14-401c-b2cb-440d98817ff4
review_focus: "Falsify whether the predeclared agreement of recurring WTI calendar state and completed 63-D1 trend clears the five-package/year floor and costs; no profitability or book-correlation claim is imported."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency, friday_close, risk_mode_dual, long_history_warmup, cfd_futures_basis, conjunction_sparsity, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity/energy sleeve mission: R1 PASS two peer-reviewed governed source lineages; R2 PASS locked prior-year same-calendar average sign AND completed 63-D1 return sign, monthly renewal, ATR stop, stale exit, and restart-safe attempt state; R3 PASS registered XTIUSD.DWX D1; R4 PASS deterministic native MT5 data only with no ML, banned indicator, external feed, grid, martingale, scale-in, or pyramiding. Deterministic dedup CLEAN across 4,193 registry rows and 376 cards plus manual parent/neighbor resolution."
---

# QM5_20136 WTI Same-Calendar Trend Agreement

## Hypothesis

Recurring physical-demand, storage, hedging, and capital-allocation pressures
can make WTI's return sign differ by calendar month. Medium-horizon commodity
trend can separately persist as shocks diffuse. Trading only when WTI's
historical same-calendar-month sign agrees with its completed 63-D1 trend sign
may isolate a slower crude-oil state whose information clock differs from the
certified XAU, SP500, NDX, and XNG book.

This is a falsifiable interaction hypothesis, not a profitability,
decorrelation, or portfolio-admission claim. Q02 must establish basic economics
and frequency; the unchanged downstream portfolio gate alone may measure
realized overlap.

## Source Traceability

The approved composite packet
`strategy-seeds/sources/KELOHARJU-MOP-WTI-CALTREND-2026/source.md` preserves
both governed peer-reviewed parent lineages.

Keloharju, Linnainmaa, and Nyberg supply the recurring same-calendar-month
return state and explicitly include crude oil in their commodity universe.
Moskowitz, Ooi, and Pedersen supply the instrument-own trailing-return-sign
trend state. Neither source tests their conjunction, a single continuous
Darwinex CFD, fixed-risk monthly renewal, an ATR stop, or QM portfolio
behavior. Those are explicit QM hypotheses.

No external source is read at runtime. The EA uses registered `XTIUSD.DWX` D1
OHLC, ATR, broker calendar, executable quotes, spread, positions, deal
history, and V5 framework state only.

## Source-defined Rules

- Recurring seasonal information is measured from returns in the same
  calendar month of prior years.
- Trend direction is the sign of the instrument's own completed trailing
  return.
- Both source states use completed price history and deterministic long/short
  direction.

The papers do not define this interaction's stop, CFD carrier, retry behavior,
or QM risk budget.

## QM Interpretations

Variant `KELOHARJU-MOP-WTI-CALTREND-2026_S01` locks:

- ten prior same-calendar years with at least five valid samples;
- arithmetic mean of completed same-month log returns;
- a completed 63-D1 log-return trend state;
- entry only when both nonzero signs agree;
- monthly close-before-renew, a frozen `3.5 * ATR(20)` stop, 35-day stale
  guard, 1,500-point spread cap, and one consumed attempt per broker month;
- native CFD data only; and
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, backtest execution.

Changing either estimator, agreement rule, horizon, stop, cadence, symbol, or
retry policy creates a new strategy.

## Non-Duplicate Decision

The deterministic pre-allocation check scanned 4,193 EA-registry rows and 376
research cards and returned `CLEAN` for slug `wti-caltrend`, strategy ID
`KELOHARJU-MOP-WTI-CALTREND-2026_S01`, and the full mechanic fingerprint.

Manual semantic review resolved the closest systems:

- `QM5_20099_wti-samecal` trades the seasonal state alone.
- `QM5_20055_wti-tsmom3m` trades the 63-D1 trend state alone.
- `QM5_20135_wti-winter-trend` uses a hard-coded November-May window and a
  252-D1 trend; it never estimates prior matching-calendar returns.
- `QM5_13115_energy-samecal` ranks WTI against XNG in a two-leg basket.
- `QM5_12576_eia-wti-season` uses fixed demand months, SMA(84), and 21-D1 ROC.
- `QM5_12983_wti-tom-mom` trades only a turn-of-month timing window.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback.

The load-bearing new state is the agreement of an adaptive historical
same-calendar WTI sign and the completed 63-D1 WTI trend sign. Removing either
state recreates a built parent mechanic. Realized correlation remains unknown.

## Markets, Timeframe, And Cadence

- Host and target: exact `XTIUSD.DWX`.
- Timeframe: D1.
- Magic slot: 0; allocated magic `201360000`.
- Decision clock: first tradable D1 bar of each broker month.
- Formation: up to ten prior returns for the decision calendar month, minimum
  five, plus the completed 63-D1 return.
- Expected cadence: approximately 5-8 packages/year after warm-up. Q02 retires
  the carrier below five completed packages/year.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Rules

The following rules are the complete authorized baseline. No parameter sweep,
post-result threshold, or favorable-month selection is authorized.

## 4. Entry Rules

1. Require exact `XTIUSD.DWX`, D1, magic slot 0, and every baseline strategy,
   news, and Friday-close input locked to the values below.
2. Evaluate only on the first tradable D1 bar of a new broker month.
3. Close an older package before the new entry. If that close is incomplete,
   consume the month and remain flat.
4. Before history, signal, spread, quote, stop, news, or order gates, persist
   the broker `YYYYMM` as consumed. A rejection, restart, stop, or blocked gate
   cannot retry that month.
5. Reject when an entry deal or EA-owned position already exists for the
   current broker month.
6. Reconstruct WTI's completed log return for the decision calendar month in
   each of the prior ten years. Require at least five valid samples and take
   their arithmetic mean.
7. Read completed D1 closes at shifts 1 and 64 and compute
   `ln(Close[1] / Close[64])`.
8. Buy only when the seasonal mean and 63-D1 return are both strictly
   positive. Sell only when both are strictly negative.
9. Stay flat for sign disagreement, exact-zero state, nonfinite arithmetic,
   insufficient history, or unavailable data.
10. Require completed D1 ATR(20), a non-negative spread no greater than 1,500
    points, and a valid executable market price.
11. Attach a frozen hard stop `3.5 * ATR(20)` from the executable entry price,
    normalized through V5 stop rules. There is no take-profit.

## 5. Exit Rules

1. Close an EA-owned package at the first D1 bar of the next broker month
   before evaluating a replacement.
2. Close after 35 elapsed calendar days as a stale-position guard.
3. The frozen broker hard stop remains active throughout the package.
4. Framework kill-switch closures remain authoritative.
5. Friday close is deliberately disabled because the source-aligned package
   spans weekends.

Lifecycle exits run before entry-only news handling. A blocked renewal must
not leave the prior month's package open.

## 6. Filters (No-Trade Module)

- Fail closed for the wrong symbol, timeframe, slot, unlocked input, invalid
  month key, missing D1 history, fewer than five same-month samples,
  non-positive close, invalid logarithm, sign disagreement, unavailable ATR,
  negative/excess spread, invalid quote, invalid normalized stop, consumed
  month, same-month deal, or owned position.
- Lock the news temporal and compliance axes OFF for Q02. No external calendar
  dependency is needed for the monthly structural signal.
- Require `qm_friday_close_enabled=false`.
- Runtime may not read a futures curve, inventory, COT, refinery, EIA, OPEC,
  volume, open interest, CSV, API, analyst forecast, or other external signal.

## 7. Trade Management Rules

- One position for magic `201360000` and one consumed decision per broker
  month.
- Close-before-renew on every monthly boundary.
- Maintain the original server-side stop; never trail or move it.
- No profit target, partial close, break-even move, retry, scale-in, reversal
  inside a month, grid, martingale, pyramid, random path, adaptive fit, or
  discretionary override.
- Restart recovery uses a terminal-persistent consumed-month marker plus
  position/deal history. Future-dated stale marker state is cleared at
  initialization for deterministic historical runs.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_history_years` | 10 | [10] | bounded prior same-month window |
| `strategy_min_history_years` | 5 | [5] | source-aligned minimum samples |
| `strategy_history_bars` | 3000 | [3000] | D1 reconstruction buffer |
| `strategy_momentum_lookback_d1` | 63 | [63] | completed medium-horizon trend |
| `strategy_min_abs_return_pct` | 0.0 | [0.0] | strict sign; no fitted deadband |
| `strategy_atr_period` | 20 | [20] | completed D1 risk estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 35 | [35] | stale guard around monthly renewal |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

There is no baseline parameter sweep. Both source states are jointly
load-bearing.

## Framework Execution Overrides

- News temporal mode: OFF.
- News compliance profile: NONE.
- Legacy news mode: OFF.
- Friday close: disabled.
- Framework kill switch and broker hard stop: authoritative.
- Forced session flatten: none.

## Exit Precedence

1. Framework kill switch and broker hard stop.
2. New broker-month close-before-renew.
3. 35-calendar-day stale close.
4. No discretionary or signal-reversal exit inside the month.

## Runtime Data Dependencies

- Chart and signal timeframe: exact `XTIUSD.DWX`, D1.
- Additional symbols: none.
- Data: native tester OHLC, quotes, ATR helper, spread, symbol metadata,
  positions, deals, and broker calendar.
- DST: no wall-clock event; broker month keys define the decision boundary.
- External calendars or finite datasets: none.
- Tester account currency: framework-owned; fixed USD risk contract.

## Author Claims

The Keloharju paper supports recurring same-calendar information in a broad
commodity cross-section. The MOP paper supports own-return trend across
futures. Neither claims that this interaction, this CFD carrier, these risk
controls, or this portfolio objective is profitable.

No source return, hit rate, profit factor, drawdown, trade count, or
correlation estimate is imported as a QM expectation.

## Risk

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. WTI gaps, continuous-CFD roll/basis, financing, limited
same-month samples, source-sample decay, sign instability, and conjunction
sparsity are first-order kill risks.

Retire on zero trades or fewer than five completed packages/year after warm-up.
Fail on look-ahead, direction without sign agreement, duplicate same-month
entry, hold beyond 35 days, missing hard stop, invalid risk mode,
nondeterminism, or any governed PF/DD failure. Do not rescue failure by
changing the lookbacks, estimator, threshold, agreement rule, stop, hold,
spread cap, retry policy, or risk mode after results.

Later gates must reject the sleeve if its realized return stream does not
diversify the certified book. No correlation waiver is authorized.

## Strategy Allowability Check

- [x] R1: two peer-reviewed named-author source lineages with durable,
  completely reviewed repository packets.
- [x] R2: fixed same-calendar estimator, completed 63-D1 sign, agreement rule,
  monthly attempt state, hard stop, and stale exit.
- [x] R3: registered `XTIUSD.DWX` D1 history route and native V5 data only.
- [x] R4: deterministic calendar/OHLC/ATR arithmetic; no ML, banned indicator,
  external signal, grid, martingale, scale-in, or pyramiding.
- [x] Dedup: deterministic CLEAN plus manual parent/neighbor differentiation.

## Framework Alignment

- no_trade: exact host/D1/slot, locked-input, history, arithmetic, agreement,
  spread, quote, stop, consumed-month, and owned-position guards.
- trade_entry: monthly seasonal/trend agreement, symmetric direction, and
  frozen ATR stop.
- trade_management: close at next month or 35-day stale boundary before
  entry-only news handling.
- trade_close: framework position close plus broker hard stop and kill switch.

## Falsification And Requalification

Any change to the seasonal sample, minimum history, trend lookback, sign
threshold, agreement rule, entry clock, stop, stale limit, spread cap, retry
state, symbol, timeframe, or risk mode requires a new binary and full pipeline
requalification. Ambiguous history or state must fail closed.

## Safety Boundary

This approval covers one card, deterministic registries, EA build, strict
compile, one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It does
not authorize a live setfile, AutoTrading, `T_Live`, a deploy or T_Live
manifest, portfolio admission, a portfolio-gate change, portfolio KPIs, or a
correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-25 | initial source-backed WTI calendar/trend agreement card | G0 | APPROVED |
| v1 | 2026-07-25 | strict compile and targeted build validation complete | Q01 | PASS |
| v1 | 2026-07-25 | paced baseline handoff; no manual backtest launched | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-25 | APPROVED | this card |
| Q01 Build Validation | 2026-07-25 | PASS: strict compile 0 errors/0 warnings; schema/spec/build checks PASS | `docs/ops/evidence/2026-07-25_qm5_20136_wti_caltrend_build_q02_enqueue.md` |
| Q02 Baseline Screening | 2026-07-25 | ENQUEUED, pending, attempt 0 | work item `1dc49254-5e14-401c-b2cb-440d98817ff4`; same evidence |
