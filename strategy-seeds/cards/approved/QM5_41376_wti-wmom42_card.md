---
card_schema_version: 2
type: strategy
strategy_id: KWON-KANG-YUN-WTI-WMOM42-2026_S01
variant_id: KWON-KANG-YUN-WTI-WMOM42-2026_S01
source_id: KWON-KANG-YUN-WTI-WMOM42-2026
ea_id: QM5_41376
slug: wti-wmom42
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41376_wti-wmom42_card.md
execution_contract_status: APPROVED
created: 2026-09-07
created_by: Research+Development
last_updated: 2026-09-07
g0_status: APPROVED
g0_decision: decisions/2026-09-07_qm5_41376_wti_skipped_week_three_week_momentum_g0.md
source_approval: decisions/2026-09-07_wti_skipped_week_three_week_momentum_source_approval.md
source_author: "Kyung Yoon Kwon; Jangkoo Kang; Jaesun Yun"
source_authors: "Kyung Yoon Kwon; Jangkoo Kang; Jaesun Yun"
source_citation: "Kwon, K. Y., Kang, J., and Yun, J. (2020), Weekly Momentum in the Commodity Futures Market, Finance Research Letters 35, 101306, DOI 10.1016/j.frl.2019.101306."
source_citations:
  - type: peer_reviewed_paper
    citation: "Kwon, Kyung Yoon; Kang, Jangkoo; and Yun, Jaesun (2020), Weekly Momentum in the Commodity Futures Market, Finance Research Letters 35, 101306."
    location: "DOI 10.1016/j.frl.2019.101306; complete-read packet strategy-seeds/sources/KWON-KANG-YUN-WTI-WMOM42-2026/source.md"
    quality_tier: A
    role: exact_weeks_t_minus_4_through_t_minus_2_formation_one_week_holding_plus_wti_membership
strategy_mechanic: normalized-week-boundary-wti-cumulative-t-minus-4-through-t-minus-2-first-open-final-close-log-return-sign-continuation-skip-t-minus-1-one-week-hold
sources: ["[[sources/KWON-KANG-YUN-WTI-WMOM42-2026]]"]
concepts: ["[[concepts/weekly-commodity-momentum]]", "[[concepts/wti-structural-trend]]"]
indicators: ["[[indicators/completed-week-log-return]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, energy, wti-crude, weekly-momentum, structural-trend, symmetric-long-short, skipped-recent-week, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 413760000
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
q01_status: PENDING
q02_status: NOT_ENQUEUED
parameters_to_test: "Locked Q02 baseline only: exact D1; 40-bar history buffer; four consecutive completed 3-5-session weeks; exclude t-1; strict nonzero ln(final close of t-2/first open of t-4) sign continuation; 180-minute entry grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
review_focus: "Falsify the source-horizon CMOM4,2 WTI stream outside the certified XAU/SP500/NDX/XNG book. Verify exact t-4..t-2 endpoints, complete exclusion of t-1, no magnitude or volatility gate, durable weekly attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_week_bar, four_consecutive_completed_weeks, excluded_immediate_week, formation_first_open_final_close, strict_log_return_sign, no_current_week_leakage, weekly_attempt_state, risk_mode_dual, hard_stop_present, next_week_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission and decisions/2026-09-07_qm5_41376_wti_skipped_week_three_week_momentum_g0.md: R1-R4 pass within disclosed cross-sectional-to-time-series, sibling-spanning, and continuous-CFD risks. Canonical dedup found only expected same-paper QM5_41375; manual review separates exact t-4..t-2 formation with t-1 excluded from the t-1-only sibling and monthly skip-one systems."
---

# QM5_41376 WTI Skipped-Recent-Week Three-Week Momentum

## Hypothesis

WTI's cumulative return over broker weeks `t-4` through `t-2` retains enough
directional information to persist through week `t`, even after deliberately
excluding the immediately recent week `t-1`. At the first tradable D1 bar of a
new week, buy after a strictly positive formation return and sell after a
strictly negative return, then flatten at the next week boundary.

Kwon, Kang, and Yun define cross-sectional `CMOM4,2` with this exact formation
and one-week holding horizon and include light sweet crude oil. They do not
establish a standalone WTI time-series edge, continuous-CFD implementation,
fixed-risk ATR stop, or independence from their stronger `CMOM1,1`; those are
falsifiable QM translations.

## Source Traceability And Claim Boundary

The single source of record is
`strategy-seeds/sources/KWON-KANG-YUN-WTI-WMOM42-2026/source.md`, approved before
card extraction in
`decisions/2026-09-07_wti_skipped_week_three_week_momentum_source_approval.md`.
The complete accepted manuscript explicitly defines formation on weeks `t-4`
through `t-2`, a week-`t` hold, and adverse evidence that the signal is largely
spanned by `CMOM1,1`. No reported result transfers to this one-asset CFD port.

## Non-Duplicate Decision

Canonical checking found expected same-paper sibling `QM5_41375_wti-wmom1`.
That EA forms only on `t-1`; this card must exclude `t-1` and form on exactly
the cumulative first-open-to-final-close path from `t-4` through `t-2`.
`QM5_20284_wti-skip1-trend` is a twelve-month monthly rule that skips one month.
Other weekly WTI systems add sign sequences, volatility states, calendar gates,
or OHLC geometry. Verdict:
`DISTINCT_WTI_CMOM42_EXACT_T_MINUS_4_TO_T_MINUS_2_SKIP_T_MINUS_1_WEEKLY_CONTINUATION`.

## Market, Clock, And State

- Host/traded symbol: input-bound exact `XTIUSD.DWX` in the factory preset.
- Timeframe: exact D1 only; EA ID/slot/magic: `41376`/`0`/`413760000`.
- Decision: first executable tick of a new normalized Monday-anchored broker
  week, within 180 elapsed minutes of the raw D1 session open.
- Signal: four consecutive completed week packages; `t-1` validates chronology
  but contributes no price to the formation return.
- At most one owned position and one consumed attempt per week.

## Energy-Label Normalization

Infer one label convention from the current D1 bar. Accept native same-day
labels or a uniform `+1` calendar-day energy convention when the raw label is
one date behind broker time. Apply it consistently to all bars. Never shift
broker time or mix conventions. Each completed package must contain three to
five unique, strictly ordered sessions; four week anchors must be exactly seven
days apart and the newest must be exactly seven days before the current anchor.

## Rules

### Entry Rules

1. Repair malformed owned exposure before entry-only filters.
2. Require exact preset symbol, D1, EA ID/slot, fixed-risk mode, news OFF, and
   Friday close disabled.
3. On a new D1 bar, derive the current normalized Monday anchor.
4. Admit only within `strategy_entry_grace_minutes=180`; late attachment
   consumes the week flat.
5. Persist the weekly attempt before history, signal, spread, quote, ATR,
   sizing, or order gates; never retry after downstream failure.
6. Reconstruct four consecutive completed three-to-five-session weeks.
7. Exclude newest completed week `t-1` from formation arithmetic.
8. Set `formation_open` to the first chronological session open of `t-4` and
   `formation_close` to the final session close of `t-2`.
9. Compute `formation_return=ln(formation_close/formation_open)`; BUY iff
   positive, SELL iff negative, equality or invalid arithmetic flat.
10. Require spread <=1,500 points and completed-bar `ATR(20,D1)`.
11. Freeze a hard stop at `3.5*ATR`; use no target and open at most one fixed-
    risk position. Return magnitude never changes risk.

### Attempt And Restart Contract

Store the normalized current Monday anchor in a terminal-global key scoped by
EA, symbol, and timeframe before fallible gates. Late initialization consumes
the missed week. Deal-history and open-position checks fail closed. Rejected
orders, stops, news, spread, restart, history, ATR, or sizing failures cannot
create a same-week retry.

### Exit Rules

Broker hard stop and framework kill switch remain authoritative. Flatten
duplicate, wrong-side, wrong-magic, missing-stop, or malformed owned exposure.
Close on the first tick whose normalized Monday anchor is later than the entry-
week anchor. Ten elapsed calendar days is stale repair only. No take-profit,
opposite signal, trail, break-even, partial close, Friday flatten, scale-in,
pyramid, grid, martingale, hedge, or discretionary close.

### Filters And No-Trade Contract

Require EA ID 41376, slot 0, D1, configured symbol, `RISK_FIXED>0`,
`RISK_PERCENT=0`, news temporal OFF, news compliance NONE, Friday close
disabled, and valid finite strategy inputs. Apply label, week adjacency,
session-count, excluded-week, positive-price, nonzero-return, spread, quote,
ATR, and entry-grace checks fail closed. Use no volatility, magnitude,
body/range, moving average, oscillator, volume, open interest, inventory,
calendar/event, curve, external file, API, or portfolio-state input.

## Parameters To Test

No optimization surface is approved. Locked baseline:

| Parameter | Value | Role |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | first-week-bar entry window |
| `strategy_history_bars` | 40 | bounded D1 buffer |
| `strategy_formation_weeks` | 3 | exact `t-4..t-2` formation |
| `strategy_skip_recent_weeks` | 1 | excludes `t-1` |
| `strategy_min_week_bars` | 3 | minimum sessions/package |
| `strategy_max_week_bars` | 5 | maximum sessions/package |
| `strategy_return_epsilon` | 0.0 | strict sign boundary |
| `strategy_atr_period_d1` | 20 | completed-bar range |
| `strategy_atr_sl_mult` | 3.5 | frozen stop distance |
| `strategy_max_hold_days` | 10 | stale repair only |
| `strategy_max_spread_points` | 1500 | entry cost guard |
| `qm_friday_close_enabled` | false | full-week identity |

## Source-Defined Rules

The paper supplies exact `t-4..t-2` cumulative-return formation, exclusion of
`t-1`, a week-`t` holding horizon, continuation ranking, and WTI membership.

## QM Interpretations

Standalone WTI sign mapping, CFD week labels, first-open/final-close endpoints,
zero boundary, durable attempt, fixed-dollar ATR risk, spread cap, and lifecycle
are QM interpretations.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
repair precede entry. No live execution override exists.

## Exit Precedence

1. Broker hard stop and framework kill switch.
2. Malformed or unsafe exposure repair.
3. Later normalized broker-week closure.
4. Ten-calendar-day stale repair.

## Runtime Data Dependencies

Configured-symbol D1 OHLC, broker time, symbol metadata, quotes, completed ATR,
framework position/deal state, and persistent terminal global state only.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop `3.5*ATR(20,D1)`; no target or strength sizing.
- Principal risks: cross-sectional-to-time-series translation, source sibling
  spanning, CFD roll/basis, week labels, weekend gaps, financing, spread,
  whipsaw, and book correlation.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Strategy Allowability Check

| Gate | Verdict | Evidence |
|---|---|---|
| R1 | PASS | One peer-reviewed complete-read paper; DOI, hash, exact horizon, WTI membership, and adverse evidence retained. |
| R2 | PASS | Clock, endpoints, excluded week, sign, side, attempt, risk, stop, spread, and lifecycle fixed. |
| R3 | PASS | Registered native XTIUSD.DWX D1 supplies runtime fields; CFD basis risk remains. |
| R4 | PASS | Deterministic native arithmetic; no ML, banned signal, external feed, grid, martingale, or pyramid. |

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than five completed trades
in any full post-warm-up year, nonpositive governed economics, wrong/mixed
labels, nonconsecutive weeks, inclusion of `t-1`, wrong endpoints, current-week
leakage, wrong sign, repeated attempts, missing stop, wrong exit, or
nondeterminism. Changing carrier, formation/skip/hold horizon, endpoint, sign,
attempt, risk, stop, or lifecycle requires a new identity and Q00/Q01 cycle.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact period, four weeks, excluded `t-1`, endpoints, sign, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` and helpers |
| malformed, later-week, stale repair | Trade Management | `Strategy_ManageOpenPosition` |
| no independent signal close | Trade Close | `Strategy_ExitSignal` returns false |
| kill switch, ownership, magic, fixed risk | Framework No-Trade | standard orchestration |
| news OFF | News hook | returns false; framework axes locked OFF |

## Validation Plan

Q01 must prove week adjacency including year boundaries, 3/4/5-session
acceptance, 2/6 rejection, exact `t-4` open and `t-2` close endpoints, complete
`t-1` exclusion, sign cases, no current-bar leakage, durable attempts, fixed-
risk frozen stops, next-week/stale repair, card lint, strict compile, setfile
schema, resolver identity, PACER input-pin audit, and static artifact validation.
Q02 alone measures density/economics; Q09 alone measures book correlation.

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-09-07 | APPROVED | `decisions/2026-09-07_qm5_41376_wti_skipped_week_three_week_momentum_g0.md` |
| Q01 Build Validation | — | PENDING | governed compile required |
| Q02 Baseline Screening | — | NOT_ENQUEUED | exact XTIUSD.DWX D1 fixed-risk row only |

## Safety Boundary

This card authorizes a branch-only non-live build, Q01 validation, one D1 fixed-
risk backtest setfile, and one paced target-only Q02 enqueue only below tester
and CPU ceilings. It excludes manual backtests, terminal control, live/demo/
shadow/stress/optimization presets, AutoTrading, `T_Live`, deploy or T_Live
manifests, portfolio-gate changes, admission, decorrelation claims, and waivers.
