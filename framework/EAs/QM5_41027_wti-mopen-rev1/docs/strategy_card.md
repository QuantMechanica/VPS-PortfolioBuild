---
card_schema_version: 2
type: strategy
strategy_id: MOP-YANG-WTI-MOPEN-REV1-2026_S01
variant_id: MOP-YANG-WTI-MOPEN-REV1-2026_S01
source_id: MOP-YANG-WTI-MOPEN-REV1-2026
ea_id: QM5_41027
slug: wti-mopen-rev1
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41027_wti-mopen-rev1_card.md
execution_contract_status: APPROVED
created: 2026-08-16
created_by: Research+Development
last_updated: 2026-08-16
g0_status: APPROVED
g0_decision: decisions/2026-08-16_wti_month_opening_reversal_g0.md
source_approval: decisions/2026-08-16_wti_month_opening_reversal_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Liu Yang; Bige Kahraman Goncu; Athanasios A. Pantelous"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Liu Yang; Bige Kahraman Goncu; Athanasios A. Pantelous"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), 228-250; Yang, Goncu, and Pantelous, Momentum and Reversal in Commodity Futures, SSRN 3069253."
source_citations:
  - type: peer_reviewed_time_series_momentum_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; governed month-opening extraction at strategy-seeds/sources/MOP-WTI-MOPEN-MOM-2026/source.md."
    quality_tier: A
    role: fixed_wti_month_opening_return_state
  - type: academic_commodity_reversal_working_paper
    citation: "Yang, L., Goncu, B. K., and Pantelous, A. A. Momentum and Reversal in Commodity Futures. SSRN 3069253."
    location: "Governed extraction at strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md."
    quality_tier: B
    role: fixed_horizon_commodity_reversal_direction
strategy_mechanic: second-current-month-wti-d1-fade-first-current-month-session-return-next-d1-flat
sources:
  - "[[sources/MOP-YANG-WTI-MOPEN-REV1-2026]]"
concepts:
  - "[[concepts/month-opening-flow-reversal]]"
  - "[[concepts/commodity-reversal]]"
  - "[[concepts/ordinal-session-calendar]]"
indicators:
  - "[[indicators/completed-session-log-return]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, month-opening, calendar-reversal, second-session, symmetric-long-short, atr-hard-stop, one-session-hold, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410270000
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
review_focus: "Falsify a fixed-clock WTI month-opening reversal outside the certified XAU/SP500/NDX/XNG book. Verify exact first/second session identity, completed first-session endpoints, contrarian direction, restart-safe monthly attempt state, and next-D1 exit; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_second_genuine_month_session_no_shift, normalized_energy_label, completed_first_session_open_close, no_current_bar_leakage, strict_contrarian_direction, persistent_month_attempt, no_late_restart_entry, next_d1_exit, risk_mode_dual, friday_close, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity/energy portfolio mission: R1 named academic momentum and reversal lineages with disclosed working-paper/composite risk; R2 exact normalized second-session clock, completed first-session open/close return, contrarian mapping, persistent attempt, stop, next-D1 close, and repair; R3 registered native XTIUSD.DWX D1 with measured session offset; R4 deterministic native arithmetic without trained or banned signal logic. Canonical exact/fuzzy dedup and manual family review are CLEAN."
---

# QM5_41027 WTI Month-Opening Session Reversal

## Hypothesis

The first completed WTI session of a broker month may contain temporary
month-boundary positioning pressure rather than persistent information.
Fading that exact session on the second genuine month session tests a compact
calendar/reversal interaction while limiting exposure to one D1 interval per
month.

This is a falsifiable direct-energy sleeve outside the certified
XAU/SP500/NDX/XNG book. It is not a source replication, profitability,
significance, decorrelation, certification, or portfolio-admission claim.

## Source Traceability And Claim Boundary

The governed packet is
`strategy-seeds/sources/MOP-YANG-WTI-MOPEN-REV1-2026/source.md`, approved
before extraction in
`decisions/2026-08-16_wti_month_opening_reversal_source_approval.md` at commit
`664785e3f`.

Moskowitz, Ooi, and Pedersen supply peer-reviewed own-return-sign lineage,
explicit WTI membership, and the parent fixed month-opening-segment
translation. Yang, Goncu, and Pantelous supply fixed-horizon commodity-
reversal lineage. Neither source tests this first-session/second-session
interaction, exact Darwinex broker months, a one-session hold, continuous CFD
construction, label normalization, fixed cash risk, or an ATR stop. Those are
disclosed QM choices. No source return, coefficient, trade count, cost,
drawdown, CFD equivalence, correlation, or portfolio statistic transfers.

## Source-Defined Rules

- Moskowitz, Ooi, and Pedersen define an instrument's own completed return
  sign as a mechanical state and explicitly include WTI in the commodity set.
- Yang, Goncu, and Pantelous supply academic commodity-reversal lineage at
  fixed price horizons.
- Neither source defines the exact month/session interaction or execution and
  risk controls below.

## QM Interpretations

The second-session selector, first-session open-to-close endpoints,
contrarian mapping, governed zero-or-`+1`-day energy-label normalization,
180-minute attachment grace, no-shift/no-retry contract, one-D1 lifecycle,
continuous-CFD carrier, fixed risk, ATR stop, and spread cap are frozen QM
falsification choices rather than author claims.

## Non-Duplicate Decision

The canonical checker scanned 4,514 registry rows and 610 root cards, found
no exact identity, and raised only `wti-mopen-mom` for manual review. Manual
review returned
`CLEAN_WTI_SECOND_SESSION_FIRST_SESSION_REVERSAL_AFTER_FAMILY_REVIEW`:

- `QM5_41013_wti-mopen-mom` waits for five current-month sessions, follows
  their aggregate sign from the sixth session, and holds through month end.
  This card fades only the first session from the second to the third session.
- `QM5_12810_wti-month-orb` measures the first five-session high/low range and
  trades a later buffered breakout with trend and range filters.
- `QM5_41023_wti-mends-mom` follows agreement between two prior-month
  segments from the first new-month bar for five bars.
- `QM5_41024_wti-1wed-mom1` follows the prior completed calendar month on a
  weekday clock; this card ignores prior-month direction and uses an ordinal
  session reversal clock.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback across
  commodity carriers, not fixed-clock direct-WTI calendar/reversal logic.

## Markets, Timeframe, And Cadence

- Host and target: exact `XTIUSD.DWX`.
- Timeframe: D1; EA `QM5_41027`; magic slot 0; magic `410270000`.
- Decision: second genuine normalized broker D1 session of each month.
- Direction: opposite the exact first-session open-to-close return sign.
- Normal exit: first later normalized D1 boundary.
- Expected cadence: approximately 10-12 completed positions/year.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Rules

The following rules are the complete authorized baseline. No shifted session,
multi-session formation, magnitude threshold, momentum flip, event filter,
curve input, oscillator, or post-result rescue is authorized.

## 4. Entry Rules

1. Evaluate only on a new exact `XTIUSD.DWX` D1 bar with EA ID 41027 and
   magic slot 0.
2. Derive the governed energy label offset. Accept only a native same-day
   label or one uniform `+86400`-second normalization when the raw current D1
   label is 24-48 hours behind broker time. Apply the same offset to current
   and historical labels; all other states fail closed.
3. Require the normalized current label's date to equal the broker date.
   Require current and shift-1 labels to share a month and shift 2 to belong
   to the immediately preceding calendar month, with strict timestamp order.
   This is exactly the second genuine month session; never shift a holiday.
4. Require the first observed tick within 180 minutes of executable D1 open.
   Persist the broker-month attempt before history, signal, news, spread,
   quote, ATR, sizing, or order gates. Never retry or backfill the month.
5. Reject owned exposure or an owned entry deal already present for that
   broker month.
6. Read the completed first-session `Open[1]` and `Close[1]`, require positive
   finite values, and compute `first_session_return=log(Close[1]/Open[1])`.
   Current-bar prices enter neither endpoint.
7. Submit one BUY only when the return is strictly negative and one SELL only
   when it is strictly positive. Exact zero or invalid arithmetic consumes the
   month flat. Signal magnitude never scales risk.
8. Require a non-negative spread no greater than 1,500 points, a positive
   finite executable quote, and completed `ATR(20,D1)`.
9. Attach one frozen broker hard stop `3.0 * ATR(20,D1)` from entry,
   normalized by V5 stop rules. There is no take-profit.
10. Open at most one position for magic `410270000`; no pending order,
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
  outside the exact second-session clock, late attachment, consumed month,
  owned exposure/deal, invalid first-session endpoints, zero return, invalid
  ATR, quote, stop, or spread.
- Lock news temporal OFF, compliance NONE, and legacy news mode OFF for Q02.
- Runtime may not read futures curves, contracts, inventory, volume, open
  interest, COT, event feeds, CSV, API, forecasts, external calendars, or
  trained output.

## 7. Trade Management Rules

- Lifecycle repair executes before all entry-only gates on every tick.
- One position maximum for magic `410270000` and one consumed attempt per
  broker month.
- Terminal-persistent attempt state plus owned deal history prevents restart
  re-entry; future-dated tester state is cleared on initialization.
- The original server-side hard stop is never moved.
- No hedge, averaging, scale-in, pyramid, grid, martingale, random path,
  adaptive fit, PnL-dependent state, or discretionary override exists.

## Parameters To Test

| parameter | baseline | authorized values | role |
|---|---:|---|---|
| `strategy_entry_session_ordinal` | 2 | [2] | exact second genuine broker-month session |
| `strategy_formation_sessions` | 1 | [1] | exact first completed month session |
| `strategy_entry_grace_minutes` | 180 | [180] | measured WTI executable-session attachment |
| `strategy_atr_period` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.0 | [3.0] | frozen hard-stop distance |
| `strategy_max_hold_days` | 4 | [4] | holiday/weekend-safe repair guard |
| `strategy_max_spread_points` | 1500 | [1500] | entry spread ceiling |

Every value is locked. A failed baseline may not be rescued by changing the
session clock, formation, direction, adding a threshold, changing entry grace,
stop, hold, or spread ceiling.

## Author Claims

Moskowitz, Ooi, and Pedersen provide time-series own-return-sign evidence in a
commodity universe that includes WTI. Yang, Goncu, and Pantelous provide
commodity-reversal lineage. The exact first-session/second-session interaction
is a QM falsification hypothesis.

## Initial Risk Profile

- `expected_pf: 1.01` is a conservative queue-ordering prior, not evidence.
- `expected_dd_pct: 25.0` reflects WTI gaps, short squeezes, roll/basis,
  sparse monthly sampling, and interaction risk.
- Expected cadence is approximately 10-12 positions per full year.
- `risk_class: high`.
- `ml_required: false`.

## Risk

Backtests use one stop-normalized fixed budget: `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Signal magnitude never changes
lots or risk.

Q02 must retire on zero trades, fewer than five completed positions per full
year, wrong session identity, current-bar leakage, momentum-side trades, late
or repeated entries, missing stops, wrong exit timing, risk-mode mismatch,
nondeterminism, or nonpositive governed economics. Working-paper risk,
multiple testing, source-to-implementation distance, futures/CFD basis,
broker-label mapping, spread, gaps, financing, roll construction, and later
book correlation are first-order risks. No parameter rescue or correlation
waiver is authorized.

## Strategy Allowability Check

- R1 `PASS_WITH_COMPOSITE_AND_WORKING_PAPER_RISK`: named academic momentum and
  reversal lineages with complete governed packets and disclosed translation
  risks.
- R2 `PASS`: exact ordinal-session identity, normalized labels, completed
  endpoints, contrarian map, attempt state, entry clock, risk, stop, spread,
  next-D1 close, and repair are fixed.
- R3 `PASS`: registered native `XTIUSD.DWX` D1 history with directly measured
  session offset supplies every runtime input.
- R4 `PASS`: deterministic calendar/OHLC/logarithm/ATR only; no trained or
  banned signal logic, external runtime feed, grid, martingale, scale-in, or
  pyramid.
- Dedup `PASS`: no exact identity; the expected month-opening-momentum fuzzy
  sibling and semantic neighbors are manually separated.

## Framework Alignment

- no_trade: exact host/D1/ID/slot/seed, locked fixed-risk/news/Friday/input
  contract, and cheap identity guards.
- trade_entry: normalized second-session clock, persistent monthly attempt,
  completed first-session return, strict contrarian direction,
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

Any change to label normalization, ordinal-session identity, first-session
endpoints, return direction, entry grace, stop, hold, spread, retry state,
symbol, timeframe, news/Friday contract, or risk mode requires a new binary
and full pipeline requalification.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-16 | initial WTI first-session/second-session reversal extraction | G0 | APPROVED |
| v1-build | 2026-08-16 | deterministic V5 implementation and strict validation | Q01 | PASS |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-16 | APPROVED | `decisions/2026-08-16_wti_month_opening_reversal_g0.md` |
| Q01 Build Validation | 2026-08-16 | PASS | strict compile and targeted build check `framework/build/compile/20260816_171720/QM5_41027_wti-mopen-rev1.compile.log`, `D:/QM/reports/framework/21/build_check_20260816_171720.json`; static P1 `D:/QM/reports/pipeline/QM5_41027/P1/P1_QM5_41027_result.json`; eight deterministic reference tests PASS |
| Q02 Baseline Screening | - | NOT ENQUEUED | - |

## Safety Boundary

This card authorizes one branch-only research build, strict compile, one
`RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It does not authorize
a manual tester launch, live/demo/shadow/stress execution, AutoTrading,
`T_Live`, a deploy or T_Live manifest, portfolio admission, portfolio-gate
change, or a correlation waiver.
