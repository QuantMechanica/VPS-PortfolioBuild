---
card_schema_version: 2
type: strategy
strategy_id: KWON-KANG-YUN-WTI-WMOM265-2026_S01
variant_id: KWON-KANG-YUN-WTI-WMOM265-2026_S01
source_id: KWON-KANG-YUN-WTI-WMOM265-2026
ea_id: QM5_41378
slug: wti-wmom265
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41378_wti-wmom265_card.md
execution_contract_status: APPROVED
created: 2026-09-07
created_by: Research+Development
last_updated: 2026-09-07
g0_status: APPROVED
g0_decision: decisions/2026-09-07_qm5_41378_wti_halfyear_weekly_momentum_g0.md
source_approval: decisions/2026-09-07_wti_halfyear_weekly_momentum_source_approval.md
source_author: "Kyung Yoon Kwon; Jangkoo Kang; Jaesun Yun"
source_authors: "Kyung Yoon Kwon; Jangkoo Kang; Jaesun Yun"
source_citation: "Kwon, K. Y., Kang, J., and Yun, J. (2020), Weekly Momentum in the Commodity Futures Market, Finance Research Letters 35, 101306, DOI 10.1016/j.frl.2019.101306."
source_citations:
  - type: peer_reviewed_paper
    citation: "Kwon, Kyung Yoon; Kang, Jangkoo; and Yun, Jaesun (2020), Weekly Momentum in the Commodity Futures Market, Finance Research Letters 35, 101306."
    location: "DOI 10.1016/j.frl.2019.101306; pp. 3-5 and Tables 1-3; complete-read packet strategy-seeds/sources/KWON-KANG-YUN-WTI-WMOM265-2026/source.md"
    quality_tier: A
    role: exact_cmom265_formation_horizon_week_t_hold_and_wti_membership
strategy_mechanic: normalized-week-boundary-wti-cmom26-5-exact-t-minus-26-through-t-minus-5-cumulative-return-sign-continuation-one-week-hold
strategy_type_flags: [commodity, energy, wti-crude, half-year-momentum, structural-trend, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 413780000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 35-50 completed WTI positions per full post-warm-up year because the exact half-year return normally has a nonzero sign; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 44
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WEAK_RAW_AND_FACTOR_SPANNING_EVIDENCE
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED
parameters_to_test: "Locked Q02 baseline only: exact D1; 160-bar history buffer; 26 consecutive completed 2-5-session weeks; strict ln(final close t-5 / first open t-26) sign; complete exclusion of t-4..t-1; 180-minute entry grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
review_focus: "Falsify the source-defined CMOM26,5 WTI stream outside the certified XAU/SP500/NDX/XNG book. Verify exact t-26..t-5 endpoints, complete exclusion of t-4..t-1 and current week, fixed risk, frozen stop, durable weekly attempt, and next-week exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, consecutive_completed_weeks, exact_cmom265_endpoints, recent_four_weeks_excluded, no_current_week_leakage, weekly_attempt_state, risk_mode_dual, hard_stop_present, next_week_exit, q02_frequency_floor, portfolio_correlation]
---

# QM5_41378 WTI Half-Year Weekly Momentum

## Hypothesis

A source-defined half-year commodity-momentum state may provide a falsifiable
WTI return stream outside the certified XAU/SP500/NDX/XNG book. At the first
tradable D1 bar of broker week `t`, follow the strict sign of WTI's cumulative
return over completed weeks `t-26..t-5`, deliberately excluding `t-4..t-1`,
and hold for one week.

The peer-reviewed source tests a cross-sectional commodity-futures portfolio,
not standalone WTI. Its `CMOM26,5` evidence is weak after factor controls and
loads strongly on carry and equity momentum. The card therefore makes no
profitability, causality, CFD-equivalence, neutrality, or decorrelation claim.

## Source Traceability And Adverse Evidence

The approved packet is
`strategy-seeds/sources/KWON-KANG-YUN-WTI-WMOM265-2026/source.md`; approval is
`decisions/2026-09-07_wti_halfyear_weekly_momentum_source_approval.md`.
The complete 20-page manuscript hash is
`D768279A0B0F601216FFFA5C48A534939822E7C29B039169ADF0CA817B222F2C`.

The source defines `CMOM26,5` from weeks `t-26..t-5`, held in week `t`, and
includes light sweet crude oil. Raw weekly return is 0.14% (t=1.76), the
AVG/CARRY-adjusted intercept is 0.06% (t=0.83), and carry loading is 0.42
(t=6.19). These are adverse boundaries, not expected EA performance.

## Non-Duplicate Decision

The pre-allocation checker found no exact duplicate and only three same-paper
fuzzy siblings; the unavailable external Wiki root remains explicit in
`artifacts/qm5_wti_wmom265_preallocation_dedup_20260907.json`.

- `QM5_41375` uses `t-1` only.
- `QM5_41376` uses `t-4..t-2` only.
- `QM5_41377` requires those two short blocks to agree.
- This card excludes all of `t-4..t-1` and uses exactly `t-26..t-5`.
- Monthly WTI trend cards use month-end endpoints and monthly holds.

Verdict: `DISTINCT_WTI_CMOM265_EXACT_HALF_YEAR_WEEKLY_BLOCK_CONTINUATION`.

## Market, Clock, And Formula

- Host and traded symbol: setfile-bound `XTIUSD.DWX`; never a code literal.
- Timeframe: exact D1; EA 41378; slot 0; magic 413780000.
- Decision: first tradable D1 bar of a normalized Monday-anchored broker week,
  within 180 elapsed minutes of the raw session open.
- History: 26 consecutive completed weekly packages with two to five unique
  ordered sessions each; 160 D1 bars requested.
- Formula:

```text
r_halfyear = ln(final_close[t-5] / first_open[t-26])
r_halfyear > 0 => BUY
r_halfyear < 0 => SELL
otherwise      => FLAT
```

## Rules

### Entry Rules

1. Repair malformed or stale owned exposure before entry-only filters.
2. Require configured symbol, D1, EA 41378, slot 0, fixed-risk backtest mode,
   both news axes OFF, and Friday close disabled.
3. Infer one energy-label convention from the current D1 bar: native same-day
   labels or uniform `+1` day. Apply it to all history.
4. Persist the normalized week attempt before history, signal, spread, quote,
   ATR, sizing, news, or order gates. Never retry that week.
5. Reconstruct exact weeks `t-1..t-26`; require seven-day anchor adjacency and
   two to five unique ordered sessions in every package.
6. Use the chronologically first open of `t-26` and final close of `t-5`.
   Reject nonpositive/nonfinite endpoints and ignore every price in
   `t-4..t-1` except for chronology validation.
7. Buy for strict positive return and sell for strict negative return. Equality
   or invalid state is flat.
8. Require spread from 0 through 1,500 points, valid quote, and completed-bar
   ATR(20,D1). Freeze a `3.5*ATR` hard stop and open one fixed-risk position.

### Attempt And Restart Contract

Persist the normalized Monday anchor in a terminal-global key scoped by EA,
magic, symbol, and timeframe before fallible gates. Late attachment consumes
the week flat. Deal history and owned-position state fail closed. A rejected
order, restart, spread, history, ATR, sizing, or news failure cannot retry.

### Exit And Management Rules

Broker hard stop and framework kill switch remain authoritative. Flatten
duplicate, wrong-side, wrong-magic, missing-stop, or otherwise malformed owned
exposure. Close at the first tick whose normalized Monday anchor is later than
the entry-week anchor. Ten elapsed days is stale repair only.

No target, opposite-signal exit, trail, break-even, partial close, Friday
flatten, scale-in, pyramid, grid, martingale, hedge, or discretionary close.

### No-Trade Contract

Fail closed for wrong symbol/period/ID/slot/risk mode, invalid label offset,
late attachment, nonconsecutive weeks, invalid session counts, nonpositive
endpoints, nonfinite return, excess spread, invalid quote/ATR/stop, consumed
attempt, prior deal, or owned position. Both news axes are OFF and Friday
close is disabled.

## Parameters To Test

No optimization surface is approved. The Q02 baseline is locked:

| Parameter | Value |
|---|---:|
| `strategy_symbol` | setfile symbol |
| `strategy_label_offset_seconds` | 86400 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 160 |
| `strategy_total_weeks` | 26 |
| `strategy_skip_recent_weeks` | 4 |
| `strategy_min_week_bars` | 2 |
| `strategy_max_week_bars` | 5 |
| `strategy_return_epsilon` | 0.0 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |
| `qm_friday_close_enabled` | false |

## Runtime Data Dependencies

Configured-symbol D1 OHLC, broker time, symbol metadata, executable quotes,
completed ATR, framework position/deal history, and terminal-global attempt
state. No external runtime dataset, event calendar, current-week signal price,
recent-four-week signal price, volume, inventory, curve, or portfolio state.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Frozen `3.5*ATR(20,D1)` hard stop; no target or signal-strength sizing.
- Principal risks: weak and factor-spanned source evidence, cross-sectional-to-
  time-series translation, futures/CFD roll and basis, repeated weekly exposure
  to a slow signal, weekend gaps, financing, spread, and book correlation.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Strategy Allowability Check

| Gate | Verdict | Evidence |
|---|---|---|
| R1 | PASS_WITH_WEAK_RAW_AND_FACTOR_SPANNING_EVIDENCE | Peer-reviewed complete-read source defines exact horizon and WTI membership; adverse results retained. |
| R2 | PASS | Clock, endpoints, exclusion, side, attempt, risk, stop, spread, and lifecycle fixed. |
| R3 | PASS_WITH_CONTINUOUS_CFD_BASIS_RISK | Registered native XTIUSD.DWX D1 history supplies runtime fields. |
| R4 | PASS | Deterministic native arithmetic without trained or banned logic. |

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than five completed trades
in any full post-warm-up year, nonpositive governed economics, any signal use
of `t-4..t-1`, mixed labels, broken week adjacency, invalid session counts,
endpoint leakage, wrong side, repeated attempt, missing stop, wrong exit, or
nondeterminism. Changing the horizon, endpoints, carrier, label policy,
attempt, stop, risk, spread, or lifecycle requires a new identity and Q00/Q01.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact period, labels, 26 weeks, endpoints, exclusion, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus helpers |
| malformed, later-week, and stale repair | Trade Management | `Strategy_ManageOpenPosition` |
| no independent signal close | Trade Close | `Strategy_ExitSignal` returns false |
| kill switch, ownership, magic, fixed risk | Framework No-Trade | standard orchestration |
| news OFF | News hook | both framework axes locked OFF |

## Validation Plan

Q01 must prove native/shifted labels, year boundaries, two/five-session
acceptance, one/six rejection, exact `t-26` and `t-5` endpoints, complete
recent-four-week exclusion, positive/negative/equality states, no current-bar
leakage, persistent attempts, fixed-risk frozen stops, next-week/stale repair,
card lint, resolver identity, PACER pin audit, and governed strict compile.

Q02 alone measures density and economics. Q09 alone establishes realized
correlation with the certified book.

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-09-07 | APPROVED | `decisions/2026-09-07_qm5_41378_wti_halfyear_weekly_momentum_g0.md` |
| Q01 Build Validation | 2026-09-07 | PASS | 14/14 reference checks; PACER audit clean; governed `COMPILE_OK`, 0 compiler errors/warnings; build check PASS |
| Q02 Baseline Screening | 2026-09-07 | ENQUEUED | work item `d4ac61bc-4b49-4eed-98ef-93b488d5e749`; XTIUSD.DWX D1; fixed-risk setfile hash `615b95008bf78117d89164a8011c4ced7cfeed5a3eb5760c2ef95db1e143b483` |

## Safety Boundary

This card authorizes a branch-only non-live build, Q01 validation, one D1
fixed-risk backtest setfile, and one paced target-only Q02 enqueue only below
tester and CPU ceilings. It excludes manual backtests, terminal control,
live/demo/shadow/stress/optimization presets, AutoTrading, `T_Live`, deploy or
live manifests, portfolio-gate changes, admission, decorrelation claims, and
correlation waivers.
