---
card_schema_version: 2
type: strategy
strategy_id: SUENAGA-MEHLITZ-XNG-VRWIN-2026_S01
variant_id: SUENAGA-MEHLITZ-XNG-VRWIN-2026_S01
source_id: SUENAGA-MEHLITZ-XNG-VRWIN-2026
ea_id: QM5_20248
slug: xng-vr-window
status: APPROVED
execution_contract_status: DRAFT
created: 2026-08-06
created_by: Research+Development
last_updated: 2026-08-06
g0_status: APPROVED
source_authors: "Hiroaki Suenaga; Aaron Smith; Jeffrey C. Williams; Julia S. Mehlitz; Benjamin R. Auer"
source_citation: "Suenaga, Smith, and Williams (2008), Journal of Futures Markets 28(5), 438-463, DOI 10.1002/fut.20317; Mehlitz and Auer (2024), The European Journal of Finance 30(8), 773-802, DOI 10.1080/1351847X.2023.2220118."
strategy_mechanic: monthly-xng-latest-return-direction-conditioned-by-q2-robust-variance-ratio-memory-inside-physical-volatility-windows
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
symbol_slot: 0
magic: 202480000
period: D1
timeframe: D1
expected_trades_per_year_per_symbol: 6
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: PENDING
review_focus: "Falsify a monthly bidirectional XNG physical-window/memory stream structurally unlike QM5_12567's two-day long-only oscillator."
---

# QM5_20248 XNG Variance-Ratio Physical Window

## Hypothesis

During the two source-defined natural-gas physical-volatility windows, follow
the latest completed monthly XNG return only when a statistically significant
robust short-memory state is persistent, and reverse it when that state is
anti-persistent. Off-window and insignificant states remain flat.

This is structurally unlike the certified `QM5_12567` two-day cumulative-RSI
long-only pullback. Profitability, density, diversification, and correlation
remain pipeline questions.

## Source And Claim Boundary

The governed packet is
`strategy-seeds/sources/SUENAGA-MEHLITZ-XNG-VRWIN-2026/source.md`.

- Suenaga, Smith, and Williams (2008), *Journal of Futures Markets* 28(5),
  438-463, DOI `10.1002/fut.20317`, supply natural-gas physical-volatility
  timing, translated to May-September and November-January broker months.
- Mehlitz and Auer (2024), *The European Journal of Finance* 30(8), 773-802,
  DOI `10.1080/1351847X.2023.2220118`, supply the 32-month `q=2` robust
  variance-ratio state, fixed two-sided 10% boundary, latest-return direction,
  and persistence-follow / anti-persistence-reverse matrix.

Neither paper tests this conjunction or the continuous CFD. Fixed risk, full
broker-month timing, ATR stop, spread cap, and lifecycle controls are QM
adaptations. No source performance or portfolio statistic transfers.

## Non-Duplicate Boundary

The pre-allocation checker scanned 4,305 registry rows and 422 cards. It found
no exact collision and surfaced only `QM5_20242_xng-rsm-window`, which uses a
twelve-month binary-sign share and fixed threshold without a variance-ratio
test or anti-persistent reversal. The other nearest boundaries are the
year-round WTI memory carrier `QM5_13134`, XNG 126-D1 seasonal trend
`QM5_20052`, year-round XNG sign momentum `QM5_13116`, and the incumbent
oscillator `QM5_12567`. Verdict:
`CLEAN_AFTER_DETERMINISTIC_AND_MANUAL_REVIEW`.

## Formula

At the first D1 bar of an eligible broker month, derive thirty-two
chronological log returns `r_0 ... r_31` from thirty-three consecutive
completed month-end closes:

```text
mean       = average(r_0 ... r_31)
S          = sum((r_i - mean)^2), i=0...31
rho_1      = sum((r_i - mean)(r_i-1 - mean), i=1...31) / S
VR(2)      = 1 + rho_1
robust_se  = sqrt(sum((r_i - mean)^2(r_i-1 - mean)^2, i=1...31) / S^2)
z          = (VR(2) - 1) / robust_se
base_dir   = sign(r_31)
trade_dir  = base_dir * sign(z)
```

`trade_dir` is actionable only in months
`{5,6,7,8,9,11,12,1}`, with nonzero `base_dir`, and when
`abs(z) > 1.64485362695147`.

## Rules

1. Require exact EA `20248`, `XNGUSD.DWX` D1, magic slot 0, and every
   declared baseline input at its locked value.
2. Process lifecycle exits before entry-only gates and evaluate entry only at
   a genuine broker-month transition.
3. Close prior-month, off-window, or forty-day-stale owned exposure.
4. In an eligible month, persist its key before history, signal, spread, quote,
   news, sizing, stop, or order gates; never retry that month.
5. Require thirty-three consecutive completed month endpoints, newest in the
   immediately prior broker month.
6. Compute the robust `q=2` state exactly. Significant persistence follows
   the latest return; significant anti-persistence reverses it.
7. Require spread in `[0,1500]` points, a valid quote, completed
   `ATR(20,D1)`, valid stop geometry, and framework fixed-risk sizing.
8. Open at most one market position with a frozen `3.0 * ATR(20,D1)` hard
   stop, no target, and no scale-in.
9. Friday close and both news axes are OFF for this monthly native-price
   baseline.
10. No intramonth reversal, target, trail, break-even, partial close, grid,
    martingale, pyramid, external runtime input, adaptive fit, or randomness.

## Parameters To Test

| parameter | default | authorized values |
|---|---:|---|
| `strategy_vr_window_months` | 32 | [32] |
| `strategy_vr_q` | 2 | [2] |
| `strategy_significance_z` | 1.64485362695147 | [1.64485362695147] |
| `strategy_summer_start_month` | 5 | [5] |
| `strategy_summer_end_month` | 9 | [9] |
| `strategy_winter_start_month` | 11 | [11] |
| `strategy_winter_end_month` | 1 | [1] |
| `strategy_history_bars` | 1200 | [1200] |
| `strategy_atr_period` | 20 | [20] |
| `strategy_atr_sl_mult` | 3.0 | [3.0] |
| `strategy_max_hold_days` | 40 | [40] |
| `strategy_max_spread_points` | 1500 | [1500] |

## Risk

Backtests use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. XNG gaps, weather, financing, roll behavior, the
futures-to-CFD basis, sparse memory significance, coarse full-month windows,
and a second XNG carrier can invalidate the thesis. Expected density is only
5-7 completed packages/year after warm-up.

## Kill Criteria

Retire below five completed packages per full post-warm-up year, on
nonpositive governed economics, or on later portfolio-correlation rejection.
Fail on off-window entry, nonconsecutive endpoints, wrong statistic,
significance boundary, direction mapping, repeated monthly attempts, hold
beyond forty days, missing stop, invalid risk mode, or nondeterminism. Do not
rescue failure by changing the window, horizon, threshold, months, direction,
carrier, stop, hold, spread cap, or retry policy.

## Framework Alignment

- no_trade: exact host/timeframe/ID/slot, locked inputs, news/Friday contract,
  physical-window and parameter guards.
- trade_entry: persisted monthly attempt, endpoint reconstruction, robust
  statistic, direction matrix, spread/quote/ATR/stop checks, and one order.
- trade_management: prior-month, off-window, and stale exits before entry.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This execution contract authorizes research, build, strict compile, and one
paced non-live Q02 handoff only. It excludes manual backtests; live, demo,
shadow, optimization, or stress setfiles; AutoTrading; `T_Live`; deploy or
T_Live manifests; portfolio admission; portfolio-gate edits; and correlation
waivers.

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-06 | APPROVED | `decisions/2026-08-06_qm5_20248_xng_vr_window_g0.md` |
| Q01 Build Validation | 2026-08-06 | PASS | strict compile `framework/build/compile/20260806_111821/QM5_20248_xng-vr-window.compile.log`; build check `D:/QM/reports/framework/21/build_check_20260806_111926.json` |
| Q02 Baseline Screening | 2026-08-06 | PENDING | work item `178a7b59-3bb7-49e7-9c28-36b7841be600`; `docs/ops/evidence/2026-08-06_qm5_20248_xng_vr_window_q02_enqueue.md` |
