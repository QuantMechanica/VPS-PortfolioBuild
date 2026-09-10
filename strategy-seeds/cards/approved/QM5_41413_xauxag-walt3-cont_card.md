---
card_schema_version: 2
type: strategy
strategy_id: FMR-CME-XAUXAG-WALT3-CONT-20260910_S01
variant_id: FMR-CME-XAUXAG-WALT3-CONT-20260910_S01
source_id: FMR-CME-XAUXAG-WALT3-CONT-20260910
ea_id: QM5_41413
slug: xauxag-walt3-cont
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41413_xauxag-walt3-cont_card.md
execution_contract_status: APPROVED
created: 2026-09-10
created_by: Research+Development
last_updated: 2026-09-10
g0_status: APPROVED
g0_decision: decisions/2026-09-10_qm5_41413_xauxag_weekly_alternation_continuation_g0.md
source_approval: decisions/2026-09-10_xauxag_weekly_alternation_continuation_source_approval.md
source_author: "Ana-Maria Fuertes; Joelle Miffre; Georgios Rallis; CME Group; OpenAI Codex"
source_citation: "Fuertes, Miffre, and Rallis (2010), Journal of Banking & Finance 34(10), 2530-2548, DOI 10.1016/j.jbankfin.2010.04.009; CME Group Gold & Silver Ratio Spread."
source_citations:
  - type: peer_reviewed_plus_exchange_bounded_mechanization
    citation: "Fuertes-Miffre-Rallis commodity momentum evidence plus CME gold/silver ratio and intermarket-spread lineage; QuantMechanica governed weekly alternation translation."
    location: strategy-seeds/sources/FMR-CME-XAUXAG-WALT3-CONT-20260910/source.md
    quality_tier: A_lineage_with_alternation_translation_risk
    role: commodity_momentum_lineage_and_gold_silver_relative_value_carrier
strategy_mechanic: normalized-week-boundary-xau-xag-four-synchronized-completed-week-endpoints-three-adjacent-relative-log-returns-strict-sign-alternation-newest-relative-winner-continuation-equal-notional-one-week-basket
strategy_type_flags: [commodity, precious-metals, gold-silver-relative-value, market-neutral-basket, three-week-sign-alternation, newest-winner-continuation, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41413_XAU_XAG_WALT3_CONT_D1
symbol: QM5_41413_XAU_XAG_WALT3_CONT_D1
host_symbol: XAUUSD.DWX
companion_symbol: XAGUSD.DWX
symbol_slots: [0, 1]
magic_numbers: [414130000, 414130001]
period: D1
timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately eight to sixteen completed paired packages per full post-warm-up year after strict three-week alternation, synchronization, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_ALTERNATION_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: D1; native synchronized XAU/XAG labels; four immediately preceding consecutive week endpoints; three strict alternating relative log-return signs; epsilon 1e-10; newest-winner continuation; 45 D1 bars; 180-minute entry grace; aggregate fixed risk; 3.5*ATR(20,D1) frozen per-leg stops; 20% notional mismatch cap; 10-day stale repair; XAU/XAG spread ceilings 1500/500."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: G0
q01_status: PENDING_BUILD
q02_status: NOT_ENQUEUED
force_build: true
review_focus: "Falsify a strict three-completed-week XAU/XAG relative-sign alternation continuation outside the certified directional XAU/SP500/NDX/XNG book. Verify four consecutive synchronized completed-week endpoints, exact strict alternation, newest-winner continuation, durable weekly attempt, aggregate fixed risk, atomic package repair, and next-week lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xau_xag_carrier, immediately_preceding_four_monday_anchors, synchronized_completed_d1_closes, three_to_five_week_sessions, three_adjacent_relative_returns, strict_nonzero_return_differences, exact_sign_alternation, newest_winner_continuation, persistent_week_attempt, equal_notional_basket, aggregate_fixed_risk, hard_stops_present, atomic_package_repair, next_week_exit, risk_mode_dual, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 preserves one governed source packet with peer-reviewed commodity-momentum and official exchange carrier lineage while disclosing the untested weekly alternation translation; R2 locks endpoints, signs, continuation direction, lifecycle, and risk; R3 uses registered native XAU/XAG D1 data; R4 uses deterministic non-trained arithmetic. No exact duplicate exists; QM5_41410 takes the opposite side, the energy-carrier analogue also fades, and same-sign streak and monthly-rank siblings use different state objects."
---

# QM5_41413 XAU/XAG Weekly Alternation Continuation

## Hypothesis

Three strict weekly reversals in the XAU-minus-XAG relative leader may identify
a state in which the newest relative move still carries information. The EA
follows the newest relative winner for one week with opposed XAU/XAG legs. This is market-neutral by construction
intent only; Q09 alone may establish realized correlation, and the sources do
not establish the exact edge.

## Source Traceability And Non-Duplicate Decision

The approved source of record is
`strategy-seeds/sources/FMR-CME-XAUXAG-WALT3-CONT-20260910/source.md`.
Fuertes, Miffre, and Rallis supply peer-reviewed cross-sectional commodity-
momentum lineage, while CME defines the ratio and intermarket-spread carrier.
Neither defines this weekly alternation signal or two-metal CFD port.

The canonical checker found no exact identity. `QM5_41410` uses the same state
and carrier but fades the newest winner; that opposite side is the complete
economic hypothesis. `QM5_41373` fades the analogous state on the economically
different XTI/XNG carrier. `QM5_41078` requires a
fresh same-sign XAU/XAG streak; `QM5_41066` and `QM5_41075` through `QM5_41077`
use only two relative returns plus magnitude states. This card uniquely joins
XAU/XAG, four consecutive synchronized completed-week endpoints, exact
three-return alternation, newest-winner continuation, and a one-week package lifecycle.

## Rules

## 4. Entry Rules

### Market, clock, and data

- Host `input strategy_host_symbol=XAUUSD.DWX`; companion
  `input strategy_companion_symbol=XAGUSD.DWX`; slots 0/1; D1 only.
- On the first tradable bar of a new Monday-anchored broker week, consume one
  durable attempt before every fallible gate.
- Reconstruct the final synchronized closes of exactly the four immediately
  preceding consecutive weeks; each must contain three to five sessions.
- Missing, asynchronous, duplicate, current-week, nonpositive, nonfinite, or
  nonconsecutive data consumes the week flat.

### Entry

Order endpoints oldest to newest and calculate three adjacent relative log
returns `d[i] = log(XAU[i+1]/XAU[i]) - log(XAG[i+1]/XAG[i])`. Require every
`abs(d[i]) > 1e-10`.

- `d0>0, d1<0, d2>0`: buy XAU and sell XAG.
- `d0<0, d1>0, d2<0`: sell XAU and buy XAG.
- Otherwise consume the week flat.

Open an equal-absolute-notional package with one aggregate
`RISK_FIXED=1000` budget, independent frozen `3.5*ATR(20,D1)` hard stops,
XAU/XAG spread ceilings of 1500/500 points, and no target. Return magnitude
never sizes or filters risk.

## 5. Exit Rules

- Close both legs at the first tick of the next broker week or after ten
  calendar days as stale repair.

## 6. Filters (No-Trade Module)

- Exact host, D1, EA 41413, slot zero, both registered magics, and the locked
  strategy inputs are required. Backtest risk must be `RISK_FIXED>0` and
  `RISK_PERCENT=0`; stress rejection is checked only for finiteness and the
  inclusive `0..1` range.
- History, synchronization, week continuity, unique sessions, positive finite
  prices, strict alternation, attempt state, quotes, spread, ATR, lot, stop,
  and notional checks fail closed.
- News and Friday-close settings remain configurable framework inputs and are
  not equality-pinned by the EA.

## 7. Trade Management Rules

- Flatten all owned exposure on an orphan, malformed direction, missing stop,
  or more than 20% absolute-notional mismatch.
- No signal exit, retry, target, trail, break-even, partial, scale-in, grid,
  martingale, or pyramid.

## Parameters To Test

There is no sweep. Q02 uses one locked baseline:

| Input | Value |
|---|---:|
| `strategy_host_symbol` | `XAUUSD.DWX` via setfile |
| `strategy_companion_symbol` | `XAGUSD.DWX` via setfile |
| `strategy_history_bars_d1` | 45 |
| `strategy_min_sessions_per_week` | 3 |
| `strategy_max_sessions_per_week` | 5 |
| `strategy_signal_epsilon` | `1e-10` |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_notional_ratio` | 1.0 |
| `strategy_max_notional_mismatch_pct` | 20.0 |
| `strategy_max_hold_days` | 10 |
| `strategy_host_max_spread_points` | 1500 |
| `strategy_companion_max_spread_points` | 500 |
| `strategy_deviation_points` | 20 |

Framework inputs use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. News, Friday close, RNG seed, and all other framework
controls remain configurable and are never equality-pinned. Stress rejection
is checked only for finiteness and the inclusive `0..1` range.

## Risk

The basket has one aggregate risk budget split across two opposed legs; it
does not allocate `RISK_FIXED` independently to each order. Per-leg lots are
derived from frozen ATR stop distances and reduced until absolute notionals
are within 20%. Equal notional does not establish neutrality. Material risks
include non-convergence, persistent relative trends, CFD roll/basis and
financing, holiday-week synchronization, paired costs, minimum-lot mismatch,
hard-stop slippage, and realized book correlation.

## Runtime Data Dependencies

Runtime uses only native input-bound XAU/XAG D1 bars, positive synchronized
completed-week closes, valid quotes and symbol metadata, completed ATR history,
and native MT5 trade/terminal state. No external calendar, alternative data,
trained output, API, or future observation is used.

## Reputable-Source Criteria

- R1: PASS with disclosed alternation-translation risk and no transferred
  result.
- R2: PASS; all data, state, entry, direction, risk, and lifecycle rules fixed.
- R3: PASS with synchronization and continuous-CFD basis risk.
- R4: PASS; deterministic native arithmetic only and no trained component.

## Falsification And Requalification

Q02 retires on zero packages, fewer than five completed packages in any full
post-warm-up year, or nonpositive governed economics. Do not alter carrier,
endpoints, sign state, direction, risk, stop, or lifecycle to rescue failure.
Any future change needs a new identity, dedup, OWNER approval, rebuild, and
full Q01+ requalification.

## Framework Alignment

- no_trade: exact input-driven identity, host/timeframe, locked strategy
  inputs, fixed-risk mode, finite bounded stress input, history,
  synchronization, position, quote, spread, and durable-attempt guards.
- trade_entry: cached alternating-sign direction and atomic opposed-leg
  package under one fixed-risk budget.
- trade_management: pair integrity, notional tolerance, orphan repair,
  next-week exit, and stale close.
- trade_close: framework close helper, broker hard stops, and no Friday-close
  override.

## Safety Boundary

Authorized only for a branch build, strict Q01, three fixed-risk backtest
presets (one logical basket plus two implementation legs), and one paced
logical Q02 handoff if CPU permits. No manual tester, optimization, live/demo/
shadow/stress preset, AutoTrading, `T_Live`, deploy/live manifest, portfolio
gate, portfolio admission, or correlation waiver is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-09-10 | initial strict XAU/XAG three-week alternation continuation card | G0 | APPROVED; build pending |
