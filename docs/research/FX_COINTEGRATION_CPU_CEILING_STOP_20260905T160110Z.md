# FX cointegration hard CPU ceiling stop

Recorded: 2026-09-05T16:01:10.428Z (18:01 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `8cbdceabc5a4b9fee97e18c777d034bc89eac260`

## Outcome

The explicit backtest CPU ceiling bound, so no tester, compile, dispatch,
enqueue, priority, or queue-payload mutation was attempted. Five one-second
whole-host samples were 100.000%, 99.715%, 98.537%, 98.830%, and 99.708%
(average 99.358%, maximum 100.000%) against the 97% hard ceiling.

The frozen 66-pair discovery remains exhausted. Its only two published strict
positive-hedge survivors are already built. `QM5_12532` has logical-basket Q02
PASS receipt `e4890d77-b865-4a48-b946-315faefca920` and later Q05 FAIL;
`QM5_12533` has logical-basket Q02 PASS receipt
`76cb11ee-7e9d-4d75-be9d-626c205bca62` and later Q04 FAIL. Neither anchor has
a current Q02 `ONINIT` or `NO_HISTORY` blocker to repair.

## Non-duplicate fallback retained

The existing structural EURUSD/GBPUSD H1 cointegration basket `QM5_12507`
remains the correct bounded fallback. Its sole logical Q02 row
`547c4fd3-f3fd-4c59-b9dc-654e96521251` is pending, unclaimed, attempt zero,
already priority-tracked, and has no active hold. The authenticated predecessor
Q01 receipt passed with 632 observed leg trades.

The row remains basket-manifest-bound and fixed-risk:

- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`;
- logical symbol `QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1`;
- manifest `framework/EAs/QM5_12507_pair-coint-z/basket_manifest.json`;
- canonical logical setfile
  `framework/EAs/QM5_12507_pair-coint-z/sets/QM5_12507_pair-coint-z_QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1_H1_backtest.set`.

Appending another Q02 row would be a duplicate. Directly claiming or launching
the existing row while the host exceeds the ceiling would violate the mission's
resource stop. The paced fleet retains ownership and may claim the existing row
only after capacity clears.

No portfolio-admission, portfolio KPI, Q08 contribution, portfolio gate,
T_Live manifest, live file, deploy, or AutoTrading surface was touched.

Machine-readable receipt:
`artifacts/fx_cointegration_cpu_ceiling_stop_20260905T160110Z_board_advisor.json`.
