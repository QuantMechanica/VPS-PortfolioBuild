---
card_schema_version: 2
ea_id: QM5_20227
slug: wti-seas-mom1
type: strategy
strategy_id: BURAKOV-MOP-WTI-SEASMOM1-2026_S01
variant_id: BURAKOV-MOP-WTI-SEASMOM1-2026_S01
source_id: BURAKOV-MOP-WTI-SEASMOM1-2026
status: APPROVED
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20227_wti-seas-mom1_card.md
execution_contract_status: DRAFT
created: 2026-08-05
created_by: Research+Development
last_updated: 2026-08-05
source_authors: "Dmitry Burakov; Max Freidin; Yuriy Solovyev; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
strategy_mechanic: wti-fixed-physical-season-direction-agrees-with-exact-immediately-completed-one-calendar-month-return-sign
source_citation: "Burakov, Freidin, and Solovyev (2018), International Journal of Energy Economics and Policy 8(2), 121-126; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: peer_reviewed_open_access_paper
    citation: "Burakov, D., Freidin, M., and Solovyev, Y. (2018). The Halloween Effect on Energy Markets: An Empirical Study. International Journal of Energy Economics and Policy 8(2), 121-126."
    location: "Methods alternative two and WTI Tables 2-3; complete governed review strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md"
    quality_tier: B
    role: physical_season_direction
  - type: peer_reviewed_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "Section 3.2, Table 2 k=1/h=1 commodity rule, Appendix A WTI universe; DOI 10.1016/j.jfineco.2011.11.003; complete governed review strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: immediately_completed_one_month_return_sign
sources:
  - "[[sources/BURAKOV-MOP-WTI-SEASMOM1-2026]]"
concepts:
  - "[[concepts/wti-seasonal-direction]]"
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/calendar-trend-concordance]]"
indicators:
  - "[[indicators/month-end-close]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, calendar-seasonality, one-month-momentum, agreement-filter, symmetric-calendar-map, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 202270000
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "One decision per broker month after two consecutive completed month-end closes; estimate five to seven concordant WTI packages/year before Q02 validation."
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
q02_status: NOT_STARTED
review_focus: "Falsify whether fixed WTI physical-season direction confirmed by the immediately completed one-month own return adds direct crude exposure and a slow calendar/trend interaction absent from the certified XAU/SP500/NDX/XNG book; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [risk_mode, friday_close_hold_semantics, restart_safe_attempt, completed_month_reconstruction, seasonal_direction, concordance_gate, source_to_cfd_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under the OWNER 2026-08-05 commodity/energy sleeve mission: R1 complete peer-reviewed WTI physical-season and one-month time-series-momentum source records; R2 locked winter/summer directions, exact completed-month endpoints, strict sign map, agreement-only entry, monthly renewal, stop, spread, and attempt state; R3 native XTIUSD.DWX D1 carrier; R4 deterministic native arithmetic only. Deterministic dedup found no exact identity; the expected wti-seas-dow fuzzy match and unconditional season, year-round one-month momentum, disjoint-season momentum, twelve-sign breadth, same-calendar, and RSI relatives are manually resolved."
---

# QM5_20227 WTI Physical-Season / One-Month Momentum Concordance

## Hypothesis

WTI's November-May versus June-October return asymmetry reflects recurring
heating demand, refinery transitions, inventory cycles, driving-season flows,
producer hedging, and weather risk. Requiring the fixed physical-season
direction to agree with WTI's immediately completed one-month own-return sign
may avoid carrying the seasonal prior against the latest monthly price state.
The result is a slow direct-crude sleeve whose carrier and signal clock differ
from the certified XAU/SP500/NDX/XNG book.

This is a falsifiable interaction, not a profitability, decorrelation,
certification, or portfolio-admission claim. Q02 must establish frequency and
economics. The unchanged downstream portfolio gate alone may measure realized
book overlap.

## Source Traceability And Claim Boundary

The governed composite packet is
`strategy-seeds/sources/BURAKOV-MOP-WTI-SEASMOM1-2026/source.md`. Burakov,
Freidin, and Solovyev supply positive November-May and negative June-October
WTI physical-season directions. Moskowitz, Ooi, and Pedersen supply the sign
of the immediately completed one-month own return and a one-month holding
horizon for the pooled commodity time-series-momentum family.

Neither source tests this concordance rule. The momentum paper does not report
a WTI-only one-month result, and neither source tests a Darwinex continuous
CFD, broker-month reconstruction, fixed cash risk, an ATR stop, financing,
costs, or the QM portfolio. No source return, significance, Sharpe, PF,
drawdown, cost, correlation, or neutrality statistic is imported.

## Non-Duplicate Decision

The deterministic pre-allocation checker scanned 4,284 registry rows and 400
canonical cards. It found no exact identity and one expected fuzzy match to
`wti-seas-dow` because both are physical-season agreement rules. Manual
mechanic review fixes the boundaries:

- `QM5_20046_wti-halloween-ls` is unconditional seasonal exposure; this
  candidate stays flat on price disagreement.
- `QM5_20187_wti-tsmom1m` follows the exact completed-month sign year-round;
  it has no fixed physical-season direction.
- `QM5_20209_wti-winter-mom1` and `QM5_20213_wti-summer-mom1` may trade in
  either direction inside disjoint seasons; this candidate never shorts
  winter or buys summer and applies one rule across all months.
- `QM5_20222_wti-seas-sign` uses twelve binary monthly returns and a 0.40
  probability threshold; this candidate uses only the exact immediately
  completed month.
- `QM5_20226_wti-seas-dow` uses a weekday event and one-session hold; this
  candidate has no weekday signal and holds month to month.
- `QM5_20205_wti-calmom1` uses a ten-year same-calendar estimate rather than
  the fixed physical-season partition.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback above a
  long-horizon filter.

The exact completed-month sign, fixed winter/summer map, agreement-only entry,
disagreement-flat state, and monthly lifecycle are jointly load-bearing.

## Markets, Timeframe, And Cadence

- Carrier: `XTIUSD.DWX`, D1, slot 0, magic `202270000`.
- Decision: first tradable D1 bar of every broker-calendar month.
- Seasonal state: BUY November-May; SELL June-October.
- Formation: two consecutive completed broker-month-end closes defining the
  immediately completed close-to-close log return.
- Hold: next broker-month transition, with a forty-calendar-day stale guard.
- Maximum cadence: twelve decisions/year; expected five to seven concordant
  packages/year; retire below five completed packages per full post-warm-up
  year.

## Rules

At the first tradable D1 bar of month `m`, reconstruct the newest two distinct
completed broker-calendar month-end closes. Require the newer endpoint to be
the month immediately before `m` and require the two endpoints to be
consecutive. Calculate:

`momentum = ln(newer_completed_month_close / older_completed_month_close)`

- November-May and strictly positive momentum: BUY `XTIUSD.DWX`.
- June-October and strictly negative momentum: SELL `XTIUSD.DWX`.
- Any disagreement, exact zero, or invalid history: remain flat after
  consuming the monthly attempt.

No current-month price enters the signal. No unconditional seasonal fallback,
cumulative-return substitute, deadband fit, parameter sweep, or post-result
rescue is authorized.

## 4. Entry Rules

1. Require exact EA ID `20227`, `XTIUSD.DWX` D1, magic slot 0, and every
   baseline input locked to the values below.
2. Process lifecycle exits before entry-only gates and evaluate only at a
   genuine broker-month transition.
3. Persist the monthly attempt before history, signal, agreement, spread,
   quote, news, stop, sizing, or order gates.
4. Reject an owned position or a same-month owned entry deal.
5. Reconstruct exactly two consecutive completed month-end closes and require
   the newest endpoint to be the just-completed month.
6. Map a strictly positive return to BUY and a strictly negative return to
   SELL; equality is flat.
7. Map November-May to seasonal BUY and June-October to seasonal SELL.
   Continue only when both directions agree.
8. Require spread in `[0,1500]` points, a valid quote, completed
   `ATR(20,D1)`, symbol metadata, fixed-risk mode, and news gates.
9. Open one market position with a frozen `3.5 * ATR(20,D1)` hard stop and no
   take-profit. Framework fixed-risk sizing remains authoritative.

## 5. Exit Rules

1. Close the prior position on the first tradable D1 bar of every new broker
   month before considering replacement risk.
2. Close any position after forty calendar days as a stale guard.
3. Close an unexpected wrong-side position immediately.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the source hold spans weekends.
6. No intramonth signal flip, target, trail, break-even, partial close,
   scale-in, hedge, grid, martingale, pyramid, or discretionary exit exists.

## 6. Filters (No-Trade Module)

- Fail closed outside the exact symbol, D1 timeframe, EA ID, slot, and frozen
  input contract.
- Reject malformed/nonconsecutive month endpoints, nonpositive prices,
  invalid or zero return, disagreement, invalid ATR/quote/point metadata,
  negative or excessive spread, consumed attempt, same-month deal, or an open
  owned position.
- Q02 freezes both news axes and legacy news mode OFF. Runtime reads no
  external calendar, futures chain, inventory, volume, open interest, file,
  API, or forecast.

## 7. Trade Management Rules

- One position maximum for magic `202270000` and one consumed attempt per
  broker month.
- Close before renewal, on a wrong-side state, after forty days, on the hard
  stop, or under framework safety action.
- Terminal-global attempt state survives restart; owned deal history provides
  a second no-reentry guard.
- No averaging, scale-in, pyramiding, grid, martingale, partial close,
  adaptive fit, or random path exists.

## Parameters To Test

| parameter | baseline | authorized values | role |
|---|---:|---|---|
| `strategy_winter_first_month` | 11 | [11] | seasonal BUY interval start |
| `strategy_winter_last_month` | 5 | [5] | seasonal BUY interval end |
| `strategy_history_bars` | 80 | [80] | bounded completed-month reconstruction |
| `strategy_atr_period` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

Changing the season partition, direction, exact one-month endpoint, strict
sign rule, agreement gate, hold, stop, carrier, or retry policy requires a new
card and full pipeline run.

## Risk

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. `RISK_FIXED` is a stop-normalized loss budget, not fixed
notional exposure. No live-risk mode is authorized.

Primary risks are interaction decay, filter-induced under-frequency,
one-month reversal, futures-to-CFD basis, WTI gaps and rolls, financing,
stop-outs, month-end history gaps, source editorial inconsistencies, and
correlation with XNG or directional assets. Retire below five completed
packages/year or on nonpositive governed economics, wrong season/direction,
disagreement trades, current-month leakage, duplicate entry, restart
nondeterminism, missing stop, risk mismatch, or later correlation rejection.
No rescue or waiver is allowed.

## Strategy Allowability Check

- [x] R1 reputable: named-author peer-reviewed papers with durable complete-
  read repository evidence and WTI/commodity applicability.
- [x] R2 mechanical: fixed season directions, two exact endpoints, strict
  sign mapping, agreement entry, renewal, attempt, stop, spread cap, and stale
  exit.
- [x] R3 testable: registered native `XTIUSD.DWX` D1 carrier.
- [x] R4 compliant: deterministic native arithmetic only; no trained output,
  external runtime feed, grid, martingale, scale-in, or pyramiding.
- [x] No exact identity; the expected fuzzy match and all nearest seasonal/
  momentum relatives are manually resolved with load-bearing distinctions.

## Framework Alignment

- no_trade: exact carrier/ID/slot, frozen inputs, month-end history, seasonal
  map, return-sign agreement, spread, attempt, and framework safety gates.
- trade_entry: exact completed-month sign, fixed seasonal direction,
  concordance gate, monthly consumed attempt, fixed-risk sizing, and frozen
  ATR stop.
- trade_management: close-before-renew, wrong-side close, and stale close.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes one branch-only research build, strict compile, one
`RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It does not authorize
a manual backtest; live, demo, or shadow setfiles; AutoTrading; `T_Live`; a
deploy or T_Live manifest; portfolio admission; a portfolio-gate change; or a
correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-05 | initial WTI season / exact one-month momentum concordance | G0 | APPROVED |
| v2 | 2026-08-05 | initial V5 framework implementation | Q01 | PASS; strict compile and build checks |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-05 | APPROVED | `decisions/2026-08-05_wti_seas_mom1_source_g0.md` |
| Q01 Compile / Static Validation | 2026-08-05 | PASS | `framework/build/compile/20260805_171850/QM5_20227_wti-seas-mom1.compile.log`; `D:/QM/reports/framework/21/build_check_20260805_171850.json`; `D:/QM/reports/pipeline/QM5_20227/P1/P1_QM5_20227_result.json` |
| Q02 Baseline Screening | - | NOT_STARTED | - |
