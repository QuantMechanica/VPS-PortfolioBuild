---
strategy_id: CODEX-FTMO-DAX-CONVEX-ORB-20260711_S01
source_id: CODEX-FTMO-DAX-CONVEX-ORB-20260711
ea_id: QM5_13201
slug: dax-convex-orb
status: REJECTED
g0_status: REVOKED
created: 2026-07-11
created_by: Codex
last_updated: 2026-07-11
source_citation: "Internal corrected causal screen: artifacts/ftmo_convex_orb_screen_broker_time_corrected_2026-07-11.json"
target_symbols: [GDAXI.DWX]
period: H1
logical_symbol: QM5_13201_DAX_CONVEX_ORB_H1
expected_trade_frequency: "Approximately 125-150 trades/year after the range-width and one-sided-trigger gates."
expected_trades_per_year_per_symbol: 140
expected_pf: 1.85
expected_dd_pct: 15.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
---

# QM5_13201 - DAX Convex Opening-Range Breakout

## Retirement

Retired on 2026-07-11 before portfolio admission. Native 2024 Model 4 produced
199 trades, PF 0.91, -12,375.17 USD, and 25,701.62 USD maximal equity drawdown,
versus the screen's 145 trades and PF 1.46. The 54-trade density gap matched
the H1 bars that touched both pending levels. The screen had skipped those
ambiguous days; executable OCO logic necessarily fills one side and generally
stops when the opposite boundary also trades. After correcting dual touches to
pessimistic losses, all 312 configurations failed the pre-holdout gate and no
holdout was opened. Corrected artifact:
`artifacts/ftmo_convex_orb_screen_broker_time_dual_touch_corrected_2026-07-11.json`.

## Source And Approval

The OWNER delegated FTMO strategy, EA, and risk decisions to Codex on
2026-07-11. After a broker-wall/UTC defect invalidated the first screen, the
entire 312-configuration experiment was rerun from the raw `T_Export` files
with Darwinex GMT+2/+3 broker time converted to real UTC before local-session
mapping. Selection again used only 2018-2022 development and 2023 validation;
2024-2025 remained sealed until each family winner was locked.

The corrected artifact selected this GDAXI configuration as the only family
winner that passed its sealed holdout gate. Dedup was clean. `QM5_13201` and
magic `132010000` are OWNER-delegated CEO+CTO FTMO allocations.

## Locked Mechanic

All session comparisons use `Europe/Berlin` wall time derived from the
framework's broker-to-UTC conversion and the EU DST calendar rule. On every
weekday:

1. Use the completed GDAXI H1 bar beginning at 08:00 Berlin as the opening
   range.
2. Compute the simple 14-bar average of true range on that completed bar. Stay
   flat if data are missing, the range is nonpositive, or range width exceeds
   `1.75 * ATR`.
3. At 09:00 Berlin, place a buy stop at `range_high + 0.05 * ATR` and a sell
   stop at `range_low - 0.05 * ATR`.
4. Each hard stop is the opposite 08:00 range boundary. Take profit is exactly
   `5R` from the pending entry and hard-stop distance.
5. The pending pair is OCO. Cancel the sibling immediately after one side
   fills. Cancel both unfilled orders at 10:00 Berlin; never re-enter that day.
6. Close any surviving position at 18:00 Berlin, after the H1 bar beginning at
   17:00 has completed.

There is at most one position and one completed trade per Berlin date. No
overnight hold, add-on, trailing stop, break-even, partial close, grid,
martingale, pyramiding, PnL adaptation, external feed, or ML is authorized.

## Selection Evidence

The Python screen charges three GDAXI points per round trip and resolves an H1
bar touching stop and target pessimistically at the stop. When both pending
sides touch in the 09:00 trigger bar, it skips the ambiguous day. Native MT5
uses its tick sequence and cancels the sibling after the first fill; that is a
declared parity risk to be adjudicated by Model 4.

- Development 2018-2022: 690 trades, PF 1.913818, +338.321941R, maximum
  drawdown 14.513947R; every calendar year positive.
- Validation 2023: 128 trades, PF 1.909669, +69.219165R, maximum drawdown
  8.826665R.
- Sealed 2024-2025: 283 trades, PF 1.850558, +130.777103R, maximum drawdown
  8.179676R; both years positive.

The result is a research-survivor claim only. Native Model 4 must confirm
timing, execution, costs, trade count, and floating MAE before book admission.

## Runtime And Risk

- Host and traded symbol: `GDAXI.DWX`, H1, slot 0.
- Q02 mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- News filters are disabled for research parity; FTMO deployment compliance is
  a separate post-pipeline decision.
- Generic broker-hour Friday close is disabled because the strategy owns a
  DST-correct 18:00 Berlin daily exit and authorizes no weekend hold.
- Native ticks/OHLC, simple true range, broker time, pending orders, positions,
  and trade transactions only.

## Boundary

Approval covers build and T1-T5 research/pipeline execution only. It does not
authorize `T_Live`, AutoTrading changes, a live setfile, deploy manifest,
portfolio admission, or paid-challenge deployment.
