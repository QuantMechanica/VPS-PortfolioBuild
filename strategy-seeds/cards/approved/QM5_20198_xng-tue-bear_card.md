---
card_schema_version: 2
ea_id: QM5_20198
slug: xng-tue-bear
type: strategy
strategy_id: BOROWSKI-MOP-XNG-TUEBEAR-2026_S01
variant_id: BOROWSKI-MOP-XNG-TUEBEAR-2026_S01
source_id: BOROWSKI-MOP-XNG-TUEBEAR-2026
status: DRAFT
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20198_xng-tue-bear_card.md
execution_contract_status: DRAFT
created: 2026-08-01
created_by: Research+Development
last_updated: 2026-08-16
source_authors: "Krzysztof Borowski; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
strategy_mechanic: tuesday-xng-long-only-when-completed-252d-return-is-negative
source_citation: "Borowski (2016), Journal of Management and Financial Sciences 26; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104."
source_citations:
  - type: peer_reviewed_paper
    citation: "Borowski, K. (2016). Analysis of Selected Seasonality Effects in Markets of Future Contracts. Journal of Management and Financial Sciences 26, 27-44."
    location: "strategy-seeds/sources/BOROWSKI-COMM-DOW-2016/source.md"
    quality_tier: B
    role: tuesday_sample_direction
  - type: peer_reviewed_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: completed_trailing_return_state
sources:
  - "[[sources/BOROWSKI-MOP-XNG-TUEBEAR-2026]]"
concepts: [xng-day-of-week-seasonality, slow-return-regime, countertrend-seasonal-bounce]
indicators: [rolling-return, atr]
strategy_type_flags: [day-of-week-seasonality, slow-regime-gate, countertrend, long-only, weekly-entry, next-bar-exit, atr-hard-stop, low-frequency]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [commodities, energy, natural_gas]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "Approximately 12-30 completed Tuesday-session packages/year while the completed 252-D1 return is negative; Q02 must prove or retire density."
expected_trades_per_year_per_symbol: 20
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: NOT_STARTED
review_focus: "Falsify whether XNG's positive Tuesday sample direction survives costs specifically in a negative slow-return regime and diversifies the certified book."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency, friday_close, risk_mode_dual, cfd_futures_basis, restart_attempt_state, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity/energy sleeve mission: R1 PASS with two completely reviewed peer-reviewed source lineages and weak Tuesday-specific evidence disclosed; R2 PASS with locked genuine-Tuesday long, strictly negative completed 252-D1 state, ATR stop, next-D1 flatten, stale repair, and restart-safe attempt; R3 PASS registered XNGUSD.DWX D1; R4 PASS native deterministic data only. Dedup CLEAN across 4,254 registry rows and 381 cards."
---

# QM5_20198 XNG Tuesday Bear-Regime Bounce

## Hypothesis

Borowski reports a positive Tuesday sample mean for natural-gas futures, while
Moskowitz, Ooi, and Pedersen provide an instrument-own completed trailing-return
sign as a slow state. Buying the XNG Tuesday session only when the completed
252-D1 return is negative may isolate a recurring bear-regime bounce whose
weekly information clock differs from the certified index/metal book and from
the existing XNG oscillator sleeve.

This conjunction is a QM falsification hypothesis. Borowski does not report a
statistically distinguished Tuesday effect, and neither paper tests the
conjunction, Darwinex CFD carrier, execution rules, profitability, or
portfolio correlation.

## Source Traceability

The approved bounded packet is
`strategy-seeds/sources/BOROWSKI-MOP-XNG-TUEBEAR-2026/source.md`.
Its two parent packets record complete reviews of the peer-reviewed sources.
Runtime reads no external source; it uses native registered D1 prices, ATR,
quotes, broker calendar, positions, deal history, and persistent terminal
state only.

## Non-Duplicate Decision

`research_dedup_check.py` returned `CLEAN` for the slug, strategy ID, authors,
and exact mechanic after scanning 4,254 registry rows and 381 cards.

- `QM5_12818_xng-tue-prem` buys Tuesday unconditionally.
- `QM5_20158_xng-tue-trend` buys Tuesday only when the completed 252-D1 return
  is positive. This card owns the disjoint negative state.
- `QM5_12603_xng-tsmom12m` is a year-round monthly trend carrier.
- `QM5_12567_cum-rsi2-commodity` uses a two-day price oscillator pullback and
  has no weekday/slow-regime interaction.

The Tuesday boundary, long direction, and negative 252-D1 state are jointly
load-bearing. Removing or flipping one recreates a parent or another build.

## Markets, Timeframe, And Cadence

- Host and target: exact `XNGUSD.DWX`.
- Timeframe: D1; magic slot 0; magic `201980000`.
- Decision clock: first observed tick within five minutes of a Tuesday D1 bar
  immediately following a Monday D1 bar.
- Direction: BUY only while `ln(Close[1] / Close[253]) < 0`.
- Ordinary exit: first new non-Tuesday D1 bar.
- Expected cadence: approximately 12-30 completed packages/year; retire below
  five/year on average.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.

## Rules

### Entry

1. Require exact `XNGUSD.DWX`, D1, EA ID 20198, slot 0, and all baseline
   inputs locked to their card defaults.
2. Require the current D1 bar to be broker Tuesday and the immediately prior
   completed D1 bar to be Monday. Do not shift a holiday-missing Tuesday.
3. Require the first observed tick within five minutes of the Tuesday bar open.
4. Derive a Tuesday-anchored broker week key and persist it as consumed before
   history, state, spread, quote, news, stop, or order gates. Never retry that
   week after rejection, restart, stop, or a blocked gate.
5. Reject if an EA-owned position or entry deal already exists in that week.
6. Read completed D1 closes at shifts 1 and 253. Permit one BUY only when
   `ln(Close[1] / Close[253])` is strictly negative. Equality, missing history,
   or invalid arithmetic stays flat for the consumed week.
7. Require a valid spread no greater than 2,500 points, a valid BUY quote, and
   completed `ATR(20,D1)`.
8. Attach one frozen hard stop `3.0 * ATR(20)` below the entry. No take-profit,
   pending order, second entry, same-week retry, or scale-in is authorized.

### Exit

1. Close the package at the first new D1 bar whose broker weekday is not
   Tuesday.
2. Close an unexpected short position immediately.
3. Close after two elapsed calendar days as a stale-position repair.
4. Keep framework Friday close enabled at broker hour 21 as a fail-safe.
5. The broker hard stop and framework kill switch remain authoritative.
6. No signal-reversal, trailing, break-even, partial, or discretionary exit.

### No-Trade And State

- Fail closed for wrong host/timeframe/ID/slot, unlocked inputs, a non-genuine
  Tuesday, late attachment, invalid week key, incomplete history, non-negative
  state, invalid ATR/quote/stop, excessive spread, or an existing package.
- News temporal mode, compliance profile, and legacy mode are locked OFF for
  this native-price Q02 baseline. Lifecycle exits remain unconditional.
- One position and one consumed decision per broker week. Preserve the frozen
  stop. Recover attempts from terminal-persistent state plus position/deal
  history; clear a future-dated marker at initialization for historical reruns.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_momentum_lookback_d1` | 252 | [252] | completed own-return horizon |
| `strategy_min_abs_return_pct` | 0.0 | [0.0] | strict negative sign; no deadband |
| `strategy_session_offset_min` | 61.6 | [61.6] | UNVERIFIED XNGUSD.DWX estimate inferred from XTIUSD.DWX; independent XNG tick measurement remains required follow-up |
| `strategy_entry_grace_minutes` | 10 | [10] | tight window around the session-tick anchor |
| `strategy_min_stub_ticks` | 20 | [20] | reject thin weekend/holiday D1 stubs |
| `strategy_min_attach_ticks` | 20 | [20] | minimum ticks within 5 minutes of the qualifying tick |
| `strategy_atr_period` | 20 | [20] | completed D1 risk estimator |
| `strategy_atr_sl_mult` | 3.0 | [3.0] | frozen hard-stop distance |
| `strategy_max_hold_days` | 2 | [2] | stale repair |
| `strategy_max_spread_points` | 2500 | [2500] | entry spread ceiling |

There is no baseline parameter sweep.

## Framework Alignment

- no_trade: exact route and locked inputs, calendar/grace, history/state,
  spread/quote/stop, attempt, and owned-position guards.
- trade_entry: genuine Tuesday plus negative completed 252-D1 state, one BUY,
  and frozen ATR stop.
- trade_management: first non-Tuesday, wrong-side, and two-day stale closes
  before entry-only gates.
- trade_close: managed close, framework Friday fail-safe, broker stop, and
  kill switch.

## Risk

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. First-order kill risks are weak Tuesday-specific source
evidence, multiple-testing bias, post-2016 decay, XNG gaps, negative-regime
continuation overwhelming the bounce, continuous-CFD roll/basis, spread,
financing, warm-up density, and portfolio correlation.

Retire on zero trades, fewer than five completed packages/year on average,
wrong-day or wrong-state entries, same-week retries, holds beyond two days,
missing stops/exits, nondeterminism, or any governed performance or
diversification failure. Do not rescue failure by changing the weekday,
state horizon/sign, direction, entry clock, stop, hold, spread cap, or risk
mode after results.

## Safety Boundary

Approval covers the card, deterministic registries, one EA build, strict Q01
validation, one fixed-risk backtest setfile, and one paced Q02 enqueue. It does
not authorize a manual backtest, live setfile, AutoTrading, T_Live, deployment,
certification, portfolio admission, correlation waiver, portfolio-gate edit,
or live-manifest edit.

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-01 | APPROVED | `decisions/2026-08-01_qm5_20198_xng_tue_bear_g0.md` |
| Q01 Build Validation | 2026-08-01 | PASS: strict compile and V5 build check, 0 errors/warnings | `D:/QM/reports/framework/21/build_check_20260801_171928.json` |
| Q02 Baseline Screening | 2026-08-01 | NOT_STARTED | enqueue only after Q01 PASS and capacity check |

## OWNER-approved session-tick entry-clock amendment (2026-08-16)

This amendment supersedes every earlier raw-D1-label/five-minute entry-clock
description in this card. No formation, signal, direction, exit, sizing,
risk, consumed-attempt, or original advance/never-shift mechanic changes.

- Anchor the qualifying window at
  `D1_bar_open + strategy_session_offset_min`, not the raw D1 label.
- `strategy_session_offset_min = 61.6` minutes: **UNVERIFIED estimate for `XNGUSD.DWX`, inferred from the XTIUSD.DWX measurement**. Independent XNG tick measurement remains a recommended follow-up.
- `strategy_entry_grace_minutes = 10`, measured tightly around that anchor.
- `strategy_min_stub_ticks = 20`; a thin weekend/holiday D1 stub consumes
  the card's original attempt/date/window flat.
- `strategy_min_attach_ticks = 20` within five minutes after the qualifying
  tick; failure consumes the original attempt/date/window flat.
- Preserve this card's existing advance-versus-never-shift semantics exactly.
