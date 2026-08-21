# QM5_41097_balke-gmt3-range-breakout-opt - Strategy Spec

**EA ID:** QM5_41097  
**Slug:** `balke-gmt3-range-breakout-opt`  
**Strategy ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`  
**Parent:** `QM5_21501_balke-gmt3-range-breakout-ppcensus`  
**Decision:** DL-089  
**Last revised:** 2026-08-21

## 0. Scope

This is the DL-089 optimization instrument for the A1-fixed Balke GMT+3 range
breakout. It is a research-only executable subject and is not authorized for a
book, T_Live, or AutoTrading. Phase 1 changes only the pattern-permission
profile; the underlying strategy mechanics remain those of QM5_21501.

## 1. Strategy Logic

The EA builds the completed 03:00-06:00 GMT+3 H1 range, places a buy stop at the
range high and a sell stop at the range low, applies the existing ATR range
band, trails after +1R, and resolves at 18:00 GMT+3. Signal construction remains
side-effect free: plan, permission, decision, then placement. The day is marked
complete only after a valid decision permits at least one leg.

The six phase-1 inputs build one closed-D1-bar permission profile:

| Input | Default | Meaning |
|---|---:|---|
| `opt_pp_buy1..3` | 0 | Up to three implemented predicate IDs gating buys. |
| `opt_pp_sell1..3` | 0 | Up to three implemented predicate IDs gating sells. |

Zero leaves a slot empty. A negative or unimplemented predicate makes `OnInit`
fail closed with `PP_CENSUS_CONFIG_INVALID`. Six zeros form the baseline.

## 2. Parameters

The DL-089 stage-S5 numeric optimization uses the parent's **already-wired**
strategy inputs — it introduces no new numeric knobs. There are deliberately no
inert placeholder inputs: an input with no mechanical use site would violate the
wired-input rule (QM5_1355) and could not carry an S5 trial. The S5 levers, their
parent (control) values, and candidate ladders are defined in
`opt_param_grid.json` (schema `qm.opt-param-grid.v1`):

| S5 lever (wired input) | Parent / control | Candidate ladder | Mechanical role |
|---|---:|---|---|
| `strategy_max_range_atr_mult` | 2.5 | 1.5, 2.0, 2.5, 3.0, 3.5 | Upper edge of the ATR range-admission band and the hard SL cap. |
| `strategy_trail_trigger_r` | 1.0 | 0.5, 0.75, 1.0, 1.25, 1.5 | Profit in R before the two-bar swing trail starts. |
| `strategy_range_end_hour` | 6 | 5, 6, 7, 8 | First GMT+3 hour after the range; sets range width and the order-placement hour. |

There is no take-profit lever: the parent has no TP mechanic and `req.tp` is
fixed at `0.0`. In the pattern-only pilot these inputs stay at their parent
defaults; S5 varies exactly one of them per trial with the parent value as the
mandatory control cell (DL-088 `AI_PARAM`).

## 3. Symbol Universe

`USDJPY.DWX` only. The instrument is scoped to the FTMO + DarwinexZero
research target.

## 4. Timeframe

H1 execution with a D1 closed-bar pattern reference (`shift=1`). This is a
swing/scalping-horizon strategy and is not HFT.

## 5. Expected Behaviour

The six-zero baseline must preserve QM5_21501 behavior. A populated profile may
only suppress planned entry legs; it cannot create an entry. Invalid pattern
state fails closed. In the pattern-only pilot the S5 numeric levers stay at
their parent defaults, so the build reproduces the parent mechanics exactly.

## 6. Source Citation

No new external trading source is introduced. Mechanics derive from QM5_21501,
which derives from QM5_13213 and René Balke's GMT+3 Range Breakout. Pattern
definitions come from `QM_PatternPermission.mqh`. Governing documents are
`PATTERN_FILTER_WF_OPT_PLAN_V3_2026-08-21.md` and DL-089.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, mandatory DXZ news blackout,
and `qm_news_stale_max_hours=336`. News freshness remains fail closed. The EA
contains no martingale, grid, or ML logic. Standard framework daily and total
drawdown controls remain authoritative (targets: <=5% daily and <=10% total).

## 8. Optimization Contract

The annual census covers 2019-2025. Each year contains one six-zero baseline,
77 single-predicate buy arms, and 77 single-predicate sell arms: 155 cells per
year and exactly 1,085 cells overall. Census generation is forbidden until the
DL-089 fixture gate is PASS. Results are research evidence only; pipeline
verdicts require pipeline evidence.

## 9. Telemetry

The EA emits `PP_CENSUS_INIT`, `PP_CENSUS_BLOCK`, and `PP_CENSUS_SUMMARY` using
the complete profile key. Summary counters record evaluated days, firing days,
suppressed legs, and invalid-permission days.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-21 | DL-089 optimization instrument with six pattern inputs and inert phase-2 placeholders. |
