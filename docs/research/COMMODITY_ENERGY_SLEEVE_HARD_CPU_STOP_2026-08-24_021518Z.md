# Commodity/energy sleeve — candidate retained and hard CPU stop

Date: 2026-08-24

Branch: `agents/board-advisor`

Base commit: `10dec7d2be2ffe78d3e045a3f95ef1a40bc21e82`

Status: stopped before card approval, allocation, build, compile, or Q02
enqueue because the explicit backtest CPU ceiling is binding

## Concrete unbuilt candidate retained

The bounded candidate is `MISHRA-SMYTH-XNG-1W-2016_S03`, working slug
`xng-1w-sign-contr`: a standalone `XNGUSD.DWX` D1 fixed-week sign
contrarian. After each exact completed broker week, it would take the opposite
direction for the next fixed week, renew only at the next valid week boundary,
use fixed cash risk plus a server-side hard stop, and preserve the standard
Friday-flat lifecycle.

The durable source packet is
`strategy-seeds/sources/MISHRA-SMYTH-XNG-PRED-2016/source.md`. It records a
complete review of Mishra and Smyth (2016), *Are Natural Gas Spot and Futures
Prices Predictable?*, *Economic Modelling* 54, 178–186, DOI
`10.1016/j.econmod.2015.12.034`. The paper tests fixed frequencies from one day
through four months. A one-week extraction would remain a single-source,
mechanical, DWX-testable, deterministic and ML-free hypothesis under R1–R4.
It is only a prospect here: the CPU stop fired before a new source addendum,
card, formal G0 decision, deterministic allocation, or build.

A fresh EA-path search found no source or binary for either the strategy ID or
working slug. The closest existing XNG systems remain mechanically distinct:

- `QM5_12567_cum-rsi2-commodity` is a long-only two-day cumulative-RSI
  pullback aligned to a slow trend, not a symmetric fixed-week sign fade.
- `QM5_13102_xng-1w-rev-vol` admits only thresholded high-volatility five-D1
  shocks and exits on normalization; this candidate is unconditional and
  fixed-horizon.
- `QM5_21504_xng-flowrev` admits only high tick-volume weeks; this candidate
  has no volume state.
- `QM5_20054_xng-1m-contr` and `QM5_20013_xng-2m-contr` use monthly and
  bimonthly endpoints rather than exact completed-week renewal.

This is a manual non-duplicate boundary, not the formal canonical dedup
verdict. The formal check was deliberately not run after the binding stop.

## Binding capacity evidence

Five fresh one-second whole-host samples at `2026-08-24T02:15:18Z` were
`99.330575%`, `100.000000%`, `100.000000%`, `98.342907%`, and
`94.540092%`. Their average was `98.442715%` and their maximum was
`100.000000%`. The fleet rule stops when either value is at least the explicit
`97%` hard ceiling, so the mission stopped.

A path-anchored process inventory at `2026-08-24T02:16:59Z` found governed
factory terminals `T2`, `T6`, and `T10`. `T_Live` was excluded by requiring an
exact `D:\QM\mt5\T<n>\terminal64.exe` path and was not controlled.

No source/card mutation, EA-ID or magic allocation, resolver regeneration,
EA build, compile, tester/backtest run, Q02 enqueue, dispatch tick, queue
priority change, terminal reservation, portfolio-gate change, live-manifest
change, or AutoTrading action occurred. Existing unrelated worktree changes
were preserved.

Machine-readable evidence is in
`artifacts/commodity_energy_sleeve_hard_cpu_stop_20260824T021518Z_board_advisor.json`.
