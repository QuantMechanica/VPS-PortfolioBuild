---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-XTIXNG-WRETR-RV-20260906_S01
variant_id: AI-CODEX-XTIXNG-WRETR-RV-20260906_S01
source_id: AI-CODEX-XTIXNG-WRETR-RV-20260906
ea_id: QM5_41360
slug: xtixng-wretr-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41360_xtixng-wretr-rv_card.md
execution_contract_status: APPROVED
created: 2026-09-06
created_by: Research+Development
last_updated: 2026-09-06
g0_status: APPROVED
g0_decision: decisions/2026-09-06_qm5_41360_xtixng_weekly_partial_retracement_g0.md
source_approval: decisions/2026-09-06_xtixng_weekly_partial_retracement_source_approval.md
source_author: "Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons"
source_authors: "Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons"
source_citation: "Villar, J. A. and Joutz, F. L. (2006), The Relationship Between Crude Oil and Natural Gas Prices, U.S. EIA; Ramberg, D. J. and Parsons, J. E. (2012), The Weak Tie Between Natural Gas and Oil Prices, The Energy Journal 33(2), 13-35."
strategy_mechanic: synchronized-completed-two-adjacent-week-xti-minus-xng-relative-returns-opposite-sign-newest-strictly-smaller-follow-newest-retracement-one-week-equal-notional-basket
strategy_type_flags: [commodity, energy, oil-gas-ratio, market-neutral-basket, weekly-partial-retracement, mean-reversion, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41360_XTI_XNG_WRETR_RV_D1
symbol: QM5_41360_XTI_XNG_WRETR_RV_D1
host_symbol: XTIUSD.DWX
companion_symbol: XNGUSD.DWX
symbol_slots: [0, 1]
magic_numbers: [413600000, 413600001]
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eight to twenty completed paired packages per full post-warm-up year after exact synchronized weeks, strict sign opposition, strict smaller newest magnitude, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 14
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WEEKLY_RETRACEMENT_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS
r3_data_risk: SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01_PENDING
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED
review_focus: "Falsify a completed-week oil/gas partial-retracement continuation outside the certified XAU/SP500/NDX/XNG book. Verify exact synchronized week ends, chronological non-overlapping returns, strict sign opposition, strict smaller newest magnitude, newest-return sides, durable weekly attempt, aggregate fixed risk, atomic basket repair, and next-week lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xti_xng_carrier, synchronized_week_endpoints, consecutive_monday_anchors, nonoverlapping_relative_returns, strict_sign_opposition, strict_newest_absolute_smaller, follow_newest_return_basket_direction, persistent_week_attempt, equal_notional_basket, aggregate_fixed_risk, hard_stops_present, atomic_package_repair, next_week_exit, risk_mode_dual, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 uses complete U.S. government and peer-reviewed oil/gas sources, retains their adverse instability evidence, and discloses the weekly partial-retracement continuation as an untested QM translation; R2 locks exact synchronized weeks, chronological relative returns, strict sign opposition, strict smaller newest magnitude, newest-return side, durable attempt, aggregate fixed risk, hard stops, and next-week lifecycle; R3 uses registered native XTI/XNG D1 histories with synchronization and CFD-basis risks explicit; R4 is deterministic native arithmetic without banned logic; canonical dedup and manual family review found no exact identity."
---

# QM5_41360 XTI/XNG Completed-Week Partial-Retracement Continuation

## Hypothesis

When an oil/gas log-ratio impulse is followed by a smaller completed-week move
in the opposite direction, the newest move is a bounded partial retracement:
the ratio finishes between the impulse extreme and its pre-impulse anchor.
Following that retracement for one additional broker week may capture continued
convergence without taking an outright single-energy signal.

The candidate is one logical two-leg package intended to add a distinct energy
relative-value driver outside the certified XAU/SP500/NDX/XNG book. Equal
notional is an execution target, not proof of neutrality. Q02 must establish
density and economics, and unchanged Q09 alone may establish realized book
correlation.

## Source Traceability And Claim Boundary

The approved source of record is
`strategy-seeds/sources/AI-CODEX-XTIXNG-WRETR-RV-20260906/source.md`,
authorized before extraction in
`decisions/2026-09-06_xtixng_weekly_partial_retracement_source_approval.md`.

Villar/Joutz and Ramberg/Parsons supply government and peer-reviewed evidence
for a weak, time-varying oil/gas relationship. The governed parent supplies
the exact two-return partial-retracement arithmetic only. No source tests
this energy CFD implementation. No return, drawdown, frequency, transaction-
cost, hedge-ratio, threshold, neutrality, or correlation statistic transfers.

## Non-Duplicate Decision

The canonical checker scanned 4,840 registry rows and 1,453 cards, found no
exact identity, and surfaced six fuzzy family matches. Manual review fixes
the boundaries:

- `QM5_41077_xauxag-wretr-rv` shares the arithmetic but uses precious metals.
- `QM5_41358_xtixng-wovershoot-rv` shares the carrier and opposite-sign state,
  but requires a strictly larger newest move and fades it; this card requires
  a strictly smaller newest move and follows it.
- `QM5_41359_xtixng-waccel-rv` requires same-sign acceleration and fades the
  shared direction, so its state is disjoint.
- `QM5_41357_xtixng-mwinsor2-rv` uses twelve monthly returns, two-per-tail
  Winsorization, and a next-month hold.
- `QM5_41340_wti-xng-divtrend` trades WTI only and uses XNG as a veto.
- Other XTI/XNG systems use fitted residuals, ranks, change points, weekdays,
  calendars, or different clocks and lifecycle rules.
- `QM5_12567_cum-rsi2-commodity` is a single-symbol, long-only, two-day XNG
  pullback and has no paired energy or weekly relative logic.

The exact carrier, three synchronized week ends, two adjacent relative
returns, strict sign opposition, strict smaller newest magnitude, newest-return side,
weekly attempt, equal-target-notional aggregate-risk package, and next-week
exit are jointly load-bearing.

## Markets, Timeframe, And Cadence

- Exact host: `XTIUSD.DWX`, D1, slot 0, magic `413600000`.
- Exact companion: `XNGUSD.DWX`, D1, slot 1, magic `413600001`.
- Logical symbol: `QM5_41360_XTI_XNG_WRETR_RV_D1`.
- Formation: three consecutive synchronized completed broker-week-end pairs.
- Decision: first tradable D1 bar of a new Monday-anchored broker week, within
  180 elapsed raw-session minutes.
- Signal: two strict opposite-sign weekly relative returns with a strictly
  smaller newest magnitude; follow the newest direction.
- Exit: first tick in a later broker week, with a ten-day stale guard.
- Expected cadence: eight to eighteen packages/year; retire below five.

## Formula

```text
s1 = ln(XTI_newest) - ln(XNG_newest)
s2 = ln(XTI_middle) - ln(XNG_middle)
s3 = ln(XTI_oldest) - ln(XNG_oldest)
r_new = s1 - s2
r_old = s2 - s3

r_old > 0 and r_new < 0 and abs(r_new) < abs(r_old)
    => SELL XTI, BUY XNG
r_old < 0 and r_new > 0 and abs(r_new) < abs(r_old)
    => BUY XTI, SELL XNG
otherwise
    => FLAT
```

All endpoints are completed before the decision week. Equality is flat.

## Rules

### Entry

1. Evaluate only once on a new exact host D1 bar under EA 41360 and slot zero.
2. Repair malformed, orphaned, duplicated, same-side, stopless, notional-
   invalid, later-week, or stale owned exposure before entry-only gates.
3. Require exact host and companion timestamps. Prove the current bar is the
   first tradable bar carrying a new Monday anchor and reject attachment later
   than 180 elapsed minutes after raw host-bar open.
4. Persist the Monday-anchor attempt before history, signal, spread, quote,
   range, sizing, news, or order gates. Never retry that week.
5. In a 30-bar buffer select the newest synchronized positive finite close pair
   for each prior Monday anchor. Require exactly current anchor minus 7, 14,
   and 21 calendar days, newest first.
6. Require both relative returns finite and non-zero, strict opposite signs,
   and `abs(r_new)<abs(r_old)`. Same signs, equality, or a non-smaller newest
   move is flat.
7. Follow the newest return through opposed legs exactly as the formula specifies.
8. Require no owned exposure or current-week entry deal, executable quotes,
   and no genuinely positive spread wider than 1,500 XTI points or 3,000 XNG
   points. Modeled zero `.DWX` spread is valid.
9. Use completed-bar ATR(20,D1) and attach a frozen hard stop at 3.5 ATR to
   each leg. Combined normalized stop risk cannot exceed one fixed-risk budget.
10. Target one-to-one absolute entry notional, round down only, and reject a
    mismatch above 20 percent. Use no take-profit.
11. Submit both market legs once. If either fails or the resulting composition
    is invalid, immediately flatten all owned exposure. No retry or fallback.

### Exit

1. Broker hard stops and framework kill-switch closure remain authoritative.
2. Immediately flatten an orphan, duplicate, same-side, wrong-symbol, wrong-
   magic, missing-stop, invalid-volume, or notional-invalid package.
3. Close both legs on the first tick whose Monday anchor is later than the
   package-open anchor.
4. Close after ten elapsed calendar days as a final stale guard.
5. There is no target, signal-reversal, trailing, break-even, partial, or
   discretionary exit and no intentional hold beyond the next broker week.

### Filters And Management

- Exact host, D1, EA 41360, slot zero, and both registered magics.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1` for Q02.
- Both news axes and Friday close are OFF; repair is never delayed by an
  entry-only gate.
- All clocks, timestamps, prices, comparisons, quotes, spreads, range values,
  sizing, stops, and notional checks fail closed.
- Own exactly one XTI position and one opposite-side XNG position.
- Persist the attempted week anchor across restart and keep original stops.
- No external data, optimizer artifact, scale-in, pyramid, grid, or second
  entry is authorized.

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

## Source-Defined Rules

The sources supply a weak, time-varying oil/gas relationship and the governed
arithmetic lineage. They do not supply the energy-carrier partial-retracement continuation.

## QM Interpretations

The strategy identity fixes the endpoint construction, return count, strict
state, inverse sides, continuous-CFD clock, durable attempt, equal-target-
notional aggregate risk, spread caps, stops, and lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
closure precede entry. The companion magic is registered as an owned foreign
magic. No live execution override exists.

## Risk

- Backtest only: aggregate-package `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Each leg has a frozen 3.5 ATR hard stop; combined normalized stop risk is at
  most one package budget.
- Major risks are non-convergence, one-leg fills, lot-step mismatch, oil/gas
  beta drift, week-end gaps, continuous-CFD basis, financing, spread, density
  below the floor, source translation, and overlap with the XNG book.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Falsification And Requalification

Q02 retires rather than tunes on zero packages, fewer than five packages per
full post-warm-up year, nonpositive governed economics, wrong or asynchronous
endpoints, nonconsecutive anchors, current-week leakage, same signs, zero,
equality, non-smaller newest move, wrong side, duplicate attempt, one-leg
survivor, aggregate-risk breach, excessive mismatch, missing stop, wrong exit,
nondeterminism, or invalid fixed-risk mode.

Changing the carrier, endpoint count, horizon, sign or magnitude condition,
direction, attempt clock, risk, stops, or lifecycle requires a new identity and
full requalification. A failed result may not be rescued by a threshold,
fitted center, beta, calendar, trend, or volatility filter.

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
strict opposite-sign retracement directions; same-sign, zero, equality, and
non-smaller-newest flat states; no current-bar leakage; durable weekly attempts;
equal-notional rounding; aggregate-risk sizing; atomic package repair; next-
week exit; card lint; strict compile; setfile schema; basket manifest; resolver
identity; and static artifact validation.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-09-06 | initial completed-week XTI/XNG partial-retracement card | G0 | APPROVED |

## Safety Boundary

This card authorizes one branch-only non-live build, Q01 validation, one
logical D1 fixed-risk backtest setfile, and one paced Q02 enqueue only below
the CPU ceiling. It does not authorize a manual backtest, terminal control,
live/demo/shadow/stress preset, AutoTrading, `T_Live`, deployment, a live
manifest, portfolio-gate change, portfolio admission, decorrelation claim,
neutrality claim, or correlation waiver.
