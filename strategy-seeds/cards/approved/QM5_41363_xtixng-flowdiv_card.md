---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-XTIXNG-FLOWDIV-20260906_S01
variant_id: AI-CODEX-XTIXNG-FLOWDIV-20260906_S01
source_id: AI-CODEX-XTIXNG-FLOWDIV-20260906
ea_id: QM5_41363
slug: xtixng-flowdiv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41363_xtixng-flowdiv_card.md
execution_contract_status: APPROVED
created: 2026-09-06
created_by: Research+Development
last_updated: 2026-09-06
g0_status: APPROVED
g0_decision: decisions/2026-09-06_qm5_41363_xtixng_weekly_relative_flow_divergence_g0.md
source_approval: decisions/2026-09-06_xtixng_weekly_relative_flow_divergence_source_approval.md
source_author: "Larry R. Williams; Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons"
source_authors: "Larry R. Williams; Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons"
source_citation: "Williams (1999), Long-Term Secrets to Short-Term Trading, Wiley Trading; Villar and Joutz (2006), U.S. EIA; Ramberg and Parsons (2012), The Energy Journal 33(2)."
source_citations:
  - type: practitioner_book
    citation: "Williams, L. R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading."
    location: "Governed extraction strategy-seeds/sources/WILLIAMS-SCHWEIKERT-XAUXAG-FLOWDIV-2026/source.md"
    quality_tier: A
    role: close_to_open_and_open_to_close_price_flow_decomposition
  - type: government_research
    citation: "Villar, J. A. and Joutz, F. L. (2006). The Relationship Between Crude Oil and Natural Gas Prices. U.S. Energy Information Administration."
    location: "Complete-read packet strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md"
    quality_tier: A
    role: oil_gas_physical_economic_link_and_instability
  - type: peer_reviewed_paper
    citation: "Ramberg, D. J. and Parsons, J. E. (2012). The Weak Tie Between Natural Gas and Oil Prices. The Energy Journal 33(2), 13-35."
    location: "DOI 10.5547/01956574.33.2.2; complete-read packet strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md"
    quality_tier: A
    role: weak_time_varying_oil_gas_relationship_and_adverse_evidence
strategy_mechanic: exact-prior-monday-friday-synchronized-xti-minus-xng-close-open-versus-open-close-strict-disagreement-follow-session-next-monday-paired-friday-flat
strategy_type_flags: [commodity, energy, oil-gas-relative-value, market-neutral-basket, price-flow-decomposition, weekly-flow-divergence, symmetric-long-short, atr-hard-stop, friday-close, low-frequency]
markets: [commodities, energy]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41363_XTI_XNG_FLOWDIV_D1
symbol: QM5_41363_XTI_XNG_FLOWDIV_D1
host_symbol: XTIUSD.DWX
companion_symbol: XNGUSD.DWX
symbol_slots: [0, 1]
magic_numbers: [413630000, 413630001]
period: D1
timeframe: D1
expected_trade_frequency: "Approximately fifteen to thirty completed paired packages per full post-warm-up year after exact completed-week synchronization and strict relative-flow disagreement; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 22
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED
review_focus: "Falsify an exact-calendar XTI/XNG weekly relative-flow-disagreement basket intended to add an energy relative-value return driver outside the certified XAU/SP500/NDX/XNG book. Verify every completed close/open endpoint, XTI-minus-XNG subtraction, strict component opposition, session-following sides, durable weekly attempt, aggregate fixed risk, atomic package repair, and paired Friday closure. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xti_xng_carrier, exact_synchronized_week, completed_close_open_endpoints, cross_energy_subtraction, strict_flow_disagreement, monday_decision_clock, weekly_attempt_state, no_current_bar_leakage, basket_atomicity, aggregate_fixed_risk, notional_mismatch, paired_friday_close, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 combines complete U.S. government and peer-reviewed oil/gas evidence with governed Williams price-flow arithmetic while preserving adverse instability and translation risk; R2 locks exact synchronized dates, endpoints, subtraction, disagreement, direction, attempt, timing, risk, stops, atomicity, and lifecycle; R3 uses registered native XTI/XNG D1 histories with synchronization and CFD-basis risks explicit; R4 is deterministic native arithmetic without banned logic; the canonical dedup scan plus manual carrier review found no exact XTI/XNG identity."
---

# QM5_41363 XTI/XNG Weekly Relative-Flow Divergence

## Hypothesis

Oil and natural gas retain physical and economic links but their regional and
contract-specific drivers can separate. When the completed prior week's
XTI-minus-XNG close-to-open flow points against its open-to-close flow, follow
the session-relative component for one opposed-leg Monday-to-Friday package.
The construction tests information-time disagreement without taking a single
outright energy signal.

Opposite, equal-notional legs are an execution target, not proof of market,
beta, volatility, factor, or portfolio neutrality. Q02 owns density and
economics. Unchanged Q09 alone may establish realized book correlation.

## Source Traceability And Claim Boundary

The approved source of record is
`strategy-seeds/sources/AI-CODEX-XTIXNG-FLOWDIV-20260906/source.md`, authorized
before extraction in
`decisions/2026-09-06_xtixng_weekly_relative_flow_divergence_source_approval.md`
at commit `f5d61a7771`.

Williams supplies the prior-close-to-open/open-to-close price-flow objects.
Villar/Joutz and Ramberg/Parsons supply government and peer-reviewed evidence
for a weak, shifting oil/gas relationship. No source tests the conjunction or
transfers a return, drawdown, density, transaction-cost, CFD-equivalence,
neutrality, or correlation claim.

## Non-Duplicate Decision

The canonical checker scanned 4,843 registry rows and 1,456 cards, found no
exact identity, and surfaced five fuzzy matches. Manual review fixes the
boundaries:

- `QM5_41030_xauxag-flowdiv` owns the arithmetic on precious metals; this
  card owns the distinct WTI/natural-gas carrier, energy contract metadata,
  oil/gas source thesis, and realized return stream. No parent result or
  parameter is imported.
- `QM5_41040_xauxag-wflow-fade` follows a session-dominant fade, while
  `QM5_41057_xauxag-wflow-agree-fade` requires component agreement.
- Existing XTI/XNG candidates use ratio levels, fitted residuals, robust
  monthly statistics, close-to-close paths, weekdays, or calendars.
- `QM5_12567_cum-rsi2-commodity` is single-symbol, long-only, and short-
  horizon.

The exact carrier, six synchronized completed endpoints, two relative
information-time components, strict opposition, session-following direction,
weekly attempt, aggregate-risk basket, and Friday close are jointly
load-bearing. Verdict:
`FUZZY_CARRIER_PORT_RESOLVED_DISTINCT_XTIXNG_WEEKLY_RELATIVE_FLOW_DISAGREEMENT_SESSION_FOLLOW_BASKET`.

## Markets, Timeframe, And Cadence

- Host: `XTIUSD.DWX`, D1, slot 0, magic `413630000`.
- Companion: `XNGUSD.DWX`, D1, slot 1, magic `413630001`.
- Logical symbol: `QM5_41363_XTI_XNG_FLOWDIV_D1`.
- Decision: first synchronized executable D1 bar of an eligible broker Monday,
  within 180 raw-session minutes.
- Formation: exact synchronized completed Monday-through-Friday week plus the
  preceding Friday close.
- Exit: paired close Friday at broker hour 21; later-week/eight-day stale
  repair.
- Expected cadence: fifteen to thirty packages/year; retire below five.

## Formula

For each completed prior-week session `d`:

```text
xti_overnight[d] = ln(XTI_open[d] / XTI_close[prior_session])
xng_overnight[d] = ln(XNG_open[d] / XNG_close[prior_session])
xti_session[d]   = ln(XTI_close[d] / XTI_open[d])
xng_session[d]   = ln(XNG_close[d] / XNG_open[d])

overnight_relative = sum(xti_overnight[d] - xng_overnight[d])
session_relative   = sum(xti_session[d]   - xng_session[d])

session_relative > 0 and overnight_relative < 0 => BUY XTI, SELL XNG
session_relative < 0 and overnight_relative > 0 => SELL XTI, BUY XNG
otherwise                                          => FLAT
```

All endpoints are completed before Monday. Exact zero is flat. Signal
magnitude never changes eligibility, direction, or risk.

## Rules

The following clauses are the complete authorized baseline. There is no
fallback signal or optimization surface.

## 4. Entry Rules

1. Evaluate only once on a new exact host D1 bar under EA 41363 and slot zero.
2. Repair malformed, orphaned, duplicated, same-side, stopless, notional-
   invalid, later-week, or stale owned exposure before entry-only gates.
3. Require the broker date to be Monday and current XTI/XNG D1 timestamps to
   match the broker date exactly.
4. Read six immediately completed bars per leg and require cross-symbol
   timestamp equality and strict newest-to-oldest ordering.
5. Require completed shared dates, newest first, to be prior Friday through
   Monday plus the preceding Friday at exact offsets 3, 4, 5, 6, 7, and 10
   calendar days. Holidays consume the week flat; no substitution exists.
6. Persist the Monday `yyyymmdd` attempt before history, signal, news, spread,
   quote, ATR, sizing, or order gates. Never retry that Monday.
7. Require elapsed time from synchronized Monday open between zero and 180
   minutes; later attachment consumes the attempt flat.
8. Require every completed open and close used by the formula positive and
   finite; the current Monday price must not enter either sum.
9. Trade only strict component opposition and follow the session-relative
   sign through opposed legs exactly as the formula states.
10. Require side-specific quotes and no positive spread wider than 1,500 XTI
    or 3,000 XNG points. Modeled zero `.DWX` spread is valid.
11. Attach a frozen `3.0*ATR(20,D1)` hard stop per leg, no take-profit, and
    cap combined normalized stop risk at one `RISK_FIXED` budget.
12. Target one-to-one absolute entry notional, round down only, and reject
    more than 20 percent mismatch.
13. Submit both legs once. On either failure or invalid composition, flatten
    all owned exposure without retry or standalone fallback.

## 5. Exit Rules

1. Broker hard stops and the framework kill switch remain authoritative.
2. Flatten orphan, duplicate, same-side, wrong-symbol, wrong-magic, missing-
   stop, invalid-volume, or notional-invalid packages immediately.
3. Close both legs at or after broker Friday 21:00; framework Friday close is
   an enabled fail-safe.
4. Close on the first observable D1 boundary in a later broker week or after
   eight elapsed calendar days as stale repair.
5. No target, opposite-flow exit, reversal, trail, break-even, partial,
   scale-in, pyramid, grid, martingale, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Exact host `XTIUSD.DWX`, companion `XNGUSD.DWX`, D1, EA 41363, slot zero,
  active magics, fixed-risk inputs, news OFF, and Friday close at hour 21.
- Current and completed D1 timestamps, calendar sequence, prices, quotes,
  spreads, ATR, sizing, hard-stop geometry, and notional match fail closed.
- No futures chain, inventory, volume, open interest, external API, CSV,
  optimizer artifact, fitted model, trained output, or manual signal exists.

## 7. Trade Management Rules

- Own exactly one XTI position under magic `413630000` and one opposite XNG
  position under magic `413630001`, or flatten all owned exposure.
- Persist the last attempted Monday across restart and never retry that week.
- Run malformed, orphan, Friday, later-week, and stale repair every tick
  before entry-only gates.
- Freeze both original stops; never widen, trail, remove, add, reverse, or
  partially close them.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_xng_symbol` | `XNGUSD.DWX` | exact companion |
| `strategy_atr_period_d1` | 20 | completed-bar range |
| `strategy_atr_sl_mult` | 3.0 | frozen stop distance |
| `strategy_xti_max_spread_points` | 1500 | XTI cost guard |
| `strategy_xng_max_spread_points` | 3000 | XNG cost guard |
| `strategy_entry_grace_minutes` | 180 | Monday boundary |
| `strategy_notional_ratio` | 1.0 | equal absolute notional target |
| `strategy_max_notional_mismatch_pct` | 20.0 | mismatch ceiling |
| `strategy_max_hold_days` | 8 | stale repair |
| `strategy_deviation_points` | 20 | order deviation |
| `qm_friday_close_enabled` | true | paired Friday closure |
| `qm_friday_close_hour_broker` | 21 | exit hour |

## Author Claims

The cited sources define the component returns and document a weak oil/gas
relationship. They do not claim this conjunction works or that the package is
neutral, profitable, or decorrelated.

## Risk

Risk is high: persistent oil/gas decoupling, regional gas shocks, energy gaps,
one-leg fills, lot-step mismatch, continuous-CFD basis and financing, spread,
low density, and overlap with the incumbent XNG sleeve can dominate the
premise. Each leg has a frozen hard stop and the package shares one fixed-
dollar budget.

## Falsification And Requalification

Q02 retires rather than tunes on zero packages, fewer than five packages in
any full post-warm-up year, nonpositive governed economics, wrong/asynchronous
dates, holiday substitution, current-Monday leakage, accepting agreement or
zero, wrong side, duplicate attempt, aggregate-risk breach, missing stop,
broken atomicity, wrong Friday lifecycle, or nondeterminism.

Changing carrier, endpoint sequence, component definition, sign condition,
direction, attempt clock, risk, stop, or lifecycle requires a new identity and
full requalification. A failure may not be rescued by a threshold, fitted
center, beta, calendar, volatility, or external-data filter.

## Strategy Allowability Check

- [x] R1: PASS with disclosed composite translation risk; the government,
  peer-reviewed, and practitioner packets were completely read before source
  approval.
- [x] R2: PASS; endpoints, arithmetic, sides, attempt, risk, stops, and
  lifecycle are fixed.
- [x] R3: PASS for registered native XTI/XNG D1 proxy data with synchronization
  and CFD-basis risks explicit.
- [x] R4: PASS; deterministic native arithmetic only, with no trained model,
  prohibited signal indicator, external feed, grid, or martingale.
- [x] Dedup: deterministic scan plus manual carrier-family review is clean.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact dates, completed flows, state, side, attempt, costs, ATR | Trade Entry | deterministic helpers and basket order helper |
| orphan/notional, Friday, later-week, stale repair | Trade Management | package lifecycle helper |
| framework close hook | Trade Close | no separate signal exit |
| kill switch, ownership, magics, aggregate risk | Framework No-Trade | standard framework plus foreign magic |
| news OFF | News hooks | both axes locked OFF |

## Validation Plan

Q01 must prove the exact Monday/Friday sequence across month and year
boundaries; synchronized chronological endpoints; all strict sign states and
their sides; no current-bar leakage; durable attempts; aggregate-risk sizing;
equal-notional rounding; atomic repair; Friday/later-week/stale exits; card
lint; strict compile; setfile schema; basket manifest; resolver identity; and
static artifact validation.

Q02 alone may measure density and baseline economics. Q09 alone may establish
realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-09-06 | initial XTI/XNG weekly relative-flow divergence card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-09-06 | APPROVED | `decisions/2026-09-06_qm5_41363_xtixng_weekly_relative_flow_divergence_g0.md` |
| Q01 Build Validation | - | NOT_BUILT | - |
| Q02 Baseline Screening | - | NOT_ENQUEUED | - |

## Safety Boundary

This card authorizes one branch-only non-live build, Q01 validation, one
logical D1 fixed-risk backtest setfile, and one paced Q02 enqueue only below
the CPU ceiling. It does not authorize a manual backtest, terminal control,
live/demo/shadow/optimization presets, AutoTrading, `T_Live`, deployment, a
live manifest, portfolio-gate change, portfolio admission, decorrelation
claim, neutrality claim, or correlation waiver.
