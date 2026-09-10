# FX cointegration QM5_12507 Q02 RAM-capacity stop

Recorded: 2026-09-10T02:17:42.302Z (04:17 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `ef53614e354a75269111886f527d336f1ea262aa`

## Result

No new pair was carded or built. The durable sign-aware reconciliation at
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships in the frozen scan, with zero uncovered.
Creating another scan-derived Card or EA would duplicate governed work.

The preferred anchors do not have a Q02 setup blocker:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 `PASS`, Q04 `PASS`, and a
  terminal Q05 `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 `PASS` and a terminal
  Q04 `FAIL`.

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` defect to repair.

## Existing-pair fallback

The concrete non-duplicate fallback remains the approved and built
EURUSD/GBPUSD H1 basket `QM5_12507_pair-coint-z`. Its logical Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` was reread from the canonical farm DB
as `pending`, unclaimed, unheld, attempt zero, and without a verdict. The
payload remains `priority_track=true`; the guarded priority dry-run returned
`already_priority_track`. Appending another row or rewriting the same priority
flag would therefore be duplicate work.

The package has a compiled `.ex5`, a basket manifest, and its canonical logical
backtest setfile. The setfile seals `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

## PACER guard

No `.mq5` was generated or edited and no compile enqueue was contemplated. The
existing source was nevertheless audited read-only using the binding command:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5"
exit 0; ok=true; EA_FRAMEWORK_INPUT_PINNED hit_count=0
```

`validate_symbol_scope.py --ea QM5_12507_pair-coint-z --json` returned
`BASKET_OK`, with all four warmed symbols declared by
`basket_manifest.json`.

## Binding capacity stop

Two five-sample whole-host CPU windows were below the explicit 97% ceiling.
The final window was `77.552888`, `75.832381`, `79.592091`, `79.992692`, and
`79.989971` percent (average `78.592005%`, maximum `79.992692%`). The CPU stop
did not bind.

Free physical memory was only 43.941 GiB of 63.120 GiB. The target's governed
`heavy_or_unknown_multisymbol` admission class reserves 44 GiB and requires a
14 GiB post-reservation floor, so normal launch requires 58 GiB free. The RAM
admission gate therefore bound. Three governed `OPT_CENSUS` work items were
also active on T2, T3, and T7; `launch_gate_max.txt` remained `1`.

No enqueue, requeue, priority mutation, dispatch tick, terminal reservation,
or tester launch was performed. The existing authenticated priority Q02 row
remains owned by normal worker claim order after capacity recovers.

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_12507_q02_ram_capacity_stop_20260910T021742Z_board_advisor.json`.

## Safety

- No Strategy Card, EA source, EX5, setfile, basket manifest, registry row, or
  magic row changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- Existing unrelated shared-worktree changes were left untouched and excluded
  from this commit.
