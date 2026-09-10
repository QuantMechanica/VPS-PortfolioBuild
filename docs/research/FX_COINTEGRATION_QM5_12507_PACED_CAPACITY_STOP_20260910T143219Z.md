# FX cointegration QM5_12507 paced-capacity stop

Recorded: 2026-09-10T14:32:19.298Z (16:32 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `603f041f5822fb1eb6f60bf8f3ed52aa1a3b6888`

## Result

No new Strategy Card or EA was created. The durable sign-aware reconciliation
in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships from the frozen scan: 66 covered and zero
uncovered. Creating another scan-derived identity would duplicate governed
work.

The two preferred anchors do not have a current Q02 setup defect:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 `PASS`, Q04 `PASS`, then a
  terminal Q05 `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 `PASS`, then a terminal
  Q04 `FAIL`.

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` blocker.

## Existing-pair fallback

The non-duplicate fallback remains the approved and built EURUSD/GBPUSD H1
basket `QM5_12507_pair-coint-z`. Its sole open logical Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` remains pending, unclaimed, attempt
zero, has no verdict, and already carries `priority_track=true`. No second
enqueue or redundant priority mutation was made.

The runtime-approved card records G0 `APPROVED` and R1-R4 `PASS`. The logical
setfile continues to seal `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

The target-specific basket regression passed:

```text
python -m pytest tools/strategy_farm/tests/test_fx_basket_manifests.py -q -k qm5_12507
1 passed, 46 deselected
```

The full manifest suite currently has one unrelated shared-worktree failure:
46 tests passed, while the concurrently added QM5_41140 setfile lacks the
expected 64-hex `build_hash` header. The QM5_12507 target test is green and no
QM5_41140 file was changed.

## PACER build guard

No `.mq5` was generated or edited and no compile enqueue was contemplated. The
existing fallback source was audited read-only with the binding command:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5
exit 0; ok=true; EA_FRAMEWORK_INPUT_PINNED hit_count=0
```

## Binding paced-capacity stop

Five one-second whole-host CPU samples were `87.850%`, `84.671%`, `82.377%`,
`78.340%`, and `73.438%` (average `81.335%`, maximum `87.850%`). The explicit
97% CPU ceiling did not fire.

The governed database simultaneously held three active factory claims on T1,
T5, and T6 while `D:/QM/strategy_farm/state/launch_gate_max.txt` was `1`. Free
physical memory was `47.97 GiB`, below the `58 GiB` admission requirement for
this four-symbol heavy/unknown multisymbol basket.

No dispatch tick, tester launch, terminal reservation, Q02 enqueue/requeue,
priority mutation, source change, or compile followed. The existing priority
Q02 row remains available to the resident worker after the serialized-lane and
RAM gates recover.

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_12507_paced_capacity_stop_20260910T143219Z_board_advisor.json`.

## Safety

- No Strategy Card, EA source, EX5, setfile, basket manifest, registry row, or
  magic row changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- Existing unrelated shared-worktree changes were preserved and excluded from
  this commit.
