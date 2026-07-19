# QM5_20009_ict-liquidity-portfolio — Strategy Spec

**EA ID:** QM5_20009  
**Slug:** `ict-liquidity-portfolio`  
**Status:** frozen research build contract  
**Full contract:** `docs/strategy_contract.md`

## Strategy modes

The same binary exposes two deliberately separate modes. Each chart attachment has
one symbol, one mode, and one registered magic slot; signals are never blended
inside a single attachment.

| Mode | Primary | TF | Mechanism |
|---|---|---|---|
| `ICT_MODE_INDEX_MSS_FVG` | NDX.DWX | M5 | NY external-range sweep -> later MSS/displacement -> first post-MSS FVG limit -> opposite range liquidity |
| `ICT_MODE_FX_WEEKLY_SWEEP` | GBPUSD.DWX | H1 | Monday-range failed break -> next-bar fade -> opposite Monday liquidity / predeclared legacy target |

Transport symbols are GDAXI.DWX (index) and USDJPY.DWX (FX). XAUUSD.DWX remains an
exploratory registration, not a required profitability claim.

## Execution and risk

- Closed-bar signal computation; Model-4 real-tick order execution.
- One position and one pending order per symbol/magic.
- Fixed-risk backtests; percent-risk live mode only.
- Live mode requires the exact portfolio-wide FTMO governor contract and fresh
  heartbeat; missing/invalid state blocks entries.
- News and governor blocks apply to entries only. Position management, risk exits,
  day/week flat rules, and framework Friday close remain active.
- Framework risk cap, magic resolution, structured logging, equity stream, kill
  switch, and two-axis news filter remain mandatory.

## Evidence status

No performance is asserted by this specification. Qualification requires the frozen
partitions, real-tick/cost tests, walk-forward, stress, parameter neighbourhood,
transport checks, synchronized portfolio replay, and sealed 2026 holdout described
in `docs/strategy_contract.md`.

