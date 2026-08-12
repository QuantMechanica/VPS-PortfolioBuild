# QM5_20240 diverse-FX Q02 post-run pump repair

Date: 2026-08-06

Branch: `agents/board-advisor`

EA: `QM5_20240_usdchf-gbpjpy`

Farm claim: `d2edcf18-4294-4135-9b75-d93a4a05b8be`

## Selection

The approved-card build backlog had no higher-diversity, viable, genuinely
unbuilt card after excluding already built relationships, unavailable Darwinex
symbols, explicit duplicates, and weak/self-published source rows. This unit
therefore used mission priority 2.

`QM5_20240` is a non-duplicate low-frequency D1 USDCHF/GBPJPY fixed-beta
cointegration basket sourced from the OWNER-ratified Tier-A Ernest Chan pair
trading extraction. Its card records an exact relationship-level dedup across
the registries and basket manifests. It trades `USDCHF.DWX` and `GBPJPY.DWX`;
`USDJPY.DWX` is conversion-history-only. The backtest setfile remains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The atomic farm claim was taken only after confirming that no open agent task
or pending/active Q02 row referenced the EA. Pre-claim backup:
`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_20240_infra_claim_20260806T133013Z.sqlite`.

## Failure and authenticated orphan evidence

Source Q02 work item:
`bc0407aa-8e2e-408f-bf5e-2e641a706901`.

The T6 work-item log records a valid report, an exact logger capture,
`run_smoke.result=PASS`, and a durable summary before its final line,
`run_smoke.stage=post_run_pump_triggered`. The no-forward-progress reaper later
marked the row `failed / INFRA_FAIL / ACTIVE_TIMEOUT` and cleared its evidence
path even though the test wrapper had finished.

The farm's own identity-bound evidence verifier authenticated the orphaned
summary and derived Q02 `PASS`. Its bindings are:

| Artifact | SHA-256 |
| --- | --- |
| EX5 | `dbf718900fbfdd35558e87fce20415329e8438f9cb7e5d1395734a1d0d7457b0` |
| MQ5 | `14ae487325f04537625eab787361b12587f483f812357c941efca54908624aff` |
| fixed-risk setfile | `ff1801ce59cb15a2cb0b24fdfb350ddc4539dd456130720307913542a4cde641` |
| orphan summary | `b828dc25966c66820a4b3b4939289a656e0ddc004d667a624c71dff9401c1563` |

The summary also matches the bound expert, host symbol, D1 period, and
`2018-07-02` through `2022-12-31` window. It contains 130 trades and no OnInit,
history, log-bomb, or binary-stability failure.

Evidence:
`D:\QM\reports\work_items\bc0407aa-8e2e-408f-bf5e-2e641a706901\QM5_20240\20260806_103010\summary.json`.

## Root cause and repair

For factory work-item report roots, `run_smoke.ps1` spawned
`pythonw run_pump_task.py` after writing its final evidence. Because
`terminal_worker` launches the wrapper in a Windows `KILL_ON_JOB_CLOSE` job,
the pump became a descendant of that work item. The worker's process-tree
monitor therefore kept the otherwise completed item alive while the unrelated
pump ran; the stale-progress reaper could then overwrite the valid completion
as `ACTIVE_TIMEOUT`.

`run_smoke.ps1` now recognizes report roots at or beneath
`D:\QM\reports\work_items` and skips its post-run pump there. Factory workers
already own result classification and their next claim. Standalone smoke roots
retain the existing pump behavior, while DEV1, DEV2, and FACTORY_OFF isolation
remain unchanged.

A focused AST regression test verifies canonical, nested, case-insensitive,
adjacent-prefix, and normalized parent-traversal cases, and asserts that the
work-item guard remains before the pump spawn.

## Governed database handoff

The authenticated orphan summary was bound to the historical row with an
exact compare-and-swap plus transition-ledger and event receipts. Its
`failed / INFRA_FAIL` disposition and timeout payload were deliberately
preserved; no historical verdict was reconstructed or rewritten. Pre-binding
backup:
`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_20240_evidence_bind_20260806T133803Z.sqlite`.

Canonical `farmctl enqueue-backtest` then created exactly one append-only,
current-binary Q02 rerun:

- new work item: `24154a28-be35-469e-a5be-58881e29733c`;
- state at enqueue: `pending`, unclaimed;
- preserved source row: `bc0407aa-8e2e-408f-bf5e-2e641a706901`;
- one pending/active Q02 row for the EA after enqueue;
- database `PRAGMA quick_check`: `ok`.

At the capacity gate, six managed factory terminals were running, below the
paced operating ceiling of seven. The item was enqueued only; no dispatch
tick, smoke test, or MT5 process was launched by this repair.

## Verification and safety

- `Test-RunSmokeWorkItemPumpIsolation.ps1`: PASS.
- `Test-RunSmokeDev1Terminal.ps1`: PASS.
- `Test-Dev2LaneScaffold.ps1`: PASS.
- `Test-RunSmokeTerminalRunningGuard.ps1`: PASS.
- PowerShell parser validation is included in the focused regression test.
- `git diff --check`: PASS.

T_Live, AutoTrading, the portfolio gate, and the deploy manifest were not
changed. No EA mechanics, risk parameters, setfile, or compiled artifact was
modified.
