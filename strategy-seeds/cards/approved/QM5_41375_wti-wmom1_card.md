---
card_schema_version: 2
type: strategy
strategy_id: KWON-KANG-YUN-WTI-WMOM1-2026_S01
variant_id: KWON-KANG-YUN-WTI-WMOM1-2026_S01
source_id: KWON-KANG-YUN-WTI-WMOM1-2026
ea_id: QM5_41375
slug: wti-wmom1
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41375_wti-wmom1_card.md
execution_contract_status: APPROVED
created: 2026-09-07
created_by: Research+Development
last_updated: 2026-09-07
g0_status: APPROVED
g0_decision: decisions/2026-09-07_qm5_41375_wti_pure_one_week_momentum_g0.md
source_approval: decisions/2026-09-07_wti_pure_one_week_momentum_source_approval.md
source_author: "Kyung Yoon Kwon; Jangkoo Kang; Jaesun Yun"
source_authors: "Kyung Yoon Kwon; Jangkoo Kang; Jaesun Yun"
source_citation: "Kwon, K. Y., Kang, J., and Yun, J. (2020), Weekly Momentum in the Commodity Futures Market, Finance Research Letters 35, 101306, DOI 10.1016/j.frl.2019.101306."
source_citations:
  - type: peer_reviewed_paper
    citation: "Kwon, Kyung Yoon; Kang, Jangkoo; and Yun, Jaesun (2020), Weekly Momentum in the Commodity Futures Market, Finance Research Letters 35, 101306."
    location: "DOI 10.1016/j.frl.2019.101306; complete-read packet strategy-seeds/sources/KWON-KANG-YUN-WTI-WMOM1-2026/source.md"
    quality_tier: A
    role: exact_one_week_formation_and_holding_horizon_plus_wti_membership
strategy_mechanic: normalized-week-boundary-wti-one-immediately-completed-three-to-five-session-week-first-open-to-final-close-log-return-sign-continuation-one-week-hold
sources: ["[[sources/KWON-KANG-YUN-WTI-WMOM1-2026]]"]
concepts: ["[[concepts/weekly-commodity-momentum]]", "[[concepts/wti-structural-trend]]"]
indicators: ["[[indicators/completed-week-log-return]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, energy, wti-crude, weekly-momentum, structural-trend, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 413750000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 45-52 completed WTI positions per full post-warm-up year before execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 48
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED_PENDING
parameters_to_test: "Locked Q02 baseline only: exact D1; 16-bar history buffer; 3-5 immediately completed week sessions; strict nonzero ln(final close/first open) sign continuation; 180-minute entry grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
review_focus: "Falsify the source-horizon pure one-week WTI momentum stream outside the certified XAU/SP500/NDX/XNG book. Verify exact prior completed week, first open/final close, sign-only continuation, no low-volatility or body/range gate, consumed weekly attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_week_bar, immediate_completed_monday_anchor, completed_week_session_count, first_open_final_close, strict_log_return_sign, no_current_week_leakage, weekly_attempt_state, risk_mode_dual, hard_stop_present, next_week_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission and decisions/2026-09-07_qm5_41375_wti_pure_one_week_momentum_g0.md: R1-R4 pass within disclosed cross-sectional-to-time-series and continuous-CFD risks. Correct-root dedup returned CLEAN across 4,855 registry rows, 1,468 cards, and 45 wiki nodes. Manual review separates the pure prior-week sign from low-volatility, body-dominance, multi-week path, calendar, event, monthly trend, and certified XNG RSI families."
---

# QM5_41375 WTI Pure One-Week Momentum

## Hypothesis

The sign of WTI's immediately completed broker-week return persists through the
next broker week. At the first tradable D1 bar of a new week, buy after a
strictly positive prior-week open-to-close return and sell after a strictly
negative return, then flatten at the next week boundary.

Kwon, Kang, and Yun document strong cross-sectional one-week commodity-futures
momentum and explicitly include light sweet crude oil. They do not establish a
standalone WTI time-series edge, continuous-CFD implementation, fixed-risk ATR
stop, or relationship to the QM book. Those remain falsifiable translations.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/KWON-KANG-YUN-WTI-WMOM1-2026/source.md`, approved before
card extraction in
`decisions/2026-09-07_wti_pure_one_week_momentum_source_approval.md` at commit
`028c8772cd`.

The complete 20-page accepted manuscript defines `CMOM1,1` from week `t-1`
and holds the ranked portfolio in week `t`. Its cross-sectional winner-minus-
loser construction is not reproduced by a one-asset sign rule. No reported
return, significance, robustness, or speculative-flow explanation transfers.

## Non-Duplicate Decision

Canonical pre-allocation checking scanned 4,855 EA-registry rows, 1,468 cards,
and 45 Strategy Wiki nodes and returned CLEAN with no fuzzy match. Manual
boundaries are load-bearing:

- `QM5_13049_xti-1w-mom-vol` requires a low-volatility filter; this card has no
  volatility state and trades every valid nonzero prior-week return.
- `QM5_41092_wti-wbody-dominance-mom` requires strict aggregate weekly
  body/range greater than two-thirds; this card uses no high/low geometry.
- `QM5_41065`-`41074` require sign transitions, acceleration, deceleration,
  pullbacks, streaks, or multi-week return states.
- WTI event, inventory, weekday, month-seasonality, intraday, and monthly
  trend systems use different clocks and state.
- Certified `QM5_12567` is a long-only two-day cumulative-RSI2 XNG pullback.

The exact WTI carrier, immediately completed Monday-anchored three-to-five-
session week, chronological first open/final close, strict log-return sign,
same-sign side, durable weekly attempt, fixed risk, and one-week hold jointly
define this identity. Verdict:
`DISTINCT_WTI_PURE_IMMEDIATELY_COMPLETED_WEEK_RETURN_SIGN_CONTINUATION`.

## Market, Clock, And State

- Host and traded symbol: input-bound exact `XTIUSD.DWX` in factory presets.
- Timeframe: exact D1 only.
- EA ID, slot, and magic: `41375`, `0`, and `413750000`.
- Decision: first executable tick of a new normalized Monday-anchored broker
  week, within 180 elapsed minutes of the raw D1 session open.
- Signal data: exact immediately completed weekly package only; current-week
  OHLC is excluded.
- At most one owned position and one consumed attempt per week.

## Energy-Label Normalization

Infer one label convention from the current D1 bar. Accept native same-day
labels or a uniform `+1` calendar-day energy convention when the raw label is
one date behind broker time. Apply it consistently to current and historical
bars. Never shift broker time or mix conventions.

The normalized current week must be exactly seven calendar days after the
completed package anchor. Accept only three to five unique, strictly ordered
completed sessions. Reject duplicate dates, mixed labels, invalid OHLC,
nonadjacent anchors, and two- or six-session packages.

## Rules

### Entry Rules

1. Repair malformed owned exposure before entry-only filters.
2. Require exact symbol input, D1, EA ID, slot, fixed-risk mode, news OFF, and
   Friday-close disabled.
3. On a new D1 bar, derive the current normalized Monday anchor.
4. Admit only within `strategy_entry_grace_minutes=180`; late attachment
   consumes the week flat.
5. Persist the weekly attempt before history, signal, news, spread, quote,
   ATR, sizing, or order gates. Never retry after downstream failure.
6. Aggregate the immediately completed three-to-five-session week and require
   exact seven-day anchor adjacency.
7. Use `week_open` from its first chronological session and `week_close` from
   its final session. Require finite positive values.
8. Compute `week_return=ln(week_close/week_open)`.
9. BUY iff `week_return>0`; SELL iff `week_return<0`; exact zero or invalid
   arithmetic stays flat.
10. Require spread no greater than 1,500 points and completed-bar
    `ATR(20,D1)`.
11. Freeze a hard stop at `3.5*ATR`; use no target.
12. Open at most one fixed-risk position. Return magnitude never changes risk.

### Attempt And Restart Contract

Store the normalized current Monday anchor in a terminal-global key scoped by
EA, symbol, and timeframe before fallible gates. Late initialization consumes
the missed week. Deal-history and open-position checks fail closed. Rejected
orders, stops, news, spread, restart, history, ATR, or sizing failures cannot
create a same-week retry.

### Exit Rules

1. Broker hard stop and framework kill switch remain authoritative.
2. Flatten duplicate, wrong-side, wrong-magic, missing-stop, or malformed
   owned exposure.
3. Close on the first tick whose normalized Monday anchor is later than the
   entry-week anchor.
4. Ten elapsed calendar days is stale repair only.

No take-profit, opposite signal, trail, break-even, partial close, Friday
flatten, scale-in, pyramid, grid, martingale, hedge, or discretionary close.

### Filters And No-Trade Contract

- Require EA ID 41375, slot 0, D1, and the configured factory symbol.
- Require `RISK_FIXED>0`, `RISK_PERCENT=0`, news temporal OFF, news compliance
  NONE, Friday close disabled, and valid finite strategy inputs.
- Apply label, anchor, session-count, positive-close, nonzero-return, spread,
  quote, ATR, and entry-grace checks fail closed.
- Use no volatility, body/range, magnitude, parent-range, close-location,
  moving average, oscillator, volume, open interest, inventory, event calendar,
  futures curve, external file, API, or portfolio-state input.

### Trade Management Rules

Own at most one position. Repair unsafe composition before entry logic. Keep
the server-side stop frozen and close a survivor at the first later normalized
week; the ten-day guard is stale repair only.

## Parameters To Test

No optimization surface is approved. The only baseline is:

| Parameter | Locked value | Role |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | first-week-bar entry window |
| `strategy_history_bars` | 16 | bounded D1 buffer |
| `strategy_min_week_bars` | 3 | minimum sessions |
| `strategy_max_week_bars` | 5 | maximum sessions |
| `strategy_return_epsilon` | 0.0 | exact strict sign boundary |
| `strategy_atr_period_d1` | 20 | completed-bar range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale repair only |
| `strategy_max_spread_points` | 1500 | entry cost guard |
| `qm_friday_close_enabled` | false | full-week identity |

## Source-Defined Rules

The paper supplies the immediately prior one-week formation horizon, one-week
holding horizon, continuation ranking, and light sweet crude oil membership.

## QM Interpretations

The standalone WTI sign mapping, continuous-CFD week labels, first-open/final-
close endpoints, exact zero boundary, persistent attempt, fixed-dollar ATR
risk, spread cap, and lifecycle are explicit QM interpretations.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
repair precede entry. No live execution override exists.

## Exit Precedence

1. Broker hard stop and framework kill switch.
2. Malformed or unsafe exposure repair.
3. Later normalized broker-week closure.
4. Ten-calendar-day stale repair.

## Runtime Data Dependencies

Configured symbol D1 OHLC, broker time, symbol metadata, quotes, completed ATR,
framework position/deal state, and persistent terminal global-variable state.
There is no external runtime dataset or event calendar.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5*ATR(20,D1)`; no target or strength sizing.
- Principal risks: cross-sectional-to-time-series translation, CFD roll/basis,
  week-label ambiguity, weekend gaps, financing, spread, whipsaw, and book
  correlation.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Strategy Allowability Check

| Gate | Verdict | Evidence |
|---|---|---|
| R1 | PASS | Peer-reviewed paper, complete accepted manuscript, DOI, retrieval hash, exact horizon, and WTI membership; port risk disclosed. |
| R2 | PASS | Clock, endpoints, sign, side, attempt, risk, stop, spread, and lifecycle fixed. |
| R3 | PASS | Registered native XTIUSD.DWX D1 history supplies runtime fields; label and CFD-basis risk remain. |
| R4 | PASS | Deterministic native arithmetic; no ML, banned signal, external feed, grid, martingale, or pyramid. |

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than five completed trades
in any full post-warm-up year, nonpositive governed economics, wrong/mixed
labels, nonadjacent weeks, invalid session count, current-week leakage, wrong
sign, late/repeated attempts, missing stop, wrong exit, or nondeterminism.

Changing carrier, formation/holding week, endpoint definition, sign mapping,
attempt, risk, stop, or lifecycle requires a new identity and Q00/Q01 cycle.
A failure may not be rescued with volatility, body/range, magnitude, calendar,
event, inventory, moving-average, or other filters.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact period, label, week, endpoints, sign, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` and helpers |
| malformed, later-week, stale repair | Trade Management | `Strategy_ManageOpenPosition` |
| no independent signal close | Trade Close | `Strategy_ExitSignal` returns false |
| kill switch, ownership, magic, fixed risk | Framework No-Trade | standard orchestration |
| news OFF | News hook | returns false; framework axes locked OFF |

## Validation Plan

Q01 must prove label equivalence, week adjacency including year boundaries,
three/four/five-session acceptance, two/six rejection, first-open/final-close
endpoints, positive/negative/zero sign cases, no current-bar leakage, durable
attempts, fixed-risk frozen stops, next-week/stale repair, card lint, strict
compile, setfile schema, resolver identity, PACER input-pin audit, and static
artifact validation.

Q02 alone measures density and baseline economics. Q09 alone establishes
realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-09-07 | initial pure one-week WTI momentum card | G0 | APPROVED |
| v2 | 2026-09-07 | Q01 governed compile/build-check and first Q02 intake | Q01/Q02 | PASS; ENQUEUED_PENDING `e9ebd527-13f3-4913-8bf5-13dc8d7c229a` |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-09-07 | APPROVED | `decisions/2026-09-07_qm5_41375_wti_pure_one_week_momentum_g0.md` |
| Q01 Build Validation | 2026-09-07 | PASS | governed compile successor `9349c325-5440-48bc-bd4d-6f22ad8ad728`; 0 errors/0 warnings; build check PASS |
| Q02 Baseline Screening | 2026-09-07 | ENQUEUED_PENDING | exact XTIUSD.DWX D1 fixed-risk row `e9ebd527-13f3-4913-8bf5-13dc8d7c229a` |

## Safety Boundary

This card authorizes a branch-only non-live build, Q01 validation, one D1
fixed-risk backtest setfile, and one paced target-only Q02 enqueue only below
tester and CPU ceilings. It excludes manual backtests, terminal control,
live/demo/shadow/stress/optimization presets, AutoTrading, `T_Live`, deploy or
T_Live manifests, portfolio-gate changes, admission, decorrelation claims, and
correlation waivers.
