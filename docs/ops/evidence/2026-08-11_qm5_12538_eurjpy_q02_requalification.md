# QM5_12538 EURJPY D1 Q02 Current-Binary Requalification

Date: 2026-08-11 (Europe/Berlin)

Branch: `agents/board-advisor`

Repository head at enqueue: `ceb93147596d5b90836935bf23287fd6fd385d9e`

Status: exactly one append-only current-binary Q02 successor was created and
claimed by the normal paced fleet; no Q02 verdict is asserted

## Selection

The frozen 66-pair FX cointegration frontier has no unbuilt relationship left.
The two original anchors also do not need Q02 repair:

- `QM5_12532` has logical-basket Q02 PASS and Q04 PASS, followed by Q05 FAIL.
- `QM5_12533` has logical-basket Q02 PASS, followed by Q04 FAIL.

Creating another scan-derived card or basket would duplicate governed work.
The mission fallback therefore advances the existing approved structural D1 FX
card `QM5_12538_nnfx-canonical-stack2-st-vortex` on its registered
`EURJPY.DWX` route. The preceding repair is recorded in
`docs/ops/evidence/2026-08-11_qm5_12538_fx_q02_perf_recovery.md`.

## Preserved infrastructure evidence

The exact predecessor is work item
`395519bb-decf-424c-9478-ccda2bf6c5ba`. It remains terminal `INFRA_FAIL` and
preserves its summary at:

`D:/QM/reports/work_items/395519bb-decf-424c-9478-ccda2bf6c5ba/QM5_12538/20260807_111114/summary.json`

That summary records three incomplete attempts with `BARS_ZERO` and
`INCOMPLETE_RUNS`, `oninit_failure_detected=false`, and the superseded EX5
SHA-256
`d6bdb066e83c28b6d40d273731b04044fa3cc35093742e7c6591ad7533d1825f`.
It is infrastructure evidence, not an economic verdict.

The requalification is bound to the repaired artifacts:

| Binding | Value |
|---|---|
| EX5 SHA-256 | `0157749c0fc7e8ead324238468b2489b45b641f32e5a2b24be25dff300f4cd20` |
| MQ5 SHA-256 | `061a979cb6fc1ac5f681b7faeb82c686fab29643e304ffd4d44f4d280a8bcaf2` |
| EURJPY setfile SHA-256 | `4b4ad3559d41be24a341e361262decf80de7ed03aa2ec5a50d390d770e238e96` |
| Execution identity | `EURJPY.DWX`, D1, `QM\\QM5_12538_nnfx-canonical-stack2-st-vortex` |
| Slot / magic | `7` / `125380007`, active |
| Backtest risk | `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` |

## Capacity and enqueue

The immediate path-anchored capacity sample at
`2026-08-11T19:49:29+00:00` found three factory terminals (`T1`, `T4`, and
`T9`) against the binding ceiling of seven, with no duplicate workers or
orphaned terminal processes. The host remained busy (five-sample total-CPU
average `84.6%`), so no manual smoke, tester, dispatch tick, or terminal
reservation was started. Only the exact append-only queue handoff was applied;
normal paced workers retained execution control.

The supported hash-bound command was:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest `
  --ea QM5_12538 --phase Q02 `
  --from-work-item-id 395519bb-decf-424c-9478-ccda2bf6c5ba `
  --append-only-rerun-of 395519bb-decf-424c-9478-ccda2bf6c5ba `
  --rerun-reason "OWNER 2026-08-11 forex-book fallback: frozen 66-pair cointegration frontier is exhausted and anchors are beyond Q02; preserve the EURJPY D1 infrastructure-only BARS_ZERO/INCOMPLETE_RUNS evidence and append exactly one current-binary Q02 requalification after the closed-bar performance repair; no strategy mechanics changed." `
  --expected-current-ex5-sha256 0157749c0fc7e8ead324238468b2489b45b641f32e5a2b24be25dff300f4cd20
```

It created exactly one successor:

- work item: `8666b05c-d0f0-455a-9d51-8d3d69f7a3b6`;
- phase / symbol: Q02 / `EURJPY.DWX`;
- immediate readback: `active`, attempt 0, claimed by `T5`, no verdict; and
- exact open-row count for the EA / phase / symbol / setfile identity: one.

The new payload records `append_only_rerun=true`, preserves the predecessor,
and carries the current EX5, MQ5, setfile, symbol, period, and expert bindings.
SQLite `PRAGMA quick_check` returned `ok`. The fleet claim occurred without a
manual dispatch from this mission.

## Safety

- No card, EA source, binary, setfile, registry, or magic row changed in this
  handoff.
- No tester, smoke run, dispatch tick, terminal start/stop, or process control
  was invoked by this mission.
- No portfolio-admission, portfolio KPI, or Q08-contribution path changed.
- No `T_Live` file, manifest, process, live setfile, or AutoTrading state
  changed.
- Pre-existing unrelated worktree changes were preserved and excluded from the
  branch commit.
