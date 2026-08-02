---
card_schema_version: 2
ea_id: QM5_20205
slug: wti-calmom1
type: strategy
strategy_id: KELOHARJU-MOP-WTI-CALMOM1-2026_S01
variant_id: KELOHARJU-MOP-WTI-CALMOM1-2026_S01
source_id: KELOHARJU-MOP-WTI-CALMOM1-2026
status: APPROVED
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/wti-calmom1_card.md
execution_contract_status: DRAFT
created: 2026-08-03
created_by: Research+Development
last_updated: 2026-08-03
source_authors: "Matti Keloharju; Juhani Linnainmaa; Peter Nyberg; Tobias Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
strategy_mechanic: wti-ten-year-same-calendar-return-sign-agrees-with-exact-immediately-completed-one-month-own-return-sign
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), The Journal of Finance 71(4), 1557-1590; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: peer_reviewed_paper
    citation: "Keloharju, M., Linnainmaa, J. T., and Nyberg, P. (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590."
    location: "Commodity construction in Sections 5.4.3-5.6 and Tables 8-9; DOI https://doi.org/10.1111/jofi.12398; complete governed review strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md"
    quality_tier: A
    role: seasonal_state
  - type: peer_reviewed_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "Sections 3.1-3.2, Table 2 Panel B, and Appendix A.4; DOI https://doi.org/10.1016/j.jfineco.2011.11.003; complete governed review strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: momentum_state
sources:
  - "[[sources/KELOHARJU-MOP-WTI-CALMOM1-2026]]"
concepts:
  - "[[concepts/same-calendar-month-seasonality]]"
  - "[[concepts/time-series-momentum]]"
indicators:
  - "[[indicators/completed-month-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, calendar-seasonality, time-series-momentum, agreement-filter, symmetric-long-short, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "One monthly decision after the five-year same-calendar warm-up; strict agreement should produce approximately 5-8 WTI packages/year before Q02 validation."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED
q02_work_item_id: 54e53b5e-aa92-4040-97c9-044bdb5cb1c8
review_focus: "Falsify the agreement of recurring WTI calendar-month seasonality and the exact immediately completed one-month own-return continuation state; profitability and book decorrelation are not imported."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [risk_mode, friday_close_hold_semantics, restart_safe_attempt, long_history_warmup, source_to_cfd_basis, conjunction_sparsity, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under the OWNER 2026-08-03 commodity/energy sleeve mission: R1 two completely reviewed peer-reviewed source lineages; R2 locked same-calendar estimator, exact immediately completed month, strict agreement, direction, attempt state, stop, spread, and monthly lifecycle; R3 registered native XTIUSD.DWX D1 carrier; R4 deterministic native arithmetic only. Exact dedup CLEAN; unconditional parents, 63-D1 agreement, and exact one-month disagreement sibling manually resolved."
---

# QM5_20205 WTI Same-Calendar / One-Month Momentum Agreement

## Hypothesis

Recurring physical demand, storage, hedging, and capital-allocation pressures
can give each WTI calendar month a persistent return sign. WTI's own latest
completed monthly return can also continue over the next month. Trading only
when those independent clocks agree may isolate a structural oil regime with
less unconditional market exposure than either parent rule.

This is a directional WTI hypothesis. It adds a crude-oil return driver that
is economically different from the certified XAU/SP500/NDX/XNG book, but it
does not claim realized decorrelation. Q02 through the unchanged portfolio
gate remain authoritative.

## Source Traceability And Claim Boundary

The canonical composite packet is
`strategy-seeds/sources/KELOHARJU-MOP-WTI-CALMOM1-2026/source.md`.
Keloharju, Linnainmaa, and Nyberg supply the recurring same-calendar commodity
return state. Moskowitz, Ooi, and Pedersen supply the source-declared
one-month-own-return continuation state and one-month hold. Both governed
parent packets record complete reads of the underlying peer-reviewed papers.

Both sources trade broad rolling commodity-futures portfolios. Neither tests
this conjunction, a single Darwinex WTI CFD, completed broker-month closes,
fixed cash risk, an ATR hard stop, or the QM portfolio. No source PF, return,
drawdown, WTI-only alpha, trade count, transaction-cost, CFD-basis, or
correlation statistic is imported.

## Non-Duplicate Decision

The deterministic pre-allocation checker scanned 4,261 registry rows and 384
cards and returned `CLEAN`. Manual mechanic review resolves the nearest EAs:

- `QM5_20099_wti-samecal` uses the seasonal sign alone.
- `QM5_20187_wti-tsmom1m` uses the immediately completed month sign alone.
- `QM5_20136_wti-caltrend` requires agreement with a completed 63-D1 return,
  not the exact immediately completed broker-calendar month.
- `QM5_20137_wti-seas-pb` uses the same two clocks but requires strict sign
  disagreement and trades the seasonal direction. This card requires strict
  agreement and therefore occupies the disjoint continuation state.
- Fixed-month, weekday, inventory, expiry, channel, and other WTI systems do
  not combine these exact information objects.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback above a
  long-horizon price filter and shares neither state nor lifecycle.

The same-calendar estimator, exact immediately completed month, strict sign
agreement, shared direction, and monthly renewal are jointly load-bearing.
Removing either state recreates a built parent; changing agreement to
disagreement recreates `QM5_20137`.

## Markets, Timeframe, And Cadence

- Carrier: `XTIUSD.DWX`, D1, magic slot 0 (`202050000`).
- Decision: first tradable WTI D1 bar of every new broker month.
- Seasonal formation: the decision calendar month's returns in the prior ten
  years, requiring at least five valid completed-month observations.
- Momentum formation: exactly the immediately completed consecutive broker
  month.
- Hold: until the next broker-month boundary, with a 35-day stale guard.
- Expected cadence: approximately 5-8 completed packages/year after warm-up;
  retire below five/year.
- Runtime data: native D1 OHLC, ATR, spread, broker calendar, positions, deal
  history, and terminal-global state only.

## Rules

The formula, entry, exit, filter, and management rules below are the complete
frozen baseline. No favorable-month list, threshold fit, parameter sweep,
external feed, or post-result rescue rule is authorized.

## Formula

At the first tradable D1 bar of decision month `m` in year `Y`, reconstruct
completed WTI month-end closes.

For each prior year `y` in `[Y-10, Y-1]` with a valid completed return for
calendar month `m`:

```text
season_y = ln(C_WTI[y,m] / C_WTI[y,m-1])
seasonal_score = arithmetic_mean(season_y)
```

Require at least five valid `season_y` observations. For the immediately
completed broker month:

```text
momentum_score = ln(C_WTI[t-1] / C_WTI[t-2])
```

- Both scores `> 1e-12`: BUY `XTIUSD.DWX`.
- Both scores `< -1e-12`: SELL `XTIUSD.DWX`.
- Disagreement, deadband, missing/nonconsecutive endpoints, nonpositive close,
  or invalid arithmetic: remain flat for the consumed month.

There is no oscillator, moving average, z-score, regression, breakout, carry
proxy, futures curve, external series, trained model, or PnL-adaptive rule.

## 4. Entry Rules

1. Require exact EA ID `20205`, `XTIUSD.DWX` D1, slot 0, and every baseline
   input locked to the values below.
2. Process lifecycle exits before entry-only gates.
3. Evaluate only at a genuine broker-month transition.
4. Persist the current month attempt before history, signal, spread, quote,
   stop, sizing, news, or order gates. A flat, blocked, rejected, stopped, or
   restarted decision cannot retry that month.
5. Reject when an EA-owned position or a current-month entry deal exists.
6. Compute the ten-prior-year same-calendar mean with at least five samples
   and the exact immediately completed consecutive-month return.
7. Require both scores beyond `1e-12` with the same sign. Buy for positive
   agreement and sell for negative agreement.
8. Require spread in `[0,1500]` points, valid current quote, completed
   `ATR(20,D1)`, normalized stop, and symbol/volume metadata.
9. Open one market BUY or SELL with no take-profit. The frozen hard stop is
   `3.5 * ATR(20,D1)` from entry; fixed-risk sizing remains framework-owned.

## 5. Exit Rules

- Close the prior package on the first tradable D1 bar of the next broker
  month before considering renewal.
- Close any position older than 35 calendar days as a stale safety override.
- Broker hard stop and framework kill switch remain authoritative.
- Friday close is disabled because the one-month source hold spans weekends.
- No intramonth signal flip, take-profit, trailing, break-even, partial close,
  scale-in, grid, martingale, pyramid, or discretionary exit exists.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbol, timeframe, EA ID, magic slot, and frozen
  input contract.
- Reject insufficient/malformed history, nonpositive closes, invalid logs,
  nonconsecutive month endpoints, sign disagreement, invalid ATR/price/point
  metadata, negative/excess spread, consumed month, same-month deal, or open
  owned position.
- Q02 freezes both news axes and the legacy news mode OFF. The signal has no
  event or external-calendar dependency.
- No futures curve, inventory, COT, volume, open interest, EIA, OPEC, CSV,
  API, weather, analyst forecast, or discretionary runtime input is allowed.

## 7. Trade Management Rules

- One position maximum for magic `202050000` and one consumed attempt per
  broker month.
- Close only at month renewal, stale guard, framework safety action, or stop.
- The persisted month marker survives restart; owned deal history provides a
  second no-reentry guard.
- No hedge, averaging, scale-in, pyramiding, grid, martingale, partial close,
  adaptive fit, or random path.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_history_years` | 10 | [10] | bounded prior same-month window |
| `strategy_min_history_years` | 5 | [5] | source-aligned sample floor |
| `strategy_history_bars` | 3000 | [3000] | bounded D1 reconstruction buffer |
| `strategy_min_abs_return_pct` | 0.0 | [0.0] | strict sign; no fitted deadband |
| `strategy_atr_period` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 35 | [35] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

There is no baseline parameter sweep. Both source states are jointly
load-bearing.

## Risk And Test Contract

The canonical Q02 setfile uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. `RISK_FIXED` is a stop-normalized loss budget, not fixed
notional exposure. No live-risk mode or live setfile is authorized.

Primary risks are one-name breadth, the five-year warm-up, limited local CFD
history, futures/CFD construction, financing, monthly gaps, oil volatility,
agreement sparsity, source decay, and correlation with other directional
assets. Q09 alone may adjudicate portfolio decorrelation.

## Kill Criteria

- Retire below five completed trades per full post-warm-up year.
- Fail on zero trades, wrong sign, current-month leakage, malformed or
  nonconsecutive month endpoints, duplicate monthly entry, restart
  nondeterminism, missing stop, risk-mode mismatch, or governed PF/DD failure.
- Do not rescue a failure with a threshold, oscillator, alternate month list,
  different horizon, disagreement regime, volatility filter, or sweep.

## Strategy Allowability Check

- [x] R1 reputable sources: two peer-reviewed papers with DOIs and complete
  durable repository reviews.
- [x] R2 mechanical: fixed month endpoints, seasonal mean, exact one-month
  sign, agreement mapping, renewal, attempt, stop, spread cap, and stale exit.
- [x] R3 testable: registered native `XTIUSD.DWX` D1 carrier.
- [x] R4 compliant: no trained model, banned indicator, external runtime
  feed, grid, martingale, scale-in, pyramiding, or adaptive PnL fitting.
- [x] Exact dedup clean; closest parent and complementary siblings manually
  resolved with all load-bearing states frozen.

## Framework Alignment

- no_trade: exact carrier/ID/slot, frozen inputs, history, calendar, spread,
  attempt, and framework safety gates.
- trade_entry: same-calendar and exact prior-month sign agreement with a
  restart-safe consumed attempt and frozen ATR stop.
- trade_management: next-month renewal and 35-day stale close before entry
  gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes one branch-only research build, strict compile, one
`RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It does not authorize
a live/demo/shadow setfile, AutoTrading, `T_Live` access, a deploy or T_Live
manifest, portfolio admission, a portfolio-gate change, or a correlation
waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-03 | initial WTI calendar / exact one-month agreement candidate | Q02 | Q01 PASS; Q02 ENQUEUED as work item `54e53b5e-aa92-4040-97c9-044bdb5cb1c8` |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-03 | APPROVED; R1-R4 PASS | this card, governed source packet, and durable decision |
| Q01 Build Validation | 2026-08-03 | PASS; strict compile and V5 build check, 0 errors/warnings | `D:/QM/reports/framework/21/build_check_20260802_233303.json` |
| Q02 Baseline Screening | 2026-08-03 | ENQUEUED; paced worker had claimed the item at handoff | `docs/ops/evidence/2026-08-03_qm5_20205_wti_calmom1_build_q02_enqueue.md`; work item `54e53b5e-aa92-4040-97c9-044bdb5cb1c8` |
