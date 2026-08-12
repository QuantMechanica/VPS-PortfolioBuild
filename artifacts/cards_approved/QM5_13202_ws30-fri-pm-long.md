---
strategy_id: CODEX-FTMO-WS30-FRI-PM-20260711_S01
source_id: CODEX-FTMO-M15-SESSION-PREMIUM-20260711
ea_id: QM5_13202
slug: ws30-fri-pm-long
status: APPROVED
g0_status: APPROVED
created: 2026-07-11
created_by: Codex
last_updated: 2026-07-11
source_citation: "Internal sealed screen: artifacts/ftmo_m15_session_premium_screen_2026-07-11.json"
target_symbols: [WS30.DWX]
period: M15
logical_symbol: QM5_13202_WS30_FRI_PM_LONG_M15
expected_trade_frequency: "Approximately one trade each Friday, 48-51 trades/year."
expected_trades_per_year_per_symbol: 49
expected_pf: 1.20
expected_dd_pct: 13.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
---

# QM5_13202 - WS30 Friday Afternoon Long

## Source And Approval

The OWNER delegated FTMO strategy, EA, and risk decisions to Codex on
2026-07-11. The strategy is the sole sealed survivor from 2,880 fixed-session
configurations across GDAXI, NDX, SP500, WS30, and XAUUSD. Source timestamps
were converted from Darwinex GMT+2/+3 broker wall time to UTC and then to the
exchange-local zone before screening. Selection used 2018-2022 development and
2023 validation only; 2024-2025 was sealed until one winner per family was
locked. Dedup was clean before allocation.

## Locked Mechanic

On each Friday, using DST-correct `America/New_York` time:

1. At the first tick of the M15 bar beginning 13:30 New York, buy `WS30.DWX` at
   market.
2. Compute the simple average of true range over the 56 completed M15 bars
   ending at shift 1.
3. Attach a hard stop exactly `1.0 * ATR56` below the actual entry. There is no
   take profit.
4. Close at 16:00 New York. If a position survives into a later New York date,
   flatten immediately.
5. Never re-enter on the same New York date, including after restart or stop.

No short, overnight hold, add-on, trailing stop, break-even, partial close,
grid, martingale, pyramiding, PnL adaptation, external feed, or ML is allowed.

## Sealed Evidence

The Python M15 screen charges four WS30 points per round trip and resolves any
same-bar stop/exit ambiguity at the stop.

- Development 2018-2022: 222 trades, PF 1.251949, +40.773065R, maximum
  drawdown 12.225346R; all five calendar years positive.
- Validation 2023: 49 trades, PF 1.442239, +14.276020R.
- Sealed 2024-2025: 98 trades, PF 1.132820, +9.271309R; 2024 PF 1.060239 and
  2025 PF 1.220218.

The edge is timing-fragile: post-selection diagnostic neighbors at 13:00 and
14:00 New York failed, while a wider `2 * ATR` stop remained positive before
holdout but did not pass the sealed period. Native M15 Model 4 must therefore
match timing and density closely; any material PF, trade-count, or DST drift is
a kill, not a tuning invitation.

## Runtime And Risk

- Host/traded symbol: `WS30.DWX`, M15, slot 0, magic `132020000`.
- Q02: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- News filters disabled for research parity. Deployment compliance is separate.
- Generic broker-hour Friday close disabled because it would fire around 14:00
  New York, before the locked 16:00 strategy exit.

## Boundary

Approval covers build and T1-T5 research/pipeline execution only. It does not
authorize `T_Live`, AutoTrading changes, a live setfile, deploy manifest,
portfolio admission, or paid-challenge deployment.
