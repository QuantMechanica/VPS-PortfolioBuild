---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-XTIXNG-WDECEL-CONT-20260906_S01
variant_id: AI-CODEX-XTIXNG-WDECEL-CONT-20260906_S01
source_id: AI-CODEX-XTIXNG-WDECEL-CONT-20260906
ea_id: QM5_41362
slug: xtixng-wdecel-cont
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41362_xtixng-wdecel-cont_card.md
execution_contract_status: APPROVED
created: 2026-09-06
created_by: Research+Development
last_updated: 2026-09-06
g0_status: APPROVED
g0_decision: decisions/2026-09-06_qm5_41362_xtixng_weekly_deceleration_continuation_g0.md
source_approval: decisions/2026-09-06_xtixng_weekly_deceleration_continuation_source_approval.md
source_author: "Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Villar and Joutz (2006), U.S. EIA; Ramberg and Parsons (2012), The Energy Journal 33(2); Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2)."
strategy_mechanic: synchronized-completed-two-adjacent-week-xti-minus-xng-relative-returns-same-sign-newest-strictly-smaller-follow-shared-direction-one-week-equal-notional-basket
strategy_type_flags: [commodity, energy, oil-gas-ratio, market-neutral-basket, weekly-deceleration, continuation, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41362_XTI_XNG_WDECEL_CONT_D1
symbol: QM5_41362_XTI_XNG_WDECEL_CONT_D1
host_symbol: XTIUSD.DWX
companion_symbol: XNGUSD.DWX
symbol_slots: [0, 1]
magic_numbers: [413620000, 413620001]
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eight to twenty completed paired packages per full post-warm-up year after exact synchronized weeks, strict same signs, strict smaller newest magnitude, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 14
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_RELATIVE_SPREAD_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS
r3_data_risk: SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: COMPILE_OK
q02_status: NOT_ENQUEUED_CPU_CEILING
review_focus: "Falsify a completed-week oil/gas deceleration continuation outside the certified XAU/SP500/NDX/XNG book. Verify exact synchronized week ends, chronological non-overlapping returns, strict same signs, strict smaller newest magnitude, shared-direction sides, durable weekly attempt, aggregate fixed risk, atomic basket repair, and next-week lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xti_xng_carrier, synchronized_week_endpoints, consecutive_monday_anchors, nonoverlapping_relative_returns, strict_same_sign, strict_newest_absolute_smaller, follow_shared_return_direction, persistent_week_attempt, equal_notional_basket, aggregate_fixed_risk, hard_stops_present, atomic_package_repair, next_week_exit, risk_mode_dual, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 uses complete U.S. government and peer-reviewed sources, retains adverse instability, and discloses the weekly relative-spread continuation as an untested QM translation; R2 locks exact synchronized weeks, chronological relative returns, strict same signs, strict smaller newest magnitude, shared-direction sides, durable attempt, aggregate fixed risk, hard stops, and next-week lifecycle; R3 uses registered native XTI/XNG D1 histories with synchronization and CFD-basis risks explicit; R4 is deterministic native arithmetic without banned logic; canonical dedup and manual family review found no exact identity."
---

# QM5_41362 XTI/XNG Completed-Week Deceleration Continuation

## Hypothesis

When the XTI/XNG log-ratio moves in the same direction for two completed
broker weeks but the newest move is strictly smaller, relative trend may still
persist for one additional week even as its impulse decelerates. Following the
shared direction through opposed oil/gas legs tests that structural state
without taking an outright single-energy signal.

The candidate is one logical two-leg package intended to add a distinct energy
relative-value driver outside the certified XAU/SP500/NDX/XNG book. Equal
notional is a target, not proof of neutrality. Q02 owns density/economics and
unchanged Q09 alone may establish realized book correlation.

## Source Traceability And Claim Boundary

The approved source of record is
`strategy-seeds/sources/AI-CODEX-XTIXNG-WDECEL-CONT-20260906/source.md`,
authorized before extraction in
`decisions/2026-09-06_xtixng_weekly_deceleration_continuation_source_approval.md`.

Villar/Joutz and Ramberg/Parsons supply government and peer-reviewed evidence
for a weak, time-varying oil/gas relationship. Moskowitz/Ooi/Pedersen supply
broad futures own-price continuation evidence. No source tests this weekly
relative-spread state. No return, drawdown, frequency, cost, hedge ratio,
neutrality, or correlation statistic transfers.

## Non-Duplicate Decision

The canonical checker scanned 4,842 registry rows and 1,455 cards, found no
exact identity, and surfaced eight fuzzy family matches. Manual review fixes
the boundaries:

- `QM5_41359_xtixng-waccel-rv` requires same-sign acceleration and fades it;
  this card requires same-sign deceleration and follows it.
- `QM5_41360_xtixng-wretr-rv` requires opposite signs and follows the newest
  partial retracement.
- `QM5_41358_xtixng-wovershoot-rv` requires an opposite-sign overshoot and
  fades it.
- `QM5_41066_xauxag-wdecay-rv` uses the same two-return state on precious
  metals and fades it instead of following it.
- Other XTI/XNG systems use fitted residuals, ranks, change points, weekdays,
  calendars, or different clocks and lifecycle rules.
- `QM5_12567_cum-rsi2-commodity` is single-symbol, long-only, and short-horizon.

The exact carrier, three synchronized week ends, two adjacent relative
returns, strict same signs, strict smaller newest magnitude, continuation side,
weekly attempt, aggregate-risk basket, and next-week exit are jointly
load-bearing. Verdict: `CLEAN_AFTER_FUZZY_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Host: `XTIUSD.DWX`, D1, slot 0, magic `413620000`.
- Companion: `XNGUSD.DWX`, D1, slot 1, magic `413620001`.
- Logical symbol: `QM5_41362_XTI_XNG_WDECEL_CONT_D1`.
- Formation: three consecutive synchronized completed broker-week-end pairs.
- Decision: first tradable D1 bar of a new Monday-anchored broker week, within
  180 elapsed raw-session minutes.
- Exit: first tick in a later broker week, with a ten-day stale guard.
- Expected cadence: eight to twenty packages/year; retire below five.

## Formula

```text
s1 = ln(XTI_newest) - ln(XNG_newest)
s2 = ln(XTI_middle) - ln(XNG_middle)
s3 = ln(XTI_oldest) - ln(XNG_oldest)
r_new = s1 - s2
r_old = s2 - s3

r_old > 0 and r_new > 0 and abs(r_new) < abs(r_old)
    => BUY XTI, SELL XNG
r_old < 0 and r_new < 0 and abs(r_new) < abs(r_old)
    => SELL XTI, BUY XNG
otherwise
    => FLAT
```

All endpoints are completed before the decision week. Equality is flat.

## Rules

The following entry, exit, filter, and management clauses are the complete
authorized baseline. No fallback signal or parameter sweep is permitted.

## Entry Rules

1. Evaluate once on a new exact host D1 bar under EA 41362 and slot zero.
2. Repair malformed, orphaned, duplicated, same-side, stopless, notional-
   invalid, later-week, or stale exposure before entry-only gates.
3. Prove the current bar is the first tradable bar carrying a new Monday
   anchor and reject attachment later than 180 minutes after raw bar open.
4. Persist the week attempt before history, signal, spread, quote, range,
   sizing, news, or order gates. Never retry that week.
5. In a 30-bar buffer select the newest synchronized positive finite close
   pair for each prior Monday anchor and require current minus 7, 14, and 21
   calendar days, newest first.
6. Require both relative returns finite and non-zero, strict same signs, and
   `abs(r_new)<abs(r_old)`. Opposite signs, equality, or a non-smaller newest
   move is flat.
7. Follow the shared sign through opposed legs exactly as the formula states.
8. Require no owned exposure/current-week entry, executable quotes, and no
   positive spread wider than 1,500 XTI or 3,000 XNG points. Zero modeled
   `.DWX` spread is valid.
9. Attach a frozen `3.5*ATR(20,D1)` hard stop per leg. Combined normalized
   stop risk cannot exceed one `RISK_FIXED` budget.
10. Target one-to-one absolute entry notional, round down only, reject more
    than 20 percent mismatch, and use no take-profit.
11. Submit both legs once. On either failure or invalid composition,
    immediately flatten all owned exposure without retry or fallback.

## Exit And Management Rules

1. Broker hard stops and framework kill-switch closure remain authoritative.
2. Flatten orphan, duplicate, same-side, wrong-symbol, wrong-magic, missing-
   stop, invalid-volume, or notional-invalid packages immediately.
3. Close both legs on the first tick whose Monday anchor is later than entry.
4. Close after ten elapsed calendar days as a final stale guard.
5. No target, signal reversal, trail, break-even, partial, scale-in, pyramid,
   grid, martingale, or discretionary exit is authorized.
6. Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both
   news axes OFF, and Friday close OFF.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_xng_symbol` | `XNGUSD.DWX` | exact companion |
| `strategy_history_bars_d1` | 30 | week-end search buffer |
| `strategy_entry_grace_minutes` | 180 | first-week-bar window |
| `strategy_atr_period_d1` | 20 | completed-bar range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | equal absolute notional target |
| `strategy_max_notional_mismatch_pct` | 20.0 | mismatch ceiling |
| `strategy_max_hold_days` | 10 | stale repair |
| `strategy_xti_max_spread_points` | 1500 | XTI cost guard |
| `strategy_xng_max_spread_points` | 3000 | XNG cost guard |
| `strategy_deviation_points` | 20 | order deviation |
| `qm_friday_close_enabled` | false | preserve full-week hold |

## Author Claims

The cited sources document a weak, shifting oil/gas relationship and broad
futures momentum. They do not claim this conjunction works, that continuous
CFDs reproduce futures, or that the basket is neutral, profitable, or
decorrelated.

## Risk

Risk is high: non-convergence, oil/gas beta drift, one-leg fills, lot-step
mismatch, energy gaps, continuous-CFD basis, financing, spread, low density,
and overlap with the incumbent XNG sleeve can dominate the premise. Each leg
has a frozen hard stop and the pair shares one fixed-dollar budget.

## Falsification And Requalification

Q02 retires rather than tunes on zero packages, fewer than five packages per
full post-warm-up year, nonpositive governed economics, wrong/asynchronous
endpoints, nonconsecutive anchors, current-week leakage, opposite signs, zero,
equality, non-smaller newest move, wrong side, duplicate attempt, one-leg
survivor, aggregate-risk breach, missing stop, wrong exit, nondeterminism, or
invalid fixed-risk mode.

Changing carrier, endpoint count, horizon, sign/magnitude condition,
direction, attempt clock, risk, stops, or lifecycle requires a new identity
and full requalification. A failure may not be rescued by a threshold, fitted
center, beta, calendar, trend, or volatility filter.

## Strategy Allowability Check

- [x] R1: PASS with disclosed translation risk; complete government and
  peer-reviewed governed sources were read before approval.
- [x] R2: PASS; state, sides, attempt, risk, stops, and lifecycle are fixed.
- [x] R3: PASS for registered native XTI/XNG D1 proxy data.
- [x] R4: PASS; deterministic native arithmetic only, with no trained model,
  prohibited signal indicator, external feed, grid, or martingale.
- [x] Dedup: deterministic scan plus manual fuzzy-family review is clean.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| synchronized weeks, returns, state, side, attempt, costs, range | Trade Entry | deterministic helpers and basket order helper |
| orphan/notional, later-week, stale repair | Trade Management | package lifecycle helper |
| survivor and next-week repair | Trade Close | package lifecycle helper |
| kill switch, ownership, magic resolver, aggregate risk | Framework No-Trade | standard framework plus foreign magic |
| news OFF | News hooks | both axes locked OFF |

## Validation Plan

Q01 must prove Monday anchors across year boundaries; three consecutive
synchronized completed week ends; chronological non-overlapping returns; both
strict same-sign deceleration directions; opposite-sign, zero, equality, and
non-smaller-newest flat states; no current-bar leakage; durable attempts;
equal-notional rounding; aggregate-risk sizing; atomic repair; next-week exit;
card lint; strict compile; setfile schema; basket manifest; resolver identity;
and static artifact validation.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-09-06 | initial completed-week XTI/XNG deceleration-continuation card | G0 | APPROVED |
| v2 | 2026-09-06 | governed compile-PASS build; paced Q02 admission stopped at the binding CPU ceiling | Q01/Q02 | COMPILE_OK; NOT_ENQUEUED_CPU_CEILING |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-09-06 | APPROVED | `decisions/2026-09-06_qm5_41362_xtixng_weekly_deceleration_continuation_g0.md` |
| Q01 Build Validation | 2026-09-06 | COMPILE_OK; BUILD_CHECK_PASS | `D:/QM/reports/work_items/acfa4f4e-8e78-474d-a9da-fbb2b5dd128c/QM5_41362/COMPILE_EA/compile_evidence.json` |
| Q02 Baseline Screening | 2026-09-06 | NOT_ENQUEUED_CPU_CEILING | five samples 95.5%-100.0%, average 98.7%, strict threshold 97%; `artifacts/qm5_41362_q02_cpu_admission_20260906.json` |

## Safety Boundary

This card authorizes one branch-only non-live build, Q01 validation, one
logical D1 fixed-risk backtest setfile, and one paced Q02 enqueue only below
the CPU ceiling. It does not authorize a manual backtest, terminal control,
live/demo/shadow/stress preset, AutoTrading, `T_Live`, deployment, a live
manifest, portfolio-gate change, portfolio admission, decorrelation claim,
neutrality claim, or correlation waiver.
