---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-XTIXNG-CS-LEADPERSIST-RV-20260906_S01
variant_id: AI-CODEX-XTIXNG-CS-LEADPERSIST-RV-20260906_S01
source_id: AI-CODEX-XTIXNG-CS-LEADPERSIST-RV-20260906
ea_id: QM5_41370
slug: xtixng-cs-leadpersist-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41370_xtixng-cs-leadpersist-rv_card.md
execution_contract_status: APPROVED
created: 2026-09-06
created_by: Research+Development
last_updated: 2026-09-06
g0_status: APPROVED
g0_decision: decisions/2026-09-06_qm5_41370_xtixng_common_shock_leader_persistence_reversion_g0.md
source_approval: decisions/2026-09-06_xtixng_common_shock_leader_persistence_reversion_source_approval.md
source_author: "Ana-Maria Fuertes; Joelle Miffre; Georgios Rallis; Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons"
source_authors: "Ana-Maria Fuertes; Joelle Miffre; Georgios Rallis; Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons"
source_citation: "Fuertes, Miffre, and Rallis (2010), Journal of Banking & Finance 34(10), DOI 10.1016/j.jbankfin.2010.04.009; Villar and Joutz (2006), U.S. EIA; Ramberg and Parsons (2012), The Energy Journal 33(2), DOI 10.5547/01956574.33.2.2."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Fuertes, A.-M., Miffre, J., and Rallis, G. (2010). Tactical Allocation in Commodity Futures Markets: Combining Momentum and Term Structure Signals. Journal of Banking & Finance 34(10), 2530-2548."
    location: "DOI 10.1016/j.jbankfin.2010.04.009; complete-read governed packet strategy-seeds/sources/FMR-MOMTS-2010/source.md"
    quality_tier: A
    role: commodity_relative_return_ranking_lineage
  - type: government_research
    citation: "Villar, J. A. and Joutz, F. L. (2006). The Relationship Between Crude Oil and Natural Gas Prices. U.S. Energy Information Administration."
    location: "Complete-read governed packet strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md"
    quality_tier: A
    role: oil_gas_physical_economic_link_and_instability
  - type: peer_reviewed_paper
    citation: "Ramberg, D. J. and Parsons, J. E. (2012). The Weak Tie Between Natural Gas and Oil Prices. The Energy Journal 33(2), 13-35."
    location: "DOI 10.5547/01956574.33.2.2; complete-read governed packet strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md"
    quality_tier: A
    role: weak_time_varying_oil_gas_relationship_and_adverse_evidence
strategy_mechanic: normalized-week-boundary-xti-xng-three-synchronized-completed-week-endpoints-two-consecutive-individual-weekly-return-pairs-strict-same-sign-each-week-strict-relative-leader-persistence-newest-winner-fade-equal-notional-one-week-hold
sources:
  - "[[sources/AI-CODEX-XTIXNG-CS-LEADPERSIST-RV-20260906]]"
concepts:
  - "[[concepts/oil-gas-relative-value]]"
  - "[[concepts/completed-week-common-direction-leader-persistence]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/completed-week-individual-log-return]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, oil-gas-relative-value, market-neutral-basket, common-direction-leader-persistence, relative-winner-reversion, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41370_XTI_XNG_CS_LEADPERSIST_RV_D1
symbol: QM5_41370_XTI_XNG_CS_LEADPERSIST_RV_D1
host_symbol: XTIUSD.DWX
companion_symbol: XNGUSD.DWX
symbol_slots: [0, 1]
magic_numbers: [413700000, 413700001]
period: D1
timeframe: D1
expected_trade_frequency: "Approximately five to twelve completed paired packages per full post-warm-up year after two strict common-sign weeks, relative-leader persistence, synchronization, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_TWO_WEEK_LEADER_PERSISTENCE_REVERSION_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: NOT_RUN
q02_status: NOT_ENQUEUED
review_focus: "Falsify a two-week XTI/XNG common-shock relative-leader-persistence fade outside the certified XAU/SP500/NDX/XNG book. Verify three synchronized completed-week endpoints, two same-sign individual-return states, strict same-leader persistence, newest-winner fade, durable weekly attempt, aggregate fixed risk, atomic basket repair, and next-week lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xti_xng_carrier, immediately_preceding_three_monday_anchors, synchronized_completed_d1_closes, three_to_five_week_sessions, exact_week_end_endpoints, strict_individual_leg_same_sign_each_week, strict_relative_leader_persistence, newest_winner_fade_direction, persistent_week_attempt, equal_notional_basket, aggregate_fixed_risk, hard_stops_present, atomic_package_repair, next_week_exit, risk_mode_dual, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 uses complete peer-reviewed commodity relative-return evidence plus complete U.S. government and peer-reviewed oil/gas evidence, retains adverse instability, and discloses the two-week common-shock leader-persistence fade as an untested QM translation; R2 locks synchronized consecutive weeks, endpoint selection, strict within-week shared signs, strict cross-week relative-leader persistence, newest-winner fade, durable attempt, aggregate fixed risk, hard stops, spreads, and next-week lifecycle; R3 uses registered native XTI/XNG D1 histories with synchronization and CFD-basis risks explicit; R4 is deterministic native arithmetic without a banned signal, trained output, or external feed; canonical dedup and manual carrier-family review resolve expected fuzzy siblings while the unavailable external Wiki remains explicit."
---

# QM5_41370 XTI/XNG Common-Shock Leader-Persistence Reversion

## Hypothesis

WTI crude oil and natural gas share broad energy-demand, production,
financing, drilling, and substitution channels, while gas also carries large
regional, weather, storage, and transport shocks. When both contracts move in
the same direction for two consecutive completed weeks and the same contract
remains the relative winner, treat that persistent displacement as an
overextension inside a weak, time-varying relationship. Sell the newest
relative winner and buy the loser as one equal-notional package for the next
week.

The reputable sources support relative commodity-return research and the weak,
unstable oil/gas link. They do not establish this state, reversion direction,
efficacy, neutrality, or decorrelation.

## Source Traceability And Claim Boundary

The approved source of record is
`strategy-seeds/sources/AI-CODEX-XTIXNG-CS-LEADPERSIST-RV-20260906/source.md`,
authorized before extraction in
`decisions/2026-09-06_xtixng_common_shock_leader_persistence_reversion_source_approval.md`.
No source statistic, coefficient, hedge ratio, transaction-cost result, or
portfolio-correlation result transfers to this card.

## Non-Duplicate Decision

The canonical checker scanned 4,850 registry rows and 1,463 cards, found no
exact identity, and surfaced five expected fuzzy siblings. The external
Strategy Wiki root was unavailable and remains an explicit coverage limit.

- `QM5_41369` uses the same formation but follows the winner; this card fades
  it.
- `QM5_41368` requires a strict leader switch before fading; this card requires
  the same strict leader in both weeks.
- `QM5_41361` fades after only one common-sign completed week.
- `QM5_41365` requires opposite signs within a completed week.
- `QM5_41367` follows a winner after one common-sign completed week.
- `QM5_12567` is a single-symbol long-only cumulative-RSI pullback.

Verdict:
`DISTINCT_TWO_WEEK_COMMON_SHOCK_STRICT_SAME_LEADER_PERSISTENCE_REVERSION`.

## Markets, Timeframe, And Cadence

- Host: exact `XTIUSD.DWX`; companion: exact `XNGUSD.DWX`.
- Logical basket: `QM5_41370_XTI_XNG_CS_LEADPERSIST_RV_D1`.
- Exact D1; slots zero and one; magics `413700000` and `413700001`.
- Decide on the first tradable synchronized D1 bar of a new Monday-anchored
  broker week, within 180 elapsed raw-session minutes.
- Use the final synchronized closes of the three immediately preceding
  consecutive weeks, each containing three to five sessions.
- Exit on the first tick in a later broker week.
- Q02 risk is aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Formula

Let `O0/G0`, `O1/G1`, and `O2/G2` be the oldest, middle, and newest final
synchronized weekly closes:

```text
o0 = ln(O1/O0); g0 = ln(G1/G0); d0 = o0-g0
o1 = ln(O2/O1); g1 = ln(G2/G1); d1 = o1-g1

same_sign(o0,g0) and same_sign(o1,g1) and d0 > eps and d1 > eps
    => SELL XTI, BUY XNG
same_sign(o0,g0) and same_sign(o1,g1) and d0 < -eps and d1 < -eps
    => BUY XTI, SELL XNG
otherwise => FLAT
```

`eps=1e-10`. Zero, equality, invalid arithmetic, mixed signs within either
week, missing/nonconsecutive weeks, asynchronous bars, or a leader switch
consumes the attempt flat. No current-week price is a signal input.

## Rules

The following rules are the complete authorized baseline. No optimization
surface or fallback mechanic exists.

## 4. Entry Rules

1. Evaluate only once on a new exact host D1 bar under EA 41370 and slots zero
   and one.
2. Repair malformed, orphaned, same-side, duplicated, notional-invalid,
   later-week, or stale owned exposure before entry-only gates.
3. Require current XTI/XNG D1 timestamps to match the current broker date and
   Monday-anchored week; the prior synchronized bar must belong to the prior
   week.
4. Persist the current-week attempt within 180 minutes of the raw host D1 open
   before history, signal, news, spread, quote, ATR, sizing, or order gates.
   Never retry that week.
5. Require three immediately preceding consecutive completed weeks, each with
   three to five synchronized sessions, using only its newest final close pair.
6. Require a strict shared sign within both weeks, `abs(d0)>eps`,
   `abs(d1)>eps`, and the same strict sign for `d0` and `d1`.
7. Fade the newest leader: `d1>eps` sells XTI/buys XNG; `d1<-eps` buys
   XTI/sells XNG.
8. Require both quotes, ATRs, symbol trade state, news clearance, and spread
   caps of 1,500 XTI points and 3,000 XNG points.
9. Split one aggregate fixed-dollar stop budget across the legs while
   targeting equal absolute USD notional. Round lots down; reject aggregate
   risk above budget or notional mismatch above 20%.
10. Open XTI first and XNG second. If leg two fails or composition is invalid,
    close all owned exposure immediately.

## 5. Exit Rules

- Close both legs at the first tick whose broker Monday anchor is later than
  the entry anchor.
- Close both after ten elapsed calendar days as a stale guard.
- Each leg carries a frozen `3.5*ATR(20,D1)` broker hard stop from completed
  bar one.
- Immediately close orphan, duplicate, same-side, wrong-symbol, later-week,
  stale, or above-20% notional-mismatch exposure.
- No signal reversal, take-profit, trail, partial, scale-in, or pyramid exists.

## 6. Filters (No-Trade Module)

- Fail closed unless attached to exact `XTIUSD.DWX` D1 with exact companion
  `XNGUSD.DWX`.
- Use framework kill switch, broker disconnect, symbol trade state, history,
  spread, and two-axis news clearance.
- Friday force-close is disabled by approved execution-contract override; the
  explicit next-week package exit owns the lifecycle.
- Missing or inconsistent state, synchronization, prices, ATR, contract
  metadata, stops, or lots consumes the week flat.

## 7. Trade Management Rules

- At most one logical two-leg package exists.
- Every tick repairs malformed exposure before entry-only gates.
- A valid package has one XTI leg and one XNG leg, opposite sides, exact
  registered magics, and notional mismatch no greater than 20%.
- The durable attempt ledger prevents restart backfill or intraday retry.

## Parameters To Test

All baseline values are locked; Q02 is not an optimizer:

```text
strategy_history_bars_d1=40
strategy_min_sessions_per_week=3
strategy_max_sessions_per_week=5
strategy_signal_epsilon=0.0000000001
strategy_entry_grace_minutes=180
strategy_atr_period_d1=20
strategy_atr_sl_mult=3.5
strategy_notional_ratio=1.0
strategy_max_notional_mismatch_pct=20.0
strategy_max_hold_days=10
strategy_xti_max_spread_points=1500
strategy_xng_max_spread_points=3000
strategy_deviation_points=20
```

## Source-Defined Rules

- Commodity relative ranks form opposed long/short portfolios.
- Oil/gas linkage is weak and time-varying; adverse instability is binding.

## QM Interpretations

- Exact two-week common-sign strict-leader persistence and newest-winner fade.
- Weekly broker-calendar clock, synchronization, session bounds, stop,
  notional target, aggregate risk cap, and lifecycle.

## Framework Execution Overrides

- `qm_friday_close_enabled=false` because the package owns a complete
  next-week exit and must measure a full broker week.
- News temporal and compliance axes remain off in Q02.

## Exit Precedence

1. framework kill switch and broker hard stops;
2. malformed/orphan atomic repair;
3. later-week exit;
4. ten-day stale exit.

## Runtime Data Dependencies

- Native synchronized `XTIUSD.DWX` and `XNGUSD.DWX` D1 OHLC/timestamps.
- Native ATR, bid/ask, spread, contract size, tick value/size, volume limits,
  positions, deals, and terminal global variables.
- No external runtime feed or trained output.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- `RISK_FIXED` is one aggregate logical-package budget, not a per-leg budget.
- Each leg has a frozen `3.5*ATR(20,D1)` hard stop.
- Lot rounding may reduce risk but never increase aggregate stop risk.
- Equal notional is only a target; it proves no beta, volatility, factor,
  dollar, or portfolio neutrality.

## Falsification And Requalification

- Retire on zero packages, fewer than five packages in any full post-warm-up
  year, or nonpositive governed economics.
- No rescue may alter carrier, two-week formation, common-sign states,
  same-leader condition, fade direction, attempt, risk, stop, or lifecycle.
- Q09 alone may test realized overlap with the certified book.

## Framework Alignment

| Card rule | Module |
|---|---|
| host/companion and fixed-input validation | No-Trade / OnInit |
| weekly clock, attempt, endpoints, signal, sizing, atomic open | Trade Entry |
| package validation, repair, later-week and stale exits | Trade Management |
| no separate boolean signal exit | Trade Close |
| kill switch, news, sizing, hard stops, telemetry | V5 framework |

## Validation Plan

1. Reference fixtures for week keys, session bounds, strict signs, leader
   persistence, equality, mixed-sign and leader-switch rejection, direction,
   sizing, attempt persistence, atomic repair, and lifecycle.
2. Card schema lint and approved-card preflight.
3. Deterministic EA/magic allocation and resolver regeneration.
4. Strict governed Q01 compile with an `.ex5` receipt.
5. One target-only logical-basket Q02 enqueue only if the fresh CPU admission
   is strictly below the hard ceiling.

## Pipeline History

- 2026-09-06: source approved; card extracted and G0 approved.

## Pipeline Phase Status

- Q01: `NOT_RUN`.
- Q02: `NOT_ENQUEUED`.
- Q03+: not authorized by this build commission.

## Safety Boundary

This card authorizes deterministic allocation, branch-only non-live build,
strict Q01, and one paced Q02 enqueue below the CPU ceiling. It authorizes no
manual tester run, optimization, portfolio-gate edit, portfolio admission,
correlation waiver, deployment, live manifest, `T_Live`, AutoTrading, or live
use.
