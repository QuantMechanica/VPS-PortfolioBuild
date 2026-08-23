---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-MEXTREME-SEQUENCE-MOM-2026_S01
variant_id: MOP-WTI-MEXTREME-SEQUENCE-MOM-2026_S01
source_id: MOP-WTI-MEXTREME-SEQUENCE-MOM-2026
ea_id: QM5_41122
slug: wti-mextreme-sequence-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41122_wti-mextreme-sequence-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-23
created_by: Research+Development
last_updated: 2026-08-23
g0_status: APPROVED
g0_decision: decisions/2026-08-23_qm5_41122_wti_monthly_extreme_sequence_momentum_g0.md
source_approval: decisions/2026-08-23_wti_monthly_extreme_sequence_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: academic_paper
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded translation strategy-seeds/sources/MOP-WTI-MEXTREME-SEQUENCE-MOM-2026/source.md"
    quality_tier: A
    role: own_price_continuation_monthly_clock_and_wti_carrier_lineage
strategy_mechanic: broker-month-boundary-wti-one-immediately-completed-seventeen-to-twenty-three-session-month-unique-low-before-high-plus-positive-body-buy-unique-high-before-low-plus-negative-body-sell-one-month-hold
sources:
  - "[[sources/MOP-WTI-MEXTREME-SEQUENCE-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/completed-month-extreme-sequence]]"
  - "[[concepts/wti-structural-trend]]"
indicators:
  - "[[indicators/completed-month-extreme-sequence]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti-crude, structural-trend, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 411220000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 6-10 completed WTI positions per full post-warm-up year after unique-extreme, body-agreement, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_EXTREME_SEQUENCE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING_BUILD
q02_status: NOT_ENQUEUED_Q01_PENDING
review_focus: "Falsify a direct-WTI completed-month extreme-sequence momentum sleeve outside the certified XAU/SP500/NDX/XNG book. Verify exact calendar-month membership, 17-23 D1 sessions, unique monthly high and low sessions, chronological low-before-high or high-before-low order, matching first-open-to-last-close sign, ambiguous/disagreement flat, one attempt, fixed risk, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, first_tradable_month_bar, immediate_completed_calendar_month, bounded_month_session_count, unique_monthly_high_session, unique_monthly_low_session, chronological_extreme_order, month_body_sign_agreement, ambiguity_and_disagreement_flat, no_current_month_leakage, monthly_attempt_state, risk_mode_dual, hard_stop_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-23; R1 PASS peer-reviewed JFE WTI monthly-momentum lineage with extreme-sequence translation disclosed; R2 PASS exact calendar-month OHLC chronology, unique extrema, body agreement, attempt, fixed risk and lifecycle; R3 PASS registered native XTIUSD.DWX D1; R4 PASS deterministi"
---

# QM5_41122 WTI Completed-Month Extreme-Sequence Momentum

## Hypothesis

A completed WTI broker-calendar month in which the unique monthly low occurs
before the unique monthly high describes a different price-discovery path from
one in which the unique high occurs first. When the month's last close versus
its first open agrees with that path, the directional auction may continue
through the next broker month.

The direct WTI carrier is economically different from the certified
XAU/SP500/NDX/XNG book. This is a diversification hypothesis only: it does not
establish profitability, neutrality, or decorrelation. Q02 owns frequency and
baseline economics; unchanged Q09 alone may establish realized portfolio
correlation.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/MOP-WTI-MEXTREME-SEQUENCE-MOM-2026/source.md`,
authorized before extraction by
`decisions/2026-08-23_wti_monthly_extreme_sequence_momentum_source_approval.md`
at commit `d066ac822`. The complete parent source hash is
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

Moskowitz, Ooi, and Pedersen document own-return continuation on monthly
horizons, directly test a one-month formation/one-month holding commodity
specification, and include WTI in their futures universe. They do not test
monthly extreme chronology, unique extreme occurrences, first-open/last-close
agreement, a Darwinex continuous CFD, fixed-dollar ATR risk, or the QM book.
Every path, execution, and risk choice below is a declared QM interpretation.

No source return, WTI-only alpha, profit factor, drawdown, trade count,
transaction cost, CFD equivalence, or correlation statistic is imported.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker used the actual Company
Reference Wiki root, scanned 4,621 registry identities, 1,290 cards, and 45
Strategy Wiki nodes, and returned `CLEAN`. After deterministic allocation it
found only the expected slug and strategy-ID self-hits for `QM5_41122`.
Evidence is in the pre- and post-allocation receipts under `artifacts/`.

Manual family review fixes the mechanical boundaries:

- `QM5_41098_wti-wextreme-sequence-mom` uses a normalized Monday-anchored
  three-to-five-session week and one-week hold. This card uses the exact
  immediately completed 17-to-23-session calendar month and next-month exit.
- `QM5_41105_wti-mclose-location-mom` uses fixed range quartiles. This card
  has no close-location threshold and uses unique extreme-session chronology.
- `QM5_41106_wti-mbody-dominance-mom` compares absolute body with full range.
  This card has no body-magnitude threshold; body sign is only a direction
  agreement check after the unique-extreme path qualifies.
- `QM5_41107_wti-minside-body-mom` and
  `QM5_41108_wti-mrange-expansion-mom` compare the completed month with a
  parent month. This card is invariant to every parent-month price.
- `QM5_41111`, `QM5_41114`, `QM5_41115`, and `QM5_41117` classify daily
  signs or fixed block-return sums. This card counts neither and ignores
  intermediate opens/closes except for OHLC validity.
- pure one-month WTI time-series momentum uses only month-end return sign.
  This card additionally requires the unique high/low auction path to agree.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback below a slow mean, not a symmetric WTI monthly auction.

The exact WTI carrier, immediately completed calendar month, 17-to-23
sessions, unique aggregate high and low sessions, chronological order,
matching body sign, ambiguity/disagreement-flat behavior, boundary entry,
durable attempt, fixed risk, and one-month hold are jointly load-bearing.
Verdict:
`CLEAN_WTI_COMPLETED_MONTH_EXTREME_SEQUENCE_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Market, Clock, And State

- Host and traded symbol: exact `XTIUSD.DWX` only.
- Timeframe: exact D1 only.
- EA ID, slot, and planned magic: `41122`, `0`, and `411220000`.
- Decision: first executable tick of a new broker-calendar month, within 180
  elapsed minutes of the raw current D1 bar open.
- Signal data: the exact immediately completed calendar-month package only;
  current-month OHLC is excluded.
- Position count: at most one owned position and at most one consumed attempt
  per broker `yyyymm`.
- Expected frequency: 8 positions/year as an ordering prior within a design
  range of approximately 6-10; Q02 must prove at least five in every scored
  full post-warm-up year.

## Completed-Month Contract

The immediately preceding D1 bar must belong to the prior calendar month.
Within a fixed 45-bar buffer, the package must contain exactly every completed
D1 session labeled with that prior year and month. Require 17 through 23
unique timestamps in strict order and one adjacent older bar from an earlier
month proving that the requested package was not truncated. A current-month
bar, duplicate timestamp, wrong month, missing boundary proof, invalid OHLC,
or session count outside 17-23 consumes the current month flat.

For the chronological completed-month session sequence `i=0..n-1`:

```text
O = open[0]
H = max(high[i])
L = min(low[i])
C = close[n-1]

iH = unique session index whose high equals H
iL = unique session index whose low equals L

iL < iH and C > O  => BUY
iH < iL and C < O  => SELL
otherwise          => FLAT
```

If the high or low occurs on multiple sessions, or both unique extremes occur
on the same session, the state is ambiguous and flat. Close/open equality and
extreme-order/body disagreement are flat. Current-month OHLC never enters the
formula. Price distance, range size, close location, and the session distance
between extremes never change eligibility or risk.

## Rules

The entry, exit, filter, and management contracts below are the complete
authorized baseline. Anything not stated here is out of scope.

## 4. Entry Rules

1. Repair malformed owned exposure before entry-only filters.
2. Require exact symbol, D1, EA ID, slot, risk mode, news modes, and Friday-
   close inputs.
3. Observe a new D1 bar and derive current broker `yyyymm` directly from its
   raw bar time.
4. Admit only within `strategy_entry_grace_minutes = 180` elapsed minutes of
   the raw current D1 bar open. Late attachment consumes the month flat.
5. Persist the current `yyyymm` attempt before history, aggregation, signal,
   news, spread, quote, ATR, sizing, or order gates. Never retry that month
   after a downstream failure.
6. Aggregate the exact immediately completed broker-calendar month. Require
   17 through 23 unique valid D1 sessions, exact month membership, and an
   adjacent older bar proving a complete package.
7. Define `O` from the chronological first session, `C` from the final
   session, `H` as maximum high, and `L` as minimum low. Require positive
   finite OHLC, valid geometry, and `H>L` with `O` and `C` inside the range.
8. Require exactly one session carrying `H` and exactly one carrying `L`.
   Repeated extremes or both extremes on the same session remain flat.
9. BUY only when the unique low session precedes the unique high session and
   `C>O`. SELL only when the unique high session precedes the unique low
   session and `C<O`. Equality, disagreement, or invalid state remains flat.
10. Require entry spread no greater than 1,500 points and a valid completed-
    bar `ATR(20,D1)`.
11. Freeze one hard stop `3.5*ATR` from entry and use no take-profit.
12. Open at most one fixed-risk position. Extreme distance, monthly return,
    and range magnitude never change the risk budget or volume.

Current-month open, high, low, and close never enter the signal. Current
quotes are execution-only after the completed-month decision.

### Attempt And Restart Contract

The attempt key is terminal-global, scoped by EA, symbol, and timeframe, and
stores current broker `yyyymm`. It is written before every fallible gate.
Initialization after the 180-minute grace consumes the missed month without
creating a late trade. Owned deal history and open-position checks are
additional fail-closed guards. A rejected order, stop-out, news block, spread
failure, restart, invalid ATR, or invalid history cannot create a same-month
retry.

## 5. Exit Rules

1. The broker hard stop and framework kill switch remain authoritative.
2. Duplicate, wrong-side, wrong-magic, missing-stop, or otherwise malformed
   owned exposure is flattened.
3. Close the position on the first tick whose broker `yyyymm` is later than
   the month stored for the position's entry attempt.
4. Forty elapsed calendar days is a stale repair only.

There is no take-profit, opposite-signal exit, trailing stop, break-even move,
partial close, Friday flattening, scale-in, pyramid, grid, martingale, hedge,
or discretionary close.

## 6. Filters (No-Trade Module)

- Require exact `XTIUSD.DWX`, D1, EA ID `41122`, and slot 0.
- Require `RISK_FIXED>0`, `RISK_PERCENT=0`, valid stop inputs, news temporal
  OFF, news compliance NONE, and Friday close disabled.
- Framework kill-switch, broker, and ownership controls remain authoritative.
- Apply entry grace, durable attempt, exact calendar-month contract, history
  and OHLC validity, unique-extreme/order/body conjunction, spread ceiling,
  valid quote, and completed ATR gate fail-closed.
- No parent-month comparison, excursion-size gate, body-share gate, wick
  threshold, close-location rule, return channel, range rank, moving average,
  oscillator, volume, open interest, inventory, event calendar, futures
  curve, external file, API, or manual runtime input is used.

## 7. Trade Management Rules

- Own at most one position on the registered magic and symbol.
- Flatten duplicate, wrong-side, missing-stop, or otherwise malformed owned
  exposure before considering a new entry.
- Leave the frozen server-side stop unchanged; do not trail, widen, partial-
  close, reverse, scale, or pyramid.
- Close a survivor at the first later broker-month boundary; use the forty-
  calendar-day guard only when that boundary repair was missed.
- Management remains reachable on every tick before any entry-only gate.

## Parameters To Test

No optimization surface is approved. The sole baseline uses:

| Parameter | Locked value | Role |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | exact first-month-bar execution window |
| `strategy_history_bars` | 45 | bounded D1 OHLC buffer with older-month proof |
| `strategy_min_month_bars` | 17 | minimum completed-month sessions |
| `strategy_max_month_bars` | 23 | maximum completed-month sessions |
| `strategy_require_unique_extremes` | true | repeated extremes fail closed |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | full-month identity |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework value |

Every value is locked in the one baseline setfile and is not an optimization
surface.

## Source-Defined Rules

Moskowitz, Ooi, and Pedersen supply own-return sign continuation, a monthly
formation/holding clock, and WTI membership. They do not supply the extreme
sequence, uniqueness rule, or body-agreement condition.

## QM Interpretations

`MOP-WTI-MEXTREME-SEQUENCE-MOM-2026_S01` fixes the calendar-month session
package, unique aggregate extreme sessions, chronological order, body-sign
agreement, continuous-CFD labels, entry grace, persistent attempt,
fixed-dollar ATR risk, spread cap, and lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
closure precede entry. No live execution override exists.

## Exit Precedence

1. Broker hard stop and framework kill switch.
2. Malformed or unsafe owned-position repair.
3. Later broker-month closure.
4. Forty-calendar-day stale repair.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` native D1 OHLC and timestamps, broker time, symbol
metadata, quotes, completed-bar ATR, framework position/deal state, and
persistent terminal global-variable attempt state. No finite external dataset
or event calendar exists.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5*ATR(20,D1)` from completed data.
- No target and no signal-strength sizing.
- Major risks are false monthly continuation, noisy or repeated extremes,
  weekend/month gaps, continuous-CFD roll/basis, financing, spread, density
  below the floor, extreme-sequence translation, and realized book
  correlation.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Strategy Allowability Check

| Gate | Verdict | Evidence |
|---|---|---|
| R1 | PASS | Named authors, peer-reviewed JFE paper, DOI, complete-paper evidence, retrieval hash, explicit WTI membership, and a monthly source clock; extreme-sequence translation risk disclosed. |
| R2 | PASS | Exact month clock, sessions, unique extremes, chronology, body agreement, attempt, risk, stop, spread, and lifecycle. |
| R3 | PASS | Registered native `XTIUSD.DWX` D1 history and MT5 state supply every runtime field; calendar-label and CFD-basis risks remain Q02 falsification items. |
| R4 | PASS | Deterministic timestamp, OHLC, and index arithmetic only; no trained or adaptive signal, external feed, grid, martingale, scale-in, or pyramid. |

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than five completed
positions in any full post-warm-up year, nonpositive governed economics,
wrong month membership, invalid session count or OHLC, accepting repeated or
same-session extremes, entry without order/body agreement, wrong side,
current-month leakage, late or repeated attempt, missing hard stop, wrong
next-month close, nondeterminism, or invalid fixed-risk mode.

Changing the WTI carrier, calendar-month aggregation, unique-extreme contract,
extreme-order rule, body agreement, attempt clock, risk, stop, or lifecycle
requires a new identity and full G0/Q01 cycle. A failed result may not be
rescued by accepting ambiguous extremes, dropping body agreement, reversing
the side, changing the hold, or adding an excursion, body-share, wick,
close-location, range-rank, return-channel, calendar, volatility, volume,
moving-average, inventory, event, oscillator, or external-data filter.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, month clock, sessions, unique extremes, chronology, body agreement, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-month, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| next-month and survivor repair | Trade Close | strategy lifecycle helper |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove first-month-bar and 180-minute clock; calendar months across
year boundaries; exact immediately completed package; chronological first
open and final close; 17/20/23-session acceptance and 16/24-session rejection;
unique low-before-high long and high-before-low short; repeated high, repeated
low, same-session extremes, close/open equality, and both order/body
disagreements flat; malformed, truncated, and current-month history rejection;
persistent monthly attempts; fixed-risk frozen-stop sizing; next-month and
stale repair; card lint; strict compile; setfile schema; resolver identity; and
static artifact validation.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-23 | initial WTI completed-month extreme-sequence momentum card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-23 | APPROVED | `decisions/2026-08-23_qm5_41122_wti_monthly_extreme_sequence_momentum_g0.md` |
| Q01 Build Validation | 2026-08-23 | PENDING_BUILD | source implementation and strict compile required |
| Q02 Baseline Screening | 2026-08-23 | NOT_ENQUEUED_Q01_PENDING | strict compile, EX5, final set binding, and Q01 PASS required |

## Safety Boundary

This card requests a branch-only non-live build, Q01 validation, one D1
`RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only below
tester and CPU ceilings. It does not authorize a manual backtest, terminal
control, live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`,
deploy or T_Live manifest, portfolio-gate change, portfolio admission,
decorrelation claim, or correlation waiver.
