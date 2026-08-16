---
card_schema_version: 2
type: strategy
strategy_id: WILLIAMS-SCHWEIKERT-XAUXAG-FLOWDIV-2026_S01
variant_id: WILLIAMS-SCHWEIKERT-XAUXAG-FLOWDIV-2026_S01
source_id: WILLIAMS-SCHWEIKERT-XAUXAG-FLOWDIV-2026
ea_id: QM5_41030
slug: xauxag-flowdiv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41030_xauxag-flowdiv_card.md
execution_contract_status: APPROVED
created: 2026-08-16
created_by: Research+Development
last_updated: 2026-08-16
g0_status: APPROVED
g0_decision: decisions/2026-08-16_xauxag_relative_flow_divergence_g0.md
source_approval: decisions/2026-08-16_xauxag_relative_flow_divergence_source_approval.md
source_author: "Larry R. Williams; Karsten Schweikert; CME Group"
source_authors: "Larry R. Williams; Karsten Schweikert; CME Group"
source_citation: "Williams (1999), Long-Term Secrets to Short-Term Trading, Wiley Trading; Schweikert (2018), Journal of Banking & Finance 88, 44-51; CME Group, Gold & Silver Ratio Spread."
source_citations:
  - type: practitioner_book
    citation: "Williams, L. R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading."
    location: "OWNER-supplied Tier-A extraction at strategy-seeds/sources/SRC03/source.md; Pro-Go close/open decomposition in raw/probe_pp15-30.txt, PDF page 18"
    quality_tier: A
    role: close_to_open_and_open_to_close_price_flow_decomposition
  - type: peer_reviewed_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; governed complete-read packets at strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md and SCHWEIKERT-QC-2018/source.md"
    quality_tier: A
    role: state_dependent_gold_silver_relationship
  - type: exchange_research
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: "Governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: B
    role: precious_metals_intermarket_carrier
strategy_mechanic: exact-prior-monday-friday-synchronized-xau-minus-xag-close-open-versus-open-close-strict-disagreement-follow-session-next-monday-paired-friday-flat
sources:
  - "[[sources/WILLIAMS-SCHWEIKERT-XAUXAG-FLOWDIV-2026]]"
concepts:
  - "[[concepts/price-flow-decomposition]]"
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/logical-basket]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, relative-value, price-flow-decomposition, weekly-flow-divergence, logical-basket, weekly-entry, friday-close, atr-hard-stop, low-frequency]
markets: [commodities, precious_metals, gold, silver]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41030_XAU_XAG_FLOWDIV_D1
symbol: QM5_41030_XAU_XAG_FLOWDIV_D1
host_symbol: XAUUSD.DWX
symbol_slot: 0
magic: 410300000
companion_symbol: XAGUSD.DWX
companion_symbol_slot: 1
companion_magic: 410300001
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 15-30 completed XAU/XAG packages per full post-warm-up year after exact-week, synchronization, and strict relative-flow disagreement gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 22
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_DISCLOSED_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: G0
q01_status: NOT_RUN
q02_status: NOT_ENQUEUED
review_focus: "Falsify an exact-calendar XAU/XAG weekly relative-flow-disagreement package designed to suppress common precious-metal direction: verify every completed close/open endpoint, cross-metal subtraction, strict opposition, session-following sides, basket atomicity, and Friday flattening. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_synchronized_week, completed_close_open_endpoints, cross_metal_subtraction, strict_flow_disagreement, monday_decision_clock, weekly_attempt_state, no_current_bar_leakage, no_late_restart_entry, basket_atomicity, aggregate_fixed_risk, notional_mismatch, magic_schema, paired_friday_close, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 OWNER-supplied Tier-A flow decomposition plus peer-reviewed and exchange gold/silver carrier lineage with disclosed conjunction risk; R2 exact sequence, endpoints, subtraction, disagreement, sides, attempt, timing, sizing, atomicity, and lifecycle; R3 native synchronized XAU/XAG D1 only; R4 deterministic arithmetic without banned signal or trained logic; canonical dedup was clean and manual review fixed all material family boundaries."
---

# QM5_41030 XAU/XAG Weekly Relative-Flow Divergence

## Hypothesis

Gold and silver share broad precious-metal drivers but react differently to
monetary, safe-haven, and industrial information. When their completed prior-
week close-to-open relative flow points against their open-to-close relative
flow, the session component may contain a cleaner directional signal than the
overnight displacement. The candidate follows that session-relative side with
opposite XAU/XAG legs from the next Monday through Friday.

This is a falsifiable price-flow and calendar translation. The opposite legs
remove some common precious-metal direction, but do not prove dollar, beta,
volatility, factor, market, or portfolio neutrality.

## Source Traceability And Claim Boundary

The sole governed composite packet is
`strategy-seeds/sources/WILLIAMS-SCHWEIKERT-XAUXAG-FLOWDIV-2026/source.md`,
approved before card extraction in
`decisions/2026-08-16_xauxag_relative_flow_divergence_source_approval.md` at
commit `ee6468d58`.

Williams supplies the prior-close-to-open and open-to-close daily price-flow
objects and discusses their divergence. Schweikert supplies a state-dependent
gold/silver relationship with adverse evidence against a constant automatically
tradable equilibrium. CME supplies the intermarket ratio/spread carrier.

The five-session sums, gold-minus-silver subtraction, strict disagreement,
session-following direction, exact calendar sequence, synchronized Darwinex
CFDs, Monday grace, Friday lifecycle, equal-notional constraint, fixed-dollar
risk, hard stops, spread caps, and attempt ledger are disclosed QM choices.
No source return, alpha, coefficient, significance, density, drawdown, cost,
neutrality, CFD equivalence, decorrelation, or portfolio result transfers.

## Non-Duplicate Decision

The deterministic pre-allocation checker scanned 4,517 EA-registry rows and
613 root-card files. It found no exact or fuzzy match. Manual review fixes the
load-bearing boundaries:

- `QM5_20019_xauxag-wkend` is a fixed XAU-long/XAG-short Friday-to-Monday
  exposure. This card uses a conditional prior-week decomposition and holds
  the selected opposite-leg package Monday-to-Friday.
- Ratio, OLS, MAD, empirical-tail, failed-break, seasonal-surprise, and CADF
  systems trade relative levels or fitted residuals. This card estimates no
  ratio level, center, scale, regression, quantile, or stationarity state.
- XAU/XAG cross-sectional momentum systems use monthly close-to-close returns.
  This card requires opposing weekly overnight and session components and
  follows only the session component.
- `QM5_20275_gsr-runfade` fades a fresh same-sign ratio-return run and exits on
  a counter-return. This card has neither a run nor a counter-return exit.
- `QM5_41029_wti-flow-agree` is single-leg WTI and requires component
  agreement. This card is a two-leg cross-metal carrier and requires strict
  disagreement.
- `QM5_12567_cum-rsi2-commodity` is an oscillator pullback, not an exact-clock
  two-leg price-flow decomposition.

Verdict:
`CLEAN_XAUXAG_WEEKLY_RELATIVE_FLOW_DISAGREEMENT_SESSION_FOLLOW_AFTER_FAMILY_REVIEW`.

## Markets, Clock, And Formula

- Logical basket: `QM5_41030_XAU_XAG_FLOWDIV_D1`.
- Host/traded slot 0: `XAUUSD.DWX`, D1, magic `410300000`.
- Companion/traded slot 1: `XAGUSD.DWX`, D1, magic `410300001`.
- Decision clock: first executable tick of an eligible broker Monday.
- Entry grace: no later than 180 minutes after the synchronized current D1
  open.
- Formation: exact synchronized completed prior Monday-through-Friday week,
  plus the preceding Friday close as the first overnight anchor.
- Normal exit: paired close on or after broker Friday hour 21.
- Expected cadence: approximately 15-30 completed packages/year.

For each prior-week completed session `d`:

```text
xau_overnight[d] = ln(XAU_open[d] / XAU_close[prior_session])
xag_overnight[d] = ln(XAG_open[d] / XAG_close[prior_session])
xau_session[d]   = ln(XAU_close[d] / XAU_open[d])
xag_session[d]   = ln(XAG_close[d] / XAG_open[d])

overnight_relative = sum(xau_overnight[d] - xag_overnight[d])
session_relative   = sum(xau_session[d]   - xag_session[d])
```

## Rules

The rules below are the complete authorized baseline. No ratio-level,
magnitude, volatility, month, event, curve, volume, oscillator, range,
breakout, regression, quantile, or external-data signal filter is authorized.

## 4. Entry Rules

1. Evaluate entry only on a new `XAUUSD.DWX` D1 bar while attached to exact
   `XAUUSD.DWX`, D1, EA ID 41030, slot 0.
2. Process orphan, malformed-package, wrong-side, duplicate, stale, and Friday
   exits before every entry-only gate.
3. Require the broker date to be Monday and the current XAU/XAG D1 timestamps
   to match exactly. Require that shared date to equal the broker date.
4. Read exactly six immediately preceding completed bars from both symbols.
   Require exact cross-symbol timestamp equality at every shift and strict
   newest-to-oldest order.
5. Require the completed shared dates, newest first, to be prior Friday,
   Thursday, Wednesday, Tuesday, Monday, and the preceding Friday at exact
   offsets 3, 4, 5, 6, 7, and 10 calendar days. A missing or shifted holiday
   session consumes the week flat; it is never substituted.
6. Derive the attempt key from the exact current broker Monday `yyyymmdd`.
   Persist it before history validation, return calculation, news, spread,
   quote, ATR, sizing, or order gates. Never retry that Monday.
7. Require elapsed time from the synchronized D1 open to be between zero and
   180 minutes. A later attachment consumes the attempt and never backfills.
8. For shifts 5 through 1 on both symbols, require positive finite
   `Open[shift]`, `Close[shift]`, and `Close[shift+1]`.
9. Compute the two five-session relative-flow sums exactly as defined above.
   The current Monday price enters neither sum.
10. If `session_relative > 0` and `overnight_relative < 0`, BUY XAU and SELL
    XAG. If `session_relative < 0` and `overnight_relative > 0`, SELL XAU and
    BUY XAG. Agreement, exact zero, or invalid arithmetic consumes the week.
11. Require valid completed-bar ATR(20,D1) for both legs. Place frozen per-leg
    hard stops at `3.0 * ATR`; use no take-profit.
12. Target equal absolute USD notionals, round volumes down only, reject
    notional mismatch above 20%, and scale the package so combined stop loss
    does not exceed one `RISK_FIXED=1000` budget.
13. Require valid quotes and no genuinely positive spread above 1,500 points
    on either leg. Modeled zero `.DWX` spread is valid.
14. Submit both market legs once. If either fails, immediately close the
    survivor and consume the week. No pending order, retry, scale-in, grid,
    martingale, pyramid, or standalone leg exists.

## 5. Exit Rules

1. Close both legs together on the first observable tick at or after broker
   Friday 21:00. Framework Friday close remains enabled as a fail-safe.
2. Close a surviving package on the first observable D1 boundary belonging to
   a later broker week. This is stale repair, not a new signal.
3. Close both legs after eight elapsed calendar days as a final stale guard.
4. Immediately flatten an orphan, duplicate, same-direction, wrong-symbol,
   wrong-magic, missing-stop, invalid-volume, or invalid-open-time package.
5. Per-leg frozen hard stops and the framework kill switch remain
   authoritative.
6. No target, opposite-flow exit, trailing stop, break-even move, partial exit,
   discretionary close, or Friday override is authorized.

## 6. Filters (No-Trade Module)

- Exact host `XAUUSD.DWX`, companion `XAGUSD.DWX`, and D1 period.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes are OFF; the signal uses completed native prices and a fixed
  weekly lifecycle.
- Friday close is ON at broker hour 21 and is load-bearing.
- Both current and completed D1 histories must be exactly synchronized.
- History, weekday continuity, opening grace, quotes, spreads, ATR, sizing,
  and hedge mismatch must be valid.
- Failure at any fallible gate after attempt persistence consumes the Monday.

## 7. Trade Management Rules

- Own at most one logical package: one XAU position under magic `410300000`
  and one XAG position under magic `410300001` in opposite directions.
- Freeze both original broker hard stops; never widen, trail, or remove them.
- Run malformed, orphan, and stale repair on every tick before entry logic.
- If one leg exits or disappears, close the other immediately.
- Persist the last attempted broker-Monday key in terminal global state so a
  restart cannot create a second weekly attempt.
- Do not add, pyramid, grid, hedge beyond the defined companion leg, partially
  close, or reverse an owned package.

## Risk

- Backtest only: one logical package `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- The combined frozen-stop loss of both legs must not exceed the one package
  budget after volume rounding.
- Target equal absolute USD notionals and reject post-rounding mismatch above
  20%. This suppresses common metal direction but proves no neutrality.
- Baseline hard stop on each leg: `3.0 * ATR(20,D1)` from completed data.
- No take-profit and no signal-magnitude sizing.
- Invalid stop distance, tick value, tick size, contract size, volume step,
  minimum volume, computed lot, or package mismatch consumes the week.
- This card creates no live, demo, shadow, stress, or optimization preset.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_atr_period_d1` | 20 | completed-bar risk range for both legs |
| `strategy_atr_sl_mult` | 3.0 | frozen per-leg hard-stop distance |
| `strategy_xau_max_spread_points` | 1500 | XAU entry cost guard |
| `strategy_xag_max_spread_points` | 1500 | XAG entry cost guard |
| `strategy_entry_grace_minutes` | 180 | restart-safe Monday boundary |
| `strategy_max_notional_mismatch_pct` | 20.0 | post-rounding hedge guard |
| `strategy_max_hold_days` | 8 | stale repair only |
| `qm_friday_close_enabled` | true | paired weekly exit fail-safe |
| `qm_friday_close_hour_broker` | 21 | paired exit clock |

No parameter sweep, after-result threshold, flow-sign, side, weekday,
component, hedge, or lifecycle change is authorized by this card.

## Data Requirements

- Native synchronized `XAUUSD.DWX` and `XAGUSD.DWX` D1 OHLC and tick
  timestamps from the registered factory history route.
- Native broker clock, symbol quotes/properties, positions, deal history, and
  terminal global variables.
- No external market-data API, futures curve, inventory series, analyst
  forecast, CSV feed, or manually maintained event calendar.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, attempt, synchronized history, flows, sides, spreads, ATR, sizing, atomic entry | Trade Entry | `Strategy_EntrySignal` plus deterministic basket helpers |
| malformed/orphan/stale repair and Friday paired close | Trade Management | `Strategy_ManageOpenPosition` plus basket lifecycle helper |
| paired Friday and stale lifecycle | Trade Close | strategy helper closes both; framework Friday close is fail-safe |
| kill switch, session ownership, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | `Strategy_NewsFilterHook` returns false; both modes OFF |

## Kill Criteria

Retire rather than tune on fewer than five completed packages per full post-
warm-up year; zero trades; nonpositive governed economics; wrong weekday
sequence or synchronization; current-bar leakage; incorrect endpoints,
subtraction, disagreement, or sides; late/repeated entry; package-risk or
notional-mismatch breach; orphan survival; wrong Friday/stale lifecycle;
nondeterminism; or registry/risk-mode mismatch.

No weak result may be rescued by adding a threshold, using flow agreement,
reversing the session direction, changing the carrier/clock, fitting a ratio,
or extending the hold.

## Validation Plan

Q01 must prove:

1. exact prior-week sequences and cross-symbol timestamps accept only the
   intended completed Monday-through-Friday history plus anchor;
2. all four sign combinations, equality, and invalid prices select only strict
   disagreement and the correct session-following opposite-leg sides;
3. arithmetic uses all twenty completed close/open return components and no
   current-Monday price;
4. persistent attempts prevent same-Monday retry after every downstream
   failure and restart;
5. joint sizing respects one fixed-dollar budget, equal-notional target,
   volume rounding, mismatch cap, and per-leg frozen ATR stops;
6. partial-order failure, orphan repair, paired Friday exit, later-week repair,
   and eight-day stale guard remain reachable; and
7. strict compile, card lint, build checks, setfile schema, basket manifest,
   magic resolver, and static Q01 validation pass.

Q02 alone may measure density and baseline economics. Q09 alone may establish
realized correlation with the certified book.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-16 | initial XAU/XAG relative-flow divergence extraction | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-16 | APPROVED | `decisions/2026-08-16_xauxag_relative_flow_divergence_g0.md` |
| Q01 Build Validation | - | NOT_RUN | - |
| Q02 Baseline Screening | - | NOT_ENQUEUED | - |

## Safety Boundary

This card authorizes a non-live build, Q01 validation, one logical-basket D1
backtest setfile, and one paced Q02 enqueue. It does not authorize a manual
backtest, tester control, live/demo/shadow/stress/optimization preset,
AutoTrading, `T_Live`, a deploy or T_Live manifest, portfolio-gate change,
portfolio admission, neutrality claim, or correlation waiver.
