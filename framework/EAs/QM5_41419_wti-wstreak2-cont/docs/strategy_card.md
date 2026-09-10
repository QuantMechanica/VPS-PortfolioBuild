---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-WSTREAK2-CONT-20260910_S01
variant_id: MOP-WTI-WSTREAK2-CONT-20260910_S01
source_id: MOP-WTI-WSTREAK2-CONT-20260910
ea_id: QM5_41419
slug: wti-wstreak2-cont
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41419_wti-wstreak2-cont_card.md
execution_contract_status: APPROVED
created: 2026-09-10
created_by: Research+Development
last_updated: 2026-09-10
g0_status: APPROVED
g0_decision: decisions/2026-09-10_qm5_41419_wti_fresh_two_week_sign_streak_continuation_g0.md
source_approval: decisions/2026-09-10_wti_fresh_two_week_sign_streak_continuation_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; OpenAI Codex"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; OpenAI Codex"
source_citation: "Moskowitz, Ooi & Pedersen (2012), Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_bounded_mechanization
    citation: "Moskowitz-Ooi-Pedersen commodity time-series momentum lineage and explicit WTI carrier; QuantMechanica governed fresh two-week state translation."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read packet strategy-seeds/sources/MOP-WTI-WSTREAK2-CONT-20260910/source.md"
    quality_tier: A_lineage_with_short_horizon_state_translation_risk
    role: commodity_continuation_lineage_and_wti_carrier
strategy_mechanic: normalized-week-boundary-wti-four-consecutive-completed-week-ending-closes-three-adjacent-weekly-returns-newest-two-strict-same-sign-preceding-strict-opposite-sign-fresh-two-week-streak-continuation-one-week-hold
sources: ["[[sources/MOP-WTI-WSTREAK2-CONT-20260910]]"]
concepts: ["[[concepts/time-series-momentum]]", "[[concepts/fresh-two-week-sign-streak]]", "[[concepts/wti-structural-trend]]"]
indicators: ["[[indicators/completed-week-ending-close]]", "[[indicators/log-return-sign]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, energy, wti-crude, weekly-continuation, structural-trend, fresh-two-week-streak, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
symbol_slots: [0]
magic: 414190000
period: D1
timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately eight to sixteen completed WTI positions per full post-warm-up year after strict fresh-state and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_SHORT_HORIZON_STATE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: D1; 45-bar history; four consecutive completed three-to-five-session broker weeks; three adjacent week-ending-close log returns; strict -++ / +-- fresh state; follow newest sign; 180-minute entry grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED
q01_build_report: D:/QM/reports/work_items/5a92a23f-e31e-4a5e-ac5f-8d2d0ca1ae85/QM5_41419/COMPILE_EA/compile_evidence.json
force_build: true
review_focus: "Falsify a direct-WTI fresh two-completed-week continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify energy labels, exact Monday anchors, four completed week endpoints, strict -++ / +-- state, same-sign side, durable weekly attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_week_bar, consecutive_monday_anchors, completed_week_endpoints, bounded_week_session_counts, strict_return_signs, fresh_two_week_transition, same_streak_direction, no_current_week_leakage, weekly_attempt_state, risk_mode_dual, hard_stop_present, next_week_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 preserves complete peer-reviewed momentum evidence and explicit WTI membership while disclosing untested weekly translation; R2 fixes every state and execution field; R3 uses registered native XTIUSD.DWX D1 data; R4 uses deterministic arithmetic. Canonical exact/fuzzy dedup is CLEAN and manual family review separates longer, seasonal, and relative-carrier siblings."
---

# QM5_41419 WTI Fresh Two-Week Sign-Streak Continuation

## Hypothesis

The first completion of two consecutive same-direction WTI weeks after an
opposite week may carry into the following broker week. On the first tradable
bar of that week, follow the fresh streak: `-,+,+` buys and `+,-,-` sells.

Moskowitz, Ooi, and Pedersen provide peer-reviewed commodity continuation
lineage and explicit WTI membership. They do not establish this weekly event.
No published efficacy, density, WTI-only alpha, or decorrelation transfers.

## Source Traceability And Non-Duplicate Decision

The approved complete-read packet is
`strategy-seeds/sources/MOP-WTI-WSTREAK2-CONT-20260910/source.md`. The canonical
scan covered 4,899 registry rows, 1,509 cards, and 45 Strategy Wiki nodes and
found no exact or fuzzy identity.

`QM5_41074` waits for `-,+,+,+` / `+,-,-,-`, one additional same-sign week.
`QM5_41415` fades that longer state. Seasonal WTI two-week cards restrict
months and omit the older opposite predecessor. `QM5_41418` applies similar
topology to a two-leg gold/silver ratio basket. Carrier, endpoint count, fresh
state, continuation side, fixed risk, and one-week lifecycle jointly define
this identity.

## Rules

### Market, clock, and state

- Trade only input-bound `XTIUSD.DWX` on D1, EA 41419, slot 0, magic 414190000.
- At the first tradable D1 bar of a new normalized Monday-anchored broker week,
  persist the current-week attempt before history, signal, news, spread, quote,
  ATR, sizing, or order gates.
- Reconstruct four consecutive completed broker-week ending closes. Every
  contributing week must contain three to five unique ordered sessions.
- Accept only one uniform raw or governed +1-day energy-label convention.
  Exclude every current-week price observation.
- Missing, duplicate, mixed-label, nonconsecutive, nonpositive, or nonfinite
  data consumes the week flat.

### Entry

Let `C0` be the newest completed week-ending close and `C3` the oldest:

```text
r0 = ln(C0/C1)
r1 = ln(C1/C2)
r2 = ln(C2/C3)
```

- `r0>0, r1>0, r2<0`: buy WTI.
- `r0<0, r1<0, r2>0`: sell WTI.
- Every other path, including exact zero, remains flat for the week.

Require entry within 180 elapsed minutes of the raw current D1 bar open, spread
no greater than 1,500 points, and completed-bar ATR(20,D1). Open at most one
position with `RISK_FIXED=1000`, a frozen `3.5*ATR` hard stop, and no target.
Return magnitude never changes risk or side.

### Exit and management

- Close at the first tick of the next normalized broker week.
- Ten elapsed calendar days is stale repair only.
- Flatten duplicate, wrong-symbol, wrong-magic, invalid-side, missing-stop,
  take-profit-bearing, future-dated, or invalid-volume owned exposure.
- No signal close, retry, target, trail, break-even, partial close, scale-in,
  pyramid, grid, martingale, hedge, or discretionary exit is allowed.

## Parameters To Test

There is no sweep. Q02 uses one locked baseline:

| Input | Value |
|---|---:|
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 45 |
| `strategy_required_weeks` | 4 |
| `strategy_min_week_bars` | 3 |
| `strategy_max_week_bars` | 5 |
| `strategy_return_epsilon` | 0 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Framework backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. News and Friday controls remain configurable and are
never equality-pinned. RNG is never compared. Stress rejection is checked
only for finiteness and the inclusive `0..1` range.

## Risk

Principal risks are unsupported weekly continuation translation, reversals,
continuous-CFD roll/basis and financing, energy-label ambiguity, weekend gaps,
spread, hard-stop slippage, sparse years, and correlation with other energy
strategies. Q09 alone may establish diversification.

## Runtime Data Dependencies

Runtime uses only input-bound XTIUSD.DWX D1 OHLC, broker time, symbol metadata,
quotes, completed ATR history, framework position/deal state, and terminal
global-variable attempt state. No external calendar, alternative data, trained
output, file feed, API, or future observation is read.

## Reputable-Source Criteria

- R1: pass with explicit short-horizon state translation risk.
- R2: pass; every rule and lifecycle condition is deterministic.
- R3: pass with explicit continuous-CFD and energy-label risk.
- R4: pass; no ML or banned indicator is used.

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than five completed trades
in any full post-warm-up year, nonpositive governed economics, wrong labels or
week adjacency, invalid session counts, current-week leakage, wrong side,
late/repeated attempts, missing stops, wrong exits, or nondeterminism. Changing
carrier, endpoints, state, side, stop, risk, or lifecycle requires a new
identity, dedup review, OWNER approval, and full Q01+ requalification.

## Framework Alignment

- no_trade: input-driven identity, symbol/timeframe, locked strategy inputs,
  fixed-risk mode, finite bounded stress probability, and durable-attempt checks.
- trade_entry: cached fresh-streak direction and one fixed-risk WTI position.
- trade_management: owned-position integrity, next-week exit, stale repair.
- trade_close: framework close helper, broker hard stop, no signal exit.
- news hook: delegates to configurable framework news inputs and pins none.

## Validation Plan

Q01 must prove raw/+1-day label equivalence, year-boundary adjacency,
three/four/five-session acceptance, two/six rejection, exact week endpoints,
both `-++` / `+--` directions and other-path rejection, no current-week
leakage, durable attempts, fixed-risk frozen stops, next-week/stale repair,
schema lint, strict compile, setfile schema, resolver identity, and a
zero-finding PACER framework-input-pin audit.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-09-10 | initial WTI fresh two-week streak-continuation card | G0 | APPROVED; build pending |
| v1-build | 2026-09-10 | governed compile and build check | Q01 | COMPILE_OK; 0 compiler errors/warnings; build-check PASS; pin audit zero findings; 6/6 tests PASS |
| v1-q02 | 2026-09-10 | first governed fixed-risk XTI canary | Q02 | ENQUEUED; pending work item `e1d50eea-cf61-45bd-b897-e4c692461733`; CPU max 70.32% |

## Safety Boundary

Authorized only for a branch build, Q01 validation, one D1 fixed-risk backtest
preset, and one paced Q02 enqueue if CPU permits. It excludes manual backtests,
optimization, live/demo/shadow/stress presets, AutoTrading, `T_Live`, deploy or
live manifests, portfolio-gate changes, portfolio admission, correlation
waivers, and decorrelation claims.
