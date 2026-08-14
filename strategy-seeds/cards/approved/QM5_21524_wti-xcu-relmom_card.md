---
card_schema_version: 2
type: strategy
strategy_id: FMR-EIA-USGS-WTI-XCU-RELMOM-2026_S01
variant_id: FMR-EIA-USGS-WTI-XCU-RELMOM-2026_S01
source_id: FMR-EIA-USGS-WTI-XCU-RELMOM-2026
ea_id: QM5_21524
slug: wti-xcu-relmom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_21524_wti-xcu-relmom_card.md
execution_contract_status: DRAFT
created: 2026-08-14
created_by: Research+Development
last_updated: 2026-08-14
g0_status: APPROVED
source_author: "Ana-Maria Fuertes; Joelle Miffre; Georgios Rallis; U.S. Energy Information Administration; CME Group; U.S. Geological Survey"
source_authors: "Ana-Maria Fuertes; Joelle Miffre; Georgios Rallis; U.S. Energy Information Administration; CME Group; U.S. Geological Survey"
source_citation: "Fuertes, Miffre, and Rallis (2010), Journal of Banking & Finance 34(10), 2530-2548; official EIA crude-oil driver, CME Copper Futures, and USGS Copper Statistics references."
source_citations:
  - type: peer_reviewed_paper
    citation: "Fuertes, A.-M., Miffre, J., and Rallis, G. (2010). Tactical Allocation in Commodity Futures Markets: Combining Momentum and Term Structure Signals. Journal of Banking & Finance 34(10), 2530-2548."
    location: "DOI 10.1016/j.jbankfin.2010.04.009; complete 47-page accepted-manuscript review strategy-seeds/sources/FMR-MOMTS-2010/source.md"
    quality_tier: A
    role: twelve_month_cross_sectional_commodity_momentum_and_one_month_hold
  - type: government_explainer
    citation: "U.S. Energy Information Administration. What drives crude oil prices: Spot Prices."
    location: "governed packet strategy-seeds/sources/EIA-CME-USGS-XTI-XCU-BRK-2026/source.md"
    quality_tier: A
    role: physical_crude_oil_driver_context
  - type: exchange_reference
    citation: "CME Group. Copper Futures."
    location: "governed packet strategy-seeds/sources/EIA-CME-USGS-XTI-XCU-BRK-2026/source.md"
    quality_tier: A
    role: benchmark_copper_carrier
  - type: government_reference
    citation: "U.S. Geological Survey. Copper Statistics and Information."
    location: "governed packet strategy-seeds/sources/EIA-CME-USGS-XTI-XCU-BRK-2026/source.md"
    quality_tier: A
    role: industrial_base_metal_supply_demand_context
strategy_mechanic: monthly-wti-copper-twelve-synchronized-completed-month-simple-return-average-rank-following-opposite-leg-equal-risk-basket
sources:
  - "[[sources/FMR-EIA-USGS-WTI-XCU-RELMOM-2026]]"
concepts:
  - "[[concepts/cross-sectional-commodity-momentum]]"
  - "[[concepts/energy-base-metal-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/completed-month-simple-return]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, base-metal, cross-sectional-momentum, relative-value, market-neutral-basket, symmetric-long-short, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, base_metals]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XCUUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XCUUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_21524_WTI_XCU_RELMOM_D1
symbol: QM5_21524_WTI_XCU_RELMOM_D1
symbol_slot: 0
magic: 215240000
companion_symbol_slot: 1
companion_magic: 215240001
period: D1
timeframe: D1
expected_trade_frequency: "Approximately twelve completed two-leg packages per full post-warm-up year; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
q01_status: PENDING
q02_status: NOT_ENQUEUED
review_focus: "Falsify a monthly energy-versus-industrial-metal relative-momentum package designed to remove common commodity direction; Q09 alone may establish realized decorrelation from the XAU/SP500/NDX/XNG book."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [common_month_end_timestamps, consecutive_month_mapping, twelve_simple_return_arithmetic_means, strict_relative_rank, basket_atomicity, aggregate_fixed_risk, restart_attempt_state, magic_schema, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-14_qm5_21524_wti_xcu_relmom_g0.md: R1 complete peer-reviewed JBF paper plus governed official EIA/CME/USGS carrier evidence; R2 exact common month ends, twelve simple-return means, strict rank, opposite legs, equal risk, stops, monthly attempt, renewal, and repair; R3 registered WTI/copper D1 route; R4 deterministic native arithmetic only. Canonical dedup CLEAN across 4,396 registry rows and 492 cards; same-pair channel and z-score fade, WTI/XNG D1 momentum, XAU/XAG monthly momentum, and incumbent XNG oscillator families were manually separated."
---

# QM5_21524 WTI/Copper Twelve-Month Relative Momentum

## Hypothesis

Slow diffusion of physical supply, demand, and hedging shocks can make relative
commodity performance persist. Each broker month this card buys the stronger
of WTI crude and copper over the prior twelve synchronized completed months and
shorts the weaker. WTI contributes energy supply, demand, spare-capacity, and
geopolitical exposure; copper contributes industrial/base-metal demand and
materials-flow exposure. The opposite-leg package aims to remove some common
USD and broad-commodity direction instead of adding another outright XAU,
index, or XNG swing.

Opposite sides and equal stop-risk halves do not prove dollar, beta,
volatility, factor, market, or portfolio neutrality. Q02 owns density and
baseline economics; Q09 alone owns realized book correlation.

## Source Traceability And Claim Boundary

The governed composite packet is
`strategy-seeds/sources/FMR-EIA-USGS-WTI-XCU-RELMOM-2026/source.md`.
Fuertes, Miffre, and Rallis (2010) supply the twelve-month cross-sectional
commodity-momentum ranking and one-month hold. The official EIA, CME, and USGS
references establish the distinct WTI and copper carrier contexts.

The paper uses a broad collateralized futures universe, not two continuous
broker CFDs. None of the sources tests this exact pair, synchronized
broker-month mapping, equal stop-risk split, hard stops, spread caps, atomic
repair, restart ledger, or QM portfolio. No source return, alpha, significance,
Sharpe ratio, drawdown, trade count, cost, hedge ratio, CFD equivalence,
neutrality, decorrelation, or portfolio result transfers.

## Non-Duplicate Decision

The canonical checker returned `CLEAN` for the slug, strategy ID, authors, and
complete mechanic across 4,396 registry rows and 492 root cards. Manual review
fixes the boundary:

- `QM5_13094_xti-xcu-brk` follows a daily price-level WTI/copper log-spread
  channel and exits on a shorter channel.
- `QM5_13090_xti-xcu-rspread` fades a short-window standardized return-spread
  shock. This card follows a twelve-month rank and forms no z-score.
- `QM5_12733_xti-xng-xmom` uses natural gas, a 126-D1 cumulative return, a
  percentage band, and Friday close rather than exact common month ends.
- `QM5_20050_xauxag-xmom12` is a precious-metals carrier with no energy or
  copper exposure.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon, long-only XNG oscillator
  pullback.

The WTI/copper carrier, exact synchronized month ends, twelve simple-return
arithmetic means, strict rank, opposite-leg package, equal fixed-risk halves,
and consumed monthly attempt are jointly load-bearing. Verdict:
`CLEAN_WTI_COPPER_TWELVE_MONTH_CROSS_SECTIONAL_MOMENTUM_PACKAGE`.

## Markets, Timeframe, And Formula

- Logical basket: `QM5_21524_WTI_XCU_RELMOM_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1, magic `215240000`.
- Companion/traded slot 1: `XCUUSD.DWX`, D1, magic `215240001`.
- Decision: first processed host D1 bar after a genuine broker-month change.
- Formation: exactly thirteen consecutive synchronized completed
  broker-month endpoints, producing twelve simple monthly returns per leg.
- Hold: until the next broker-month transition, with a forty-day stale guard.

```text
r_wti[m] = WTI_month_close[m] / WTI_month_close[m-1] - 1
r_xcu[m] = XCU_month_close[m] / XCU_month_close[m-1] - 1

avg12_wti = sum(r_wti[m], m=1..12) / 12
avg12_xcu = sum(r_xcu[m], m=1..12) / 12
relative_momentum = avg12_wti - avg12_xcu

BUY WTI / SELL XCU when relative_momentum >  1e-10
SELL WTI / BUY XCU when relative_momentum < -1e-10
FLAT otherwise
```

Return magnitude never changes risk. Log returns, cumulative endpoint return,
daily-bar windows, ratio channels, z-scores, regression hedge ratios, and
alternate horizons are not equivalent.

## Rules

The entry, exit, filter, and lifecycle rules below are the complete authorized
baseline. No signal or execution parameter sweep is authorized.

## 4. Entry Rules

1. Require exact EA ID `21524`, `XTIUSD.DWX` D1 host, slot 0, both registered
   magics, and every locked input.
2. Process malformed-package repair and prior-month liquidation before
   entry-only gates. Evaluate only after a genuine broker-month transition.
3. Persist the current broker month as consumed before history, signal, news,
   spread, quote, ATR, sizing, or order checks. A flat, blocked, failed,
   stopped, or partially opened decision may not retry that month.
4. Reject owned exposure or any same-month entry deal for either registered
   magic.
5. Load bounded completed WTI and copper D1 histories and derive exactly
   thirteen consecutive common broker-month endpoints ending in the
   immediately completed month.
6. Reject duplicate, current-month, stale, nonpositive, nonfinite,
   nonchronological, nonconsecutive, or timestamp-mismatched endpoints. The
   newest common endpoint must be no more than ten calendar days stale.
7. Calculate exactly twelve simple monthly returns for each leg and each
   twelve-return arithmetic mean. Reject nonfinite arithmetic.
8. Buy WTI and sell copper above the strict positive deadband; sell WTI and
   buy copper below the strict negative deadband. Consume all other states
   flat.
9. Require WTI/copper spreads in `[0,1500]` and `[0,1200]` points, executable
   quotes, completed `ATR(20,D1)`, valid stops, registered magics, and valid
   contract and volume metadata.
10. Split one aggregate `RISK_FIXED=1000` package budget equally between the
    two independently ATR-normalized legs. Attach one frozen
    `3.5 * ATR(20,D1)` hard stop to each; no take-profit.
11. Open WTI then copper and retain exposure only if exactly one correctly
    directed, opposite-side position exists in each slot. Flatten every owned
    leg immediately after order or final-package failure.

## 5. Exit Rules

1. Close both legs on the first processed WTI D1 bar of every new broker month
   before evaluating replacement risk, even when the rank is unchanged.
2. Close both legs after forty elapsed calendar days as a stale guard.
3. Immediately flatten an orphan, duplicate, wrong-symbol, same-direction,
   wrong-magic, or missing-stop package.
4. Per-leg broker hard stops and the framework kill switch remain
   authoritative.
5. Friday close is disabled because the source-aligned hold spans weekends.
6. There is no intramonth signal exit, target, trail, break-even, partial
   close, scale-in, grid, martingale, pyramid, or discretionary exit.

## 6. Filters (No-Trade Module)

- Fail closed outside the exact host, D1 timeframe, EA ID, slot, fixed-risk,
  news, Friday, stress, or locked strategy contract.
- Reject a consumed month, existing or same-month exposure, incomplete or
  mismatched month endpoints, wrong endpoint count, nonconsecutive months,
  stale/nonfinite history, inside-deadband rank, excessive spread, invalid
  quote, ATR, stop, magic, contract, or volume state.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  and package repair run before entry-only gates.
- Runtime may not read a futures chain, external file or API, inventory,
  analyst forecast, trained output, optimizer result, or portfolio state.

## 7. Trade Management Rules

- Maintain exactly one WTI position and one oppositely directed copper
  position, each under its registered magic and original broker hard stop.
- One shared fixed-risk package budget is split equally by stop risk. Signal
  magnitude never scales the budget.
- Consume at most one decision per broker month. Terminal-persistent state
  plus owned deal and position history prevents restart re-entry; tester
  initialization clears only a future-dated marker.
- Close old-month, stale, orphaned, duplicate, same-direction, wrong-magic,
  wrong-symbol, or missing-stop exposure before entry logic.
- No randomness, PnL-adaptive fit, partial close, scale-in, grid, martingale,
  or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_return_window_months` | 12 | [12] | exact monthly return count |
| `strategy_history_bars_d1` | 800 | [800] | bounded D1 reconstruction buffer per leg |
| `strategy_max_endpoint_gap_days` | 10 | [10] | newest common endpoint freshness guard |
| `strategy_rank_deadband` | 1e-10 | [1e-10] | strict average-return difference threshold |
| `strategy_atr_period_d1` | 20 | [20] | completed per-leg stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop multiple |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_wti_max_spread_pts` | 1500 | [1500] | WTI entry spread ceiling |
| `strategy_xcu_max_spread_pts` | 1200 | [1200] | copper entry spread ceiling |
| `strategy_deviation_points` | 20 | [20] | basket order deviation |

Every timestamp, endpoint, return type, estimator, horizon, threshold, side,
risk split, stop, hold, spread, deviation, and retry rule is locked.

## Author Claims

Fuertes, Miffre, and Rallis test broad cross-sectional commodity-futures
momentum with twelve-month formation and a one-month hold. EIA, CME, and USGS
establish WTI and copper as distinct physical-commodity carriers. None claims
that this two-CFD package is profitable, neutral, or uncorrelated with the QM
book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` for the aggregate package. Risk is high: this is a narrow
two-name translation; WTI supply shocks and copper industrial cycles can
reverse abruptly; both CFDs retain USD, growth, roll, financing, gap, and
liquidity exposure; synchronized history may be shallow; and legging, stop
desynchronization, or lot granularity may dominate the relative return.

Opposite direction and equal stop-risk halves do not guarantee dollar, beta,
volatility, factor, market, or portfolio neutrality.

## Kill Criteria

- Retire on zero trades or fewer than five completed packages per full
  post-warm-up year.
- Fail on wrong month mapping, endpoint count, timestamp mismatch,
  nonconsecutive months, log or cumulative returns, wrong arithmetic mean,
  wrong rank direction, repeated attempt, same-direction/orphan legs,
  aggregate-risk breach, hold beyond forty days, missing stop, invalid risk
  mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing a window, estimator, threshold,
  direction, carrier, risk split, stop, hold, spread, deviation, or retry rule.

## Strategy Allowability Check

| gate | verdict | reasoning |
|---|---|---|
| R1 | PASS | Complete peer-reviewed JBF manuscript review plus governed official EIA, CME, and USGS carrier references. |
| R2 | PASS | Fixed common month endpoints, twelve simple-return means, strict rank, opposite legs, package risk, stops, attempt state, renewal, and repair. |
| R3 | PASS | Registered WTI/copper D1 history and native execution state supply every runtime input; Q02 validates synchronization and fills. |
| R4 | PASS | Deterministic calendar, price, arithmetic, ATR risk, and trade-state operations only; no trained output or banned signal indicator. |

- [x] Dedup: deterministic CLEAN; manual review separates same-pair channel
  continuation and z-score reversion, WTI/XNG D1 momentum, XAU/XAG monthly
  momentum, and the incumbent XNG oscillator.

## Framework Alignment

- no_trade: exact host/D1/EA/slot, locked inputs, risk/news/Friday contract,
  magic, and cheap parameter guards.
- trade_entry: consumed monthly attempt, synchronized completed-month
  reconstruction, twelve simple-return means, strict rank, spread/quote/ATR/
  stop checks, two orders, and atomic final validation.
- trade_management: malformed-package repair, next-month close, forty-day
  stale exit, and orphan cleanup before entry-only gates.
- trade_close: framework close helper, per-leg broker hard stops, and kill
  switch.

## Safety Boundary

This card authorizes only research, deterministic allocation, build, strict
compile/Q01, one logical-basket `RISK_FIXED` backtest setfile, and one paced
non-live Q02 handoff when CPU capacity permits. It does not authorize a manual
backtest; live, demo, shadow, stress, or optimization artifact; AutoTrading;
`T_Live`; deploy or T_Live manifest; portfolio admission; portfolio-gate
change; or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-14 | initial WTI/copper twelve-month cross-sectional momentum package | G0 | APPROVED; build pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-14 | APPROVED; R1-R4 PASS | `decisions/2026-08-14_qm5_21524_wti_xcu_relmom_g0.md`; governed composite source packet |
| Q01 Build Validation | — | PENDING | — |
| Q02 Baseline Screening | — | NOT ENQUEUED | — |
