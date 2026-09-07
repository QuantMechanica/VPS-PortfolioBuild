# FX cointegration QM5_12507 Q02 hard CPU stop

Recorded: 2026-09-07T10:51:06.7174845Z (12:51 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `bad066aa4d9670ec715b9bbb7635e132d2c1dcb2`

## Outcome

No new scan-derived pair was built. The durable sign-aware reconciliation of
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` already accounts for all
66 unordered relationships, so another Card or EA would duplicate governed
work. The preferred anchors remain beyond Q02: `QM5_12532` reached logical
basket Q02 PASS and later failed Q05, while `QM5_12533` reached logical-basket
Q02 PASS and later failed Q04.

The mission-authorized existing-card fallback remains the concrete
`EURUSD.DWX` / `GBPUSD.DWX` H1 relationship in `QM5_12507_pair-coint-z`. A
read-only state-database reread found its canonical logical Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` pending, unclaimed, unheld, attempt zero,
without a verdict, and already `priority_track=true`. It remains the sole open
row for that exact EA, phase, and logical-symbol identity. No duplicate Q02 row
was appended.

## Binding CPU ceiling

Five one-second whole-host CPU samples were `99.609397%`, `97.374088%`,
`81.261608%`, `88.751474%`, and `94.946576%`. Average utilization was
`92.388629%` and maximum utilization was `99.609397%`. The paced admission rule
requires both measures to remain strictly below `97%`, so the maximum dimension
bound and the mission's explicit CPU stop rule applied.

Free physical memory was 25.034 GiB of 63.120 GiB. The farm concurrently held
nine active work items and seven running factory terminals (`T1`, `T2`, `T4`,
`T5`, `T6`, `T7`, and `T8`), equal to the seven-terminal process ceiling.

No compile, enqueue, priority mutation, claim, dispatch, tester launch,
terminal control, or backtest followed the capacity finding.

## PACER guard and fixed-risk contract

No `.mq5` source was generated or edited, so the required post-write,
pre-compile framework-input pin audit and its refusal branch were not entered.
No enqueue-compile command was issued. The existing authenticated logical
preset remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Its basket manifest continues to declare all four symbols
that the two-pair implementation warms before evaluating the active FX pair.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12507_q02_hard_cpu_stop_20260907T105106Z_board_advisor.json`.

## Safety

No Strategy Card, EA source or binary, registry, magic row, setfile, basket
manifest, farm row, pipeline verdict, portfolio-admission/KPI/Q08-contribution
surface, portfolio gate, `T_Live` manifest or terminal, live/deploy artifact,
or AutoTrading state was changed. Concurrent unrelated shared-worktree changes
were left unstaged and untouched.

## Resume contract

On the next paced wake, reread this exact Q02 row and resample capacity. If the
row remains uniquely pending, unheld, and unclaimed, leave it to the governed
terminal-worker claim order when both CPU admission and terminal capacity
clear. Never append a duplicate Q02 row.
