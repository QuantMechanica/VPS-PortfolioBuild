# FX Cointegration Fleet Stop — CPU Ceiling

**Observed:** 2026-07-22T14:15:29+02:00

**Branch:** `agents/board-advisor`

## Outcome

No basket was built or enqueued and no MT5 process was launched. The paced
farm was already above the mission ceiling at inspection time:

- `8` `terminal64` processes were running.
- `9` work items were `active` and `3016` were `pending` in
  `D:/QM/strategy_farm/state/farm_state.sqlite`.
- The explicit CPU-ceiling stop rule therefore applies.

## De-duplication and frontier

- `QM5_12532` AUDUSD/NZDUSD is not Q02-blocked: canonical evidence already
  records Q02 PASS, Q04 PASS, and terminal Q05 strategy FAIL.
- `QM5_12533` EURJPY/GBPJPY is not Q02-blocked: repaired logical-basket Q02
  passed and the sleeve later reached a terminal Q04 strategy failure.
- The approved 66-pair scan cohort already has EA builds, so creating another
  card or EA from the same pair list would duplicate completed work.
- The first previously unadvanced approved sleeve, `QM5_12760`
  GBPUSD/GBPJPY, already has logical Q02 queue row `2` in
  `D:/QM/reports/pipeline/mt5_queue.db`. Its status remains `queued` with host
  symbol `GBPUSD.DWX`; no duplicate row was inserted.

## Safe resume condition

After active tester load drops below the authorized ceiling, allow the
existing `QM5_12760` logical-basket Q02 row to dispatch. Preserve its
`basket_manifest.json`, D1 low-frequency mechanics, and backtest risk contract
(`RISK_FIXED=1000`, `RISK_PERCENT=0`). Do not enqueue component-leg jobs.

## Safety boundary

No live terminal or AutoTrading state was changed. No deploy manifest,
portfolio-admission gate, portfolio KPI, Q08 contribution path, or portfolio
gate file was modified.
