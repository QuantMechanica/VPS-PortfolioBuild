# FX cointegration hard CPU-ceiling stop

Recorded: 2026-09-05T22:16:08.3947547Z (2026-09-06 00:16 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `aec1b657b649544e942c80372eea7d93024b1336`

## Outcome

The explicit backtest CPU ceiling bound, so no card, EA, registry, compile,
enqueue, priority, claim, dispatch, tester, terminal, or queue-payload mutation
was attempted. Five one-second whole-host samples were 97%, 100%, 100%, 99%,
and 100% (average 99.2%, maximum 100%) against the 97% hard ceiling.

The frozen 66-pair discovery remains exhausted under the durable sign-aware
frontier reconciliation. Creating a new scan-derived identity would duplicate
governed work. The two preferred anchors remain past Q02:

- `QM5_12532` has logical-basket Q02 PASS and later Q05 FAIL.
- `QM5_12533` has logical-basket Q02 PASS and later Q04 FAIL.

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` blocker.

## Preserved non-duplicate continuation

The bounded existing fallback remains `QM5_12507_pair-coint-z`, specifically
its EURUSD/GBPUSD H1 cointegration sleeve. Direct read-only inspection of the
canonical farm database confirmed that logical Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` remains pending, unclaimed, attempt
zero, priority-tracked, and without an active hold. It already has an
authenticated Q01 PASS with 632 observed leg trades.

Its sealed execution inputs remain structural and fixed-risk:

- logical symbol `QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1`;
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`;
- manifest `framework/EAs/QM5_12507_pair-coint-z/basket_manifest.json`;
- canonical logical setfile
  `framework/EAs/QM5_12507_pair-coint-z/sets/QM5_12507_pair-coint-z_QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1_H1_backtest.set`.

Appending another Q02 row would duplicate the governed continuation. Claiming
or launching the existing row while every sampled CPU reading meets or exceeds
the ceiling would violate the mission's resource stop. The ordinary paced
fleet retains ownership after capacity recovers.

## Capacity and safety

At the exact-row audit the farm had eight active and 13,015 pending work
items. The immediately preceding path-aware slot snapshot observed six factory
terminals (`T1`, `T2`, `T3`, `T4`, `T7`, and `T10`). Free physical memory was
33.445 GiB of 63.120 GiB. `T_Live` was observed only as an excluded process and
was not controlled.

No portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate,
T_Live-manifest, live/deploy, or AutoTrading surface was touched.

Machine-readable receipt:
`artifacts/fx_cointegration_cpu_ceiling_stop_20260905T221608Z_board_advisor.json`.

## Resume contract

On the next paced wake, re-read the exact Q02 row and re-sample capacity. If it
remains uniquely pending, unheld, and unclaimed and all admission ceilings
clear, leave it to the governed terminal-worker claim order. Never append a
duplicate Q02 row.
