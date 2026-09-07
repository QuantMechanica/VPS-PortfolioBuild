# FX cointegration QM5_12507 Q02 hard CPU stop

Recorded: 2026-09-07T02:00:16.1380126Z (04:00 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `0e2049fb923bdc1a69aee7cdc36dd529b89583b6`

## Outcome

No new scan-derived pair was built. The durable sign-aware reconciliation of
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` already accounts for all
66 unordered relationships, so a new Card or EA would duplicate governed work.
The preferred anchors are not Q02-blocked: `QM5_12532` is past logical-basket
Q02 PASS and later failed Q05, while `QM5_12533` is past logical-basket Q02 PASS
and later failed Q04.

The selected existing-card fallback remains the concrete EURUSD/GBPUSD H1
relationship in `QM5_12507_pair-coint-z`. Its canonical logical Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` remains pending, unclaimed, attempt zero,
and without a verdict. It is the existing non-duplicate handoff; appending
another Q02 row would split its authenticated Q01 lineage.

## Binding CPU ceiling

Five one-second whole-host CPU samples were 87%, 94%, 88%, 99%, and 99%.
Average utilization was 93.4% and maximum utilization was 99%. The mission's
97% hard ceiling binds when either measure reaches it, so the maximum triggered
an immediate stop. Four factory metatesters were visible on T2, T3, T4, and T9;
factory terminals were visible on T2, T3, T4, T9, and T10. Free physical memory
was 40.062 GiB.

No compile, enqueue, priority mutation, claim, dispatch, tester launch, terminal
control, or backtest followed the capacity finding.

## PACER guard and fixed-risk contract

No `.mq5` source was generated or edited, so the required pre-compile pin audit
and its refusal branch were not entered. No enqueue-compile command was issued.
The previously sealed logical preset remains the governed handoff with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; its basket
manifest remains at
`framework/EAs/QM5_12507_pair-coint-z/basket_manifest.json`.

## Safety

No Strategy Card, EA source, registry, magic row, setfile, basket manifest,
farm row, pipeline verdict, portfolio-admission/KPI/Q08-contribution surface,
portfolio gate, `T_Live` manifest or terminal, live/deploy artifact, or
AutoTrading state was changed. Concurrent unrelated worktree changes were left
unstaged and untouched.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12507_q02_hard_cpu_stop_20260907T020016Z_board_advisor.json`.

## Resume contract

On the next paced wake, re-read the exact Q02 row and re-sample capacity. If the
row remains uniquely pending, unheld, and unclaimed, leave it to the governed
terminal-worker claim order when CPU and RAM admission clear. Never append a
duplicate Q02 row.
