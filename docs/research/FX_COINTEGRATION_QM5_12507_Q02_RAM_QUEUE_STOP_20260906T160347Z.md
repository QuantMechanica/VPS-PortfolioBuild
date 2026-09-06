# FX cointegration QM5_12507 Q02 RAM/queue stop

Recorded: 2026-09-06T16:03:47.8862469Z (18:03 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `eca677c1219c0d12febc074f540bf7fc1e480348`

## Outcome

No new scan-derived pair was built. The frozen sign-aware 66-pair FX scan is
already fully represented, and its preferred anchors need no Q02 repair:
`QM5_12532` has logical-basket Q02/Q04 PASS followed by Q05 FAIL, while
`QM5_12533` has logical-basket Q02 PASS followed by Q04 FAIL.

The mission-authorized existing-card fallback remains the concrete
`EURUSD.DWX` / `GBPUSD.DWX` H1 relationship in `QM5_12507_pair-coint-z`. Its
canonical logical Q02 item `547c4fd3-f3fd-4c59-b9dc-654e96521251` remains the
only open row for that exact identity: pending, unclaimed, unheld, attempt zero,
without a verdict, and already `priority_track=true`. Appending another Q02 row
would duplicate runnable work and split the authenticated Q01 lineage.

## Binding capacity and queue state

Five one-second whole-host CPU samples were 82.130517%, 81.563889%,
89.270304%, 89.843770%, and 96.982098%. Their average was 87.958116% and their
maximum was 96.982098%, so the mission's 97% CPU ceiling did not bind.

Free physical memory was only 22.118 GiB of 63.120 GiB. The authenticated Q02
payload declares four warmed symbols, which keeps the row in the 44 GiB
heavy/unknown multisymbol reservation class. Normal admission therefore needs
44 GiB plus the 14 GiB post-reservation floor, or 58 GiB available. Seven farm
work items were active at the state reread. The governed drain tracker still
names older priority basket `QM5_10718`, so `QM5_12507` may neither bypass that
row nor force a terminal claim.

The apparent two-leg shortcut is not valid: the approved EA also supports the
NDX/WS30 pair and `Strategy_EnsureBasketScope()` explicitly selects and warms
all four declared symbols. Shrinking only `basket_manifest.json` or its Q02
payload would misstate the binary's history and memory scope. A pair-selective
binary would require reviewed source work plus fresh Q01 lineage; this wake did
not change strategy mechanics or forge that lineage.

## PACER guard and integrity

The existing source was reread with the binding command:

`python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5`

It returned `ok=true`, predicate `EA_FRAMEWORK_INPUT_PINNED`, and zero findings.
`validate_symbol_scope.py --ea QM5_12507_pair-coint-z` returned `BASKET_OK` with
all four warmed symbols declared. The logical backtest setfile remains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

No MQ5 source was generated or edited, so there was no compile enqueue. Had the
pin audit returned nonzero or emitted any `EA_FRAMEWORK_INPUT_PINNED` finding,
the build would have been refused exactly as required.

## Safety and continuation

No EA, Strategy Card, registry, setfile, basket manifest, queue row, priority,
hold, claim, terminal, tester, verdict, portfolio-admission/KPI/Q08-contribution
surface, portfolio gate, `T_Live` manifest or terminal, live/deploy artifact, or
AutoTrading state was changed. Concurrent unrelated worktree changes were left
unstaged and untouched.

Let the existing priority Q02 row advance through the resident worker's
canonical order after the active fleet drains and the older `QM5_10718` drain
claim resolves. Do not append, reprioritize, or manually dispatch a duplicate.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12507_q02_ram_queue_stop_20260906T160347Z_board_advisor.json`.
