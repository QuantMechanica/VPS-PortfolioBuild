---
card_schema_version: 2
type: strategy
strategy_id: MOP-CME-XAUXAG-WSTREAK2-CONT-20260910_S01
variant_id: MOP-CME-XAUXAG-WSTREAK2-CONT-20260910_S01
source_id: MOP-CME-XAUXAG-WSTREAK2-CONT-20260910
ea_id: QM5_41418
slug: xauxag-wstreak2-cont
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41418_xauxag-wstreak2-cont_card.md
execution_contract_status: APPROVED
created: 2026-09-10
created_by: Research+Development
last_updated: 2026-09-10
g0_status: APPROVED
g0_decision: decisions/2026-09-10_qm5_41418_xauxag_fresh_two_week_sign_streak_continuation_g0.md
source_approval: decisions/2026-09-10_xauxag_fresh_two_week_sign_streak_continuation_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; CME Group; OpenAI Codex"
source_citation: "Moskowitz, Ooi & Pedersen (2012), Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003; CME Group Gold & Silver Ratio Spread."
source_citations:
  - type: peer_reviewed_plus_exchange_bounded_mechanization
    citation: "Moskowitz-Ooi-Pedersen commodity time-series momentum lineage plus CME gold/silver ratio and intermarket-spread carrier; QuantMechanica governed fresh two-week relative-sign translation."
    location: strategy-seeds/sources/MOP-CME-XAUXAG-WSTREAK2-CONT-20260910/source.md
    quality_tier: A_lineage_with_short_horizon_relative_translation_risk
    role: commodity_continuation_lineage_and_gold_silver_relative_carrier
strategy_mechanic: normalized-week-boundary-xau-xag-four-synchronized-completed-week-endpoints-newest-two-same-sign-relative-log-returns-after-opposite-predecessor-follow-equal-notional-one-week-basket
sources: ["[[sources/MOP-CME-XAUXAG-WSTREAK2-CONT-20260910]]"]
concepts: ["[[concepts/gold-silver-relative-value]]", "[[concepts/fresh-two-week-sign-streak]]", "[[concepts/market-neutral-basket]]"]
indicators: ["[[indicators/completed-week-relative-log-return-sign]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, precious-metals, gold-silver-relative-value, market-neutral-basket, fresh-two-week-sign-streak, trend-following, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41418_XAU_XAG_WSTREAK2_CONT_D1
symbol: QM5_41418_XAU_XAG_WSTREAK2_CONT_D1
host_symbol: XAUUSD.DWX
companion_symbol: XAGUSD.DWX
symbol_slots: [0, 1]
magic_numbers: [414180000, 414180001]
period: D1
timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately eight to sixteen completed paired packages per full post-warm-up year after strict fresh two-week state, synchronization, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_SHORT_HORIZON_RELATIVE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: D1; input-bound synchronized XAU/XAG labels; four immediately preceding consecutive week endpoints; newest two strict same-sign relative log returns after strict opposite predecessor; epsilon 1e-10; follow newest sign; 45 D1 bars; 180-minute entry grace; aggregate fixed risk; 3.5*ATR(20,D1) frozen per-leg stops; 20% notional mismatch cap; 10-day stale repair; XAU/XAG spread ceilings 1500/500."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q02
q01_status: PASS
q02_status: NOT_ENQUEUED
q01_build_report: D:/QM/reports/work_items/6683cc5f-a969-4c4b-881a-9676af581196/QM5_41418/COMPILE_EA/compile_evidence.json
force_build: true
review_focus: "Falsify a fresh two-completed-week XAU/XAG relative-sign continuation basket outside the certified directional XAU/SP500/NDX/XNG book. Verify four synchronized completed-week endpoints, strict -++ / +-- state, continuation package, durable weekly attempt, aggregate fixed risk, atomic repair, and next-week lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [input_bound_xau_xag_carrier, immediately_preceding_four_monday_anchors, synchronized_completed_d1_closes, three_to_five_week_sessions, three_adjacent_relative_returns, strict_nonzero_return_differences, fresh_two_week_streak, continuation_package_direction, persistent_week_attempt, equal_notional_basket, aggregate_fixed_risk, hard_stops_present, atomic_package_repair, next_week_exit, risk_mode_dual, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 preserves complete peer-reviewed momentum and exchange carrier evidence while disclosing the untested weekly relative translation; R2 locks endpoints, signs, direction, lifecycle, and risk; R3 uses registered native XAU/XAG D1 data; R4 uses deterministic non-trained arithmetic. Canonical exact/fuzzy dedup is CLEAN; the opposite-side two-week sibling, three-week fade, and overlapping-majority continuation use mechanically different direction or states."
---

# QM5_41418 XAU/XAG Fresh Two-Week Sign-Streak Continuation

## Hypothesis

The first completion of two consecutive same-direction broker-week moves in
the gold/silver log ratio after an opposite week may carry into the next broker
week. Follow that fresh streak through an opposed XAU/XAG basket. Equal
notional is a construction target, not proof of neutrality; Q09 alone may
establish realized portfolio correlation.

## Source Traceability And Non-Duplicate Decision

The approved complete-read packet is
`strategy-seeds/sources/MOP-CME-XAUXAG-WSTREAK2-CONT-20260910/source.md`.
Moskowitz, Ooi, and Pedersen support a commodity continuation family and CME
defines the ratio-spread carrier. Neither source defines or validates this
weekly relative event, CFD translation, risk scheme, density, or
diversification.

The corrected canonical scan found no exact or fuzzy identity. `QM5_41417`
trades the exact opposite side; `QM5_41078` requires `-+++` / `+---` from five
endpoints and fades only after the third week. `QM5_41414` requires a majority
flip between two overlapping three-return windows. The exact carrier,
endpoints, signs, continuation side, attempt, aggregate risk, and lifecycle
jointly define this identity.

## Rules

### Market, clock, and data

- Host `strategy_host_symbol=XAUUSD.DWX`; companion
  `strategy_companion_symbol=XAGUSD.DWX`; slots 0/1; D1 only. Symbols remain
  inputs in source; the setfile supplies factory `.DWX` names.
- On the first tradable bar of a new Monday-anchored broker week, consume one
  durable attempt before every fallible gate.
- Reconstruct the final synchronized closes of exactly the four immediately
  preceding consecutive weeks; each must contain three to five sessions.
- Missing, asynchronous, duplicate, current-week, nonpositive, nonfinite,
  mixed-label, or nonconsecutive data consumes the week flat.

### Entry

Order endpoints newest to oldest and calculate:

```text
r0 = log(XAU0/XAU1) - log(XAG0/XAG1)
r1 = log(XAU1/XAU2) - log(XAG1/XAG2)
r2 = log(XAU2/XAU3) - log(XAG2/XAG3)
```

Require every `abs(r[i]) > 1e-10`.

- `r0>0, r1>0, r2<0`: buy XAU and sell XAG.
- `r0<0, r1<0, r2>0`: sell XAU and buy XAG.
- Otherwise consume the week flat.

Open an equal-absolute-notional package with one aggregate
`RISK_FIXED=1000` budget, independent frozen `3.5*ATR(20,D1)` hard stops,
XAU/XAG spread ceilings of 1500/500 points, and no target. Return magnitude
never sizes or filters risk.

### Exit and management

- Close both legs at the first tick of the next broker week or after ten
  calendar days as stale repair.
- Flatten all owned exposure on an orphan, duplicate, malformed direction,
  missing stop, or more than 20% absolute-notional mismatch.
- No signal exit, retry, target, trail, break-even, partial, scale-in, grid,
  martingale, pyramid, or discretionary override.

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

Framework backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. News and Friday controls remain configurable framework
inputs and are never equality-pinned. RNG is never compared. Stress rejection
is checked only for finiteness and the inclusive `0..1` range.

## Risk

The basket has one aggregate fixed-dollar risk budget split across two opposed
legs. Principal risks are unsupported weekly relative-momentum translation,
sharp ratio reversals, CFD roll/basis and financing, synchronization, paired
costs, minimum-lot mismatch, stop slippage, sparse years, and realized overlap
with the XAU sleeve. Equal notional does not establish factor neutrality.

## Runtime Data Dependencies

Runtime uses only input-bound XAU/XAG D1 bars, broker time, positive
synchronized completed-week closes, valid quotes and symbol metadata,
completed ATR history, native positions/deals, and terminal-global attempt
state. No external calendar, alternative data, trained output, API, file feed,
or future observation is used.

## Reputable-Source Criteria

- R1: PASS with disclosed short-horizon relative translation risk.
- R2: PASS; all data, state, entry, side, risk, and lifecycle rules are fixed.
- R3: PASS with synchronization and continuous-CFD basis risk.
- R4: PASS; deterministic native arithmetic only and no trained component.

## Falsification And Requalification

Q02 retires on zero packages, fewer than five completed packages in any full
post-warm-up year, or nonpositive governed economics. Wrong week adjacency,
synchronization, sign, side, attempt, pairing, stop, aggregate risk, exit, or
determinism also retires the build. Do not tune a failure. Any change to the
carrier, endpoint count, streak rule, direction, risk, or lifecycle requires a
new identity, dedup review, OWNER approval, and full Q01+ requalification.

## Framework Alignment

- no_trade: exact input-driven identity, host/timeframe, locked strategy
  inputs, fixed-risk mode, finite bounded stress input, history, position,
  quote, spread, synchronization, and durable-attempt guards.
- trade_entry: cached strict fresh-streak direction and atomic opposed-leg
  package under one fixed-risk budget.
- trade_management: package integrity, notional tolerance, orphan repair,
  next-week exit, and stale close.
- trade_close: framework close helper, broker hard stops, and no Friday-close
  override.
- news hook: configurable framework news contract with no equality pin.

## Validation Plan

Q01 must prove raw/+1-day label equivalence, year-boundary adjacency,
three/four/five-session acceptance, two/six rejection, exact synchronized
endpoints, both `-++` / `+--` directions, continuing-streak and mixed-sign flat
states, no current-week leakage, durable attempts, aggregate fixed-risk stops,
atomic repair, next-week/stale exits, schema lint, resolver identity, a
zero-finding PACER pin audit, and governed strict compile/build checks.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-09-10 | initial XAU/XAG fresh two-week streak-continuation card | G0 | APPROVED; build pending |
| v1-build | 2026-09-10 | governed compile and build check | Q01 | COMPILE_OK; 0 compiler errors/warnings; build-check PASS; pin audit zero findings; 6/6 tests PASS |

## Safety Boundary

Authorized only for a branch build, strict Q01, fixed-risk backtest presets,
and one paced logical Q02 handoff if CPU permits. No manual tester,
optimization, live/demo/shadow/stress preset, AutoTrading, `T_Live`, deploy or
live manifest, portfolio-gate change, portfolio admission, correlation waiver,
or decorrelation/neutrality claim is authorized.
