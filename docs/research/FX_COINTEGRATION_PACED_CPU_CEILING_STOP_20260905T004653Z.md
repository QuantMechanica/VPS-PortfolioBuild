# FX cointegration paced-fleet CPU ceiling stop

Recorded: 2026-09-05T00:46:53Z (02:46 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `30943808142035e99159f01fd8be94752070d55e`

## Outcome

The mission stopped at its explicit backtest CPU ceiling. A five-sample
whole-host window peaked at 99.513% against the 97% stop threshold. No card,
EA, registry row, queue row, priority field, worker claim, compile, dispatch,
or tester run was created after that observation.

The stop is non-duplicate. The strict 66-pair research frontier remains fully
mechanized according to the latest durable complete relationship census, both
preferred anchors are already past Q02, and the selected existing-card
fallback already has one unique runnable priority-bound continuation.

## Frontier and anchor preflight

The controlling research remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its strict v3 study
tested all 66 unordered relationships and qualified only EURJPY/GBPJPY and
AUDUSD/NZDUSD. The later complete reconciliation found all 66 relationships
represented and zero approved-but-unbuilt identities, so minting another
scan-derived card or EA would duplicate governed work.

Current canonical anchor receipts in
`D:/QM/strategy_farm/state/farm_state.sqlite` are:

| EA | Relationship | Logical Q02 | Downstream terminal path |
| --- | --- | --- | --- |
| `QM5_12532` | AUDUSD / NZDUSD | `e4890d77`, done / PASS | Q04 PASS, then Q05 FAIL |
| `QM5_12533` | EURJPY / GBPJPY | `76cb11ee`, done / PASS | Q04 FAIL |

Historical ONINIT and NO_HISTORY rows do not supersede these later logical
basket PASS receipts. Neither anchor has a current Q02 setup blocker.

## Existing-card fallback

The selected concrete continuation remains `QM5_12778`, the structural D1
AUDUSD/EURJPY two-leg cointegration basket. It uses a fixed-beta log spread,
closed-bar z-score rules, and fixed-risk backtest configuration; no ML or
banned indicator is involved.

Its exact `Q09_NEWS` work item
`24acc5d4-3e34-526e-a7a8-12640a2e759f` was read directly from the live farm
database after the CPU observation:

- pending, unclaimed, attempt 0, verdict unset;
- `priority_track=true` and `q09_activation_state=RUNNABLE_BOUND`;
- `RISK_FIXED=1000` and `RISK_PERCENT=0`;
- one sealed 2026-01-01 through 2026-04-06 diagnostic window.

That row is already the non-duplicate governed continuation. Enqueuing another
row or rewriting its priority would add no evidence, so neither occurred.

## Binding capacity stop

The five one-second CPU samples were 99.513%, 83.303%, 72.110%, 80.090%, and
88.773% (average 84.758%, maximum 99.513%). The ceiling binds when either the
average or maximum reaches 97%; the maximum therefore required an immediate
stop.

The read-only slot snapshot showed all ten factory workers present, seven
factory terminals running, no duplicate workers, and no orphaned terminal
processes. Scheduled paced workers retain claim and dispatch ownership.

## Safety and resume contract

No portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate,
T_Live-manifest, live/deploy, terminal-control, or AutoTrading surface was
touched. Existing unrelated dirty worktree changes were preserved.

On a later paced wake, re-read the exact QM5_12778 row before acting. If it is
still pending, do not duplicate it; let the scheduled worker claim it. If it
has ended with an infrastructure taxonomy, preserve the terminal row and use
only the canonical append-only rerun path after a fresh sub-ceiling resource
preflight.

Machine-readable companion:
`artifacts/fx_cointegration_paced_cpu_ceiling_stop_20260905T004653Z_board_advisor.json`.

Open company context remains in `docs/ops/OPEN_ITEMS_STATUS.md`.
