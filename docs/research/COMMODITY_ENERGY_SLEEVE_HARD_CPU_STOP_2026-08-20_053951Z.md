# Commodity/energy sleeve — candidate preflight and hard CPU stop

Date: 2026-08-20

Branch: `agents/board-advisor`

Status: stopped before card approval, allocation, build, or Q02 enqueue because
the explicit backtest CPU ceiling is binding

## Concrete candidate retained for a later capacity window

The preflight selected one prospective second-XNG mechanic:
`MISHRA-SMYTH-XNG-1W-2016_S03`, working slug `xng-1w-sign-contr`.
It would evaluate the source-defined fixed one-week frequency as a standalone
`XNGUSD.DWX` D1 time-series sign contrarian: after an exact completed broker
week, take the opposite sign for the next fixed week, renew at the next valid
week boundary, use fixed cash risk and a server-side hard stop, and preserve
the standard Friday-flat lifecycle.

The durable source packet is
`strategy-seeds/sources/MISHRA-SMYTH-XNG-PRED-2016/source.md`. It records a
complete 36-page author-manuscript review of Mishra and Smyth (2016), *Are
Natural Gas Spot and Futures Prices Predictable?*, *Economic Modelling* 54,
178-186, DOI `10.1016/j.econmod.2015.12.034`, including the exact trading-rule
locations and the paper's tested-frequency boundary.

The deterministic source router classified a fresh DOI request as
`PERMISSION_REQUIRED`, lead status `DEFERRED:SOURCE_POLICY`, adapter `generic`,
state `ROUTER_ONLY`. No proxy, mirror, cookie, CAPTCHA, or alternate retrieval
was attempted. The existing approved repository packet therefore remains the
bounded source of record.

## Manual family boundary (not a formal dedup verdict)

- `QM5_12567_cum-rsi2-commodity` is a long-only two-day cumulative-RSI
  pullback aligned to a slow trend, not a symmetric weekly sign fade.
- `QM5_13102_xng-1w-rev-vol` admits only thresholded high-volatility five-D1
  shocks and uses a normalization exit; the candidate is unconditional and
  fixed-horizon.
- `QM5_21504_xng-flowrev` admits only high tick-volume weeks; the candidate
  has no volume state.
- `QM5_1132_qp-futures-weekly-reversal` selects cross-sectional winners and
  losers from 37 markets after a volume rank; it is not a standalone XNG
  time-series package.
- `QM5_20054_xng-1m-contr` and `QM5_20013_xng-2m-contr` use fixed monthly and
  bimonthly endpoints, not exact completed-week renewal.

This is a promising non-duplicate boundary, not approval. The canonical dedup
checker and full G0 review were deliberately not run after the CPU stop fired.

## Binding stop condition

Five two-second whole-host CPU samples were `99.80%`, `96.29%`, `99.90%`,
`100.00%`, and `99.95%`. Average CPU was `99.19%` and maximum CPU was
`100.00%`, above the explicit `97%` ceiling.

A path-anchored process scan found active factory terminals at T2, T3, T6,
and T10. `T_Live` was explicitly excluded and was neither inspected beyond
process-path exclusion nor controlled.

Per the mission stop condition, there was no card approval, EA-ID or magic
allocation, resolver regeneration, build, compile, tester run, Q02 enqueue,
dispatch tick, requeue, priority mutation, terminal reservation, or terminal
control. No portfolio gate, T_Live manifest, T_Live file, or AutoTrading state
was touched.

Machine-readable evidence is in
`artifacts/commodity_energy_sleeve_hard_cpu_stop_20260820T053951Z_board_advisor.json`.
