# Scheduled-task hygiene and factory-hours panel — 2026-09-02

Task: `246d5d1f-49b8-490b-b005-f1534ffc3e8d`

Authority: CEO mandate in `docs/ops/CEO_AUDIT_2026-09-02.md`. No scheduled task
was manually started, no terminal was launched, and no `T_Live` or sealed-gate
state was changed.

## Applied scheduled-task changes

The idempotent plan/apply/rollback tool
`tools/strategy_farm/apply_scheduled_task_hygiene_20260902.ps1` exported all 18
affected definitions before applying changes. Runtime receipt:
`D:\QM\reports\state\scheduled_task_hygiene_20260902.json` (SHA-256
`d390464b9cc34d2138ee874e2fd90db01dd06f457b9f863c30d345a45b579639`).
The 18 rollback XML files are in
`D:\QM\reports\state\scheduled_task_hygiene_20260902_before_20260902T103441Z`.

Five recurring tasks that had reached `267014` were given bounded limits suited
to their measured workload:

| Task | Before | After |
|---|---:|---:|
| `QM_StrategyFarm_PumpMaintenance_Hourly` | PT30M | PT2H |
| `QM_StrategyFarm_Dashboard_Hourly` | PT30M | PT1H |
| `QM_StrategyFarm_HourlyMonitor_60min` | PT30M | PT1H |
| `QM_StrategyFarm_UnbuiltCardsDisposition_Hourly` | PT10M | PT1H |
| `QM_StrategyFarm_ContinuousRetention_45min` | PT40M | PT2H |

Thirteen completed July/August one-offs were unregistered after export:
the three `QM_Balke_*` tasks, two `QM_QM10834_AUDIT_*` tasks,
`QM_QM13210_XAU_AUDIT_*`, `QM_QM20002_G2_AUDIT_*`,
`QM_TMP_SpawnWorkers_Once`, `QM_NDX_Convert`, `QM_Q08_Neighborhood`,
`QM_Rebuild_Wave`, `QM_FTMO_Round26_Prep_Sunday`, and
`QM_PreSunday_Prep_Saturday`. Readback found all 13 absent and all five new
limits exact.

Rollback command (OWNER/Claude interactive lane only):

```powershell
& C:\QM\repo\tools\strategy_farm\apply_scheduled_task_hygiene_20260902.ps1 `
  -Rollback `
  -BackupDir D:\QM\reports\state\scheduled_task_hygiene_20260902_before_20260902T103441Z
```

## Exit-code repairs

`run_public_snapshot_task.ps1` logged `rc=` while the incident guard returned
`valid=True`, no holds, and no error. The bounded child helper now completes the
parameterless `WaitForExit()`, refreshes the process, and captures a typed exit
code after redirected streams drain. This removes the PowerShell/.NET null-exit
race that incorrectly compared unequal to zero.

`QM_EvidenceCohortWatch_Daily_0420` exit 3 is not an execution defect. It is the
watcher's documented `LOSS_OBSERVED` result: on 2026-09-02 it found 642 missing
files among 1,205 baselined rows. The meta-monitor now preserves this as an
explicit hard evidence-loss finding instead of a generic nonzero warning. It is
deliberately not masked or translated to success.

## Rolling factory-hours panel

The existing read-only concurrency/throughput measurement now emits explicit
available, used, and `idle_or_unattributed` lost slot-hours. The hourly monitor
refreshes a rolling seven-day CSV and Markdown panel before its broader health
query and raises `FACTORY_UTILIZATION_LOW` below 55%.

First measured window (2026-08-26 10:36Z through 2026-09-02 10:36Z):

- available: 1,680.000 slot-hours;
- used: 914.088 terminal-hours;
- lost/idle-or-unattributed: 765.912 slot-hours;
- utilization: 54.41%, therefore the `<55%` alarm is active;
- 5,297 execution verdicts and 2,795 measurement cells.

Runtime panel:
`D:\QM\reports\state\factory_hours\factory_hours_rolling_7d.md` and `.csv`.
CPU-pause log coverage was incomplete, so that submetric is explicitly a lower
bound; slot-hour accounting comes from the farm database.

Verification: 54 focused tests passed across concurrency telemetry, scheduled
failure adjudication, public-snapshot incident guarding, mutation locking, and
factory quiescence. Both changed PowerShell scripts parsed with zero errors.
