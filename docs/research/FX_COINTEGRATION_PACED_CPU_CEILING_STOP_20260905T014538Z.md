# FX cointegration paced-fleet CPU ceiling stop

Recorded: 2026-09-05T01:45:38Z (03:45 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `a1de8557fcf2bee15d0f293eed047f2a8bf0cbe6`

## Outcome

The mission stopped at its explicit backtest CPU ceiling. Five one-second
whole-host samples were `100.000%`, `100.000%`, `99.320%`, `96.096%`, and
`95.227%`: average `98.129%`, maximum `100.000%`. Both the average and maximum
exceeded the `97%` stop threshold. No build, compile, queue mutation, priority
rewrite, worker claim, terminal dispatch, or backtest was attempted after the
observation.

## Non-duplicate frontier decision

The controlling 66-pair scan remains fully mechanized. The latest complete
reconciliation records 123 approved cointegration identities and 123 matching
EA directories, with no approved-but-unbuilt identity. Creating another Card,
EA, basket manifest, registry allocation, or logical Q02 row would duplicate
governed coverage.

The two preferred anchors have terminal receipts beyond Q02:

- `QM5_12532` AUDUSD/NZDUSD: logical Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533` EURJPY/GBPJPY: logical Q02 PASS, then Q04 FAIL.

Historical ONINIT and NO_HISTORY rows do not supersede those later logical
basket PASS receipts, so neither anchor needs a Q02 setup repair.

## Existing-card resume point

The selected existing FX continuation remains `QM5_12778`, the structural D1
AUDUSD/EURJPY two-leg cointegration basket. Its exact `Q09_NEWS` item was read
from the live farm database after the ceiling observation:

- item `24acc5d4-3e34-526e-a7a8-12640a2e759f`;
- pending, unclaimed, attempt 0, verdict unset;
- `priority_track=true`, `q09_activation_state=RUNNABLE_BOUND`;
- `RISK_FIXED=1000`, `RISK_PERCENT=0`;
- sealed diagnostic window 2026-01-01 through 2026-04-06.

This is already the unique governed continuation. Appending another row or
rewriting its priority would be duplicate work. Scheduled paced workers retain
claim and dispatch ownership.

## Safety and resume contract

No portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate,
T_Live manifest/file, live/deploy, terminal-control, or AutoTrading surface was
touched. Existing unrelated dirty worktree changes were preserved.

On the next paced wake, re-read the exact QM5_12778 row and resource ceiling.
If the row is still pending, do not duplicate it. If it ends with an
infrastructure taxonomy, preserve the terminal row and use only the canonical
append-only rerun path after a fresh sub-ceiling preflight.

Machine-readable companion:
`artifacts/fx_cointegration_paced_cpu_ceiling_stop_20260905T014538Z_board_advisor.json`.

Open company context remains in `docs/ops/OPEN_ITEMS_STATUS.md`.
