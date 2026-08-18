---
card_schema_version: 2
type: strategy
strategy_id: CRABEL-WTI-WEEKNR7-2026_S01
variant_id: CRABEL-WTI-WEEKNR7-2026_S01
source_id: CRABEL-WTI-WEEKNR7-2026
ea_id: QM5_41061
slug: wti-week-nr7-brk
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41061_wti-week-nr7-brk_card.md
execution_contract_status: APPROVED
created: 2026-08-18
created_by: Research+Development
last_updated: 2026-08-18
g0_status: APPROVED
g0_decision: decisions/2026-08-18_qm5_41061_wti_completed_week_nr7_g0.md
source_approval: decisions/2026-08-18_wti_completed_week_nr7_source_approval.md
source_author: "Toby Crabel"
source_authors: "Toby Crabel"
source_citation: "Crabel, Toby. Day Trading with Short-Term Price Patterns and Opening Range Breakout. Traders Press, 1990."
source_citations:
  - type: trading_book
    citation: "Crabel, Toby. Day Trading with Short-Term Price Patterns and Opening Range Breakout. Traders Press, 1990."
    location: "Governed complete-read lineage strategy-seeds/sources/CRABEL-WTI-NR7-BRK-2026/source.md and strategy-seeds/sources/CRABEL-WTI-WEEK-ORB-2026/source.md; bounded joined packet strategy-seeds/sources/CRABEL-WTI-WEEKNR7-2026/source.md"
    quality_tier: A
    role: narrow_range_contraction_and_subsequent_range_expansion_lineage
strategy_mechanic: normalized-complete-wti-week-strict-nr7-full-range-next-week-completed-close-breakout-friday-flat
sources:
  - "[[sources/CRABEL-WTI-WEEKNR7-2026]]"
concepts:
  - "[[concepts/weekly-volatility-compression]]"
  - "[[concepts/weekly-range-expansion]]"
  - "[[concepts/crude-oil-trend-breakout]]"
indicators:
  - "[[indicators/complete-week-high-low-range]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, weekly-nr7, volatility-compression, range-expansion, breakout-continuation, atr-hard-stop, friday-flat, symmetric-long-short, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410610000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately five to ten completed XTI positions per full post-warm-up year after strict complete-week NR7 and next-week close-break gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_TIME_AGGREGATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: READY_TO_ENQUEUE
review_focus: "Falsify a direct-WTI complete-week compression/next-week expansion stream outside the certified XAU/SP500/NDX/XNG book. Verify uniform energy-label normalization, exact Monday-Friday membership, strict seven-week range comparison, completed-close breakout chronology, durable weekly attempt, fixed-risk hard stop, and Friday-flat lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, uniform_energy_label_normalization, complete_week_membership, strict_nr7_range, completed_close_only, next_week_only, weekly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_enabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 uses a named-author/publisher systematic trading book with governed NR7 and complete-week records while disclosing the untested weekly CFD translation; R2 locks normalization, exact week membership, strict seven-week comparison, next-week close breakout, side, attempt, risk, and lifecycle; R3 uses registered native XTI D1 with energy-label and CFD-basis risks explicit; R4 is deterministic timestamp, OHLC, range, ATR, quote, position, deal, and terminal-state arithmetic without a banned signal, trained output, external feed, grid, or martingale; canonical dedup found no exact identity and manual family review separated the rule from daily NR7, weekly ORB, inside-week, metals-ratio NR7, and commodity RSI systems."
---

# QM5_41061 WTI Completed-Week NR7 Expansion

## Hypothesis

An unusually narrow complete WTI week can represent structural volatility
compression. If a completed D1 close in the immediately following broker week
escapes that compressed week's full high-low range, the expansion may persist
long enough to support a short continuation position through Friday.

The candidate is direct crude-oil exposure intended to introduce a physical-
energy return driver outside the certified XAU/SP500/NDX/XNG book. Carrier
difference does not prove diversification. Q02 must establish density and
economics, and unchanged Q09 alone may establish realized book correlation.

## Source Traceability And Claim Boundary

The approved joined source packet is
`strategy-seeds/sources/CRABEL-WTI-WEEKNR7-2026/source.md`, authorized before
card extraction at
`decisions/2026-08-18_wti_completed_week_nr7_source_approval.md`.

Toby Crabel's named 1990 Traders Press book supplies narrow-range contraction
and later range-expansion lineage. The governed parent records preserve the
daily NR7 and complete-week translations. Crabel does not test this exact
normalized seven-complete-week WTI rule, a Darwinex continuous CFD, the
completed-close trigger, fixed cash risk, ATR stop, spread cap, attempt state,
or Friday-flat lifecycle.

No source return, profit factor, Sharpe ratio, drawdown, trade count,
transaction cost, CFD equivalence, threshold, stop, hold, or portfolio-
correlation statistic transfers. Every implementation choice below is a
pre-result QM falsification choice.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,548 registry rows and 625 root
cards. It found no exact identity and surfaced only the expected fuzzy family
match to `QM5_12965_wti-week-orb`. Manual semantic review fixes the boundaries:

- `QM5_13096_xti-nr7-brk` defines one D1 bar as the NR7 setup and requires the
  immediately next D1 bar plus SMA, slope, candle, and close-location filters.
  This card compares seven complete weeks and contains none of those filters.
- `QM5_12965_wti-week-orb` defines the current week's opening box from its
  first completed D1 bar. This card's range comes only from the immediately
  prior complete week after a strict seven-week comparison.
- `QM5_13075_xti-inweek-brk` requires a parent/inside-week relation. This card
  imposes no containment condition and compares full ranges across seven
  complete weeks.
- `QM5_41060_xauxag-week-nr7-brk` computes synchronized XAU/XAG close ratios
  and owns a two-leg equal-notional metal package. This card computes outright
  WTI high-low ranges and owns one energy position.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback,
  including an XNG carrier, and has no weekly compression state.

The exact WTI carrier, uniform session-label convention, immediately prior
complete Monday-Friday setup, full high-low range, strict seven-week
comparison, next-week completed-close escape, continuation side, one weekly
attempt, and Friday-flat lifecycle are jointly load-bearing. Verdict:
`CLEAN_WTI_COMPLETE_WEEK_NR7_NEXT_WEEK_EXPANSION_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Exact period: D1; EA `41061`; slot `0`; magic `410610000`.
- Formation: seven valid complete normalized broker weeks.
- Decision: first executable new D1 tick from broker Tuesday through Friday.
- Signal observation: latest completed normalized current-week D1 close.
- Ordinary exit: broker Friday at hour 21.
- Expected cadence: five to ten completed positions/year; retire below five.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Formula

For one normalized broker Monday key `W`, a complete week contains exactly one
bar for each weekday Monday through Friday. Define:

```text
week_high(W)  = max(D1 high for normalized weekdays Monday..Friday)
week_low(W)   = min(D1 low  for normalized weekdays Monday..Friday)
week_range(W) = week_high(W) - week_low(W)
```

Let `W-1` be the calendar week immediately before the current decision week
and let `W-2 ... W-7` be the next six older valid complete weeks, with older
incomplete holiday weeks skipped. The setup is valid only when:

```text
week_range(W-1) > 0
week_range(W-1) < week_range(W-k) for every k in 2..7
```

Equality is not NR7. With `c` equal to the latest completed D1 close in the
current week:

```text
c > week_high(W-1) => BUY
c < week_low(W-1)  => SELL
otherwise          => FLAT
```

Current-bar OHLC, intrabar extrema, weekly close-only proxy ranges, and trend
or season filters do not enter.

## Rules

The entry, exit, filter, management, and risk rules below are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XTIUSD.DWX` D1 bar while attached to EA
   ID 41061 and magic slot zero.
2. Repair malformed, later-week, Friday-expired, or stale owned exposure before
   entry-only gates.
3. Compare the raw current D1 bar date with the broker date. Select offset zero
   when they match or `+1` calendar day only when the raw label is exactly one
   day behind. Apply the selected offset uniformly to every current and
   historical bar. Reject every other, mixed, or ambiguous convention.
4. Require the normalized current D1 date to equal the broker date, broker
   weekday Tuesday through Friday, attachment within 180 minutes of the raw
   D1 bar open, and the latest completed normalized bar to be exactly the prior
   calendar day in the same broker week.
5. Derive the current normalized broker-Monday week key. Require the immediately
   prior calendar week to contain exactly one completed bar for each Monday
   through Friday. Select six additional older valid complete weeks within a
   bounded 90-bar buffer, skipping incomplete older weeks without changing
   chronological order.
6. For every selected week require positive finite highs/lows, one bar per
   weekday, high not below low, and a positive finite full range. The prior
   week's range must be strictly smaller than all six older ranges.
7. Compare only the latest completed current-week close with the prior week's
   full extrema. Equality and non-breaks remain flat. BUY strictly above the
   high and SELL strictly below the low.
8. Once a strict break exists, persist the current broker-Monday week key
   before spread, quote, ATR, sizing, news, or order gates. A rejection,
   failure, stop, close, or restart may not retry that week.
9. Require no owned position, a valid executable quote, and no genuinely
   positive spread wider than 1,500 points. A modeled zero `.DWX` spread is
   valid.
10. Require valid completed-bar `ATR(20,D1)` and attach one frozen hard stop at
    `3.5 * ATR`. Size the position to the single `RISK_FIXED=1000` budget. Use
    no take-profit.
11. Submit one slot-zero market order once. No pending order, retry, scale-in,
    grid, martingale, pyramid, hedge, or second entry exists.

## 5. Exit Rules

1. Broker hard stop and framework kill-switch closure remain authoritative.
2. Immediately flatten duplicate, wrong-symbol, wrong-magic, missing-stop,
   invalid-volume, or invalid-open-time exposure.
3. Close at broker Friday hour 21 or later. Framework Friday close remains
   enabled at the same hour and is an intentionally redundant safety path.
4. Close on the first observed D1 bar belonging to a later normalized broker
   week than the position open week.
5. Close after eight elapsed calendar days as a final stale guard.
6. No target, signal-reversal exit, trailing stop, break-even move, partial
   exit, discretionary close, or intentional weekend hold is authorized.

## 6. Filters (No-Trade Module)

- Exact host, D1, EA 41061, slot zero, and registered magic.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes and legacy mode are OFF for Q02; lifecycle repair is never
  delayed by an entry-only gate.
- Uniform label normalization, current-week chronology, exact complete-week
  membership, bounded seven-week sample, finite full ranges, strict comparison,
  completed-close break, durable attempt, spread, quote, ATR, sizing, and stop
  geometry all fail closed.
- No futures chain, inventory, volume, open interest, event feed, API, CSV,
  optimizer artifact, trained output, ratio, oscillator, or manual signal is
  read at runtime.

## 7. Trade Management Rules

- Own at most one `XTIUSD.DWX` position under magic `410610000`.
- Persist the last attempted broker-Monday key so restart cannot create a
  second attempt in the same week.
- Manage malformed, Friday-expired, later-week, stale, and kill-switch exits on
  every tick before entry evaluation.
- Freeze the original hard stop; never widen, trail, or remove it.
- Do not retry, add, pyramid, grid, martingale, partially close, hedge, or
  reverse.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_week_lookback` | 7 | exact complete-week range sample |
| `strategy_history_bars` | 90 | bounded D1 retrieval buffer |
| `strategy_entry_min_dow` | 2 | broker Tuesday |
| `strategy_entry_max_dow` | 5 | broker Friday |
| `strategy_entry_grace_minutes` | 180 | new-D1 execution window |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 8 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | true | Friday-flat identity |
| `qm_friday_close_hour_broker` | 21 | broker close boundary |

No lookback, week definition, range definition, breakout side, entry window,
stop, spread, hold, or lifecycle sweep is authorized.

## Author Claims

The source supplies only structural narrow-range/expansion lineage. This card
does not claim source replication, profitability, density, continuous-CFD
equivalence, portfolio admission, or realized decorrelation.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5 * ATR(20,D1)` from completed data.
- No target and no signal-strength sizing.
- Major risks are WTI gap/tail exposure, futures-versus-CFD construction,
  energy-session label ambiguity, holiday-week scarcity, Friday execution,
  spread, financing, density below the economic floor, and portfolio overlap.
- This card creates no live, demo, shadow, stress, or optimization preset.

## Acceptance And Retirement

Q02 retires rather than tunes on zero trades, fewer than five completed
positions per full post-warm-up year, nonpositive governed economics, wrong or
mixed energy labels, incomplete immediate prior week, wrong weekday membership,
non-strict NR7, close-only setup range, current-bar leakage, wrong breakout
side, duplicate attempt, missing hard stop, weekend hold, nondeterminism, or
invalid fixed-risk mode.

No weak result may be rescued by changing seven weeks, accepting an incomplete
prior week, using a daily setup, adding a trend/seasonality filter, changing
the range or close trigger, widening the stop, extending the hold, or retrying.
Any such change creates a new identity and requires a new source/card decision.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, label, chronology, weeks, strict NR7, close break, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, Friday, later-week, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| Friday and survivor repair | Trade Close | strategy lifecycle helper plus framework Friday close |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | `Strategy_NewsFilterHook` returns false; both modes OFF |

## Validation Plan

Q01 must prove:

1. native and uniformly shifted energy labels produce the same complete-week
   identity and reject mixed/ambiguous labels;
2. exact Monday-Friday membership, incomplete immediate-prior rejection,
   older-holiday skipping, strict range comparison, and equality rejection;
3. latest completed current-week close only, correct continuation side, and no
   current-bar leakage;
4. persisted week attempts prevent retry after downstream failure and restart;
5. fixed-risk sizing uses a valid frozen completed-bar ATR stop;
6. malformed, Friday, later-week, and eight-day repair remain reachable; and
7. strict compile, card lint, build checks, setfile schema, magic resolver, and
   static Q01 validation pass.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-18 | initial WTI completed-week NR7 card | G0 | APPROVED |
| v1-build | 2026-08-18 | deterministic WTI implementation, independent reference suite, strict compile, build checks, and static artifact validation | Q01 | PASS |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-18 | APPROVED | `decisions/2026-08-18_qm5_41061_wti_completed_week_nr7_g0.md` |
| Q01 Build Validation | 2026-08-18 | PASS | `D:/QM/reports/framework/21/build_check_20260818_062557.json`; `D:/QM/reports/pipeline/QM5_41061/P1/P1_QM5_41061_result.json` |
| Q02 Baseline Screening | - | READY_TO_ENQUEUE | target-only paced handoff after fresh capacity checks |

## Safety Boundary

This card authorizes a non-live build, Q01 validation, one D1 `RISK_FIXED`
backtest setfile, and one paced target-only Q02 enqueue only below tester and
CPU ceilings. It does not authorize a manual backtest, terminal control,
live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`, deploy or
T_Live manifest, portfolio-gate change, portfolio admission, decorrelation
claim, or correlation waiver.
