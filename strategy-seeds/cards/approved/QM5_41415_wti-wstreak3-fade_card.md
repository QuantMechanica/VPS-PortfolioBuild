---
card_schema_version: 2
type: strategy
strategy_id: YANG-WTI-WSTREAK3-FADE-20260910_S01
variant_id: YANG-WTI-WSTREAK3-FADE-20260910_S01
source_id: YANG-WTI-WSTREAK3-FADE-20260910
ea_id: QM5_41415
slug: wti-wstreak3-fade
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41415_wti-wstreak3-fade_card.md
execution_contract_status: APPROVED
created: 2026-09-10
created_by: Research+Development
last_updated: 2026-09-10
g0_status: APPROVED
g0_decision: decisions/2026-09-10_qm5_41415_wti_fresh_three_week_sign_streak_reversion_g0.md
source_approval: decisions/2026-09-10_wti_fresh_three_week_sign_streak_reversion_source_approval.md
source_author: "Chao Yang; A. Goncu; Athanasios A. Pantelous; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; OpenAI Codex"
source_authors: "Chao Yang; A. Goncu; Athanasios A. Pantelous; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; OpenAI Codex"
source_citation: "Yang, C., Goncu, A., and Pantelous, A. A. (2017), Momentum and Reversal in Commodity Futures, SSRN 3069253; Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: academic_composite_with_bounded_translation
    citation: "Yang, Goncu, and Pantelous (2017), Momentum and Reversal in Commodity Futures; Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum."
    location: "SSRN 3069253; DOI 10.1016/j.jfineco.2011.11.003; complete-read packet strategy-seeds/sources/YANG-WTI-WSTREAK3-FADE-20260910/source.md"
    quality_tier: A_and_academic_lineage_with_weekly_state_translation_risk
    role: commodity_reversal_direction_plus_completed_week_state_and_wti_carrier
strategy_mechanic: normalized-week-boundary-wti-five-consecutive-completed-week-ending-closes-four-adjacent-weekly-returns-newest-three-strict-same-sign-preceding-strict-opposite-sign-fresh-three-week-streak-reversion-one-week-hold
sources: ["[[sources/YANG-WTI-WSTREAK3-FADE-20260910]]"]
concepts: ["[[concepts/commodity-reversal]]", "[[concepts/fresh-three-week-sign-streak]]", "[[concepts/wti-structural-reversal]]"]
indicators: ["[[indicators/completed-week-ending-close]]", "[[indicators/log-return-sign]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, energy, wti-crude, weekly-reversal, structural-reversal, fresh-three-week-streak, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 414150000
period: D1
timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately five to ten completed WTI positions per full post-warm-up year after the strict fresh-streak and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WEEKLY_PATH_AND_REVERSAL_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: D1; 50-bar history buffer; five consecutive completed three-to-five-session broker weeks; four adjacent week-ending-close log returns; newest three strict same-sign, preceding strict opposite; newest-streak-sign reversal; 180-minute entry grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q02
q01_status: PENDING
q02_status: PENDING
force_build: true
review_focus: "Falsify a direct-WTI fresh three-week sign-streak reversal sleeve outside the certified XAU/SP500/NDX/XNG book. Verify uniform energy labels, exact Monday anchors, five completed week-ending closes, four adjacent returns, strict -+++ / +--- state, opposite-streak side, durable weekly attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_week_bar, consecutive_monday_anchors, completed_week_endpoints, bounded_week_session_counts, strict_return_signs, fresh_three_week_transition, opposite_streak_direction, no_current_week_leakage, weekly_attempt_state, risk_mode_dual, hard_stop_present, next_week_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 preserves academic commodity-reversal lineage and a complete peer-reviewed WTI source record while disclosing the untested weekly streak-fade translation; R2 fixes every state and execution field; R3 uses registered native XTIUSD.DWX D1 data; R4 uses deterministic arithmetic. The only fuzzy hit is QM5_41074, whose load-bearing continuation direction is opposite; QM5_41412 admits a disjoint strict-alternation state."
---

# QM5_41415 WTI Fresh Three-Week Sign-Streak Reversion

## Hypothesis

The first completion of three consecutive same-direction WTI weeks after an
opposite week may represent a short-horizon overreaction. On the first
tradable bar of the next broker week, fade that fresh streak for one week:
`-,+,+,+` sells and `+,-,-,-` buys.

Yang, Goncu, and Pantelous provide academic commodity-reversal lineage.
Moskowitz, Ooi, and Pedersen provide a complete peer-reviewed own-return
method record and explicit WTI carrier membership. Neither establishes this
weekly streak fade. No published efficacy, density, or decorrelation transfers.

## Source Traceability And Non-Duplicate Decision

The approved complete-read packet is
`strategy-seeds/sources/YANG-WTI-WSTREAK3-FADE-20260910/source.md`. The
canonical scan covered 4,895 registry rows and 1,505 repository cards, found
no exact identity, and returned only `QM5_41074` as an expected fuzzy sibling;
the configured Strategy Wiki root was unavailable and is disclosed.

`QM5_41074` follows the identical fresh-streak state; this card fades it.
`QM5_41412` fades strict `+,-,+` / `-,+,-` alternation, which cannot overlap
this card's `-,+,+,+` / `+,-,-,-` state. Two-week sign-handoff, magnitude-
ordered, unconditional reversal, and seasonal systems use different states.
The carrier, five endpoints, four adjacent returns, fresh three-week state,
opposite side, and one-week hold jointly define this identity.

## Rules

### Market, clock, and state

- Trade only the input-bound `XTIUSD.DWX` host on D1, EA ID `41415`, slot `0`,
  magic `414150000`.
- At the first tradable D1 bar of a new normalized Monday-anchored broker week,
  persist the current-week attempt before history, signal, news, spread,
  quote, ATR, sizing, or order gates.
- Reconstruct five consecutive completed broker-week ending closes. Every
  contributing week must contain three to five unique, ordered sessions.
- Accept only one uniform raw or governed `+1`-day energy-label convention.
  Exclude all current-week price data.
- Reject missing, duplicate, mixed-label, nonconsecutive, nonpositive, or
  nonfinite data and consume the week flat.

### Entry

Let `C0` be the newest completed week-ending close and `C4` the oldest:

```text
r0 = ln(C0/C1)
r1 = ln(C1/C2)
r2 = ln(C2/C3)
r3 = ln(C3/C4)
```

- `r0>0, r1>0, r2>0, r3<0`: sell WTI.
- `r0<0, r1<0, r2<0, r3>0`: buy WTI.
- Every other path, including exact zero, remains flat for the week.

Require entry within 180 elapsed minutes of the raw current D1 session open, a
spread no greater than 1,500 points, and completed-bar `ATR(20,D1)`. Open at
most one position with `RISK_FIXED=1000`, a frozen hard stop at `3.5*ATR`, and
no target. Return magnitude never changes risk or side.

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
| `strategy_history_bars` | 50 |
| `strategy_required_weeks` | 5 |
| `strategy_min_week_bars` | 3 |
| `strategy_max_week_bars` | 5 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Framework backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. News and Friday controls remain configurable framework
inputs and are never equality-pinned by the locked-configuration guard. RNG is
never compared. Stress rejection is checked only for finiteness and `0..1`.

## Risk

The fixed-dollar budget sizes one WTI position from its frozen ATR stop.
Principal risks are unsupported weekly reversal translation, reversal crashes,
continuous-CFD roll and basis, energy-label ambiguity, weekend gaps, financing,
spread, stop slippage, sparse years, and correlation with other energy
strategies. Q09 alone may establish diversification.

## Runtime Data Dependencies

Runtime uses only input-bound XTIUSD.DWX D1 OHLC, broker time, symbol metadata,
quotes, completed ATR history, framework position/deal state, and terminal
global-variable attempt state. There is no external calendar, alternative
data, trained output, file feed, API, or future observation.

## Reputable-Source Criteria

- R1: PASS with explicit weekly-path and reversal-translation risk.
- R2: PASS; carrier, clock, endpoints, signs, side, risk, and exit are fixed.
- R3: PASS with disclosed continuous-CFD and energy-label risk.
- R4: PASS; native arithmetic only and no trained or banned signal component.

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than five completed trades
in any full post-warm-up year, nonpositive governed economics, wrong labels or
week adjacency, invalid session counts, current-week leakage, wrong side,
late/repeated attempts, missing stops, wrong exits, or nondeterminism. Changing
carrier, endpoint, state, direction, stop, risk, or lifecycle requires a new
identity, dedup review, OWNER approval, and full Q01+ requalification.

## Framework Alignment

- no_trade: input-driven identity, symbol/timeframe, finite strategy inputs,
  fixed-risk mode, finite bounded stress probability, history, position,
  quote, spread, and durable-attempt checks.
- trade_entry: cached opposite-streak direction and one fixed-risk WTI position.
- trade_management: owned-position integrity, next-week exit, stale repair.
- trade_close: framework close helper, broker hard stop, no signal exit.
- news hook: delegates to configurable framework news inputs and pins none.

## Validation Plan

Q01 must prove raw/+1-day label equivalence, year-boundary adjacency,
three/four/five-session acceptance, two/six rejection, exact week-ending-close
endpoints, both fresh-streak directions and nonmatching rejection, opposite
side, no current-week leakage, durable attempts, fixed-risk frozen stops,
next-week/stale repair, schema lint, strict compile, setfile schema, resolver
identity, and a zero-finding PACER framework-input-pin audit.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-09-10 | initial WTI fresh three-week streak-reversion card | G0 | APPROVED; build pending |

## Safety Boundary

Authorized only for a branch build, Q01 validation, one D1 fixed-risk backtest
preset, and one paced Q02 enqueue if CPU permits. It excludes manual backtests,
optimization, live/demo/shadow/stress presets, AutoTrading, `T_Live`, deploy
or live manifests, portfolio-gate changes, admission, decorrelation claims,
and correlation waivers.
