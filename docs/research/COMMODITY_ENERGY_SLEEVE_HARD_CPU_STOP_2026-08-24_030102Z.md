# Commodity/energy sleeve - retained XNG candidate and hard CPU stop

Date: 2026-08-24

Branch: `agents/board-advisor`

Base commit: `dcffee2427aadbd82f0b749b112692b11d5e6caa`

Status: stopped before source addendum, card approval, allocation, build,
compile, or Q02 enqueue because the explicit backtest CPU ceiling is binding

## Concrete unbuilt candidate retained

The selected candidate is `MISHRA-SMYTH-XNG-1W-2016_S03`, working slug
`xng-1w-sign-contr`: a standalone `XNGUSD.DWX` D1 fixed-complete-week sign
contrarian. After each completed broker week, the strategy would take the
opposite direction for the next fixed week, renew only at the next valid week
boundary, use fixed cash risk plus a server-side hard stop, and preserve the
standard Friday-flat lifecycle. It is deterministic, low-frequency, structural,
and uses no ML or banned indicator.

The reputable bounded source packet is
`strategy-seeds/sources/MISHRA-SMYTH-XNG-PRED-2016/source.md`. It records a
complete review of Mishra and Smyth (2016), *Are Natural Gas Spot and Futures
Prices Predictable?*, *Economic Modelling* 54, 178-186, DOI
`10.1016/j.econmod.2015.12.034`. The paper tests fixed frequencies from one day
through four months. A one-week extraction would remain a single-source,
mechanical and DWX-testable hypothesis under R1-R4.

The manual non-duplicate boundary is concrete:

- `QM5_12567_cum-rsi2-commodity` is a long-only two-day cumulative-RSI
  pullback aligned to a slow trend, not a symmetric fixed-week sign fade.
- `QM5_13102_xng-1w-rev-vol` requires a thresholded high-volatility five-D1
  shock and exits on normalization; this candidate is unconditional and
  fixed-horizon.
- `QM5_21504_xng-flowrev` conditions on high tick volume; this candidate has no
  volume state.
- `QM5_20054_xng-1m-contr` and `QM5_20013_xng-2m-contr` use monthly and
  bimonthly endpoints rather than exact completed-week renewal.

The formal canonical dedup check was not run after the binding stop, so this is
a retained candidate rather than a card or approval claim.

## Binding capacity evidence

Five fresh one-second whole-host samples at `2026-08-24T03:01:02Z` were all
`100.0%`. Both their average and maximum were `100.0%`, above the explicit
`97.0%` ceiling.

A path-anchored process inventory found governed factory terminals `T1`, `T2`,
`T3`, `T4`, `T8`, and `T10`. `T_Live` was excluded by requiring an exact
`D:\QM\mt5\T<n>\terminal64.exe` path and was not accessed or controlled.

Per the mission stop condition, no source/card mutation, EA-ID or magic
allocation, resolver regeneration, EA build, compile, tester/backtest run, Q02
enqueue, dispatch tick, terminal reservation, portfolio-gate change,
live-manifest change, or AutoTrading action occurred. Existing unrelated
worktree changes were preserved.

Machine-readable evidence is
`artifacts/commodity_energy_sleeve_hard_cpu_stop_20260824T030102Z_board_advisor.json`.
