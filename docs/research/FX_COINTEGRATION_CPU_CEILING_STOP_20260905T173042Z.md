# FX cointegration paced CPU-ceiling stop

Recorded: 2026-09-05T17:30:42.761Z (19:30 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `c65450df1f52c75e485037d26e654c127ebf60d4`

## Outcome

The explicit backtest CPU ceiling bound, so no tester, compile, dispatch,
claim, enqueue, priority, or queue-payload mutation was attempted. Five
one-second whole-host samples were 90.341%, 89.365%, 91.602%, 94.346%, and
99.322% (average 92.995%, maximum 99.322%) against the 97% hard ceiling.
The queue snapshot had nine active work items; the follow-up exact-row audit
had seven. Free physical memory was 21.369 GiB of 63.120 GiB.

The frozen 66-pair discovery remains exhausted. Its only two published strict
positive-hedge survivors are already built. `QM5_12532` has logical-basket Q02
PASS receipt `e4890d77-b865-4a48-b946-315faefca920` and later Q05 FAIL;
`QM5_12533` has logical-basket Q02 PASS receipt
`76cb11ee-7e9d-4d75-be9d-626c205bca62` and later Q04 FAIL. Neither anchor has
a current Q02 `ONINIT` or `NO_HISTORY` blocker to repair.

## Non-duplicate continuation preserved

The existing structural EURUSD/GBPUSD H1 cointegration basket `QM5_12507`
remains the bounded fallback. Direct SQLite inspection confirmed its one
logical Q02 row `547c4fd3-f3fd-4c59-b9dc-654e96521251` remains pending,
unclaimed, attempt zero, priority-tracked, and without a hold. Exactly one
pending-or-active row exists for the EA, phase, and logical symbol. The
authenticated predecessor Q01 passed with 632 observed leg trades.

The preserved row remains basket-manifest-bound and fixed-risk:

- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`;
- logical symbol `QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1`;
- manifest `framework/EAs/QM5_12507_pair-coint-z/basket_manifest.json`;
- canonical logical setfile
  `framework/EAs/QM5_12507_pair-coint-z/sets/QM5_12507_pair-coint-z_QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1_H1_backtest.set`.

Appending another Q02 row would duplicate the governed continuation. Claiming
or launching the existing row while a sampled CPU value exceeds the ceiling
would violate the mission's resource stop. The ordinary paced fleet retains
ownership and may claim it through canonical ordering only after all admission
ceilings clear.

No portfolio-admission, portfolio KPI, Q08 contribution, portfolio gate,
T_Live manifest, live file, deploy, or AutoTrading surface was touched.

Machine-readable receipt:
`artifacts/fx_cointegration_cpu_ceiling_stop_20260905T173042Z_board_advisor.json`.
