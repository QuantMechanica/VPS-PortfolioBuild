# QM5_20009 ict-liquidity-portfolio — Strategy Spec

**EA ID:** QM5_20009  
**Status:** frozen research build contract v2  
**Full contract:** `docs/strategy_contract.md`

The binary exposes two mutually exclusive sleeves. Every chart attachment has one
symbol, one mode and one registered magic; signals and attempt budgets never blend.

| Mode | Locked markets | TF | Deterministic mechanism |
|---|---|---|---|
| `ICT_MODE_INDEX_MSS_FVG` | NDX.DWX; GDAXI.DWX transport | M1 | 09:30-10:00 NY opening range; 10-11 sweep/reclaim -> later MSS -> earliest FVG proximal-edge limit -> opposite OR boundary |
| `ICT_MODE_FX_WEEKLY_SWEEP` | EURUSD.DWX + GBPUSD.DWX | M5 | previous NY-week PWH/PWL sweep in London/NY session -> later MSS -> earliest FVG limit -> fixed preceding-session boundary |

Common execution is closed-bar and restart-reconstructed. The first chronological
eligible reclaim consumes the day/week; no later setup may rescue an incomplete or
failed attempt. There is no partial close, break-even or trailing stop in v1.

Model-4 real-tick tests use fixed risk, explicit costs and the preregistered center
plus 12 one-axis neighbors. Live mode is percent-risk only and fails closed without
the exact fresh portfolio-wide FTMO governor contract. Entry filters never suppress
position management, pending cancellation, hard flats or framework Friday close.

No performance is asserted here. Qualification requires the frozen DEV/OOS/2026-H1
partitions, plateau, duplicate, cost/slippage, cross-market, correlation/drawdown,
synchronized FTMO replay and unchanged V5 gates defined in the full contract.
