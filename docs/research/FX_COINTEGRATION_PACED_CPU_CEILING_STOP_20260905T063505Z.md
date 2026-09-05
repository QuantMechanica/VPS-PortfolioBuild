# FX cointegration paced-fleet CPU ceiling stop

Recorded: 2026-09-05T06:35:05Z (08:35 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `47800e367c41f04e89d4ac05b081c0a4f82afd28`

## Outcome

The mission stopped at its explicit backtest CPU ceiling. Five one-second
whole-host samples were `70.130%`, `94.055%`, `100.000%`, `97.364%`, and
`79.895%`: average `88.289%`, maximum `100.000%`. The ceiling binds when
either the average or maximum reaches `97%`, so the maximum required an
immediate stop. No card, EA, registry, queue, priority, claim, terminal,
tester, or portfolio state was changed.

## Non-duplicate selection

The controlling scan remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its frozen 66-pair
frontier is already fully mechanized; the latest complete reconciliation found
123 approved cointegration identities, 123 matching EA directories, and no
approved-but-unbuilt identity. Minting another scan-derived card, basket
manifest, registry allocation, EA, or logical Q02 row would duplicate governed
coverage.

The preferred anchors remain beyond Q02:

- `QM5_12532` AUDUSD/NZDUSD has logical Q02 `PASS` (`e4890d77`), Q04
  `PASS`, then Q05 `FAIL` on the economic PF floor.
- `QM5_12533` EURJPY/GBPJPY has logical Q02 `PASS` (`76cb11ee`), then Q04
  `FAIL` on combined basket metrics.

Historical ONINIT and NO_HISTORY records do not supersede those later logical
basket PASS receipts, so neither anchor has a current Q02 setup defect.

## Existing forex continuation

The unique non-duplicate fallback remains `QM5_12778`, the structural D1
AUDUSD/EURJPY two-leg cointegration basket. Its canonical farm row was re-read
after the ceiling observation:

- work item `24acc5d4-3e34-526e-a7a8-12640a2e759f`;
- phase `Q09_NEWS`, pending, unclaimed, attempt 0, no verdict;
- `priority_track=true`, `q09_activation_state=RUNNABLE_BOUND`;
- `RISK_FIXED=1000`, `RISK_PERCENT=0`;
- sealed diagnostic window 2026-01-01 through 2026-04-06.

The row is already the governed continuation. Appending another row,
rewriting priority, or manually dispatching it would be duplicate or would
bypass the paced worker's ownership. At the final database read, eight work
items were active and a separate Q09 predecessor (`QM5_11179` on T6) still
occupied the downstream lane.

## Capacity and safety

Five factory terminals were observed on T1, T2, T3, T5, and T6, with eight
factory workers present. The separate FTMO and `T_Live` processes were
observed only and were not touched. The farm database passed `PRAGMA
quick_check`.

No portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate,
T_Live-manifest, live/deploy, terminal-control, or AutoTrading surface was
changed. Existing unrelated dirty-worktree changes were preserved.

On the next paced wake, re-read the exact QM5_12778 row and take a fresh CPU
window. Do not duplicate an open continuation. If it ends with infrastructure
taxonomy, preserve the terminal row and use only the canonical append-only
rerun path after a sub-ceiling preflight.

Machine-readable companion:
`artifacts/fx_cointegration_paced_cpu_ceiling_stop_20260905T063505Z_board_advisor.json`.
