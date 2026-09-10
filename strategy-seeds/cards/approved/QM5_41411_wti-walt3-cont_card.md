---
card_schema_version: 2
type: strategy
strategy_id: KWON-WTI-WALT3-CONT-20260910_S01
variant_id: KWON-WTI-WALT3-CONT-20260910_S01
source_id: KWON-WTI-WALT3-CONT-20260910
ea_id: QM5_41411
slug: wti-walt3-cont
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41411_wti-walt3-cont_card.md
execution_contract_status: APPROVED
created: 2026-09-10
created_by: Research+Development
last_updated: 2026-09-10
g0_status: APPROVED
g0_decision: decisions/2026-09-10_qm5_41411_wti_weekly_alternation_continuation_g0.md
source_approval: decisions/2026-09-10_wti_weekly_alternation_continuation_source_approval.md
source_author: "Kyung Yoon Kwon; Jangkoo Kang; Jaesun Yun; OpenAI Codex"
source_authors: "Kyung Yoon Kwon; Jangkoo Kang; Jaesun Yun; OpenAI Codex"
source_citation: "Kwon, K. Y., Kang, J., and Yun, J. (2020), Weekly Momentum in the Commodity Futures Market, Finance Research Letters 35, 101306, DOI 10.1016/j.frl.2019.101306."
source_citations:
  - type: peer_reviewed_paper_with_bounded_translation
    citation: "Kwon, Kang, and Yun (2020), Weekly Momentum in the Commodity Futures Market, Finance Research Letters 35, 101306."
    location: "DOI 10.1016/j.frl.2019.101306; complete-read packet strategy-seeds/sources/KWON-WTI-WALT3-CONT-20260910/source.md"
    quality_tier: A_lineage_with_alternation_translation_risk
    role: exact_one_week_holding_horizon_and_wti_momentum_carrier
strategy_mechanic: normalized-weekly-wti-three-consecutive-completed-week-open-to-close-log-returns-strict-sign-alternation-newest-week-sign-continuation-one-week-hold
sources: ["[[sources/KWON-WTI-WALT3-CONT-20260910]]"]
concepts: ["[[concepts/weekly-commodity-momentum]]", "[[concepts/wti-structural-trend]]"]
indicators: ["[[indicators/completed-week-log-return]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, energy, wti-crude, weekly-momentum, structural-trend, three-week-sign-alternation, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 414110000
period: D1
timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately eight to sixteen completed WTI positions per full post-warm-up year after the strict three-return alternation and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_ALTERNATION_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: D1; 35-bar history buffer; three immediately preceding consecutive completed three-to-five-session weeks; first-open/final-close log returns; strict oldest-to-newest sign alternation; newest sign continuation; 180-minute entry grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q01
q01_status: PENDING
q02_status: NOT_ENQUEUED
force_build: true
review_focus: "Falsify a strict three-completed-week WTI sign-alternation continuation outside the certified book. Verify exact consecutive weekly packages, open-to-close endpoints, strict alternation, newest-sign direction, durable weekly attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_week_bar, three_immediately_completed_monday_anchors, completed_week_session_count, first_open_final_close, strict_three_return_sign_alternation, newest_sign_continuation, no_current_week_leakage, weekly_attempt_state, risk_mode_dual, hard_stop_present, next_week_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 preserves the peer-reviewed weekly commodity-momentum and WTI lineage while disclosing the untested three-week alternation gate and standalone time-series translation; R2 fixes the complete state machine; R3 uses registered native XTIUSD.DWX D1 data; R4 uses deterministic arithmetic. The only fuzzy hit is the source-horizon one-week sibling QM5_41375, whose one-return state differs materially from this card's three-return alternating path."
---

# QM5_41411 WTI Weekly Alternation Continuation

## Hypothesis

When WTI's three immediately completed broker-week open-to-close returns
alternate signs exactly, the newest weekly direction identifies the side of a
one-week continuation trade. The alternating path is a structural trend-state
filter, not a reversal rule: `+,-,+` buys and `-,+,-` sells.

Kwon, Kang, and Yun document cross-sectional one-week commodity-futures
momentum and explicitly include light sweet crude oil. They do not establish a
standalone WTI time-series edge or the three-week alternation gate. Those are
falsifiable QM translations; no published return or significance transfers.

## Source Traceability And Non-Duplicate Decision

The approved complete-read source packet is
`strategy-seeds/sources/KWON-WTI-WALT3-CONT-20260910/source.md`. The canonical
pre-allocation check scanned 4,891 registry rows and 1,501 repository cards,
found no exact identity, and returned only `QM5_41375` as a fuzzy sibling; the
configured Strategy Wiki root was unavailable and is disclosed in the receipt.

`QM5_41375` follows one immediately completed weekly return without a path
filter. `QM5_41065` uses two close-to-close weekly returns and a single flip.
`QM5_41074` requires a fresh same-sign three-week streak. `QM5_41404` and
`QM5_41406` require same-sign seasonal agreement. Relative-value alternation
systems `QM5_41373` and `QM5_41410` trade opposed two-leg baskets and fade the
newest relative winner. This identity instead combines one WTI carrier, three
consecutive open-to-close weekly returns, exact sign alternation, newest-sign
continuation, and a one-week hold.

## Rules

### Market, clock, and state

- Trade only the input-bound `XTIUSD.DWX` host on D1, EA ID `41411`, slot `0`,
  magic `414110000`.
- At the first tradable D1 bar of a new normalized Monday-anchored broker week,
  persist the current-week attempt before any fallible history, signal, news,
  spread, quote, ATR, sizing, or order gate.
- Reconstruct exactly the three immediately preceding consecutive completed
  weeks. Each must contain three to five unique, ordered sessions.
- For every week use the first chronological session open and final session
  close. Exclude all current-week price data from the signal.
- Reject missing, duplicate, mixed-label, nonconsecutive, nonpositive, or
  nonfinite data and consume the week flat.

### Entry

Order the completed weeks oldest to newest and compute
`r[i]=ln(final_close[i]/first_open[i])`. Require every return to be finite and
strictly nonzero.

- `r0>0, r1<0, r2>0`: buy WTI.
- `r0<0, r1>0, r2<0`: sell WTI.
- Every other sign path remains flat for the week.

Require entry within 180 elapsed minutes of the raw current D1 session open, a
spread no greater than 1,500 points, and completed-bar `ATR(20,D1)`. Open at
most one position with aggregate `RISK_FIXED=1000`, a frozen hard stop at
`3.5*ATR`, and no target. Return magnitude never changes risk or side.

### Exit and management

- Close at the first tick of the next normalized broker week.
- Ten elapsed calendar days is stale repair only.
- Flatten duplicate, wrong-side, wrong-magic, or missing-stop owned exposure
  before entry-only filters.
- No signal close, retry, target, trail, break-even, partial close, scale-in,
  pyramid, grid, martingale, hedge, or discretionary exit is allowed.

## Parameters To Test

There is no sweep. Q02 uses one locked baseline:

| Input | Value |
|---|---:|
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 35 |
| `strategy_required_weeks` | 3 |
| `strategy_min_week_bars` | 3 |
| `strategy_max_week_bars` | 5 |
| `strategy_return_epsilon` | 0.0 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |
| `strategy_deviation_points` | 20 |

Framework backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. News and Friday controls remain configurable framework
inputs and are never equality-pinned by the locked-configuration guard. The
RNG seed is never compared. Stress rejection is validated only for finiteness
and the inclusive `0..1` range.

## Risk

The fixed-dollar budget sizes one WTI position from its frozen ATR stop.
Principal risks are the unsupported alternation translation, standalone
time-series port, weekly whipsaw, continuous-CFD roll and basis, energy-label
ambiguity, weekend gaps, financing, spread, stop slippage, and correlation
with other energy strategies. No result establishes market neutrality or
portfolio diversification; Q09 alone may do so.

## Runtime Data Dependencies

Runtime uses only input-bound XTIUSD.DWX D1 OHLC, broker time, symbol metadata,
quotes, completed ATR history, framework position/deal state, and terminal
global-variable attempt state. There is no external calendar, alternative
data, trained output, file feed, API, or future observation.

## Reputable-Source Criteria

- R1: PASS with explicit alternation and time-series translation risk.
- R2: PASS; carrier, clock, packages, endpoints, signs, side, risk, and exit
  are deterministic and locked.
- R3: PASS with disclosed continuous-CFD and label risk.
- R4: PASS; native arithmetic only and no trained or banned signal component.

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than five completed trades
in any full post-warm-up year, nonpositive governed economics, wrong labels or
week adjacency, invalid session counts, current-week leakage, wrong sign side,
late or repeated attempts, missing stops, wrong exits, or nondeterminism.
Changing carrier, weekly endpoint, sign topology, direction, stop, risk, or
lifecycle requires a new identity, dedup review, OWNER approval, and full
Q01+ requalification.

## Framework Alignment

- no_trade: exact input-driven identity, symbol/timeframe, strategy inputs,
  fixed-risk mode, finite bounded stress probability, history, position,
  quote, spread, and durable-attempt checks.
- trade_entry: cached newest-sign direction and one fixed-risk WTI position.
- trade_management: owned-position integrity, next-week exit, and stale repair.
- trade_close: framework close helper, broker hard stop, and no signal exit.
- news hook: returns false without locking any framework news input.

## Validation Plan

Q01 must prove label equivalence, year-boundary adjacency, three/four/five-
session acceptance, two/six rejection, weekly first-open/final-close endpoints,
both alternating directions and nonalternating rejection, no current-week
leakage, durable attempts, fixed-risk frozen stops, next-week/stale repair,
schema lint, strict compile, setfile schema, resolver identity, and a zero-hit
PACER input-pin audit.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-09-10 | initial WTI three-week alternation continuation card | G0 | APPROVED; build pending |

## Safety Boundary

Authorized only for a branch build, Q01 validation, one D1 fixed-risk backtest
preset, and one paced Q02 enqueue if CPU permits. It excludes manual backtests,
optimization, live/demo/shadow/stress presets, AutoTrading, `T_Live`, deploy or
live manifests, portfolio-gate changes, admission, decorrelation claims, and
correlation waivers.
