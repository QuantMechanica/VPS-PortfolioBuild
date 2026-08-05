---
card_schema_version: 2
ea_id: QM5_20231
slug: wti-seas-mom12
type: strategy
strategy_id: BURAKOV-MOP-WTI-SEASMOM12-2026_S01
variant_id: BURAKOV-MOP-WTI-SEASMOM12-2026_S01
source_id: BURAKOV-MOP-WTI-SEASMOM12-2026
status: APPROVED
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20231_wti-seas-mom12_card.md
execution_contract_status: DRAFT
created: 2026-08-05
created_by: Research+Development
last_updated: 2026-08-05
source_authors: "Dmitry Burakov; Max Freidin; Yuriy Solovyev; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
strategy_mechanic: wti-fixed-physical-season-direction-agrees-with-exact-completed-twelve-calendar-month-cumulative-return-sign
source_citation: "Burakov, Freidin, and Solovyev (2018), International Journal of Energy Economics and Policy 8(2), 121-126; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: peer_reviewed_open_access_paper
    citation: "Burakov, D., Freidin, M., and Solovyev, Y. (2018). The Halloween Effect on Energy Markets: An Empirical Study. International Journal of Energy Economics and Policy 8(2), 121-126."
    location: "Methods alternative two and WTI Tables 2-3; complete governed review strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md"
    quality_tier: B
    role: physical_season_direction
  - type: peer_reviewed_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "Section 3.2 selected twelve-month rule and Appendix A WTI universe; DOI 10.1016/j.jfineco.2011.11.003; complete governed review strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: completed_twelve_month_return_sign
sources:
  - "[[sources/BURAKOV-MOP-WTI-SEASMOM12-2026]]"
concepts:
  - "[[concepts/wti-seasonal-direction]]"
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/calendar-trend-concordance]]"
indicators:
  - "[[indicators/month-end-close]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, calendar-seasonality, twelve-month-momentum, agreement-filter, symmetric-calendar-map, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 202310000
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "One decision per broker month after thirteen consecutive completed month-end closes; estimate five to eight concordant WTI packages/year before Q02 validation."
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
q01_status: NOT_STARTED
q02_status: NOT_STARTED
review_focus: "Falsify whether fixed WTI physical-season direction confirmed by the exact completed twelve-calendar-month cumulative return adds direct crude exposure and a slow structural clock absent from the certified XAU/SP500/NDX/XNG book; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [risk_mode, friday_close_hold_semantics, restart_safe_attempt, completed_month_reconstruction, seasonal_direction, concordance_gate, source_to_cfd_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under the OWNER 2026-08-05 commodity/energy sleeve mission: R1 complete peer-reviewed WTI physical-season and twelve-month time-series-momentum source records; R2 locked winter/summer directions, thirteen consecutive completed month ends, strict cumulative-return sign, agreement-only entry, monthly renewal, stop, spread, and attempt state; R3 registered native XTIUSD.DWX D1 carrier; R4 deterministic native arithmetic only. Deterministic dedup found no exact identity and four expected wti-seas-* fuzzy matches; the year-round parent, winter and summer 252-D1 interactions, sign-breadth, one-month, same-calendar, weekday, gap, reversal, and RSI relatives are manually resolved."
---

# QM5_20231 WTI Physical-Season / Twelve-Month Momentum Concordance

## Hypothesis

WTI's November-May versus June-October return asymmetry reflects recurring
heating demand, refinery transitions, inventory cycles, driving-season flows,
producer hedging, and weather risk. Requiring the fixed physical-season
direction to agree with WTI's exact completed twelve-calendar-month own return
may avoid carrying that seasonal prior against a persistent slow price state.
The result is a monthly direct-crude sleeve whose carrier and information
clock differ from the certified XAU, SP500, NDX, and XNG book.

This is a falsifiable interaction, not a profitability, decorrelation,
certification, or portfolio-admission claim. Q02 must establish frequency and
economics. The unchanged downstream portfolio gate alone may measure realized
book overlap.

## Source Traceability And Claim Boundary

The governed composite packet is
`strategy-seeds/sources/BURAKOV-MOP-WTI-SEASMOM12-2026/source.md`. Burakov,
Freidin, and Solovyev supply positive November-May and negative June-October
WTI physical-season directions. Moskowitz, Ooi, and Pedersen supply the sign
of a completed twelve-month own return as a monthly futures direction state.

Neither source tests this concordance, a WTI-only seasonal momentum result,
Darwinex continuous CFDs, broker-month reconstruction, fixed cash risk, an
ATR stop, costs, financing, or the QM portfolio. No source return,
significance, Sharpe, PF, drawdown, cost, correlation, or neutrality statistic
is imported.

## Non-Duplicate Decision

The deterministic pre-allocation checker scanned 4,288 registry rows and 404
canonical cards. It found no exact identity and four expected fuzzy matches
to the `wti-seas-*` family. Manual mechanic review fixes the boundaries:

- `QM5_20046_wti-halloween-ls` is unconditional seasonal exposure; this
  candidate stays flat when price and season disagree.
- `QM5_12603_wti-tsmom12m` follows the twelve-month state year-round and has
  no physical-season agreement requirement.
- `QM5_20135_wti-winter-trend` uses completed shifts 1 and 253, permits either
  direction only in November-May, and never trades summer. This candidate
  reconstructs exact calendar-month endpoints, never shorts winter, and can
  sell in June-October only on agreement.
- `QM5_20141_wti-sumtrend` is a weekly July-November short-only interaction
  with a different source season and lifecycle.
- `QM5_20222_wti-seas-sign` counts twelve individual return signs at a fixed
  `0.40` threshold. This candidate uses one cumulative twelve-month endpoint
  return and has no breadth estimator.
- `QM5_20227_wti-seas-mom1` uses only the exact immediately completed month.
- `QM5_20205_wti-calmom1` uses a ten-year same-calendar mean and one-month
  sign; `QM5_20226`, `QM5_20229`, and `QM5_20230` use weekday, one-month
  reversal, or weekend-gap information objects.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback above a
  slow filter, not a monthly energy calendar/trend interaction.

The exact twelve completed calendar months, fixed winter/summer directions,
agreement-only entry, disagreement-flat state, and monthly lifecycle are
jointly load-bearing.

## Markets, Timeframe, And Cadence

- Carrier: `XTIUSD.DWX`, D1, slot 0, magic `202310000`.
- Decision: first tradable D1 bar of each broker-calendar month.
- Seasonal direction: BUY November-May; SELL June-October.
- Formation: thirteen consecutive completed broker-month-end closes defining
  the cumulative return across exactly twelve completed calendar months.
- Hold: next broker-month transition, with a forty-calendar-day stale guard.
- Maximum cadence: twelve decisions/year; expected five to eight concordant
  packages/year; retire below five packages per full post-warm-up year.

## Rules

At the first tradable D1 bar of month `m`, reconstruct the latest thirteen
distinct completed broker-calendar month-end closes, newest first. Require the
newest endpoint to be the month immediately before `m` and every endpoint to
be consecutive. Calculate:

`momentum = ln(newest_completed_month_close / oldest_completed_month_close)`

- November-May and strictly positive momentum: BUY `XTIUSD.DWX`.
- June-October and strictly negative momentum: SELL `XTIUSD.DWX`.
- Any disagreement, exact zero, or invalid history: consume the month and
  remain flat.

No current-month price enters the signal. No unconditional seasonal fallback,
D1-bar approximation, binary-sign breadth substitute, deadband, parameter
sweep, or post-result rescue is authorized.

## 4. Entry Rules

1. Require exact EA ID `20231`, `XTIUSD.DWX` D1, magic slot 0, and every
   baseline input locked to the values below.
2. Process lifecycle exits before entry-only gates and evaluate only at a
   genuine broker-month transition.
3. Persist the monthly attempt before history, signal, agreement, spread,
   quote, news, stop, sizing, or order gates.
4. Reject an owned position or a same-month owned entry deal.
5. Reconstruct exactly thirteen consecutive completed month-end closes and
   require the newest endpoint to be the just-completed month.
6. Map a strictly positive cumulative return to BUY and a strictly negative
   return to SELL; equality is flat.
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
- Reject malformed or nonconsecutive month endpoints, nonpositive prices,
  invalid or zero cumulative return, disagreement, invalid ATR/quote/point
  metadata, negative or excessive spread, consumed attempt, same-month deal,
  or an open owned position.
- Q02 freezes both news axes and legacy news mode OFF. Runtime reads no
  external calendar, futures chain, inventory, volume, open interest, file,
  API, or forecast.

## 7. Trade Management Rules

- One position maximum for magic `202310000` and one consumed attempt per
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
| `strategy_lookback_months` | 12 | [12] | exact completed-month formation horizon |
| `strategy_history_bars` | 500 | [500] | bounded month-end reconstruction |
| `strategy_atr_period` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

Changing the season partition, direction, exact twelve-month endpoints,
strict sign, agreement gate, hold, stop, carrier, or retry policy requires a
new card and full pipeline run.

## Risk

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. `RISK_FIXED` is a stop-normalized loss budget, not fixed
notional exposure. No live-risk mode is authorized.

Primary risks are interaction decay, filter-induced under-frequency,
twelve-month reversal, futures-to-CFD basis, WTI gaps and rolls, financing,
stop-outs, month-end history gaps, source editorial inconsistencies, and
correlation with XNG or directional assets. Retire below five completed
packages/year or on nonpositive governed economics, wrong season/direction,
disagreement trades, endpoint leakage, duplicate entry, restart
nondeterminism, missing stop, risk mismatch, or later correlation rejection.
No rescue or waiver is allowed.

## Strategy Allowability Check

- [x] R1 reputable: named-author peer-reviewed papers with durable complete-
  read repository evidence and WTI/commodity applicability.
- [x] R2 mechanical: fixed season directions, thirteen exact endpoints,
  strict cumulative sign, agreement entry, renewal, attempt, stop, spread cap,
  and stale exit.
- [x] R3 testable: registered native `XTIUSD.DWX` D1 carrier.
- [x] R4 compliant: deterministic native arithmetic only; no trained output,
  external runtime feed, grid, martingale, scale-in, or pyramiding.
- [x] No exact identity; all nearest seasonal/trend relatives are manually
  resolved with load-bearing distinctions.

## Framework Alignment

- no_trade: exact carrier/ID/slot, frozen inputs, month-end history, seasonal
  map, cumulative-return agreement, spread, attempt, and framework gates.
- trade_entry: twelve-month return sign, fixed seasonal direction,
  concordance gate, monthly consumed attempt, fixed-risk sizing, and frozen
  ATR stop.
- trade_management: close-before-renew, wrong-side close, and stale close.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes one branch-only research build, strict compile, one
`RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It does not authorize
a manual backtest; live, demo, or shadow setfiles; AutoTrading; `T_Live`; a
deploy or T_Live manifest; portfolio admission; a portfolio-gate change; or
a correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-05 | initial WTI physical-season / twelve-month momentum concordance | G0 | APPROVED |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-05 | APPROVED | `decisions/2026-08-05_qm5_20231_wti_seas_mom12_g0.md` |
| Q01 Compile / Static Validation | - | NOT_STARTED | - |
| Q02 Baseline Screening | - | NOT_STARTED | - |
