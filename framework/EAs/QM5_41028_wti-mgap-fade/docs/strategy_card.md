---
card_schema_version: 2
type: strategy
strategy_id: TGIF-YANG-WTI-MGAP-2026_S01
variant_id: TGIF-YANG-WTI-MGAP-2026_S01
source_id: TGIF-YANG-WTI-MGAP-2026
ea_id: QM5_41028
slug: wti-mgap-fade
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41028_wti-mgap-fade_card.md
execution_contract_status: APPROVED
created: 2026-08-16
created_by: Research+Development
last_updated: 2026-08-16
g0_status: APPROVED
g0_decision: decisions/2026-08-16_wti_month_boundary_gap_fade_g0.md
source_approval: decisions/2026-08-16_wti_month_boundary_gap_fade_source_approval.md
source_author: "Seth A. Hoelscher; Cedric Mbanga; Walt A. Nelson; Liu Yang; Bige Kahraman Goncu; Athanasios A. Pantelous"
source_authors: "Seth A. Hoelscher; Cedric Mbanga; Walt A. Nelson; Liu Yang; Bige Kahraman Goncu; Athanasios A. Pantelous"
source_citation: "Hoelscher, Mbanga, and Nelson (2017), Journal of Finance Issues 16(1), 47-68, DOI 10.58886/jfi.v16i1.2264; Yang, Goncu, and Pantelous, Momentum and Reversal in Commodity Futures, SSRN 3069253."
source_citations:
  - type: peer_reviewed_wti_weekend_paper
    citation: "Hoelscher, S. A., Mbanga, C., and Nelson, W. A. (2017). TGIF? The Weekend Effect in Energy Commodities. Journal of Finance Issues 16(1), 47-68."
    location: "DOI 10.58886/jfi.v16i1.2264; complete governed review at strategy-seeds/sources/TGIF-WTI-WEEKEND-2017/source.md."
    quality_tier: B
    role: wti_nontrading_boundary_and_close_to_open_timing_lineage
  - type: academic_commodity_reversal_working_paper
    citation: "Yang, L., Goncu, B. K., and Pantelous, A. A. Momentum and Reversal in Commodity Futures. SSRN 3069253."
    location: "Governed extraction at strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md."
    quality_tier: B
    role: fixed_horizon_commodity_reversal_direction
strategy_mechanic: first-genuine-broker-month-session-fade-current-open-versus-prior-completed-close-gap-next-d1-flat
sources:
  - "[[sources/TGIF-YANG-WTI-MGAP-2026]]"
concepts:
  - "[[concepts/month-boundary-gap-reversal]]"
  - "[[concepts/commodity-reversal]]"
  - "[[concepts/first-session-calendar]]"
indicators:
  - "[[indicators/boundary-gap-log-return]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, month-boundary, opening-gap, calendar-reversal, first-session, symmetric-long-short, atr-hard-stop, one-session-hold, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410280000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 10-12 completed one-session WTI positions per full post-warm-up year; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_AND_WORKING_PAPER_RISK
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED
review_focus: "Falsify a fixed-clock WTI month-boundary gap fade outside the certified XAU/SP500/NDX/XNG book. Verify exact first-session identity, prior-close/current-open endpoints, contrarian direction, restart-safe monthly attempt state, and next-D1 exit; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_first_genuine_month_session_no_shift, normalized_energy_label, fixed_current_open_prior_completed_close, no_current_tick_leakage, strict_contrarian_direction, persistent_month_attempt, no_late_restart_entry, next_d1_exit, risk_mode_dual, friday_close, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity/energy portfolio mission: R1 named peer-reviewed WTI weekend/calendar and academic commodity-reversal lineages with disclosed working-paper/composite risk; R2 exact normalized first-session clock, fixed current-open/prior-close gap, contrarian mapping, persistent attempt, stop, next-D1 close, and repair; R3 registered native XTIUSD.DWX D1 with measured session offset; R4 deterministic native arithmetic without trained or banned signal logic. Canonical exact/fuzzy dedup and manual family review are CLEAN."
---

# QM5_41028 WTI Month-Boundary Gap Fade

## Hypothesis

The discontinuity between WTI's final completed session close in one broker
month and the fixed open of the next month's first session may contain
temporary boundary positioning and non-trading-window pressure. Fading that
exact close-to-open gap for one D1 interval tests a compact calendar/reversal
interaction while avoiding a rolling price oscillator or long directional
hold.

This is a falsifiable direct-energy sleeve outside the certified
XAU/SP500/NDX/XNG book. It is not a source replication, profitability,
significance, decorrelation, certification, or portfolio-admission claim.

## Source Traceability And Claim Boundary

The governed packet is
`strategy-seeds/sources/TGIF-YANG-WTI-MGAP-2026/source.md`, approved before
extraction in
`decisions/2026-08-16_wti_month_boundary_gap_fade_source_approval.md` at
commit `50d77b36a`.

Hoelscher, Mbanga, and Nelson supply peer-reviewed WTI weekday/weekend return
structure and identify that a weekday-labelled close-to-close return can
contain a non-trading close-to-open component. Yang, Goncu, and Pantelous
supply fixed-horizon commodity-reversal lineage. Neither source tests a
first-of-month WTI gap fade, exact Darwinex broker months, a one-session hold,
continuous CFD construction, label normalization, fixed cash risk, or an ATR
stop. Those are disclosed QM choices. No source return, coefficient, trade
count, cost, drawdown, CFD equivalence, correlation, or portfolio statistic
transfers.

## Source-Defined Rules

- Hoelscher, Mbanga, and Nelson provide WTI calendar/non-trading-boundary
  evidence and distinguish the timing embedded in close-to-close returns.
- Yang, Goncu, and Pantelous supply academic commodity-reversal lineage at
  fixed return horizons.
- Neither source defines the exact first-month-session conjunction or the
  execution and risk controls below.

## QM Interpretations

The first-session selector, prior-close/current-open endpoints, contrarian
mapping, governed zero-or-`+1`-day energy-label normalization, 180-minute
attachment grace, no-shift/no-retry contract, one-D1 lifecycle,
continuous-CFD carrier, fixed risk, ATR stop, and spread cap are frozen QM
falsification choices rather than author claims.

## Non-Duplicate Decision

The canonical checker scanned 4,515 registry rows and 611 root cards and
returned `CLEAN` without an exact or fuzzy identity. Manual review returned
`CLEAN_WTI_FIRST_MONTH_SESSION_BOUNDARY_GAP_FADE_AFTER_FAMILY_REVIEW`:

- `QM5_12750_wti-weekend-gap-fade` and
  `QM5_12779_wti-weekend-gap-bounce` require a genuine Friday/Monday pair, a
  magnitude threshold, one-sided entry, and a prior-close target. This card
  uses the first genuine session of every broker month, either gap sign, no
  magnitude threshold, no target, and a next-D1 exit.
- `QM5_20217_wti-wkend-mom` follows a Monday open beyond the prior Friday
  range plus a lagged-volatility buffer. This card fades only the signed
  prior-close/current-open gap.
- `QM5_20230_wti-seas-gap` adds a fixed physical-season direction and follows
  a threshold break. This card has no season map, range, volatility threshold,
  or continuation side.
- `QM5_41027_wti-mopen-rev1` waits for the first current-month session to
  complete and fades its open-to-close return during the second session. This
  card trades the first session itself from the cross-month close/open gap.
- `QM5_41016_wti-mclose-mom` follows five prior-month intervals for five
  current-month sessions. This card reads one cross-boundary observation and
  owns one session.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback across
  commodity carriers, not fixed-clock direct-WTI boundary-gap logic.

## Markets, Timeframe, And Cadence

- Host and target: exact `XTIUSD.DWX`.
- Timeframe: D1; EA `QM5_41028`; magic slot 0; magic `410280000`.
- Decision: first genuine normalized broker D1 session of each month.
- Direction: opposite the exact prior-final-close/current-first-open gap sign.
- Normal exit: first later normalized D1 boundary.
- Expected cadence: approximately 10-12 completed positions/year.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Rules

The following rules are the complete authorized baseline. No shifted session,
magnitude threshold, weekday or season filter, continuation flip, event or
curve input, oscillator, target, or post-result rescue is authorized.

## 4. Entry Rules

1. Evaluate only on a new exact `XTIUSD.DWX` D1 bar with EA ID 41028 and
   magic slot 0.
2. Derive the governed energy label offset. Accept only a native same-day
   label or one uniform `+86400`-second normalization when the raw current D1
   label is 24-48 hours behind broker time. Apply the same offset to current
   and historical labels; all other states fail closed.
3. Require the normalized current label's date to equal the broker date.
   Require current shift 0 and completed shift 1 to belong to different,
   exactly consecutive broker months with strict timestamp order. This is the
   first genuine month session; never shift a holiday.
4. Require the first observed tick within 180 minutes of executable D1 open.
   Persist the broker-month attempt before history, signal, news, spread,
   quote, ATR, sizing, or order gates. Never retry or backfill the month.
5. Reject owned exposure or an owned entry deal already present for that
   broker month.
6. Read fixed `Open[0]` and completed `Close[1]`, require positive finite
   values, and compute `gap_return=log(Open[0]/Close[1])`. The current tick,
   bid, ask, high, low, and partial close enter neither endpoint.
7. Submit one BUY only when the gap is strictly negative and one SELL only
   when it is strictly positive. Exact zero or invalid arithmetic consumes
   the month flat. Gap magnitude never scales risk.
8. Require a non-negative spread no greater than 1,500 points, a positive
   finite executable quote, and completed `ATR(20,D1)`.
9. Attach one frozen broker hard stop `3.0 * ATR(20,D1)` from entry,
   normalized by V5 stop rules. There is no take-profit.
10. Open at most one position for magic `410280000`; no pending order,
    duplicate entry, scale-in, grid, martingale, or pyramid is authorized.

## 5. Exit Rules

1. Close on the first normalized D1 bar whose date differs from the
   normalized entry date.
2. Close after four elapsed calendar days as a stale-position guard.
3. Close malformed, duplicated, missing-stop, or invalid owned exposure before
   evaluating a new entry.
4. Framework Friday close at broker hour 21 remains enabled as a fail-safe.
5. Broker hard stops and the framework kill switch remain authoritative.
6. No target, opposite-signal exit, trailing stop, break-even move, partial
   close, scale-in, grid, martingale, or discretionary close is authorized.

## 6. Filters (No-Trade Module)

- Fail closed for wrong symbol, timeframe, EA ID, slot, seed, risk contract,
  news contract, Friday-close contract, or unlocked strategy input.
- Fail closed for invalid label normalization, broker-date mismatch, a date
  outside the exact first-session clock, late attachment, consumed month,
  owned exposure/deal, invalid gap endpoints, zero gap, invalid ATR, quote,
  stop, or spread.
- Lock news temporal OFF, compliance NONE, and legacy news mode OFF for Q02.
- Runtime may not read futures curves, contracts, inventory, volume, open
  interest, COT, event feeds, CSV, API, forecasts, external calendars, or
  trained output.

## 7. Trade Management Rules

- Lifecycle repair executes before all entry-only gates on every tick.
- One position maximum for magic `410280000` and one consumed attempt per
  broker month.
- Terminal-persistent attempt state plus owned deal history prevents restart
  re-entry; future-dated tester state is cleared on initialization.
- The original server-side hard stop is never moved.
- No hedge, averaging, scale-in, pyramid, grid, martingale, random path,
  adaptive fit, PnL-dependent state, or discretionary override exists.

## Parameters To Test

| parameter | baseline | authorized values | role |
|---|---:|---|---|
| `strategy_entry_session_ordinal` | 1 | [1] | exact first genuine broker-month session |
| `strategy_entry_grace_minutes` | 180 | [180] | measured WTI executable-session attachment |
| `strategy_atr_period` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.0 | [3.0] | frozen hard-stop distance |
| `strategy_max_hold_days` | 4 | [4] | holiday/weekend-safe repair guard |
| `strategy_max_spread_points` | 1500 | [1500] | entry spread ceiling |

Every value is locked. A failed baseline may not be rescued by adding a gap
threshold, changing the session clock or direction, adding a weekday/season
filter or target, or changing entry grace, stop, hold, or spread ceiling.

## Author Claims

Hoelscher, Mbanga, and Nelson provide WTI calendar/non-trading-boundary
evidence. Yang, Goncu, and Pantelous provide commodity-reversal lineage. The
exact first-month-session boundary-gap fade is a QM falsification hypothesis.

## Initial Risk Profile

- `expected_pf: 1.01` is a conservative queue-ordering prior, not evidence.
- `expected_dd_pct: 25.0` reflects WTI gaps, short squeezes, roll/basis,
  sparse monthly sampling, and interaction risk.
- Expected cadence is approximately 10-12 positions per full year.
- `risk_class: high`.
- `ml_required: false`.

## Risk

Backtests use one stop-normalized fixed budget: `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Gap magnitude never changes lots
or risk.

Q02 must retire on zero trades, fewer than five completed positions per full
year, wrong session identity, current-tick leakage, continuation-side trades,
late or repeated entries, missing stops, wrong exit timing, risk-mode
mismatch, nondeterminism, or nonpositive governed economics. Working-paper
risk, multiple testing, source-to-implementation distance, weekend/month-end
overlap, continuous-futures/CFD basis, broker-label mapping, spread, gaps,
financing, roll construction, and later book correlation are first-order
risks. No parameter rescue or correlation waiver is authorized.

## Strategy Allowability Check

- R1 `PASS_WITH_COMPOSITE_AND_WORKING_PAPER_RISK`: named academic WTI calendar
  and commodity-reversal lineages with complete governed packets and
  disclosed translation risks.
- R2 `PASS`: exact first-session identity, normalized labels, fixed
  prior-close/current-open endpoints, contrarian map, attempt state, entry
  clock, risk, stop, spread, next-D1 close, and repair are fixed.
- R3 `PASS`: registered native `XTIUSD.DWX` D1 history with directly measured
  session offset supplies every runtime input.
- R4 `PASS`: deterministic calendar/OHLC/logarithm/ATR-risk-plumbing only; no
  trained or banned signal logic, external runtime feed, grid, martingale,
  scale-in, or pyramid.
- Dedup `PASS`: no exact or fuzzy identity; weekend-gap, breakaway-gap,
  first-session-return, and month-segment neighbors are manually separated.

## Framework Alignment

- no_trade: exact host/D1/ID/slot/seed, locked fixed-risk/news/Friday/input
  contract, and cheap identity guards.
- trade_entry: normalized first-session clock, persistent monthly attempt,
  fixed current-open/prior-close gap, strict contrarian direction,
  spread/quote/ATR validation, and frozen hard stop.
- trade_management: malformed-state, first-later-D1, and stale repair before
  entry-only gates.
- trade_close: V5 position-close path, Friday fail-safe, server hard stop, and
  framework kill switch.

## Framework Execution Overrides

News temporal mode OFF, compliance NONE, and legacy news mode OFF. Friday
close is enabled at broker hour 21. Framework risk sizing, server-side hard
stop, and kill switch remain authoritative.

## Exit Precedence

1. Framework kill switch and server-side hard stop.
2. First later normalized D1 boundary or malformed exposure repair.
3. Four-calendar-day stale close.
4. Framework Friday close at broker hour 21.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` D1 OHLC, broker time/calendar, measured session-offset
contract, completed ATR, quotes, spread, symbol metadata, positions, deals,
and terminal global state only. No external runtime source is authorized.

## Falsification And Requalification

Any change to label normalization, first-session identity, gap endpoints,
return direction, entry grace, stop, hold, spread, retry state, symbol,
timeframe, news/Friday contract, or risk mode requires a new binary and full
pipeline requalification.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-16 | initial WTI month-boundary gap-fade extraction | G0 | APPROVED |
| v1-build | 2026-08-16 | deterministic V5 implementation and strict validation | Q01 | PASS |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-16 | APPROVED | `decisions/2026-08-16_wti_month_boundary_gap_fade_g0.md` |
| Q01 Build Validation | 2026-08-16 | PASS | strict compile `framework/build/compile/20260816_180551/QM5_41028_wti-mgap-fade.compile.log`; build check `D:/QM/reports/framework/21/build_check_20260816_180637.json`; static P1 `D:/QM/reports/pipeline/QM5_41028/P1/P1_QM5_41028_result.json`; eight reference tests PASS |
| Q02 Baseline Screening | - | NOT_ENQUEUED | Q01 must pass first |

## Safety Boundary

This card authorizes one branch-only research build, strict compile, one
`RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It does not
authorize a manual tester launch, live/demo/shadow/stress execution,
AutoTrading, `T_Live`, a deploy or T_Live manifest, portfolio admission,
portfolio-gate change, or a correlation waiver.
