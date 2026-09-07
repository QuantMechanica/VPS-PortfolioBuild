# FX cointegration QM5_12507 Q02 hard CPU stop

Recorded: 2026-09-07T15:32:32.1194351Z (17:32 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `c06143c612bfc6e1105dbf8cfaedb48f87fca167`

## Outcome

No new scan-derived pair was built. The controlling cross-ledger guard still
shows that all 66 unordered relationships in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` are represented, so a
new Card or EA would duplicate governed work. The preferred anchors remain
beyond Q02: `QM5_12532` has logical-basket Q02 PASS followed by Q05 FAIL, and
`QM5_12533` has logical-basket Q02 PASS followed by Q04 FAIL.

The mission-authorized existing-card fallback remains the concrete
`EURUSD.DWX` / `GBPUSD.DWX` H1 relationship in `QM5_12507_pair-coint-z`. A
fresh canonical state-database read found its logical Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` pending, unclaimed, unheld, attempt
zero, without a verdict, and already `priority_track=true`. It remains the
single open row for this exact EA, phase, and logical-symbol identity. No
duplicate Q02 row was appended or reprioritized.

## Binding CPU ceiling

Five one-second whole-host CPU samples were `98.536053%`, `92.305575%`,
`96.293822%`, `98.438140%`, and `95.121818%`. Average utilization was
`96.139082%` and maximum utilization was `98.536053%`. Paced admission requires
both measures to remain strictly below `97%`, so the maximum dimension bound
and the mission's explicit CPU stop rule applied.

Free physical memory was 30.238 GiB of 63.120 GiB. The farm concurrently held
eight active work items and seven running factory terminals (`T2`, `T3`, `T4`,
`T5`, `T8`, `T9`, and `T10`), equal to the seven-terminal process ceiling. Ten
terminal workers were present, with no duplicates or orphaned tester processes.

No compile, enqueue, priority mutation, claim, dispatch, tester launch,
terminal control, or backtest followed the capacity finding.

## PACER guard and fixed-risk contract

No `.mq5` source was generated or edited, so the required post-write,
pre-compile framework-input pin audit and its refusal branch were not entered.
No enqueue-compile command was issued. The authenticated logical preset remains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; the existing
basket manifest continues to declare every symbol warmed by the implementation.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12507_q02_hard_cpu_stop_20260907T153232Z_board_advisor.json`.

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
