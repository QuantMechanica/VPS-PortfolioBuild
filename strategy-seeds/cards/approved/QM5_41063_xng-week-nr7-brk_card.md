---
card_schema_version: 2
type: strategy
strategy_id: CRABEL-XNG-WEEKNR7-2026_S01
variant_id: CRABEL-XNG-WEEKNR7-2026_S01
source_id: CRABEL-XNG-WEEKNR7-2026
ea_id: QM5_41063
slug: xng-week-nr7-brk
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41063_xng-week-nr7-brk_card.md
execution_contract_status: APPROVED
created: 2026-08-20
created_by: Research+Development
last_updated: 2026-08-20
g0_status: APPROVED
g0_decision: decisions/2026-08-20_qm5_41063_xng_completed_week_nr7_g0.md
source_approval: decisions/2026-08-20_xng_completed_week_nr7_source_approval.md
source_author: "Toby Crabel"
source_authors: "Toby Crabel"
source_citation: "Crabel, Toby. Day Trading with Short-Term Price Patterns and Opening Range Breakout. Traders Press, 1990."
source_citations:
  - type: trading_book
    citation: "Crabel, Toby. Day Trading with Short-Term Price Patterns and Opening Range Breakout. Traders Press, 1990."
    location: "Governed complete-read lineage strategy-seeds/sources/CRABEL-WTI-NR7-BRK-2026/source.md and strategy-seeds/sources/CRABEL-WTI-WEEK-ORB-2026/source.md; bounded carrier packet strategy-seeds/sources/CRABEL-XNG-WEEKNR7-2026/source.md"
    quality_tier: A
    role: narrow_range_contraction_and_subsequent_range_expansion_lineage
strategy_mechanic: normalized-complete-xng-week-strict-nr7-full-range-next-week-completed-close-breakout-friday-flat
sources:
  - "[[sources/CRABEL-XNG-WEEKNR7-2026]]"
concepts:
  - "[[concepts/weekly-volatility-compression]]"
  - "[[concepts/weekly-range-expansion]]"
  - "[[concepts/natural-gas-structural-breakout]]"
indicators:
  - "[[indicators/complete-week-high-low-range]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, natural-gas, weekly-nr7, volatility-compression, range-expansion, breakout-continuation, atr-hard-stop, friday-flat, symmetric-long-short, low-frequency]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
host_symbol: XNGUSD.DWX
symbol_slot: 0
magic: 410630000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately five to ten completed XNG positions per full post-warm-up year after strict complete-week NR7 and next-week close-break gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_TIME_AGGREGATION_AND_CARRIER_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: NOT_ENQUEUED_CPU_CEILING
q01_build_report: D:/QM/reports/framework/21/build_check_20260820_073038.json
q01_p1_evidence: D:/QM/reports/pipeline/QM5_41063/P1/P1_QM5_41063_result.json
review_focus: "Falsify a complete-week XNG compression/next-week expansion stream whose logic differs from the certified QM5_12567 XNG pullback. Verify uniform energy-label normalization, exact Monday-Friday membership, strict seven-week range comparison, completed-close breakout chronology, durable weekly attempt, fixed-risk hard stop, and Friday-flat lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xng_carrier, uniform_energy_label_normalization, complete_week_membership, strict_nr7_range, completed_close_only, next_week_only, weekly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_enabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 uses a named-author/publisher systematic trading book with governed NR7 and complete-week records while disclosing the untested weekly XNG CFD translation; R2 locks normalization, exact week membership, strict seven-week comparison, next-week close breakout, side, attempt, risk, and lifecycle; R3 uses registered native XNG D1 with energy-label and CFD-basis risks explicit; R4 is deterministic timestamp, OHLC, range, ATR, quote, position, deal, and terminal-state arithmetic without a banned signal, trained output, external feed, grid, or martingale; canonical dedup found no exact identity and manual family review separated the rule from cumulative-RSI2, thresholded weekly return, daily ID/NR4, monthly ORB, WTI, and metals-ratio systems."
---

# QM5_41063 XNG Completed-Week NR7 Expansion

## Hypothesis

An unusually narrow complete natural-gas week can represent structural
volatility compression. If a completed D1 close in the immediately following
broker week escapes the compressed week's full high-low range, the expansion
may persist through Friday.

This is a second XNG return stream whose logic differs from the certified
`QM5_12567` short-horizon oscillator pullback. That difference does not prove
diversification. Q02 must establish density and economics, and unchanged Q09
alone may establish realized book correlation.

## Source Traceability And Claim Boundary

The approved packet is
`strategy-seeds/sources/CRABEL-XNG-WEEKNR7-2026/source.md`, authorized before
card extraction at
`decisions/2026-08-20_xng_completed_week_nr7_source_approval.md` and durably
committed as `467ec1cdd`.

Toby Crabel's named 1990 Traders Press book supplies narrow-range contraction
and later range-expansion lineage. Crabel does not test this exact normalized
seven-complete-week rule on natural gas or a Darwinex continuous CFD. The WTI
sibling is a carrier control, not evidence for XNG.

No source or sibling return, profit factor, Sharpe ratio, drawdown, trade
count, transaction cost, CFD equivalence, threshold, stop, hold, or portfolio-
correlation statistic transfers. Every implementation choice below is a
pre-result QM falsification choice.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,550 registry rows and 625 root
cards. It found no exact identity and raised one lexical weekly-range family
match. Manual review fixes these boundaries:

- `QM5_12567_cum-rsi2-commodity` is long-only cumulative-RSI2 pullback logic
  aligned to a slow trend and held at most five bars. This card is symmetric,
  uses no oscillator or trend filter, and forms on seven complete weeks.
- `QM5_13101_xng-1w-mom-vol` and `QM5_13102_xng-1w-rev-vol` threshold a five-
  D1 return under a volatility gate. This card ranks full weekly high-low
  ranges and then requires a later completed-close escape.
- `QM5_13105_xng-idnr4-brk` uses a D1 inside-day/narrow-four setup, not exact
  complete Monday-Friday weeks.
- `QM5_12812_xng-month-orb` forms a current-month opening range rather than a
  prior-week compression state.
- `QM5_41061_wti-week-nr7-brk` uses the same locked estimator on outright WTI.
  This card is the predeclared XNG carrier falsification and inherits no WTI
  result; the carrier is fixed and may not be selected after results.
- `QM5_41060_xauxag-week-nr7-brk` computes synchronized XAU/XAG close ratios
  and owns a two-leg metal basket, not one outright XNG position.

The exact XNG carrier, uniform session-label convention, complete-week full
range, strict seven-week comparison, next-week completed-close escape,
continuation side, one weekly attempt, and Friday-flat lifecycle are jointly
load-bearing. Verdict:
`CLEAN_XNG_COMPLETE_WEEK_NR7_CARRIER_EXTENSION_AFTER_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XNGUSD.DWX`.
- Exact period: D1; EA `41063`; slot `0`; magic `410630000`.
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
and `W-2 ... W-7` the six next-older valid complete weeks. The setup requires:

```text
week_range(W-1) > 0
week_range(W-1) < week_range(W-k) for every k in 2..7
```

With `c` equal to the latest completed D1 close in the current week:

```text
c > week_high(W-1) => BUY
c < week_low(W-1)  => SELL
otherwise          => FLAT
```

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XNGUSD.DWX` D1 bar under EA 41063 and
   magic slot zero.
2. Repair malformed, later-week, Friday-expired, or stale owned exposure before
   entry-only gates.
3. Select offset zero when the raw current D1 date equals the broker date or
   `+1` calendar day only when it is exactly one day behind. Apply that one
   convention to every bar and reject mixed or ambiguous labels.
4. Require the normalized current date to equal the broker date, weekday
   Tuesday through Friday, attachment within 180 minutes of raw D1 bar open,
   and the latest completed normalized bar to be the prior calendar day in the
   same broker week.
5. Require the immediately prior calendar week to contain exactly one completed
   bar per Monday-Friday weekday. Select six older valid complete weeks within
   a bounded 90-bar buffer; incomplete older holiday weeks may be skipped.
6. Require positive finite highs/lows, high not below low, and positive finite
   full ranges. The prior week's range must be strictly smaller than all six
   older ranges.
7. Compare only the latest completed current-week close with the prior week's
   extrema. BUY strictly above the high and SELL strictly below the low.
8. Persist the current broker-Monday week key after a strict break and before
   spread, quote, ATR, sizing, news, or order gates. Never retry that week.
9. Require no owned position, a valid executable quote, and no genuinely
   positive spread wider than 1,500 points. Modeled zero `.DWX` spread is valid.
10. Attach one frozen hard stop at `3.5 * ATR(20,D1)` from completed data and
    size one position to `RISK_FIXED=1000`. Use no take-profit.
11. Submit one slot-zero market order once. No pending order, retry, scale-in,
    grid, martingale, pyramid, hedge, or second entry exists.

## 5. Exit Rules

1. Broker hard stop and framework kill-switch closure remain authoritative.
2. Immediately flatten duplicate, wrong-symbol, wrong-magic, missing-stop,
   invalid-volume, or invalid-open-time exposure.
3. Close at broker Friday hour 21 or later; framework Friday close is enabled
   at the same hour as a redundant safety path.
4. Close on the first observed D1 bar belonging to a later normalized broker
   week than the position-open week.
5. Close after eight elapsed calendar days as a final stale guard.
6. No target, reversal exit, trail, break-even move, partial exit,
   discretionary close, or intentional weekend hold is authorized.

## 6. Filters (No-Trade Module)

- Exact host, D1, EA 41063, slot zero, and registered magic.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes and legacy mode are OFF for Q02; lifecycle repair is never
  delayed by an entry-only gate.
- Uniform label normalization, complete-week membership, finite ranges, strict
  NR7, completed-close break, durable attempt, spread, quote, ATR, sizing, and
  stop geometry all fail closed.
- No futures chain, inventory, volume, open interest, event feed, API, CSV,
  optimizer artifact, trained output, oscillator, or manual signal is read.

## 7. Trade Management Rules

- Own at most one `XNGUSD.DWX` position under magic `410630000`.
- Persist the last attempted broker-Monday key across restart.
- Manage malformed, Friday-expired, later-week, stale, and kill-switch exits
  before entry evaluation.
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
| `strategy_max_spread_points` | 1500 | XNG entry cost guard |
| `qm_friday_close_enabled` | true | Friday-flat identity |
| `qm_friday_close_hour_broker` | 21 | broker close boundary |

## Source-Defined Rules

Crabel supplies the narrow-range contraction and subsequent expansion lineage.
He does not supply the weekly XNG carrier, date normalization, exact sample,
close trigger, risk controls, or lifecycle.

## QM Interpretations

`CRABEL-XNG-WEEKNR7-2026_S01` fixes weekly aggregation, strict seven-week full-
range comparison, completed-close confirmation, exact XNG carrier, uniform
date normalization, one attempt, ATR stop, spread cap, and Friday-flat hold.

## Framework Execution Overrides

Both news axes are OFF. Friday close is ON at broker hour 21. Framework kill
switch and ownership closure precede entry. No live execution override exists.

## Exit Precedence

1. Broker hard stop and framework kill switch.
2. Malformed or unsafe owned-position repair.
3. Broker Friday 21 closure.
4. Later normalized broker-week repair.
5. Eight-calendar-day stale repair.

## Runtime Data Dependencies

Exact `XNGUSD.DWX` native D1 OHLC, broker time, symbol metadata, quotes,
completed-bar ATR, framework position/deal state, and persistent terminal
global-variable attempt state. No finite external dataset or calendar exists.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5 * ATR(20,D1)` from completed data.
- No target and no signal-strength sizing.
- Major risks are natural-gas gap/tail exposure, futures-versus-CFD basis,
  energy-session label ambiguity, holiday-week scarcity, Friday execution,
  financing, spread, density below the floor, and overlap with the XNG book.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than five completed
positions per full post-warm-up year, nonpositive governed economics, wrong or
mixed labels, incomplete immediate prior week, non-strict NR7, current-bar
leakage, wrong side, duplicate attempt, missing hard stop, weekend hold,
nondeterminism, or invalid fixed-risk mode.

Changing the XNG carrier, seven-week sample, range definition, trigger,
direction, attempt clock, risk, stop, or lifecycle requires a new identity,
binary, complete stream reconciliation, and portfolio requalification.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, label, weeks, strict NR7, close break, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, Friday, later-week, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| Friday and survivor repair | Trade Close | strategy lifecycle helper plus framework Friday close |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | `Strategy_NewsFilterHook` returns false; both axes OFF |

## Validation Plan

Q01 must prove native and uniformly shifted label equivalence; exact complete-
week membership; incomplete immediate-prior rejection; older-holiday skipping;
strict range and equality rejection; completed-current-week close chronology;
both continuation sides; no current-bar leakage; persistent weekly attempts;
fixed-risk frozen-stop sizing; lifecycle repair; card lint; strict compile;
setfile schema; resolver identity; and static artifact validation.

Q02 alone may measure frequency and baseline economics. Q09 alone may establish
realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-20 | initial XNG completed-week NR7 carrier card | G0 | APPROVED |
| v1-build | 2026-08-20 | deterministic XNG implementation, reference suite, strict compile/build checks, and static artifact validation | Q01 | PASS |
| v1-q02-capacity | 2026-08-20 | target-only dry run selected one row; apply withheld above the hard host-CPU ceiling | Q02 | NOT_ENQUEUED_CPU_CEILING |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-20 | APPROVED | `decisions/2026-08-20_qm5_41063_xng_completed_week_nr7_g0.md` |
| Q01 Build Validation | 2026-08-20 | PASS | `D:/QM/reports/framework/21/build_check_20260820_073038.json`; `D:/QM/reports/pipeline/QM5_41063/P1/P1_QM5_41063_result.json` |
| Q02 Baseline Screening | 2026-08-20 | NOT_ENQUEUED_CPU_CEILING | `docs/ops/evidence/2026-08-20_qm5_41063_xng_week_nr7_q01_q02_cpu_ceiling_stop.md` |

## Safety Boundary

This card authorizes a branch-only non-live build, Q01 validation, one D1
`RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only below
tester and CPU ceilings. It does not authorize a manual backtest, terminal
control, live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`,
deploy or T_Live manifest, portfolio-gate change, portfolio admission,
decorrelation claim, or correlation waiver.
