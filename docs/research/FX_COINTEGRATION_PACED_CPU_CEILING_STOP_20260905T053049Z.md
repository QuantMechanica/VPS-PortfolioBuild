# FX cointegration paced-fleet CPU ceiling stop

Recorded: 2026-09-05T05:30:49Z (07:30 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `aeb5aa8bd2317437f27ce09710654bec2c2769aa`

## Outcome

The mission stopped at its explicit backtest CPU ceiling. Five one-second
whole-host samples were `93.27%`, `90.76%`, `99.71%`, `100.00%`, and
`100.00%`: average `96.748%`, maximum `100.00%`. The ceiling binds when either
the average or maximum reaches `97%`, so the maximum required an immediate
stop. No card, EA, registry, queue, priority, claim, terminal, tester, or
portfolio state was changed.

## Non-duplicate selection

The controlling scan remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its frozen 66-pair
frontier is already fully mechanized; the latest complete reconciliation found
123 approved cointegration identities, 123 matching EA directories, and no
approved-but-unbuilt identity. Minting another scan-derived card, basket
manifest, registry allocation, EA, or logical Q02 row would duplicate governed
coverage.

The preferred anchors remain beyond Q02:

- `QM5_12532` AUDUSD/NZDUSD has logical Q02 `PASS`, Q04 `PASS`, then Q05
  `FAIL` on the economic PF floor.
- `QM5_12533` EURJPY/GBPJPY has logical Q02 `PASS`, then Q04 `FAIL` on the
  combined basket metrics.

Historical ONINIT and NO_HISTORY records do not supersede those later
logical-basket PASS receipts, so neither anchor has a current Q02 setup defect.

## Existing forex continuation

The concrete fallback remains `QM5_12778`, the structural D1 AUDUSD/EURJPY
two-leg cointegration basket. Its exact governed continuation was re-read from
the canonical farm database after the ceiling observation:

- work item `24acc5d4-3e34-526e-a7a8-12640a2e759f`;
- phase `Q09_NEWS`, pending, unclaimed, attempt 0, no verdict;
- `priority_track=true`, `q09_activation_state=RUNNABLE_BOUND`;
- `RISK_FIXED=1000`, `RISK_PERCENT=0`;
- sealed diagnostic window 2026-01-01 through 2026-04-06;
- the former `OOS_WINDOW_MISMATCH` hold remains released.

This row is already the unique non-duplicate continuation. Appending another
row, rewriting its priority, or manually dispatching it would duplicate or
bypass the paced worker's ownership.

## Capacity and safety

Five factory terminals/testers were active on T2, T3, T4, T6, and T8, with all
ten factory workers present. The separate FTMO and `T_Live` processes were
observed only and were not touched. The farm database passed `PRAGMA
quick_check`.

No portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate,
T_Live-manifest, live/deploy, terminal-control, or AutoTrading surface was
changed. Existing unrelated dirty worktree changes were preserved.

On the next paced wake, re-read the exact QM5_12778 row and a fresh CPU window.
Do not duplicate an open continuation. If it ends with infrastructure taxonomy,
preserve the terminal row and use only the canonical append-only rerun path
after a sub-ceiling preflight.

Machine-readable companion:
`artifacts/fx_cointegration_paced_cpu_ceiling_stop_20260905T053049Z_board_advisor.json`.
