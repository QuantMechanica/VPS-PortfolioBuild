---
card_schema_version: 2
type: strategy
strategy_id: GORSKA-YANG-WTI-FRIWEEKFADE-2026_S01
variant_id: GORSKA-YANG-WTI-FRIWEEKFADE-2026_S01
source_id: GORSKA-YANG-WTI-FRIWEEKFADE-2026
ea_id: QM5_41051
slug: wti-fri-weekfade
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41051_wti-fri-weekfade_card.md
execution_contract_status: APPROVED
created: 2026-08-17
created_by: Research+Development
last_updated: 2026-08-17
g0_status: APPROVED
g0_decision: decisions/2026-08-17_wti_friday_week_pullback_g0.md
source_approval: decisions/2026-08-17_wti_friday_week_pullback_source_approval.md
source_author: "Anna Gorska; Malgorzata Krawiec; Liu Yang; Bige Kahraman Goncu; Athanasios A. Pantelous"
source_authors: "Anna Gorska; Malgorzata Krawiec; Liu Yang; Bige Kahraman Goncu; Athanasios A. Pantelous"
source_citation: "Gorska and Krawiec (2015), Calendar Effects in the Market of Crude Oil, Quantitative Methods in Economics 16(4); Yang, Goncu, and Pantelous, Momentum and Reversal in Commodity Futures, SSRN 3069253."
source_citations:
  - type: academic_journal_article
    citation: "Gorska, A. and Krawiec, M. (2015). Calendar Effects in the Market of Crude Oil. Quantitative Methods in Economics 16(4)."
    location: "Governed extraction strategy-seeds/sources/GORSKA-WTI-CAL-2015/source.md; primary PDF https://ageconsearch.umn.edu/record/230857/files/2015_4_7.pdf"
    quality_tier: A
    role: positive_wti_friday_calendar_direction
  - type: academic_working_paper
    citation: "Yang, L., Goncu, B. K., and Pantelous, A. A. Momentum and Reversal in Commodity Futures. SSRN 3069253."
    location: "Governed extraction strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md; https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3069253"
    quality_tier: B
    role: structural_fixed_horizon_commodity_reversal_lineage
strategy_mechanic: exact-current-monday-open-through-thursday-close-wti-negative-return-friday-long-broker-hour21-flat
sources:
  - "[[sources/GORSKA-YANG-WTI-FRIWEEKFADE-2026]]"
concepts:
  - "[[concepts/crude-oil-day-of-week-seasonality]]"
  - "[[concepts/fixed-horizon-commodity-reversal]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, calendar-reversal, exact-week, friday-session, atr-hard-stop, low-frequency, long-only]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410510000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 20-25 completed WTI Friday-session positions per full post-warm-up year after exact-week, negative-formation, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 22
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_AND_WORKING_PAPER_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_SESSION_LABEL_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING
q02_status: NOT_ENQUEUED
review_focus: "Falsify an exact within-week WTI pullback/Friday calendar sleeve outside the certified XAU/SP500/NDX/XNG book. Verify exact Monday-through-Friday identity, completed Monday-open and Thursday-close endpoints, negative-only long mapping, durable Friday attempt, and same-session flattening. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_monday_friday_week, normalized_energy_label, completed_monday_open, completed_thursday_close, strict_negative_state, no_current_friday_signal_price, friday_decision_clock, friday_attempt_state, long_only_side, friday_hour21_exit, risk_mode_dual, hard_stop_present, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 combines a named academic WTI Friday source and a named commodity-reversal working-paper lineage while declaring the short-horizon conjunction untested; R2 locks exact weekdays, endpoints, sign, direction, attempt, risk, and lifecycle; R3 uses registered native XTI D1 with session-label risk explicit; R4 is deterministic arithmetic without trained logic, banned signal indicators, or external feeds; canonical dedup returned CLEAN and manual family review separated every neighboring WTI Friday identity."
---

# QM5_41051 WTI Exact-Week Pullback / Friday Bounce

## Hypothesis

WTI's source-documented positive Friday return window may be stronger after
the same exact trading week has lost ground from Monday open through Thursday
close. The candidate buys only that Friday session after a strictly negative
completed four-session formation and exits at the governed Friday cutoff.

This is a falsifiable calendar/reversal conjunction. It is not an author-
tested rule, a profitability claim, an inventory forecast, or evidence of low
correlation with the certified portfolio.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/GORSKA-YANG-WTI-FRIWEEKFADE-2026/source.md`, approved
before card extraction in
`decisions/2026-08-17_wti_friday_week_pullback_source_approval.md` at commit
`286fd512d`.

Gorska and Krawiec supply only the positive historical WTI Friday direction.
Yang, Goncu, and Pantelous supply only a broad fixed-horizon commodity-
reversal lineage. Neither tests the exact Monday-open/Thursday-close
formation, one-session Friday hold, Darwinex continuous CFD, risk contract,
or portfolio relationship. No reported source performance transfers.

## Market, Clock, And State

- Host and traded symbol: exact `XTIUSD.DWX` only.
- Timeframe: exact D1 only.
- EA ID / slot / magic: `41051` / `0` / `410510000`.
- Decision: first executable tick of a genuine broker Friday, within 180
  minutes of the executable D1 open.
- Required completed sequence: Thursday, Wednesday, Tuesday, Monday with no
  missing-day substitution.
- Signal endpoints: completed Monday open and completed Thursday close only.
- Position count: at most one owned position.

## Energy-Label Normalization

Infer one label convention from the current Friday bar. Accept native same-day
labels or one uniform `+1` calendar-day offset when the current label is one
day behind broker Friday. Apply the same offset to every completed bar.
Require normalized Friday/Thursday/Wednesday/Tuesday/Monday dates at calendar
offsets zero through four and bounded adjacent session gaps of 20-28 hours.
Any mixed, stale, missing, holiday-compressed, or substituted sequence consumes
the Friday flat.

## Rules

The numbered entry, exit, filter, and management contracts below are frozen as
one strategy identity. They are evaluated only on exact `XTIUSD.DWX` D1 state,
and every invalid or unavailable entry state is flat rather than inferred.

## 4. Entry Rules

1. Repair malformed owned exposure before entry-only filters.
2. Require exact symbol, D1, EA ID, slot, risk mode, news modes, and Friday-
   close inputs.
3. Observe a new D1 bar and confirm broker Friday.
4. Admit only within `strategy_entry_grace_minutes = 180` from the executable
   session open. A late Friday initialization consumes the day.
5. Persist the broker-Friday `yyyymmdd` attempt before history, signal, news,
   spread, quote, ATR, sizing, or order gates. Never retry that date.
6. Require exact completed Thursday, Wednesday, Tuesday, and Monday sessions
   under one uniform energy-label convention.
7. Require finite positive `MondayOpen` and `ThursdayClose` and compute:

   `formation_return = ln(ThursdayClose / MondayOpen)`

8. BUY only when `formation_return < 0`. Positive, exact-zero, invalid, late,
   or broken-calendar states stay flat. Return magnitude never changes size.
9. Require spread no greater than 1,500 points and a valid completed-bar
   `ATR(20,D1)`.
10. Freeze one BUY stop at `entry - 3.0 * ATR`; use no target.

No current Friday open, high, low, close, bid, or ask may enter the signal.
The current quote is execution-only after the completed-bar decision.

## Attempt And Restart Contract

The attempt key is terminal-global, scoped by EA, symbol, and timeframe, and
stores the broker Friday date key. It is written before every fallible gate.
Initialization after the 180-minute Friday grace consumes the missed Friday
without creating a late trade. Deal history and open-position checks provide
additional fail-closed guards. A rejected order, stop-out, news block, spread
failure, restart, or invalid ATR cannot create a same-Friday retry.

## 5. Exit Rules

1. The broker hard stop and framework kill switch remain authoritative.
2. Duplicate, wrong-side, wrong-magic, missing-stop, or otherwise malformed
   owned exposure is flattened.
3. Framework Friday close at broker hour 21 is the normal strategy exit.
4. Any owned position still present at the first later D1 boundary is closed.
5. Three elapsed calendar days is the final stale guard.

There is no profit target, trailing stop, partial close, signal reversal,
scale-in, pyramid, grid, martingale, or hedge.

## 6. Filters (No-Trade Module)

- Require exact `XTIUSD.DWX`, D1, EA ID `41051`, and slot 0.
- Require `RISK_FIXED > 0`, `RISK_PERCENT = 0`, valid stop inputs, news
  temporal OFF, news compliance NONE, and Friday close enabled at hour 21.
- Framework kill-switch, broker, ownership, and Friday-close controls remain
  authoritative.
- Apply the 180-minute attach grace, one-attempt ledger, exact calendar and
  history requirements, spread ceiling, valid quote, and completed ATR gate.
- A filter failure consumes the already-recorded Friday attempt; there is no
  same-session retry or alternate carrier.

## 7. Trade Management Rules

- Own at most one BUY position on the registered magic and symbol.
- Flatten duplicate, wrong-side, missing-stop, or otherwise malformed owned
  exposure before considering a new entry.
- Leave the frozen server-side stop unchanged; do not trail, widen, partial-
  close, reverse, scale, or pyramid.
- Let the framework Friday hour-21 control perform the normal close.
- Close any survivor at the first later D1 boundary or after three calendar
  days as deterministic repair.

## Risk And Sizing

- Backtest mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Portfolio weight: `1.0`.
- Hard stop: frozen `3.0 * ATR(20,D1)`.
- Maximum spread: `1500` points.
- Maximum owned positions: one.
- Friday close: enabled at broker hour 21.
- News temporal mode: OFF.
- News compliance profile: NONE.

Risk is derived from the frozen stop distance through the standard V5 sizing
contract. Formation magnitude does not affect risk or volume.

## Parameters To Test

No optimization surface is approved. The sole baseline uses:

- `strategy_entry_grace_minutes = 180`
- `strategy_atr_period_d1 = 20`
- `strategy_atr_sl_mult = 3.0`
- `strategy_max_hold_days = 3`
- `strategy_max_spread_points = 1500`

Changing the weekday, completed endpoints, sign, direction, stop, or lifecycle
creates a new strategy identity and cannot rescue this card.

## Allowability And Non-Duplicate Review

- R1: `PASS_WITH_COMPOSITE_AND_WORKING_PAPER_RISK`.
- R2: `PASS` with a fully locked calendar, state, side, attempt, risk, and
  lifecycle.
- R3: `PASS_WITH_SESSION_LABEL_RISK` on registered native WTI D1.
- R4: `PASS`; no ML, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, hedge, or pyramid.

The canonical check scanned 4,538 registry rows and 625 root cards and returned
`CLEAN`. Manual review returned
`CLEAN_WTI_EXACT_MONDAY_THURSDAY_LOSS_FRIDAY_BOUNCE_AFTER_FAMILY_REVIEW`:

- `QM5_12753` uses one thresholded Thursday return, not the four-session path;
- `QM5_20117` shorts after a large Thursday surge;
- `QM5_12597` is unconditional;
- `QM5_20145` and `QM5_20172` use 252-D1 states;
- `QM5_41026` uses first-Friday/prior-month state; and
- `QM5_41019` through `QM5_41022` enter from earlier/prior-week momentum.

## Framework Execution Overrides

The framework kill switch, ownership, fixed-risk sizer, position/deal state,
and Friday-close orchestration remain authoritative. Both news axes are OFF.
The strategy adds only exact-calendar entry state, durable attempts, one
frozen hard stop, and stale-position repair. It creates no live alias,
execution-contract registry row, or promotion entitlement.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, attempt, history, calendar, endpoints, sign, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed and later-D1/stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helpers |
| Friday hour-21 close | Framework No-Trade / Friday close | standard framework orchestration |
| fallback close state | Trade Close | `Strategy_ExitSignal` remains deterministic and framework-compatible |
| fixed risk and ownership | Framework No-Trade | standard V5 guards and sizing |
| news OFF | News hooks | both modes OFF and `Strategy_NewsFilterHook` returns false |

## Runtime Data Dependencies

Runtime uses only native D1 OHLC/timestamps, broker time, current quotes,
symbol contract properties, ATR, positions, deals, and terminal-global attempt
state. It has no external event feed, inventory series, futures curve, fitted
artifact, trained output, manual signal, CSV, API, or web dependency.

## Kill Criteria

Retire rather than tune on fewer than five completed positions per full post-
warm-up year; zero trades; nonpositive governed economics; wrong date sequence
or label normalization; current-Friday signal leakage; wrong endpoints, sign,
or side; late/repeated entry; missing stop; wrong Friday lifecycle;
nondeterminism; or registry/risk mismatch.

No weak result may be rescued by adding a threshold, trend, mean, oscillator,
inventory, volatility, body, range, or season filter; changing direction;
changing formation endpoints; or extending the hold.

## Validation Plan

Q01 must prove:

1. same-day and uniform `+1` label conventions accept only exact Monday-
   Thursday history before broker Friday;
2. missing, substituted, mixed-label, late, and non-Friday sequences reject;
3. negative, zero, and positive completed formations map only negative to BUY;
4. Monday open and Thursday close are the only signal prices, with current
   Friday price changes unable to alter the decision;
5. persistent attempts prevent same-Friday retry after every downstream
   failure and restart;
6. fixed-risk sizing uses a valid frozen ATR stop;
7. Friday close, next-D1 repair, malformed repair, and stale guard remain
   reachable; and
8. strict compile, card lint, build checks, setfile schema, magic resolver,
   and static Q01 validation pass.

Q02 alone may measure density and baseline economics. Q09 alone may establish
realized correlation with the certified book.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-17 | initial exact-week pullback / Friday bounce card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-17 | APPROVED | `decisions/2026-08-17_wti_friday_week_pullback_g0.md` |
| Q01 Build Validation | - | PENDING | branch-only build required |
| Q02 Baseline Screening | - | NOT_ENQUEUED | Q01 and capacity gate required |

## Safety Boundary

This card authorizes a non-live build, Q01 validation, one D1 backtest setfile,
and one paced target-only Q02 enqueue below the governed capacity ceilings. It
does not authorize a manual backtest, terminal control, live/demo/shadow/
stress/optimization preset, AutoTrading, `T_Live`, a deploy or T_Live
manifest, portfolio-gate change, portfolio admission, decorrelation claim, or
correlation waiver.
