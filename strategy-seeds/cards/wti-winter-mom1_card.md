---
card_schema_version: 2
ea_id: QM5_20209
slug: wti-winter-mom1
type: strategy
strategy_id: BURAKOV-MOP-WTI-WINTER-MOM1-2026_S01
variant_id: BURAKOV-MOP-WTI-WINTER-MOM1-2026_S01
source_id: BURAKOV-MOP-WTI-WINTER-MOM1-2026
status: APPROVED
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/wti-winter-mom1_card.md
execution_contract_status: DRAFT
created: 2026-08-03
created_by: Research+Development
last_updated: 2026-08-03
source_authors: "Dmitry Burakov; Max Freidin; Yuriy Solovyev; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
strategy_mechanic: november-may-wti-exact-prior-completed-calendar-month-return-sign
source_citation: "Burakov, Freidin, and Solovyev (2018), International Journal of Energy Economics and Policy 8(2), 121-126; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: peer_reviewed_open_access_paper
    citation: "Burakov, D., Freidin, M., and Solovyev, Y. (2018). The Halloween Effect on Energy Markets: An Empirical Study. International Journal of Energy Economics and Policy 8(2), 121-126."
    location: "Methods alternative two and WTI Tables 2-3; complete governed review strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md"
    quality_tier: B
    role: seasonal_regime
  - type: peer_reviewed_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "Sections 3.1-3.2, Table 2 Panel B, and Appendix A.4; DOI https://doi.org/10.1016/j.jfineco.2011.11.003; complete governed review strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: one_month_direction
sources:
  - "[[sources/BURAKOV-MOP-WTI-WINTER-MOM1-2026]]"
concepts:
  - "[[concepts/wti-winter-regime]]"
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/seasonal-trend-interaction]]"
indicators:
  - "[[indicators/completed-month-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, calendar-seasonality, time-series-momentum, seasonal-regime-gate, symmetric-long-short, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "One monthly package in each November-May broker month after two completed month-end closes; approximately seven WTI packages/year before Q02 validation."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PENDING_BUILD
q02_status: NOT_ENQUEUED
review_focus: "Falsify whether the source-backed November-May WTI regime changes the payoff of the exact prior-month continuation state enough to add direct crude exposure; Q09 alone may establish book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [risk_mode, friday_close_hold_semantics, restart_safe_attempt, exact_month_endpoints, seasonal_gate, source_to_cfd_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under the OWNER 2026-08-03 commodity/energy sleeve mission: R1 fully reviewed peer-reviewed winter-regime and one-month momentum sources; R2 locked months, exact consecutive completed-month endpoints, sign map, renewal, stop, spread, and attempt state; R3 registered native XTIUSD.DWX D1 carrier; R4 deterministic native arithmetic only. Exact dedup CLEAN and nearest regime, horizon, unconditional, calendar-direction, and oscillator builds manually resolved."
---

# QM5_20209 WTI Winter-Regime / One-Month Momentum

## Hypothesis

WTI's November-May regime can reflect recurring physical demand, storage,
producer hedging, and capital-allocation pressure. WTI's exact just-completed
monthly return can separately persist for the following month. Trading that
one-month direction only inside the fixed winter regime may isolate a crude-oil
state whose carrier and information clock differ from the certified
XAU/SP500/NDX/XNG book.

This is a falsifiable interaction hypothesis, not a profitability or
decorrelation claim. Q02 must establish basic economics and frequency; the
unchanged downstream portfolio gate alone may measure realized book overlap.

## Source Traceability And Claim Boundary

The governed packet
`strategy-seeds/sources/BURAKOV-MOP-WTI-WINTER-MOM1-2026/source.md` joins two
complete peer-reviewed source reads. Burakov, Freidin, and Solovyev supply the
fixed WTI November-May interval. Moskowitz, Ooi, and Pedersen supply the
instrument-own past-return sign family and explicitly report a one-month
formation/one-month hold commodity portfolio that includes WTI in the source
universe.

Neither paper tests this conjunction, WTI-only one-month performance, a
Darwinex continuous CFD, completed broker-month endpoints, fixed cash risk,
an ATR stop, or the QM book. No source return, Sharpe, PF, drawdown,
significance, cost, correlation, or neutrality statistic is imported.

## Non-Duplicate Decision

The deterministic pre-allocation checker scanned 4,265 EA registry rows and
386 cards and returned `CLEAN`. Manual mechanic review fixes the boundaries:

- `QM5_20135_wti-winter-trend` uses a 252-D1 trend inside November-May; this
  card uses the exact immediately completed consecutive calendar month.
- `QM5_20187_wti-tsmom1m` uses the same one-month sign year-round and does not
  force a June season exit.
- `QM5_20015_wti-halloween-winter` is unconditional winter long-only.
- `QM5_20046_wti-halloween-ls` maps calendar season directly to direction.
- `QM5_20205_wti-calmom1` reconstructs recurring same-calendar history and
  requires sign agreement; this card has no historical seasonal estimator.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback with a
  multiday exit.

The November-May entry gate, June-October flat state, exact prior completed
month, symmetric return-sign map, and monthly renewal are jointly load-bearing.

## Markets, Timeframe, And Cadence

- Carrier: `XTIUSD.DWX`, D1, slot 0, magic `202090000`.
- Decision: first tradable D1 bar of each broker month.
- Eligible months: November, December, January, February, March, April, May.
- Formation: latest two distinct, consecutive completed broker-month closes.
- Hold: next broker-month transition, with a forty-calendar-day stale guard.
- Expected cadence: approximately seven completed packages/year; retire below
  five per full post-warm-up year.

## Rules

At the first tradable D1 bar of active month `m`, let `C1` be the close of the
just-completed broker-calendar month and `C2` the close of the preceding
consecutive month:

`r1 = ln(C1 / C2)`

- `r1 > 0`: BUY `XTIUSD.DWX`.
- `r1 < 0`: SELL `XTIUSD.DWX`.
- `r1 = 0`, invalid/nonconsecutive endpoints, or June-October: remain flat.

No current-month close enters the signal. No threshold, trend refit,
same-calendar estimator, unconditional fallback, parameter sweep, or
post-result rescue rule is authorized.

## 4. Entry Rules

1. Require exact EA ID `20209`, `XTIUSD.DWX` D1, magic slot 0, and every
   baseline input locked to the values below.
2. Process lifecycle exits before entry-only gates and evaluate only at a
   genuine broker-month transition.
3. Reject June through October. In each active month, persist the attempt
   before history, signal, spread, quote, news, stop, sizing, or order gates.
4. Reject an owned position or a same-month owned entry deal.
5. Reconstruct the two latest distinct completed month-end closes; require
   that they end in the just-completed month and are consecutive.
6. Buy for a strictly positive log return and sell for a strictly negative
   log return. Equality or invalid state stays flat for the consumed month.
7. Require spread in `[0,1500]` points, a valid quote, completed
   `ATR(20,D1)`, symbol metadata, risk mode, and news gates.
8. Open one market position with a `3.5 * ATR(20,D1)` hard stop and no
   take-profit. Framework fixed-risk sizing remains authoritative.

## 5. Exit Rules

1. Close the prior position on the first tradable D1 bar of every new broker
   month before considering replacement risk.
2. Force flat from June through October.
3. Close any position after forty calendar days as a stale guard.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the source hold spans weekends.
6. No intramonth signal flip, take-profit, trail, break-even, partial close,
   scale-in, grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbol, D1 timeframe, EA ID, slot, and frozen
  input contract.
- Reject ineligible months, malformed/nonconsecutive month endpoints,
  nonpositive prices, invalid logs, invalid ATR/quote/point metadata, negative
  or excessive spread, consumed attempt, same-month deal, or open position.
- Q02 freezes both news axes and legacy news mode OFF. No external calendar,
  futures chain, inventory, volume, open interest, CSV, API, or forecast is
  read at runtime.

## 7. Trade Management Rules

- One position maximum for magic `202090000` and one consumed attempt per
  eligible broker month.
- Close before renewal, at the June season boundary, after forty days, on the
  hard stop, or under framework safety action.
- Terminal-global attempt state survives restart; owned deal history provides
  a second no-reentry guard.
- No hedge, averaging, scale-in, pyramiding, grid, martingale, partial close,
  adaptive fit, or random path exists.

## Parameters To Test

| parameter | baseline | authorized values | role |
|---|---:|---|---|
| `strategy_first_active_month` | 11 | [11] | winter regime start |
| `strategy_last_active_month` | 5 | [5] | winter regime end |
| `strategy_history_bars` | 80 | [80] | bounded month-end reconstruction |
| `strategy_atr_period` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

Changing the regime, endpoint definition, return direction, hold, stop,
carrier, or retry policy requires a new card and full pipeline run.

## Risk

The canonical Q02 setfile uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. `RISK_FIXED` is a stop-normalized loss budget, not fixed
notional exposure. No live-risk mode is authorized.

Primary risks are one-name breadth, seven-decision cadence, seasonal and
momentum interaction decay, futures-to-CFD construction, WTI gaps and rolls,
financing, stop-outs, month-end history gaps, and correlation with XNG or
directional assets. Retire below five completed packages/year or on
nonpositive governed economics, wrong season/direction, current-month leakage,
duplicate entry, restart nondeterminism, missing stop, risk mismatch, or later
correlation rejection. No parameter rescue or correlation waiver is allowed.

## Strategy Allowability Check

- [x] R1 reputable: two named-author peer-reviewed papers with official or
  institutional access and durable complete-read evidence.
- [x] R2 mechanical: fixed months, endpoints, sign mapping, renewal, attempt,
  stop, spread cap, and stale exit.
- [x] R3 testable: registered native `XTIUSD.DWX` D1 carrier.
- [x] R4 compliant: deterministic native arithmetic only; no trained model,
  external runtime feed, grid, martingale, scale-in, or pyramiding.
- [x] Exact dedup clean; nearest regime, horizon, unconditional, calendar-map,
  and oscillator builds manually resolved.

## Framework Alignment

- no_trade: exact carrier/ID/slot, frozen inputs, active season, month-end
  history, spread, attempt, and framework safety gates.
- trade_entry: exact prior-month sign, monthly consumed attempt, fixed-risk
  sizing, and frozen ATR stop.
- trade_management: close-before-renew, June season exit, and stale close.
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
| v1 | 2026-08-03 | initial WTI winter / exact one-month momentum candidate | G0 | APPROVED; build pending |

