# FX cointegration QM5_12507 Q02 RAM-capacity stop

Recorded: 2026-09-10T07:18:59.7353019Z (09:18 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `a3bcab4955e9716fbffee1d8e1952ffa9b2d05de`

## Result

No new pair was carded or built. The complete v3 source scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` admits only the two
positive-hedge survivors already represented by `QM5_12532` and `QM5_12533`.
The durable sign-aware reconciliation at
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships, with zero uncovered. Creating another
scan-derived Card or EA would duplicate governed work.

The preferred anchors do not have a Q02 setup blocker:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 `PASS`, Q04 `PASS`, and a
  terminal Q05 `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 `PASS` and a terminal
  Q04 `FAIL`.

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` defect to repair.

## Existing-pair fallback

The concrete non-duplicate fallback remains the OWNER-approved EURUSD/GBPUSD
H1 basket `QM5_12507_pair-coint-z`. The approved Card has R1-R4 `PASS`, the EA
is built, and its basket scope validates as `BASKET_OK`.

Its logical Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` was reread from the canonical farm DB
as `pending`, unclaimed, unheld, attempt zero, and without a verdict. The row
already carries `priority_track=true`; the guarded priority dry-run returned
`already_priority_track`. Appending another Q02 row or rewriting the priority
flag would therefore be duplicate work.

The canonical logical setfile seals `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

## PACER guard

No `.mq5` was generated or edited and no compile enqueue was contemplated. The
existing source was audited read-only using the binding command:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5"
exit 0; ok=true; EA_FRAMEWORK_INPUT_PINNED hit_count=0
```

`validate_symbol_scope.py --ea-label QM5_12507_pair-coint-z --json` returned
`BASKET_OK`, with all four warmed symbols declared by `basket_manifest.json`.

## Binding capacity stop

Five one-second whole-host CPU samples were `63.517008`, `69.010775`,
`65.365456`, `63.401052`, and `64.945179` percent (average `65.247894%`,
maximum `69.010775%`). The explicit 97% CPU ceiling did not bind.

Free physical memory was only 41.866 GiB of 63.120 GiB. The target's governed
`heavy_or_unknown_multisymbol` admission class reserves 44 GiB and requires a
14 GiB post-reservation floor, so normal launch requires 58 GiB free. The RAM
admission gate therefore bound. Four governed `OPT_CENSUS` work items were
active on T3, T6, T7, and T10 while `launch_gate_max.txt` remained `1`.

No enqueue, requeue, priority mutation, dispatch tick, terminal reservation,
or tester launch was performed. The existing authenticated priority Q02 row
remains owned by normal worker claim order after capacity recovers.

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_12507_q02_ram_capacity_stop_20260910T071859Z_board_advisor.json`.

## Safety

- No Strategy Card, EA source, EX5, setfile, basket manifest, registry row, or
  magic row changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- Existing unrelated shared-worktree changes were left untouched and excluded
  from this commit.
