# QM5_20009 ict-liquidity-portfolio — Strategy Spec

**EA ID:** QM5_20009  
**Status:** frozen research build contract v5
**Full contract:** `docs/strategy_contract.md`

The binary exposes two mutually exclusive sleeves. Every chart attachment has one
symbol, one mode and one registered magic; signals and attempt budgets never blend.

| Mode | Locked markets | TF | Deterministic mechanism |
|---|---|---|---|
| `ICT_MODE_INDEX_MSS_FVG` | NDX.DWX; GDAXI.DWX transport | M1 | 09:30-10:00 NY opening range; 10-11 sweep/reclaim -> later MSS -> earliest FVG virtual proximal-edge trigger -> opposite OR boundary |
| `ICT_MODE_FX_SESSION_SWEEP` | EURUSD.DWX + GBPUSD.DWX | M5 | completed Asian-range boundary sweep/reclaim in London 02:00-05:00 NY -> later MSS -> earliest FVG virtual trigger -> opposite Asian boundary |

Common execution is closed-bar and restart-reconstructed. The first chronological
eligible reclaim consumes the NY day; no later setup may rescue an incomplete or
failed attempt. There is no partial close, break-even or trailing stop in v1.

Model-4 real-tick tests use fixed risk, explicit costs and the preregistered center
plus 12 one-axis neighbors. Live mode is percent-risk only and fails closed without
the exact fresh portfolio-wide FTMO governor contract. Entry filters never suppress
position management, virtual-intent cancellation, hard flats or framework Friday
close. The EA never leaves a strategy pending order at the broker: an intent is
voided at the first session/news/governor violation and becomes a market request
only on a freshly revalidated Bid/Ask touch.

Arm-time checks never apply server-pending distance rules. At touch, entry/RR uses
Ask for buys and Bid for sells, while broker stop constraints use Bid for buys and
Ask for sells. The intent is consumed before an explicit one-shot send; no Requote
or Price-Off retry is permitted. Lots are capped with `OrderCalcMargin` for the
actual market side and price.

No performance is asserted here. Qualification requires the frozen DEV/OOS/2026-H1
partitions, plateau, duplicate, cost/slippage, cross-market, correlation/drawdown,
synchronized FTMO replay and unchanged V5 gates defined in the full contract.
