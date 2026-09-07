# Diversity backlog: QM5_34008 collision and tester-ceiling stop

Recorded: 2026-09-07T13:50:46Z (15:50 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `c9706b7c3fb4a16e5059ebb4505ccf3acc164179`

## Outcome

The highest-diversity apparent build-backlog identity is not free work.
`QM5_34008_multicurrency-basket-dispersion-hedger` is an approved,
market-neutral seven-pair FX basket, but its parameterized source and fixed-risk
setfiles are already committed. The farm already contains source-hash-bound
governed compile work item `1c77fcf2-39ef-47f6-a448-5dd1457bce03`, bound to
build task `c97b5cdc-8d55-404e-9ec0-47496d1a75f6` and MQ5 SHA-256
`7203979e4a508dee2a5e041c57538e29b8bb107dbdf0cf0d53b0d76c977266ae`.
The compile row remains pending under
`COMPILE_EA_WORKER_ROLLOUT_PENDING`; it is unclaimed and has no verdict.

Rebuilding the EA or appending another compile row would duplicate governed
work and risk colliding with the existing owner path. No build task or work
item was claimed, rewritten, released, prioritized, or enqueued.

## Binding tester-ceiling observation

During the admission audit, the read-only farm snapshot reached seven active
governed tester rows, exactly the pacer saturation threshold. The production
decision predicate is covered by
`test_codex_fleet_pacer_tester_drain_cap.py::test_pacer_tester_drain_saturated_at_threshold`:
an active count of seven is saturated.

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T2 | Q10_NEWS | QM5_11167 | XAUUSD.DWX | `f625d9aa-da34-44bb-aa9f-0eda284f3f32` |
| T10 | Q04 | QM5_11377 | USDJPY.DWX | `4bfc0c7d-797e-42c0-808a-13e396ac9648` |
| T1 | OPT_CENSUS | QM5_41324 | USDJPY.DWX | `269d3d80-00a2-5de5-bbb5-d02d0114bd60` |
| T4 | Q04 | QM5_41102 | XTIUSD.DWX | `cae8cc86-589d-4981-8e51-825863426563` |
| T6 | OPT_CENSUS | QM5_41345 | XAUUSD.DWX | `c9c32cc7-a630-5228-b86f-cfc2d235b267` |
| T8 | OPT_CENSUS | QM5_41347 | XAUUSD.DWX | `32357e50-afd6-577d-b381-f6aeaa69e003` |
| T9 | OPT_CENSUS | QM5_41305 | XTIUSD.DWX | `2003311e-5698-5798-8b08-fdc04d3fa076` |

A concurrent five-sample whole-host CPU window measured `75.591778%`,
`67.167260%`, `73.535110%`, `84.986866%`, and `82.543008%`; average CPU was
`76.764805%` and maximum CPU was `84.986866%`. CPU percentage was below the
separate 97% guard, but the seven-active-row tester ceiling independently
bound. The active count later began draining; this wake did not reverse the
already-reached stop decision and start new work behind that race.

Machine-readable evidence is in
`artifacts/diversity_backlog_qm5_34008_collision_cpu_stop_20260907T1350Z.json`.

## PACER guard and safety boundary

No generated MQ5 was written or edited in this wake, so the post-write
`audit_framework_input_pins.py --check-source` boundary was not entered. No
compile command, smoke, backtest, Q02 enqueue, dispatch tick, terminal control,
or process control was run.

No Strategy Card, EA source, EX5, SPEC, setfile, basket manifest, identity or
magic registry, resolver, farm verdict, portfolio gate, `T_Live` manifest,
deploy manifest, live terminal, or AutoTrading state was changed. Existing
unrelated shared-worktree changes were preserved and excluded from this commit.

## Continuation

Let the existing `QM5_34008` compile row advance through its reviewed worker
path. A later wake should re-read its status and only use canonical
`intake-first-q02` after `COMPILE_OK`, with a fresh CPU/terminal admission
snapshot. It must not enqueue a second compile or first-Q02 row.
