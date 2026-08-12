# FX Cointegration Funnel Triage — CPU Ceiling

**Date:** 2026-07-21  
**Branch:** `agents/board-advisor`  
**Mission:** grow the certified V5 book with a non-duplicate market-neutral FX
cointegration sleeve.

## Outcome

No Q02 work item was enqueued and no MT5 process was launched. The paced farm
was already above the mission ceiling at inspection time: `9` work items were
`active` and `3304` were `pending` in
`D:/QM/strategy_farm/state/farm_state.sqlite`. The repository also had
`D:/QM/strategy_farm/state/FACTORY_OFF.flag` present. The mission's explicit
CPU-ceiling stop rule therefore applies.

This is a de-duplicated stop, not an empty candidate search:

- `QM5_12532` AUDUSD/NZDUSD has a logical-basket Q02 `PASS`, Q04 `PASS`, and a
  terminal Q05 strategy `FAIL` (`PF 0.950 < 1.0`). Its historical component-leg
  `NO_HISTORY` rows are retired and do not justify another Q02.
- `QM5_12533` EURJPY/GBPJPY has a repaired logical-basket Q02 `PASS` and later
  terminal strategy evidence. Its old component-leg ONINIT/history failures
  are superseded.
- The strict all-sign extension of the OWNER-requested 66-pair scan is already
  exhausted through `QM5_13119` USDJPY/EURAUD. That final strict row is built,
  passed repaired Q02 and Q03, and failed Q04 (2024 net PF `0.872`).
- `QM5_13106` AUDUSD/EURGBP is also not an advancement candidate: canonical
  work item `78e5573f-9b83-42fc-8cbc-04125c4e42f1` passed Q02, canonical Q03
  passed, and Q04 work item `a33683ca-ddff-4291-93c7-df149fb5a324` failed
  (`F1 net PF 0.974`, `F2 net PF 1.551`). A later Q02 `INFRA_FAIL` row is stale
  relative to that completed funnel and must not be requeued.

## Next Safe Action

After the farm drops below its authorized ceiling and `FACTORY_OFF.flag` is
cleared by its owner, select an approved FX basket whose latest canonical gate
is genuinely pending. Do not resurrect a superseded Q02 row or re-run any of
the terminal strategy failures above. Preserve logical-basket dispatch through
the EA's `basket_manifest.json`, D1 low-frequency mechanics, and
`RISK_FIXED=1000` / `RISK_PERCENT=0` backtest risk.

## Safety Boundary

No `T_Live`, AutoTrading, deploy manifest, portfolio-admission gate,
portfolio KPI, Q08 contribution path, or portfolio gate file was read or
modified during this triage.
