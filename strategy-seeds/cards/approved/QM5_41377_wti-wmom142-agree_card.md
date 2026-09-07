---
card_schema_version: 2
type: strategy
strategy_id: KWON-KANG-YUN-WTI-WMOM142-AGREE-2026_S01
variant_id: KWON-KANG-YUN-WTI-WMOM142-AGREE-2026_S01
source_id: KWON-KANG-YUN-WTI-WMOM142-AGREE-2026
ea_id: QM5_41377
slug: wti-wmom142-agree
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41377_wti-wmom142-agree_card.md
execution_contract_status: APPROVED
created: 2026-09-07
created_by: Research+Development
last_updated: 2026-09-07
g0_status: APPROVED
g0_decision: decisions/2026-09-07_qm5_41377_wti_disjoint_weekly_momentum_agreement_g0.md
source_approval: decisions/2026-09-07_wti_disjoint_weekly_momentum_agreement_source_approval.md
source_author: "Kyung Yoon Kwon; Jangkoo Kang; Jaesun Yun"
source_authors: "Kyung Yoon Kwon; Jangkoo Kang; Jaesun Yun"
source_citation: "Kwon, K. Y., Kang, J., and Yun, J. (2020), Weekly Momentum in the Commodity Futures Market, Finance Research Letters 35, 101306, DOI 10.1016/j.frl.2019.101306."
source_citations:
  - type: peer_reviewed_paper
    citation: "Kwon, Kyung Yoon; Kang, Jangkoo; and Yun, Jaesun (2020), Weekly Momentum in the Commodity Futures Market, Finance Research Letters 35, 101306."
    location: "DOI 10.1016/j.frl.2019.101306; complete-read packet strategy-seeds/sources/KWON-KANG-YUN-WTI-WMOM142-AGREE-2026/source.md"
    quality_tier: A
    role: exact_cmom11_and_cmom42_disjoint_formation_horizons_plus_wti_membership
strategy_mechanic: normalized-week-boundary-wti-strict-sign-agreement-between-immediate-t-minus-1-week-return-and-disjoint-cumulative-t-minus-4-through-t-minus-2-return-one-week-hold
sources: ["[[sources/KWON-KANG-YUN-WTI-WMOM142-AGREE-2026]]"]
concepts: ["[[concepts/weekly-commodity-momentum]]", "[[concepts/disjoint-horizon-agreement]]", "[[concepts/wti-structural-trend]]"]
indicators: ["[[indicators/completed-week-log-return]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, energy, wti-crude, weekly-momentum, structural-trend, disjoint-horizon-agreement, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 413770000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 20-35 completed WTI positions per full post-warm-up year after strict disjoint-block sign agreement and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 26
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_AND_TIME_SERIES_PORT_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: CPU_CEILING_STOP_NOT_ENQUEUED
parameters_to_test: "Locked Q02 baseline only: exact D1; 40-bar history buffer; four consecutive completed 3-5-session weeks; strict agreement of ln(final close t-1 / first open t-1) and ln(final close t-2 / first open t-4); 180-minute entry grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
review_focus: "Falsify a direct-WTI disjoint weekly-horizon agreement stream outside the certified XAU/SP500/NDX/XNG book. Verify exact t-1 and t-4..t-2 endpoints, no overlap or current-week leakage, strict same-sign admission, fixed risk, frozen stop, durable attempt, and next-week exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_week_bar, four_consecutive_completed_weeks, disjoint_cmom11_cmom42_blocks, strict_sign_agreement, no_current_week_leakage, weekly_attempt_state, risk_mode_dual, hard_stop_present, next_week_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER-authorized WTI sleeve; peer-reviewed complete-read source defines both disjoint weekly horizons and WTI membership; strict conjunction, execution clock, risk, stop and lifecycle locked; native D1 data; deterministic no-ML implementation; expected fuzzy parents manually resolved."
---

# QM5_41377 WTI Disjoint Weekly Momentum Agreement

## Hypothesis

WTI continuation is admitted only when its immediately completed broker week
and the disjoint preceding three-week block point in the same direction. At the
first tradable D1 bar of week `t`, buy when both the `t-1` return and cumulative
`t-4..t-2` return are strictly positive, sell when both are strictly negative,
and otherwise remain flat. Hold any admitted position for one broker week.

Kwon, Kang, and Yun define the two disjoint formation states as `CMOM1,1` and
`CMOM4,2` and explicitly include light sweet crude oil. They do not test their
conjunction, standalone WTI time-series direction, continuous-CFD execution,
fixed-risk ATR stops, or the QM book. Those remain falsifiable QM translations.

## Source Traceability And Claim Boundary

The approved source packet is
`strategy-seeds/sources/KWON-KANG-YUN-WTI-WMOM142-AGREE-2026/source.md`, with
source approval in
`decisions/2026-09-07_wti_disjoint_weekly_momentum_agreement_source_approval.md`.
Its parent records preserve a complete 20-page accepted-manuscript read, DOI,
retrieval URL, and PDF hash. A fresh generic-source route was policy-deferred;
the exact receipt is `artifacts/wti_wmom142_source_router_receipt_20260907.json`
and no bypass was attempted.

The source uses cross-sectional commodity-futures ranks. No return, alpha,
significance, robustness, causality, transaction-cost result, WTI-only result,
CFD equivalence, or decorrelation transfers. It also reports that `CMOM4,2` is
largely spanned by `CMOM1,1`, so the agreement gate may only reduce density.

## Non-Duplicate Decision

The pre-allocation checker scanned 4,857 EA-registry rows and 1,470 cards. It
found only expected fuzzy matches to the two parents; the unavailable Strategy
Wiki root remains an explicit finding in
`artifacts/qm5_wti_wmom142_agree_preallocation_dedup_20260907.json`.

- `QM5_41375_wti-wmom1` follows every valid `t-1` sign and does not read the
  older block.
- `QM5_41376_wti-wmom42` follows every valid `t-4..t-2` sign while excluding
  `t-1` from its state.
- `QM5_41022_wti-wdual-mom` splits one prior week into two internal segments
  and closes on Friday; this card compares two source-defined multi-week
  blocks and exits on the next normalized week boundary.
- Adjacent-week acceleration, deceleration, flip, pullback, and resumption
  systems require individual return paths or magnitude inequalities. This
  card uses no magnitude or adjacent-path condition.
- Monthly dual-horizon systems decide and roll monthly.

The strict conjunction is load-bearing: removing either disjoint state exactly
recreates a built parent. Verdict:
`DISTINCT_WTI_CMOM11_CMOM42_DISJOINT_SIGN_AGREEMENT_WEEKLY_CONTINUATION`.

## Market, Clock, And State

- Host and traded symbol: input-bound exact `XTIUSD.DWX` in the factory set.
- Timeframe: exact D1; EA ID 41377; slot 0; magic 413770000.
- Decision: first tradable D1 bar of a normalized Monday-anchored broker week,
  within 180 elapsed minutes of the raw D1 session open.
- Formation: exactly four consecutive completed weekly packages, each with
  three to five unique sessions.
- At most one owned position and one consumed attempt per broker week.

## Formula

For decision week `t`:

```text
r_recent = ln(final_close[t-1] / first_open[t-1])
r_prior  = ln(final_close[t-2] / first_open[t-4])

r_recent > 0 and r_prior > 0  => BUY
r_recent < 0 and r_prior < 0  => SELL
otherwise                     => FLAT
```

The two return intervals do not overlap. All endpoints are completed before
week `t`; current-week price is execution-only.

## Rules

### Entry Rules

1. Repair malformed or stale owned exposure before entry-only filters.
2. Require configured symbol, D1, EA 41377, slot 0, fixed-risk backtest mode,
   both news axes OFF, and Friday close disabled.
3. Infer one energy-label convention from the current D1 bar: native same-day
   labels or a uniform `+1` calendar-day offset only. Apply it to every bar.
4. Derive the normalized Monday anchor and admit only the first tradable bar
   of the week within 180 raw-session minutes.
5. Persist the week attempt before history, signal, spread, quote, ATR, sizing,
   news, or order gates. Never retry that week.
6. Reconstruct exact completed weeks `t-1` through `t-4`; require anchors at
   seven-day intervals and three to five unique ordered sessions per week.
7. Use the chronologically first open and final close of each required block.
   Require all four formula endpoints to be positive and finite.
8. Compute `r_recent` and `r_prior` exactly as above. Buy only for strict
   positive agreement and sell only for strict negative agreement. Equality,
   disagreement, invalid arithmetic, or broken chronology remains flat.
9. Require a nonnegative spread no greater than 1,500 points, a valid quote,
   and completed-bar ATR(20,D1).
10. Freeze a hard stop at `3.5*ATR`, use no target, and open at most one
    fixed-risk position. Signal magnitude never changes risk.

### Attempt And Restart Contract

Persist the normalized Monday anchor in a terminal-global key scoped by EA,
symbol, and timeframe before any fallible entry gate. Late attachment consumes
the week flat. Deal history and owned-position state fail closed. A rejected
order, restart, spread, history, ATR, sizing, or news failure cannot retry.

### Exit Rules

1. Broker hard stop and framework kill switch remain authoritative.
2. Flatten duplicate, wrong-side, wrong-magic, missing-stop, or otherwise
   malformed owned exposure.
3. Close at the first tick whose normalized Monday anchor is later than the
   entry-week anchor.
4. Ten elapsed calendar days is stale repair only.

No take-profit, opposite-signal exit, trail, break-even, partial close, Friday
flatten, scale-in, pyramid, grid, martingale, hedge, or discretionary close.

### Filters And No-Trade Contract

- Fail closed for wrong symbol/period/ID/slot/risk mode, invalid label offset,
  late attachment, nonconsecutive weeks, invalid session counts, nonpositive
  endpoints, nonfinite returns, sign disagreement/equality, excess spread,
  invalid quote/ATR/stop, consumed attempt, prior deal, or owned position.
- Both news axes are OFF and Friday close is disabled.
- Runtime reads no current-week signal price, volatility state, magnitude
  threshold, range geometry, calendar-month state, moving average, oscillator,
  volume, open interest, inventory, futures curve, external file, API, or
  portfolio state.

### Trade Management Rules

Own at most one slot-zero position. Keep the original server-side stop frozen.
Close survivors at the first later normalized week and use the ten-day guard
only for stale repair. Never add, reverse, hedge, or retry.

## Parameters To Test

No optimization surface is approved. The Q02 baseline is locked:

| Parameter | Value | Role |
|---|---:|---|
| `strategy_symbol` | setfile symbol | carrier input; never a code literal |
| `strategy_label_offset_seconds` | 86400 | factory energy-label convention |
| `strategy_entry_grace_minutes` | 180 | first-week-bar window |
| `strategy_history_bars` | 40 | bounded D1 history buffer |
| `strategy_required_weeks` | 4 | exact completed packages |
| `strategy_min_week_bars` | 3 | minimum sessions/package |
| `strategy_max_week_bars` | 5 | maximum sessions/package |
| `strategy_return_epsilon` | 0.0 | exact strict sign boundary |
| `strategy_atr_period_d1` | 20 | completed-bar range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale repair only |
| `strategy_max_spread_points` | 1500 | entry cost guard |
| `qm_friday_close_enabled` | false | full-week identity |

## Source-Defined Rules

The paper supplies the disjoint `CMOM1,1` and `CMOM4,2` formation intervals,
their week-`t` holding horizon, continuation ranking, and WTI membership. It
does not supply the conjunction or standalone time-series mapping.

## QM Interpretations

`KWON-KANG-YUN-WTI-WMOM142-AGREE-2026_S01` fixes strict sign agreement,
standalone WTI side mapping, CFD week labels, first-open/final-close endpoints,
zero handling, persistent attempts, fixed-dollar ATR risk, spread cap, and
next-week lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
repair precede entry. No live execution override exists.

## Exit Precedence

1. Broker hard stop and framework kill switch.
2. Malformed or unsafe exposure repair.
3. Later normalized broker-week closure.
4. Ten-calendar-day stale repair.

## Runtime Data Dependencies

Configured-symbol D1 OHLC, broker time, symbol metadata, executable quotes,
completed ATR, framework position/deal history, and terminal-global attempt
state. No external runtime dataset or event calendar is used.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Frozen `3.5*ATR(20,D1)` hard stop; no target or signal-strength sizing.
- Principal risks: source-state dependence, lower density, cross-sectional-to-
  time-series translation, futures/CFD roll and basis, energy-label ambiguity,
  weekend gaps, financing, spread, whipsaw, and realized book correlation.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Strategy Allowability Check

| Gate | Verdict | Evidence |
|---|---|---|
| R1 | PASS_WITH_COMPOSITE_AND_TIME_SERIES_PORT_RISK | Peer-reviewed complete-read source defines both disjoint horizons and WTI membership; conjunction and adverse spanning evidence are explicit. |
| R2 | PASS | Clock, endpoints, agreement, side, attempt, risk, stop, spread, and lifecycle are fixed. |
| R3 | PASS_WITH_CONTINUOUS_CFD_BASIS_RISK | Registered native XTIUSD.DWX D1 history supplies runtime fields. |
| R4 | PASS | Deterministic native arithmetic without trained or banned logic. |

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than five completed trades
in any full post-warm-up year, nonpositive governed economics, disagreement-
state entry, mixed labels, broken week adjacency, invalid session counts,
endpoint leakage, wrong side, repeated attempt, missing stop, wrong exit, or
nondeterminism.

Changing either formation block, conjunction rule, endpoint, carrier, label
policy, attempt, stop, risk, spread, or lifecycle requires a new identity and
full Q00/Q01 cycle. No result-driven rescue is authorized.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact period, labels, four weeks, endpoints, agreement, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus helpers |
| malformed, later-week, and stale repair | Trade Management | `Strategy_ManageOpenPosition` |
| no independent signal close | Trade Close | `Strategy_ExitSignal` returns framework-managed none |
| kill switch, ownership, magic, fixed risk | Framework No-Trade | standard orchestration |
| news OFF | News hook | both framework axes locked OFF |

## Validation Plan

Q01 must prove native and shifted label equivalence, year-boundary adjacency,
three/four/five-session acceptance, two/six rejection, exact `t-1` and
`t-4..t-2` endpoints, positive and negative agreement, disagreement/equality
flat states, no current-bar leakage, persistent attempts, fixed-risk frozen
stops, next-week/stale repair, card lint, strict compile, setfile schema,
resolver identity, PACER input-pin audit, and static reference tests.

Q02 alone measures density and economics. Q09 alone establishes realized
correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-09-07 | initial disjoint weekly momentum agreement card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-09-07 | APPROVED | `decisions/2026-09-07_qm5_41377_wti_disjoint_weekly_momentum_agreement_g0.md` |
| Q01 Build Validation | 2026-09-07 | PASS | governed compile `0a670cc3-b225-4089-95a4-8a89a7515af6`; 0 errors/0 warnings; build check PASS |
| Q02 Baseline Screening | 2026-09-07 | CPU_CEILING_STOP_NOT_ENQUEUED | fresh sample reached 98.829518% against 97% ceiling |

## Safety Boundary

This card authorizes a branch-only non-live build, Q01 validation, one D1
fixed-risk backtest setfile, and one paced target-only Q02 enqueue only below
tester and CPU ceilings. It excludes manual backtests, terminal control,
live/demo/shadow/stress/optimization presets, AutoTrading, `T_Live`, deploy or
T_Live manifests, portfolio-gate changes, admission, decorrelation claims, and
correlation waivers.
