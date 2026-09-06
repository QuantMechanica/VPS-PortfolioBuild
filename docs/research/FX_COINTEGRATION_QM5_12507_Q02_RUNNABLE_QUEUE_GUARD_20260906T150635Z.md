# FX cointegration QM5_12507 Q02 runnable queue guard

Recorded: 2026-09-06T15:06:35.3552312Z (17:06 Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

No new pair was built because the durable sign-aware reconciliation already
accounts for every relationship in the frozen 66-pair FX scan. The two published
survivors also need no Q02 repair: `QM5_12532` has Q02/Q04 PASS followed by Q05
FAIL, and `QM5_12533` has Q02 PASS followed by Q04 FAIL. A new scan-derived
identity would weaken the published selection criterion or duplicate governed
coverage.

The mission-authorized existing-card fallback therefore remains
`QM5_12507_pair-coint-z`, specifically its EURUSD/GBPUSD H1 logical basket. Its
canonical Q02 item `547c4fd3-f3fd-4c59-b9dc-654e96521251` was reread as the sole
open row for that exact identity: pending, unclaimed, unheld, attempt zero, no
verdict, and already `priority_track=true`.

No second Q02 row was appended. That would not advance the sleeve; it would
duplicate an already-runnable work item and split its evidence lineage.

## Runnable-state evidence

Five one-second whole-host CPU samples were 85.369316%, 85.294529%,
85.354753%, 83.105659%, and 86.046253%. Their average was 85.034102% and their
maximum was 86.046253%, so every sample was strictly below the mission's 97%
hard stop. Free physical memory was 27.18 GiB of 63.12 GiB.

The canonical top-down selector placed the target 151st among 7,973 eligible
pending rows. This is queue-order latency rather than a hold, duplicate, or CPU
ceiling: priority downstream gates drain before a priority Q02 row. The row is
already in the governed worker claim path and should retain its original age and
identity.

The bound backtest setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The EA's basket manifest declares all four symbols the
two-pair implementation warms, and `validate_symbol_scope.py` returned
`BASKET_OK`.

The framework-input pin audit returned `ok=true` with zero
`EA_FRAMEWORK_INPUT_PINNED` findings. No MQ5 was generated or edited in this
wake, and no compile was enqueued. A diagnostic ad-hoc build check correctly
refused while factory terminal processes were alive
(`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`); no retry occurred. The legacy approved
Card remains under its existing G0 approval; current schema lint reports its old
section layout as compatibility debt, so this wake did not rewrite or reapprove
the Card.

## Evidence and safety

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_12507_q02_runnable_queue_guard_20260906T150635Z_board_advisor.json`.

No EA, Strategy Card, registry, setfile, basket manifest, queue row, verdict,
portfolio-admission/KPI/Q08-contribution surface, T_Live manifest or terminal,
live/deploy artifact, or AutoTrading state was changed. Concurrent unrelated
worktree changes were left unstaged and untouched.

## Next deterministic step

Let the existing priority Q02 row be claimed through the canonical terminal
worker order. On a later paced wake, reread this exact row; append no successor
unless the row first reaches a terminal infrastructure verdict and the governed
append-only rerun contract applies.
