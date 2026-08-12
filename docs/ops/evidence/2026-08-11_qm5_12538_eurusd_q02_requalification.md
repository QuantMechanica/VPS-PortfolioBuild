# QM5_12538 EURUSD D1 Q02 Current-Binary Requalification

Date: 2026-08-11 (Europe/Berlin)

Branch: `agents/board-advisor`

Repository head at enqueue: `55d43b90003a987e2559e87b5e61e8e4556ace48`

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
`EURUSD.DWX` route. The current-binary performance repair and its strict build
evidence are recorded in
`docs/ops/evidence/2026-08-11_qm5_12538_fx_q02_perf_recovery.md`.

The approved card expects 18 trades/year/symbol and uses fixed mechanical
McGinley, SuperTrend, Vortex, ADX, and ATR rules. It contains no ML, grid,
martingale, averaging-down, or PnL-adaptive mechanics. No card, parameter,
indicator, risk rule, or market-universe change was made in this handoff.

## Preserved infrastructure evidence

The exact predecessor is work item
`31e65c62-2721-432d-8ad0-b59989ffa688`. It remains terminal `INFRA_FAIL` and
preserves its dispatch preflight evidence at:

`D:/QM/reports/work_items/31e65c62-2721-432d-8ad0-b59989ffa688/QM5_12538/Q02/preflight_failure.json`

That evidence records a staged-EX5 source-hash mismatch: the current repaired
EX5 SHA-256 was
`0157749c0fc7e8ead324238468b2489b45b641f32e5a2b24be25dff300f4cd20`,
while the predecessor payload expected the superseded binary SHA-256
`d6bdb066e83c28b6d40d273731b04044fa3cc35093742e7c6591ad7533d1825f`.
This is infrastructure evidence, not an economic verdict.

The requalification is bound to the repaired artifacts:

| Binding | Value |
|---|---|
| EX5 SHA-256 | `0157749c0fc7e8ead324238468b2489b45b641f32e5a2b24be25dff300f4cd20` |
| MQ5 SHA-256 | `061a979cb6fc1ac5f681b7faeb82c686fab29643e304ffd4d44f4d280a8bcaf2` |
| EURUSD setfile SHA-256 | `4cf46cf7200dcc5c704e9ded7140bb002e077f7dbb7b63409eb822cd3af2534e` |
| Execution identity | `EURUSD.DWX`, D1, `QM\\QM5_12538_nnfx-canonical-stack2-st-vortex` |
| Slot / magic | `0` / `125380000`, active |
| Backtest risk | `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` |

## Capacity and enqueue

The immediate path-anchored capacity sample at
`2026-08-11T20:50:30+00:00` found two factory terminals (`T1` and `T8`), below
the binding ceiling of seven. `T_Live` and the FTMO terminal were observed only
to exclude them from the factory count and were not controlled.

The supported hash-bound command was:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest `
  --ea QM5_12538 --phase Q02 `
  --from-work-item-id 31e65c62-2721-432d-8ad0-b59989ffa688 `
  --append-only-rerun-of 31e65c62-2721-432d-8ad0-b59989ffa688 `
  --rerun-reason "OWNER 2026-08-11 forex-book fallback: frozen 66-pair cointegration frontier is exhausted and anchors are beyond Q02; preserve the EURUSD staged-EX5 hash-mismatch infrastructure evidence and append exactly one current-binary Q02 requalification after the closed-bar performance repair; no strategy mechanics changed." `
  --expected-current-ex5-sha256 0157749c0fc7e8ead324238468b2489b45b641f32e5a2b24be25dff300f4cd20
```

It created exactly one successor:

- work item: `0c41b34a-a73c-4d36-b1ac-1b725f257478`;
- phase / symbol: Q02 / `EURUSD.DWX`;
- created at: `2026-08-11T20:50:34+00:00`;
- verification readback: `active`, attempt 0, claimed by `T5`, no verdict; and
- exact open-row count for the EA / phase / symbol identity: one.

The payload records `append_only_rerun=true`, preserves the predecessor, and
binds the current EX5, MQ5, setfile, symbol, period, expert, and fixed-risk
values. A post-enqueue target-only sweep selected zero rows, and SQLite
`PRAGMA quick_check` returned `ok`. No manual dispatch tick was run; the normal
fleet claimed the pending row.

## Safety

- No card, EA source, binary, setfile, registry, or magic row changed in this
  handoff.
- No manual tester, smoke run, terminal start/stop, reservation, or process
  control was invoked.
- No portfolio-admission, portfolio KPI, or Q08-contribution path changed.
- No `T_Live` file, manifest, process, live setfile, or AutoTrading state
  changed.
- Pre-existing unrelated worktree changes were preserved and excluded from the
  branch commit.
