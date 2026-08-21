---
card_schema_version: 2
type: strategy
strategy_id: BIANCHI-MOP-WTI-WCLOSE-TURN-MOM-2026_S01
variant_id: BIANCHI-MOP-WTI-WCLOSE-TURN-MOM-2026_S01
source_id: BIANCHI-MOP-WTI-WCLOSE-TURN-MOM-2026
ea_id: QM5_41099
slug: wti-wclose-turn-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41099_wti-wclose-turn-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-22
created_by: Research+Development
last_updated: 2026-08-22
g0_status: APPROVED
g0_decision: decisions/2026-08-22_qm5_41099_wti_weekly_close_turn_momentum_g0.md
source_approval: decisions/2026-08-22_wti_weekly_close_turn_momentum_source_approval.md
source_author: "Robert J. Bianchi; Michael E. Drew; John Hua Fan; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Robert J. Bianchi; Michael E. Drew; John Hua Fan; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Bianchi, R. J., Drew, M. E., and Fan, J. H. (2015), Combining Momentum with Reversal in Commodity Futures, Journal of Banking & Finance 59, 423-444, DOI 10.1016/j.jbankfin.2015.07.006; Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: academic_paper
    citation: "Bianchi, Robert J.; Drew, Michael E.; and Fan, John Hua (2015), Combining Momentum with Reversal in Commodity Futures, Journal of Banking & Finance 59, 423-444."
    location: "DOI 10.1016/j.jbankfin.2015.07.006; complete-read record strategy-seeds/sources/BIANCHI-MOMREV-2015/source.md"
    quality_tier: A
    role: commodity_reversal_and_wti_carrier_lineage
  - type: academic_paper
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read record strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded translation strategy-seeds/sources/BIANCHI-MOP-WTI-WCLOSE-TURN-MOM-2026/source.md"
    quality_tier: A
    role: own_return_continuation_and_wti_carrier_lineage
strategy_mechanic: normalized-week-boundary-wti-one-immediately-completed-three-to-five-session-week-every-chronological-close-strict-single-interior-turn-strict-monotone-legs-final-close-full-recovery-beyond-first-close-continuation-one-week-hold
sources:
  - "[[sources/BIANCHI-MOP-WTI-WCLOSE-TURN-MOM-2026]]"
concepts:
  - "[[concepts/commodity-reversal]]"
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/weekly-close-path-recovery]]"
  - "[[concepts/wti-structural-trend]]"
indicators:
  - "[[indicators/ordered-completed-session-closes]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti-crude, completed-week-close-path, single-turn-recovery, time-series-momentum, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410990000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 6-18 completed WTI positions per full post-warm-up year after the strict single-turn and full-recovery gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WEEKLY_CLOSE_PATH_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: G0
q01_status: PENDING
q02_status: NOT_QUEUED
review_focus: "Falsify a direct-WTI completed-week close-turn recovery sleeve outside the certified XAU/SP500/NDX/XNG book. Verify uniform energy labels, exact Monday anchors, one immediately completed 3-5-session week, every chronological close, exactly one strict interior turn, strict monotone legs, final close beyond the first close in the recovery direction, one attempt, fixed risk, and next-week exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_week_bar, immediate_completed_monday_anchor, bounded_week_session_count, every_chronological_session_close, strict_single_interior_turn, strict_monotone_legs, final_close_full_recovery_beyond_first_close, equality_and_multi_turn_flat, no_current_week_leakage, weekly_attempt_state, risk_mode_dual, hard_stop_present, next_week_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER-authorized WTI sleeve; R1 complete-read peer-reviewed reversal and continuation sources with weekly close-path translation disclosed; R2 exact close chronology, turn, recovery, attempt, fixed risk and lifecycle; R3 native WTI D1; R4 deterministic comparisons without banned or trained logic"
---

# QM5_41099 WTI Completed-Week Close-Turn Recovery Momentum

## Hypothesis

A completed WTI broker week can contain an internal reversal without ending
as a failed move. When every session close falls strictly into one interior
trough and then rises strictly to finish above the first close, the completed
recovery direction may persist into the next broker week. The exact mirror
applies after one interior peak and a final close below the first close.

The direct WTI carrier is economically different from the certified
XAU/SP500/NDX/XNG book. This is a diversification hypothesis only. It does not
establish profitability or decorrelation; Q02 owns frequency and baseline
economics, and unchanged Q09 alone may establish realized correlation.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/BIANCHI-MOP-WTI-WCLOSE-TURN-MOM-2026/source.md`,
authorized before extraction by
`decisions/2026-08-22_wti_weekly_close_turn_momentum_source_approval.md` at
commit `854ef19f5`. The bounded packet SHA-256 is
`FEFDBA09C09D51066F3CEEE47CDCF443EF8908AC0995A110E96BAE447EB55027`.

Bianchi, Drew, and Fan document commodity momentum and longer-horizon reversal
components. Moskowitz, Ooi, and Pedersen document own-return continuation and
include NYMEX WTI in their futures universe. Neither paper tests a within-week
single-turn close path, strict monotone segments, full endpoint recovery, a
Darwinex continuous CFD, fixed-dollar ATR risk, or the QM book. All weekly
path, execution, and risk choices below are declared QM interpretations.

No source return, WTI-only alpha, profit factor, drawdown, trade count,
transaction cost, CFD equivalence, or correlation statistic is imported.

## Non-Duplicate Decision

Before allocation, the canonical checker scanned 4,588 registry identities
and 1,267 repository cards and found no exact or fuzzy match. Its optional
Strategy-Wiki root was unavailable, so the honest verdict remained
`INPUT_ERROR_FAIL_CLOSED`. After deterministic allocation, the checker found
only the expected exact registry self-hit for `QM5_41099`. Manual family
review fixes the mechanical boundaries:

- `QM5_41098_wti-wextreme-sequence-mom` orders the sessions carrying the
  aggregate weekly high and low and confirms with weekly open-to-close sign.
  This card ignores open/high/low and requires every chronological session
  close to form one strict interior turn plus full recovery.
- `QM5_41084_wti-wdaybreadth-mom` counts positive and negative adjacent D1
  returns in an exact five-session week and requires four-of-five breadth plus
  a parent-close-to-final-close sign. This card has no sign count or parent
  close; a multi-turn path remains flat even if one sign dominates.
- `QM5_41092_wti-wbody-dominance-mom` compares an aggregate open/close body
  with the high-low range. This card computes neither a weekly body nor a
  range threshold.
- `QM5_41095_wti-wexcursion-imbalance-mom` and
  `QM5_41096_wti-wexcursion-reject-rv` compare open-centred high/low
  excursions at a strict ratio. This card is invariant to opens and intraday
  extremes.
- `QM5_41065`, `QM5_41068` through `QM5_41072`, `QM5_41074`, and
  `QM5_41082` classify paths across multiple completed weekly returns. This
  card uses the within-week close sequence of one completed week.
- `QM5_41029`, `QM5_41032`, and `QM5_41033` decompose overnight and
  intraday flows. This card reads no open and performs no gap/body
  decomposition.
- `QM5_9361_mql5-ichi-kumo-bounce` uses a three-bar cloud touch plus ADX/DI on
  M30, not a WTI weekly native-close path.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback below a slow mean. This card is symmetric direct WTI,
  weekly, and oscillator-free.

The exact carrier, immediately completed Monday-anchored package, three-to-
five sessions, every chronological close, one strict interior turning point,
strict monotone legs, final recovery beyond the first close, boundary entry,
durable attempt, fixed risk, and one-week hold are jointly load-bearing.
Verdict:
`NO_EXACT_WTI_WEEKLY_CLOSE_TURN_RECOVERY_MOMENTUM_DUPLICATE_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Host and target: exact `XTIUSD.DWX`.
- Timeframe: exact D1; magic slot 0; planned magic `410990000`.
- Decision: first tradable normalized D1 bar of a new Monday-anchored broker
  week, within 180 elapsed raw-session minutes.
- Formation: every session close from the exact immediately completed broker
  week; current-week data is excluded.
- Normal exit: first tick whose normalized Monday anchor is later than the
  position-open anchor.
- Expected cadence: approximately 6-18 completed positions/year; Q02 must
  prove at least five in every full post-warm-up year.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Energy-Label Normalization

Infer one label convention from the current D1 bar. Accept native same-day
labels or a uniform `+1` calendar-day energy convention when the raw bar label
is one date behind broker time. Apply that same choice to the current bar and
every historical bar used in aggregation. Never shift broker time, mix label
conventions, or infer a separate offset per bar.

The normalized current bar must belong to a Monday-anchored week whose anchor
is exactly seven calendar days after the completed package anchor. Holiday-
shortened completed weeks remain valid only with three to five unique,
strictly ordered sessions. Two or six sessions, duplicate dates, mixed
labels, invalid closes, nonadjacent anchors, or unclassifiable history remain
flat.

## Formula

For the exact immediately completed chronological session closes
`c[0] ... c[n-1]`, where `3 <= n <= 5`:

```text
one k in [1,n-2]
c[0] > c[1] > ... > c[k] < c[k+1] < ... < c[n-1]
and c[n-1] > c[0]                                      => BUY

one k in [1,n-2]
c[0] < c[1] < ... < c[k] > c[k+1] > ... > c[n-1]
and c[n-1] < c[0]                                      => SELL

otherwise                                               => FLAT
```

The strict monotone legs guarantee one unique interior turn. Adjacent-close
equality, no interior turn, more than one turn, incomplete recovery, final/
first equality, malformed history, or invalid arithmetic is flat. Turn index,
depth, and recovery magnitude never change eligibility or size.

## Rules

The entry, exit, filter, and management contracts below are the complete
authorized baseline. Anything not stated is out of scope.

## 4. Entry Rules

1. Repair malformed owned exposure before entry-only filters.
2. Require exact `XTIUSD.DWX`, D1, EA ID `41099`, slot zero, fixed-risk mode,
   news modes, Friday-close state, and every locked strategy input.
3. Observe a new D1 bar and derive the normalized Monday anchor for the
   current decision week under one uniform energy-label convention.
4. Admit only within `strategy_entry_grace_minutes=180` elapsed minutes of
   the raw current D1 bar open. Late attachment consumes the week flat.
5. Persist the normalized Monday-anchor attempt before history, signal, news,
   spread, quote, ATR, sizing, or order gates. Never retry that week.
6. Require no owned position and no same-magic entry deal already recorded in
   the current normalized week.
7. Load the exact immediately completed weekly package. Require three to five
   unique, strictly ordered sessions, exact seven-day anchor adjacency, and
   positive finite closes. Exclude all current-week bars.
8. Find the adjacent-close comparison signs in chronological order. Require
   exactly one sign change at an interior session: decreasing then increasing
   for a trough, or increasing then decreasing for a peak. Equality is flat.
9. BUY only when the strict trough path's final close is above its first
   close. SELL only when the strict peak path's final close is below its first
   close. No-turn, multi-turn, incomplete-recovery, or equality states remain
   flat.
10. Require a valid quote, spread no greater than 1,500 points, and a valid
    completed-bar `ATR(20,D1)`.
11. Freeze one hard stop at `3.5 * ATR` from entry and use no take-profit.
12. Open at most one fixed-risk slot-zero market position. Path depth,
    recovery size, and turn position never change risk or volume.

Current-week OHLC never enters the signal. The current quote is execution-only
after the completed-week decision.

### Attempt And Restart Contract

The attempt key is terminal-global, scoped by EA, symbol, and timeframe, and
stores the normalized current Monday anchor. It is written before every
fallible gate. Initialization after the 180-minute grace consumes the missed
week without a late trade. Owned deal history and position checks provide
additional fail-closed guards. A rejected order, stop-out, spread failure,
restart, invalid ATR, or invalid history cannot create a same-week retry.

## 5. Exit Rules

1. Broker hard stop and the framework kill switch remain authoritative.
2. Duplicate, wrong-side, wrong-symbol, wrong-magic, missing-stop, invalid-
   volume, or otherwise malformed owned exposure is flattened immediately.
3. Close on the first tick whose normalized Monday anchor is later than the
   anchor stored for the position's entry week.
4. Close after ten elapsed calendar days as a stale repair only.

There is no target, opposite-signal exit, trail, break-even move, partial
close, Friday flattening, scale-in, pyramid, grid, martingale, hedge, or
discretionary close.

## 6. Filters (No-Trade Module)

- Require exact host, D1, EA ID, slot, registered magic, fixed-risk values,
  news axes OFF/NONE, and Friday close disabled.
- Framework kill-switch, broker, and ownership controls remain authoritative.
- Apply the entry grace, durable attempt, uniform label, weekly adjacency,
  three-to-five-session chronology, strict single-turn/full-recovery state,
  spread, quote, ATR, sizing, and stop geometry fail-closed.
- No open/high/low signal, parent week, sign-count threshold, excursion ratio,
  body share, wick, close-location threshold, return channel, range rank,
  moving average, oscillator, volume, open interest, inventory, event
  calendar, futures curve, external file, API, or manual runtime input exists.

## 7. Trade Management Rules

- Own at most one `XTIUSD.DWX` position under magic `410990000`.
- Flatten duplicate, wrong-side, missing-stop, or otherwise malformed owned
  exposure before considering a new entry.
- Leave the frozen server-side stop unchanged; never widen, trail, partial-
  close, reverse, scale, or pyramid.
- Close a survivor at the first later normalized weekly boundary; use the
  ten-calendar-day guard only when that boundary repair was missed.
- Management remains reachable on every tick before any entry-only gate.

## Parameters To Test

No optimization surface is approved. The sole Q02 baseline uses:

| Parameter | Locked value | Role |
|---|---:|---|
| `strategy_label_offset_seconds` | 86400 | uniform raw-to-energy-session label normalization |
| `strategy_entry_grace_minutes` | 180 | exact first-week-bar execution window |
| `strategy_history_bars` | 16 | bounded D1 close buffer |
| `strategy_required_weeks` | 1 | exact immediately completed weekly package |
| `strategy_min_week_bars` | 3 | minimum completed-week sessions |
| `strategy_max_week_bars` | 5 | maximum completed-week sessions |
| `strategy_require_single_turn` | true | no-turn, equality, or multi-turn flat |
| `strategy_require_full_recovery` | true | final close strictly beyond first close |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | full-week identity |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework value |

Every value is locked in one backtest setfile and is not an optimization
surface.

## Source-Defined Rules

Bianchi, Drew, and Fan supply commodity momentum/reversal lineage. Moskowitz,
Ooi, and Pedersen supply own-return continuation and WTI membership. Neither
source supplies the weekly horizon, close-path shape, or recovery condition.

## QM Interpretations

`BIANCHI-MOP-WTI-WCLOSE-TURN-MOM-2026_S01` fixes the weekly horizon, one
completed session package, every chronological close, strict single interior
turn, full endpoint recovery, continuous-CFD Monday anchors and label
normalization, entry grace, persistent attempt, fixed-dollar ATR risk, spread
cap, and lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch, ownership
repair, and lifecycle management precede entry. No live override exists.

## Exit Precedence

1. Broker hard stop and framework kill switch.
2. Malformed or unsafe owned-position repair.
3. Later normalized broker-week closure.
4. Ten-calendar-day stale repair.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` native D1 closes and timestamps, broker time, symbol
metadata, quotes, completed-bar ATR, framework position/deal state, and a
persistent terminal global-variable attempt marker. No finite external
dataset or event calendar exists.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5 * ATR(20,D1)` from completed data.
- No target and no path-magnitude sizing.
- Major risks are false continuation after recovery, weekend gaps,
  continuous-CFD roll/basis, energy-session label ambiguity, financing,
  spread, density below the floor, weekly source translation, and realized
  book correlation.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Strategy Allowability Check

| Gate | Verdict | Evidence |
|---|---|---|
| R1 | PASS_WITH_WEEKLY_CLOSE_PATH_TRANSLATION_RISK | Two named-author, peer-reviewed DOI papers with complete-read evidence and explicit WTI membership; weekly close-path translation risk disclosed. |
| R2 | PASS | Exact label, anchor, session chronology, strict turn/recovery rules, side, attempt, fixed risk, stop, spread, and lifecycle. |
| R3 | PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK | Registered native `XTIUSD.DWX` D1 history and MT5 state provide every runtime field; energy-label and CFD-basis risks remain Q02 falsification items. |
| R4 | PASS | Deterministic timestamps, completed closes, comparisons, ATR risk, quotes, and execution state only; no trained or adaptive signal, external feed, grid, martingale, scale-in, or pyramid. |

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than five completed
positions in any full post-warm-up year, nonpositive governed economics,
wrong or mixed labels, a nonadjacent anchor, invalid session count or close,
adjacent equality, absent or multiple turns, incomplete recovery, wrong side,
current-week leakage, late or repeated attempt, missing hard stop, wrong next-
week close, nondeterminism, or invalid fixed-risk mode.

Changing the WTI carrier, weekly aggregation, close sequence, strict-turn
contract, full-recovery condition, attempt clock, risk, stop, or lifecycle
requires a new identity and full Q00/Q01 cycle. A failed result may not be
rescued by accepting equality, endpoint or multiple turns, incomplete
recovery, reversing the side, changing the hold, or adding a depth, return,
range, body, wick, close-location, calendar, volatility, volume, moving-
average, inventory, event, or external-data filter.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, label, week anchor, sessions, close path, strict turn, recovery, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-week, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| next-week and survivor repair | Trade Close | strategy lifecycle helper |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove native and uniformly shifted label equivalence; first-week-bar
and 180-minute clock; Monday anchors across year boundaries; exact completed-
week aggregation; three/four/five-session acceptance and two/six-session
rejection; strict trough/full-recovery long; strict peak/full-recovery short;
adjacent equality, monotone no-turn, endpoint turn, multi-turn, and incomplete
recovery flat; malformed and current-week history rejection; persistent
weekly attempts; fixed-risk frozen-stop sizing; next-week and stale repair;
card lint; strict compile; setfile schema; resolver identity; and static
artifact validation.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-22 | initial WTI completed-week close-turn recovery card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-22 | APPROVED | `decisions/2026-08-22_qm5_41099_wti_weekly_close_turn_momentum_g0.md` |
| Q01 Build Validation | - | NOT_STARTED | - |
| Q02 Baseline Screening | - | NOT_QUEUED | - |

## Safety Boundary

This card requests a branch-only non-live build, Q01 validation, one D1
`RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only below
tester and CPU ceilings. It does not authorize a manual backtest, terminal
control, live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`,
deploy or T_Live manifest, portfolio-gate change, portfolio admission,
decorrelation claim, or correlation waiver.
