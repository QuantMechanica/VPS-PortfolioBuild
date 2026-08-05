---
card_schema_version: 2
ea_id: QM5_20222
slug: wti-seas-sign
type: strategy
strategy_id: BURAKOV-PAPAILIAS-WTI-SEASIGN-2026_S01
variant_id: BURAKOV-PAPAILIAS-WTI-SEASIGN-2026_S01
source_id: BURAKOV-PAPAILIAS-WTI-SEASIGN-2026
status: APPROVED
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20222_wti-seas-sign_card.md
execution_contract_status: DRAFT
created: 2026-08-05
created_by: Research+Development
last_updated: 2026-08-05
source_authors: "Dmitry Burakov; Max Freidin; Yuriy Solovyev; Fotis Papailias; Jiadong Liu; Dimitrios D. Thomakos"
strategy_mechanic: wti-fixed-seasonal-direction-agrees-with-twelve-completed-month-return-sign-probability
source_citation: "Burakov, Freidin, and Solovyev (2018), International Journal of Energy Economics and Policy 8(2), 121-126; Papailias, Liu, and Thomakos (2021), Journal of Banking & Finance 124, 106063."
source_citations:
  - type: peer_reviewed_open_access_paper
    citation: "Burakov, D., Freidin, M., and Solovyev, Y. (2018). The Halloween Effect on Energy Markets: An Empirical Study. International Journal of Energy Economics and Policy 8(2), 121-126."
    location: "Methods alternative two and WTI Tables 2-3; complete governed review strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md"
    quality_tier: B
    role: seasonal_direction
  - type: peer_reviewed_paper
    citation: "Papailias, F., Liu, J., and Thomakos, D. D. (2021). Return Signal Momentum. Journal of Banking & Finance 124, 106063."
    location: "Sections 2.1, 2.2, and 4; Equations 7 and 10; WTI Tables G.1-G.3; DOI 10.1016/j.jbankfin.2021.106063; complete governed review strategy-seeds/sources/PAPAILIAS-RSM-2021/source.md"
    quality_tier: A
    role: return_sign_state
sources:
  - "[[sources/BURAKOV-PAPAILIAS-WTI-SEASIGN-2026]]"
concepts:
  - "[[concepts/wti-seasonal-direction]]"
  - "[[concepts/return-sign-persistence]]"
  - "[[concepts/seasonal-trend-concordance]]"
indicators:
  - "[[indicators/month-end-close]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, calendar-seasonality, return-sign-state, agreement-filter, symmetric-calendar-map, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "One decision per broker month after thirteen completed month-end closes; estimate six to nine concordant WTI packages/year before Q02 validation."
expected_trades_per_year_per_symbol: 7
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
review_focus: "Falsify whether fixed WTI seasonal direction confirmed by twelve-month return-sign breadth adds direct crude exposure and a physical-season clock absent from the certified XAU/SP500/NDX/XNG book; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [risk_mode, friday_close_hold_semantics, restart_safe_attempt, completed_month_reconstruction, seasonal_direction, concordance_gate, source_to_cfd_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under the OWNER 2026-08-05 commodity/energy sleeve mission: R1 complete peer-reviewed WTI seasonal and return-sign source records; R2 locked winter/summer directions, thirteen completed month ends, twelve binary signs, fixed 0.40 threshold, agreement-only entry, monthly renewal, stop, spread, and attempt state; R3 native XTIUSD.DWX D1 carrier; R4 deterministic native arithmetic only. Deterministic dedup CLEAN; unconditional season, year-round sign-momentum, winter sign-momentum, same-calendar, and RSI relatives are manually resolved."
---

# QM5_20222 WTI Seasonal / Return-Sign Concordance

## Hypothesis

WTI's November-May and June-October return asymmetry reflects recurring
heating demand, refinery transitions, inventory cycles, driving-season flows,
producer hedging, and weather risk. Requiring that fixed physical-season
direction to agree with the distribution of WTI's last twelve completed
monthly return signs may avoid fighting a persistent price state. The result
is a slow conditional crude-oil sleeve whose carrier and clock differ from
the certified XAU/SP500/NDX/XNG book.

This is a falsifiable interaction, not a profitability, decorrelation, or
certification claim. Q02 must establish frequency and economics; the
unchanged downstream portfolio gate alone may measure realized book overlap.

## Source Traceability And Claim Boundary

The governed composite packet is
`strategy-seeds/sources/BURAKOV-PAPAILIAS-WTI-SEASIGN-2026/source.md`.
Burakov, Freidin, and Solovyev supply positive November-May and negative
June-October WTI seasonal directions. Papailias, Liu, and Thomakos supply the
fixed twelve-month binary return-sign probability, 0.40 threshold, direction
map, and one-month renewal.

Neither source tests this concordance rule, a Darwinex continuous CFD,
broker-month reconstruction, fixed cash risk, an ATR stop, or the QM
portfolio. No source return, Sharpe, PF, drawdown, cost, correlation, or
neutrality statistic is imported. Source-label inconsistencies, adverse WTI
drawdown evidence, and the possibility that filtering destroys frequency
remain explicit kill risks.

## Non-Duplicate Decision

The deterministic checker scanned 4,279 registry rows and 395 canonical
cards. It found no exact identity and no fuzzy match above threshold. Manual
mechanic review fixes the boundaries:

- `QM5_20046_wti-halloween-ls` and `QM5_20093_wti-summer-short` take
  unconditional seasonal exposure; this candidate stays flat on disagreement.
- `QM5_13150_wti-signmom` follows the twelve-sign state year-round without a
  fixed seasonal-direction agreement requirement.
- `QM5_20221_wti-win-signmom` follows the sign state symmetrically only in
  November-May and is forced flat June-October. This candidate never shorts
  winter or buys summer and may trade either season only on agreement.
- `QM5_20205_wti-calmom1` combines a ten-year same-calendar mean with the
  immediately completed one-month sign, not twelve binary signs.
- `QM5_20136_wti-caltrend` combines a same-calendar mean with a 63-D1 return
  sign, not the fixed Burakov partition and sign probability.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback above a
  long-horizon filter.

The winter/summer directions, twelve binary signs, fixed 0.40 threshold,
agreement-only entry, disagreement-flat state, and monthly renewal are
jointly load-bearing. Removing either state recreates a built parent.

## Markets, Timeframe, And Cadence

- Carrier: `XTIUSD.DWX`, D1, slot 0, magic `202220000`.
- Decision: first tradable D1 bar of every broker month.
- Seasonal direction: BUY November-May; SELL June-October.
- Formation: thirteen consecutive completed broker-month closes defining
  twelve monthly returns.
- Hold: next broker-month transition, with a forty-calendar-day stale guard.
- Maximum cadence: twelve decisions/year; expected six to nine concordant
  packages/year; retire below five completed packages per full post-warm-up
  year.

## Rules

At the first tradable D1 bar of month `m`, reconstruct the latest thirteen
distinct completed broker-calendar month-end closes, newest first. For each
of the twelve consecutive completed monthly returns, assign `1` when the
return is non-negative and `0` when negative:

`positive_probability = non_negative_return_count / 12`

- November-May and probability at least `0.40`: BUY `XTIUSD.DWX`;
- June-October and probability below `0.40`: SELL `XTIUSD.DWX`;
- any seasonal/sign disagreement or invalid history: remain flat.

No current-month close enters the signal. No unconditional seasonal fallback,
cumulative-return substitute, adaptive threshold, parameter sweep, or
post-result rescue is authorized.

## 4. Entry Rules

1. Require exact EA ID `20222`, `XTIUSD.DWX` D1, magic slot 0, and every
   baseline input locked to the values below.
2. Process lifecycle exits before entry-only gates and evaluate only at a
   genuine broker-month transition.
3. Persist the monthly attempt before history, signal, agreement, spread,
   quote, news, stop, sizing, or order gates.
4. Reject an owned position or a same-month owned entry deal.
5. Reconstruct exactly thirteen completed month-end closes; require the
   newest endpoint to be the just-completed month and all endpoints
   consecutive.
6. Convert the twelve returns to binary signs using non-negative as `1`.
   Classify the sign state long at probability `>= 0.40`, otherwise short.
7. Classify November-May as seasonal long and June-October as seasonal short.
   Continue only if both directions agree.
8. Require spread in `[0,1500]` points, a valid quote, completed
   `ATR(20,D1)`, symbol metadata, fixed-risk mode, and news gates.
9. Open one market position with a `3.5 * ATR(20,D1)` hard stop and no
   take-profit. Framework fixed-risk sizing remains authoritative.

## 5. Exit Rules

1. Close the prior position on the first tradable D1 bar of every new broker
   month before considering replacement risk.
2. Close any position after forty calendar days as a stale guard.
3. Broker hard stops and the framework kill switch remain authoritative.
4. Friday close is disabled because the source hold spans weekends.
5. No intramonth signal flip, target, trail, break-even, partial close,
   scale-in, grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbol, D1 timeframe, EA ID, slot, and frozen
  input contract.
- Reject malformed/nonconsecutive month endpoints, nonpositive prices,
  invalid returns, disagreement, invalid ATR/quote/point metadata, negative
  or excessive spread, consumed attempt, same-month deal, or open position.
- Q02 freezes both news axes and legacy news mode OFF. No external calendar,
  futures chain, inventory, volume, open interest, CSV, API, or forecast is
  read at runtime.

## 7. Trade Management Rules

- One position maximum for magic `202220000` and one consumed attempt per
  broker month.
- Close before renewal, after forty days, on the hard stop, or under framework
  safety action.
- Terminal-global attempt state survives restart; owned deal history provides
  a second no-reentry guard.
- No hedge, averaging, scale-in, pyramiding, grid, martingale, partial close,
  adaptive fit, or random path exists.

## Parameters To Test

| parameter | baseline | authorized values | role |
|---|---:|---|---|
| `strategy_winter_first_month` | 11 | [11] | seasonal long interval start |
| `strategy_winter_last_month` | 5 | [5] | seasonal long interval end |
| `strategy_lookback_months` | 12 | [12] | source return-sign window |
| `strategy_positive_threshold` | 0.40 | [0.40] | fixed source direction threshold |
| `strategy_history_bars` | 500 | [500] | bounded month-end reconstruction |
| `strategy_atr_period` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

Changing the season partition, direction, binary-sign definition, threshold,
agreement rule, hold, stop, carrier, or retry policy requires a new card and
full pipeline run.

## Risk

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. `RISK_FIXED` is a stop-normalized loss budget, not fixed
notional exposure. No live-risk mode is authorized.

Primary risks are one-name breadth, interaction decay, filter-induced
under-frequency, futures-to-CFD basis, WTI gaps and rolls, financing,
stop-outs, month-end history gaps, source editorial inconsistencies, adverse
source drawdown, and correlation with XNG or directional assets. Retire below
five completed packages/year or on nonpositive governed economics, wrong
season/direction, disagreement trades, current-month leakage, duplicate
entry, restart nondeterminism, missing stop, risk mismatch, or later
correlation rejection. No rescue or waiver is allowed.

## Strategy Allowability Check

- [x] R1 reputable: named-author peer-reviewed papers with durable
  complete-read repository evidence and WTI-specific results.
- [x] R2 mechanical: fixed season directions, thirteen endpoints, twelve
  binary signs, threshold, agreement mapping, renewal, attempt, stop, spread
  cap, and stale exit.
- [x] R3 testable: registered native `XTIUSD.DWX` D1 carrier.
- [x] R4 compliant: deterministic native arithmetic only; no trained model,
  external runtime feed, grid, martingale, scale-in, or pyramiding.
- [x] No exact or fuzzy identity; all nearest seasonal/sign relatives are
  manually resolved with load-bearing distinctions.

## Framework Alignment

- no_trade: exact carrier/ID/slot, frozen inputs, month-end history, seasonal
  map, sign-state agreement, spread, attempt, and framework safety gates.
- trade_entry: twelve-return sign probability, fixed seasonal direction,
  concordance gate, monthly consumed attempt, fixed-risk sizing, and frozen
  ATR stop.
- trade_management: close-before-renew and stale close.
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
| v1 | 2026-08-05 | initial WTI seasonal/sign concordance candidate | G0 | APPROVED |
| v2 | 2026-08-05 | initial framework implementation | Q01 | PASS; strict compile and build checks |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-05 | APPROVED | `decisions/2026-08-05_qm5_20222_wti_seas_sign_g0.md` |
| Q01 Compile / Static Validation | 2026-08-05 | PASS | `framework/build/compile/20260805_084246/QM5_20222_wti-seas-sign.compile.log`; `D:/QM/reports/framework/21/build_check_20260805_084339.json` |
| Q02 Baseline Screening | - | NOT_ENQUEUED | - |
