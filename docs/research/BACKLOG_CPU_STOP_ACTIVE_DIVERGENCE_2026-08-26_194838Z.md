# Build-backlog CPU stop: active/process divergence

Date: 2026-08-26 UTC (`2026-08-26T19:48:38Z`)

Branch: `agents/board-advisor`

Observation base: `914112133233b7366708e24ffc23d7b01905f2ec`

Status: stopped before backlog ranking, claiming, build, smoke, or Q02 enqueue
because the explicit tester CPU ceiling is binding

## Binding capacity result

Five fresh one-second whole-host CPU readings were `99.5164%`, `99.7294%`,
`99.6164%`, `96.7816%`, and `97.3045%`. Their average was `98.5897%` and their
maximum was `99.7294%`, above the farm worker's `CPU_MAX_LOAD_PERCENT = 97.0`
admission ceiling. No tester, compile, build-check, or smoke process was started.

## New throughput observation

The farm DB reported eight active work items, but the same read-only snapshot
found live factory tester processes and terminal reservations only on T4, T5,
T6, and T7. Those four live rows include the diverse Q03 market-neutral basket
`QM5_20220` on `USDCAD/AUDJPY`; it was left undisturbed.

Four other active rows had neither a live tester process nor a reservation in
the snapshot:

| Terminal | EA | Phase | Symbol | DB updated (UTC) |
|---|---|---|---|---|
| T1 | QM5_21507 | Q10_NEWS | XAUUSD.DWX | 2026-08-26 13:55:00 |
| T3 | QM5_11124 | Q09 | SP500.DWX | 2026-08-26 11:48:40 |
| T9 | QM5_10114 | Q10_NEWS | GDAXI.DWX | 2026-08-25 12:34:53 |
| T10 | QM5_10123 | Q10_NEWS | XAUUSD.DWX | 2026-08-26 16:50:49 |

This is recorded as an active-row/process divergence, not as a verdict that the
rows are stale or safely reclaimable. A later unsaturated operator should run
the governed MT5 reconciliation path before treating those four slots as
occupied or available. No repair flag, worker control, terminal control, task
transition, or database mutation was used here.

## Mission disposition

The binding CPU gate was evaluated before selecting or claiming a build task.
No approved card, EA identity, magic row, resolver entry, source, setfile, EX5,
queue row, or verdict was created or changed. This avoids a stranded build claim
while the tester frontier cannot accept its mandatory smoke.

The portfolio gate, portfolio-admission code/state, `T_Live` manifest,
`T_Live`, and AutoTrading were untouched. All pre-existing shared-worktree
changes were preserved.

Machine-readable receipt:
`artifacts/backlog_cpu_stop_active_divergence_20260826T194838Z.json`.
