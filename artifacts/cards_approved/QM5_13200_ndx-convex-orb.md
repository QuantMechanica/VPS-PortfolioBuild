---
strategy_id: CODEX-FTMO-CONVEX-ORB-20260711_S01
source_id: CODEX-FTMO-CONVEX-ORB-20260711
ea_id: QM5_13200
slug: ndx-convex-orb
status: REJECTED
g0_status: REVOKED
created: 2026-07-11
created_by: Codex
last_updated: 2026-07-11
source_citation: "Internal causal screen: artifacts/ftmo_convex_orb_screen_2026-07-11.json"
target_symbols: [NDX.DWX]
period: H1
logical_symbol: QM5_13200_NDX_CONVEX_ORB_H1
expected_trade_frequency: "Approximately 90-105 trades/year after the range-width and one-sided-trigger gates."
expected_trades_per_year_per_symbol: 95
expected_pf: 1.20
expected_dd_pct: 37.3
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
---

# QM5_13200 - NDX Convex Opening-Range Breakout

## Retirement

Retired on 2026-07-11 before portfolio admission. The source CSV stores MT5
broker-wall epoch values, but the original screen interpreted them as UTC.
Native 2024 Model 4 produced only 4 trades versus the research expectation of
roughly 100, exposing the session shift. The corrected screen is preserved as
`artifacts/ftmo_convex_orb_screen_broker_time_corrected_2026-07-11.json` and
selected a different GDAXI mechanic under `QM5_13201`.

## Source And Approval

The OWNER delegated all FTMO strategy, EA, and risk decisions to Codex on
2026-07-11. The strategy was selected by the sealed, causal screen in
`artifacts/ftmo_convex_orb_screen_2026-07-11.json`. The screen evaluated 312
predeclared configurations across four instruments. Selection used 2018-2022
development data and 2023 validation data; 2024-2025 remained sealed until the
family winner was locked. Dedup was clean before allocation.

`QM5_13200` is intentionally outside the concurrently allocated `1314x`
commodity sequence. It is an OWNER-delegated CEO+CTO FTMO allocation and has a
single active magic for `NDX.DWX` slot 0.

## Locked Mechanic

All session comparisons use `America/New_York` wall time derived from the
framework's DST-aware broker-to-UTC conversion. On every weekday:

1. Use the completed H1 bars beginning at 09:00 and 10:00 New York as the
   opening range.
2. Read simple `ATR(14)` on the completed 10:00 bar. Stay flat if data are
   missing, the range is nonpositive, or range width exceeds `1.75 * ATR`.
3. At 11:00 New York, place a buy stop at `range_high + 0.05 * ATR` and a sell
   stop at `range_low - 0.05 * ATR`.
4. Each order's hard stop is the opposite range boundary. Its take profit is
   exactly `8R` from the pending entry using that hard-stop distance.
5. The pending pair is OCO. Cancel the sibling immediately after one side
   fills. Cancel all unfilled orders at 12:00 New York; never re-enter that day.
6. Close any surviving position at 16:00 New York, after the H1 bar beginning
   at 15:00 has completed.

There is at most one position and one completed trade per New York date. No
overnight hold, add-on, trailing stop, break-even, partial close, grid,
martingale, pyramiding, PnL-adaptive rule, external feed, or ML is authorized.

## Research Contract

The Python screen charges four NDX points per round trip and resolves an H1 bar
that touches stop and target pessimistically at the stop. If both pending sides
are touched during the 11:00 trigger bar, the research screen skips the day
because H1 OHLC cannot identify first touch. Native MT5 instead follows its tick
sequence and the EA cancels the sibling after the first fill. This is a declared
parity risk, not permission to optimize the native implementation.

Locked screen evidence:

- Development 2018-2022: 398 trades, PF 1.198933, +58.153996R, maximum
  drawdown 37.293953R; 2018, 2021, and 2022 positive, 2019 negative.
- Validation 2023: 91 trades, PF 1.206555, +13.779086R.
- Sealed 2024-2025: 203 trades, PF 1.783863, +100.613651R, maximum drawdown
  14.091779R; both years positive.

These are research-survivor statistics, not a production claim. Native Model 4
must confirm timing, cost, execution, and density. The stale NDX symbol-matrix
failure remains an infrastructure disclosure and must not be rewritten as PASS
without the prescribed DST validation procedure.

## Runtime And Risk

- Host and traded symbol: `NDX.DWX`, H1, slot 0.
- Q02 backtest mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- News temporal and funded-account compliance filters are disabled for research
  parity. FTMO deployment eligibility is a separate post-pipeline decision.
- The generic broker-hour Friday close is disabled for research parity because
  broker 21:00 occurs before the locked 16:00 New York exit. The strategy's
  own daily close leaves no authorized weekend hold.
- Native H1 OHLC/ticks, ATR, broker time, pending-order state, positions, and
  trade transactions only.

## Boundary

Approval covers build and T1-T5 research/pipeline execution only. It does not
authorize `T_Live`, AutoTrading changes, a live setfile, a deploy manifest,
portfolio admission, or any paid-challenge deployment.
