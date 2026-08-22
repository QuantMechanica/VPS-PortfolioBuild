---
card_schema_version: 2
type: strategy
strategy_id: MOP-XNG-WRANGE-MIGRATE-MOM-2026_S01
variant_id: MOP-XNG-WRANGE-MIGRATE-MOM-2026_S01
source_id: MOP-XNG-WRANGE-MIGRATE-MOM-2026
ea_id: QM5_41101
slug: xng-wrange-migrate-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41101_xng-wrange-migrate-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-22
created_by: Research+Development
last_updated: 2026-08-22
g0_status: APPROVED
g0_decision: decisions/2026-08-22_qm5_41101_xng_weekly_range_migration_momentum_g0.md
source_approval: decisions/2026-08-22_xng_weekly_range_migration_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: academic_paper
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded translation strategy-seeds/sources/MOP-XNG-WRANGE-MIGRATE-MOM-2026/source.md"
    quality_tier: A
    role: own_price_continuation_and_natural_gas_carrier_lineage
strategy_mechanic: normalized-week-boundary-xng-two-consecutive-completed-weekly-ohlc-packages-strict-higher-high-higher-low-or-lower-high-lower-low-auction-range-migration-continuation-one-week-hold
sources:
  - "[[sources/MOP-XNG-WRANGE-MIGRATE-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/completed-week-auction-range-migration]]"
  - "[[concepts/natural-gas-structural-trend]]"
indicators:
  - "[[indicators/completed-week-high-low-structure]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, natural-gas, structural-trend, completed-week-range-migration, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
host_symbol: XNGUSD.DWX
symbol_slot: 0
magic: 411010000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 12-24 completed XNG positions per full post-warm-up year after exact weekly history, strict two-endpoint migration, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 18
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WEEKLY_RANGE_STATE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PENDING_BUILD
q02_status: NOT_QUEUED
review_focus: "Falsify an XNG completed-week auction-range migration trend distinct from certified QM5_12567. Verify uniform energy labels, exact Monday anchors, two consecutive completed weekly OHLC packages, three-to-five sessions each, strict HH+HL or LH+LL state, mixed/equality flat, one attempt, fixed risk, and next-week exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_week_bar, consecutive_monday_anchors, completed_weekly_ohlc, bounded_week_session_counts, strict_two_endpoint_range_migration, equality_and_mixed_flat, no_current_week_leakage, weekly_attempt_state, risk_mode_dual, hard_stop_present, next_week_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER-authorized XNG sleeve; R1 complete-read peer-reviewed natural-gas source with weekly range-state translation risk disclosed; R2 exact labels, weeks, OHLC, strict HH+HL/LH+LL, attempt, risk, and lifecycle; R3 registered native XNG D1; R4 deterministic price arithmetic; no XNG identity collision"
---

# QM5_41101 XNG Completed-Week Auction-Range Migration Momentum

## Hypothesis

When both endpoints of natural gas's completed weekly auction range migrate in
the same direction versus the parent week, the whole price-discovery region
has shifted rather than merely printing a close-to-close fluctuation.
Following a strict higher-high/higher-low state long or a strict lower-high/
lower-low state short for the next broker week may capture a structural XNG
trend that is materially different from the certified two-day oscillator
pullback.

The XNG carrier is already represented in the certified book by
`QM5_12567`, but the signal, direction set, horizon, and lifecycle here are
different. That does not establish profitability or decorrelation. Q02 owns
frequency and baseline economics; unchanged Q09 alone may establish realized
portfolio correlation.

## Source Traceability And Claim Boundary

The sole source of record is
`strategy-seeds/sources/MOP-XNG-WRANGE-MIGRATE-MOM-2026/source.md`, authorized
before extraction by
`decisions/2026-08-22_xng_weekly_range_migration_momentum_source_approval.md`
at commit `9169ec306`. The complete parent source hash is
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

Moskowitz, Ooi, and Pedersen document own-return continuation over monthly
horizons and include natural-gas futures in their commodity universe. They do
not test a weekly higher-high/higher-low or lower-high/lower-low state, a
continuous CFD, fixed-dollar ATR risk, or the QM book. Every weekly clock,
range-state, execution, and risk choice below is a declared QM interpretation.

No source return, XNG-only alpha, profit factor, drawdown, trade count,
transaction cost, CFD equivalence, neutrality, or correlation statistic is
imported.

## Non-Duplicate Decision

The canonical pre-allocation checker included author and mechanic fields,
scanned 4,590 registry identities, 1,269 repository cards, and 45 Strategy-
Wiki nodes. It found no exact identity and returned the expected fuzzy WTI
carrier sibling. After allocation, the exact hit is solely the reserved
`QM5_41101` registry row. Manual semantic review fixes the boundaries:

- `QM5_41089_wti-wrange-migrate-mom` is the separately falsifiable WTI
  carrier sibling. No WTI result or execution evidence transfers to XNG.
- certified `QM5_12567_cum-rsi2-commodity` is long-only and buys a two-day
  cumulative-RSI2 pullback under a slow trend filter. This card is symmetric,
  oscillator-free, compares two complete weekly ranges, and holds to the next
  weekly boundary.
- `QM5_41081_xng-wclose-location-mom` uses parent-close-to-new-close return
  sign and the newest close's location in its range. This card reads no close
  and has no close-location threshold.
- `QM5_41094_xng-wbody-dominance-mom` compares one completed week's open-
  close body with its high-low range. This card reads neither open nor close
  and instead compares two completed high-low packages.
- `QM5_41063_xng-week-nr7-brk` ranks seven ranges and waits for a current-week
  breakout. This card ranks nothing and excludes all current-week signal
  price.
- `QM5_10596_mql5-highlow` counts a configurable H4 bar run and exits on an
  opposite H4 star. It is not a completed-week XNG auction package.

The exact XNG carrier, two consecutive completed weekly packages, three-to-
five-session contract, strict same-direction migration of both aggregate
weekly extremes, mixed/equality-flat rule, boundary entry, durable attempt,
and one-week lifecycle are jointly load-bearing. Verdict:
`CLEAN_XNG_COMPLETED_WEEK_TWO_ENDPOINT_AUCTION_RANGE_MIGRATION_CONTINUATION_AFTER_CARRIER_AND_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Target symbol and host: exact `XNGUSD.DWX`.
- Timeframe: exact D1; magic slot 0; planned magic `411010000`.
- Decision: first tradable normalized D1 bar of a new Monday-anchored broker
  week, within 180 elapsed raw-session minutes.
- Formation: the two immediately preceding consecutive completed broker-week
  OHLC packages, with three to five completed sessions each.
- Normal exit: first tick whose broker Monday anchor is later than the open
  position's anchor.
- Expected frequency: approximately 12-24 completed positions/year; Q02 must
  prove at least five per full post-warm-up year or retire.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Formula

Let `H0` and `L0` be the newest completed week's aggregate high and low, and
`H1` and `L1` its consecutive parent's aggregate high and low:

```text
H0 > H1 and L0 > L1  => BUY XNGUSD.DWX
H0 < H1 and L0 < L1  => SELL XNGUSD.DWX
otherwise             => FLAT
```

All values complete before the decision week begins. The current D1 open,
high, low, close, volume, and tick price never enter the signal. Equality at
either endpoint, an inside or outside week, or one-up/one-down mixed migration
is flat. Migration distance never changes eligibility or risk.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XNGUSD.DWX` D1 bar under EA 41101 and
   magic slot zero.
2. Repair malformed, later-week, or stale owned exposure before entry-only
   gates.
3. Select label offset zero when the raw current D1 date equals broker date,
   or `+1` day only when it is exactly one calendar day behind. Apply the same
   convention to every historical bar and reject every other or mixed state.
4. Derive the current Monday anchor from normalized time. Require the newest
   completed bar to have an older anchor, proving the current bar is the first
   tradable bar of this week.
5. Require attachment within 180 elapsed minutes of raw D1 bar open. Persist
   the current Monday-anchor attempt before history, signal, spread, quote,
   ATR, sizing, news, or order gates. Never retry that week.
6. Require no owned position and no same-magic entry deal already recorded in
   the current broker week.
7. Within a fixed 30-bar buffer, reconstruct exactly the immediately completed
   week and its parent. Require anchors at current minus 7 and 14 calendar
   days, strict reverse-time bar order, three to five unique sessions per
   week, positive finite OHLC, and strict positive aggregate ranges.
8. Aggregate maximum high and minimum low independently for each week. Buy
   only when both newest endpoints are strictly higher. Sell only when both
   are strictly lower. Equality, inside/outside geometry, or mixed migration
   stays flat.
9. Require a valid executable quote and no genuinely positive spread wider
   than 1,500 points. Modeled zero `.DWX` spread is valid.
10. Attach one frozen hard stop at `3.5 * ATR(20,D1)` from completed data and
    size one position to `RISK_FIXED=1000`. Use no take-profit.
11. Submit one slot-zero market order once. No pending order, retry, scale-in,
    grid, martingale, pyramid, hedge, or second entry exists.

## 5. Exit Rules

1. Broker hard stop and framework kill-switch closure remain authoritative.
2. Immediately flatten duplicate, wrong-symbol, wrong-magic, missing-stop,
   invalid-volume, or invalid-open-time exposure.
3. Close on the first tick whose broker Monday anchor is later than the
   position-open Monday anchor.
4. Close after ten elapsed calendar days as a stale safety repair.
5. No Friday close, target, signal flip, trail, break-even move, partial exit,
   discretionary close, or intentional hold beyond the next week.

## 6. Filters (No-Trade Module)

- Exact host, D1, EA 41101, slot zero, and registered magic.
- Exact fixed-risk values and every frozen strategy input.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes and legacy mode are OFF; Friday close is OFF.
- Uniform label normalization, first-week-bar clock, 180-minute grace,
  consecutive anchors, session counts, OHLC aggregation, strict range state,
  durable attempt, spread, quote, ATR, sizing, and stop geometry fail closed.
- No futures chain, inventory, volume, open interest, event feed, API, CSV,
  optimizer artifact, trained output, oscillator, or manual signal is read.

## 7. Trade Management Rules

- Own at most one `XNGUSD.DWX` position under magic `411010000`.
- Persist the last attempted Monday anchor across restart.
- Manage malformed, later-week, stale, and kill-switch exits before entry.
- Freeze the original hard stop; never widen, trail, or remove it.
- Do not retry, add, pyramid, grid, martingale, partially close, hedge, or
  reverse inside the week.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | exact first-week-bar execution window |
| `strategy_history_bars` | 30 | bounded D1 weekly-OHLC buffer |
| `strategy_required_weeks` | 2 | exact consecutive completed packages |
| `strategy_min_week_bars` | 3 | minimum sessions in each completed week |
| `strategy_max_week_bars` | 5 | maximum sessions in each completed week |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale repair only |
| `strategy_max_spread_points` | 1500 | XNG entry cost guard |
| `qm_friday_close_enabled` | false | preserve full-week identity |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework value |

## Source-Defined Rules

Moskowitz, Ooi, and Pedersen supply own-price continuation lineage and natural-
gas membership. They do not supply the weekly horizon or range-migration
state.

## QM Interpretations

`MOP-XNG-WRANGE-MIGRATE-MOM-2026_S01` fixes the weekly horizon, completed
weekly OHLC packages, strict two-endpoint comparisons, equality/mixed-state
rejection, continuous-CFD Monday anchors and label normalization, entry grace,
persistent attempt, fixed-dollar ATR risk, spread cap, and lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
closure precede entry. No live execution override exists.

## Exit Precedence

1. Broker hard stop and framework kill switch.
2. Malformed or unsafe owned-position repair.
3. Later broker-week closure.
4. Ten-calendar-day stale repair.

## Runtime Data Dependencies

Exact `XNGUSD.DWX` native D1 OHLC/timestamps, broker time, symbol metadata,
quotes, completed-bar ATR, framework position/deal state, and persistent
terminal-global attempt state. No external dataset or calendar exists.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5 * ATR(20,D1)` from completed data.
- No target and no signal-strength sizing.
- Major risks are false weekly continuation, weekend gaps, continuous-CFD
  basis, XNG session-label ambiguity, financing, spread, density below the
  floor, weekly source translation, and realized overlap with `QM5_12567`.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than five completed
positions per full post-warm-up year, nonpositive governed economics, wrong
or mixed labels, nonconsecutive Monday anchors, invalid session counts or
OHLC, entry at equality or a mixed/inside/outside state, wrong side, current-
week leakage, late or repeated attempt, missing hard stop, wrong next-week
close, nondeterminism, or invalid fixed-risk mode.

Changing the XNG carrier, weekly packages, range comparisons, direction,
attempt clock, risk, stop, or lifecycle requires a new identity, binary,
complete stream reconciliation, and portfolio requalification. A failed
result may not be rescued by accepting equality or mixed states, adding a
close or current-week gate, reversing the side, changing the hold, or adding
calendar, return, close-location, volatility, volume, moving-average,
inventory, event, or external state.

## Strategy Allowability Check

- [x] R1: one bounded source ID with named peer-reviewed authors, DOI,
  complete-paper evidence, durable retrieval hash, and explicit natural-gas
  membership; weekly range-state translation risk is disclosed.
- [x] R2: exact clock, labels, anchors, sessions, OHLC aggregation, strict
  comparisons, side, attempt, hard stop, spread, and lifecycle are mechanical.
- [x] R3: registered `XNGUSD.DWX` D1 plus native V5 execution state supplies
  all runtime inputs; energy-label and continuous-CFD basis risk remain open.
- [x] R4: deterministic timestamp, OHLC, comparison, ATR, quote, position,
  deal-history, and terminal-state arithmetic only; no prohibited mechanism.
- [x] Dedup: no XNG identity collision; the WTI carrier sibling and adjacent
  XNG families are explicitly separated.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, label, week anchors, sessions, OHLC aggregation, strict range state, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-week, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| next-week and survivor repair | Trade Close | strategy lifecycle helper |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove native and uniformly shifted label equivalence; first-week-bar
and 180-minute clock; Monday anchors across year boundaries; two consecutive
weekly packages; three/four/five-session acceptance and two/six-session
rejection; exact high/low aggregation; long and short migrations; equality,
inside, outside, and both mixed states flat; no current-bar leakage; persistent
weekly attempts; fixed-risk frozen-stop sizing; next-week and stale repair;
card lint; strict compile; setfile schema; resolver identity; and static
artifact validation.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-22 | initial XNG completed-week range-migration card | Q00 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| Q00 Research Intake | 2026-08-22 | APPROVED | `decisions/2026-08-22_qm5_41101_xng_weekly_range_migration_momentum_g0.md` |
| Q01 Build Validation | - | PENDING | approved build has not yet entered |
| Q02 Baseline Screening | - | NOT_QUEUED | requires Q01 PASS and fresh capacity check |

## Safety Boundary

This card may authorize a branch-only non-live build, Q01 validation, one D1
`RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only below
tester and CPU ceilings. It does not authorize a manual backtest, terminal
control, live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`,
deploy or `T_Live` manifest, portfolio-gate change, portfolio admission,
decorrelation claim, or correlation waiver.
