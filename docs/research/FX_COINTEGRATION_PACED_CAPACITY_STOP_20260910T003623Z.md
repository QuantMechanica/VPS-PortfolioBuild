# FX cointegration: exhausted frontier and paced-capacity stop

Recorded: 2026-09-10T00:36:23Z

Branch: `agents/board-advisor`

## Result

No new pair was carded or built. The durable sign-aware reconciliation in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships from the frozen scan: 66 covered, zero
uncovered. Creating another scan-derived identity would duplicate governed
work.

The two preferred anchors are not blocked at Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 `PASS`, Q04 `PASS`, and a
  terminal Q05 `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 `PASS` and a terminal
  Q04 `FAIL`.

Neither has a current Q02 `ONINIT` or `NO_HISTORY` defect to repair.

## Existing-pair fallback

The non-duplicate fallback remains the approved and built EURUSD/GBPUSD H1
basket `QM5_12507_pair-coint-z`. Its sole logical Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` is pending, unclaimed, attempt zero,
and already `priority_track=true`. The canonical priority dry-run returned
`already_priority_track=true`; no second enqueue or redundant priority write
was made.

The existing package retains a compiled `.ex5`, its basket manifest, and the
logical backtest setfile. The setfile seals `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

Although no source was generated in this run and therefore no compile enqueue
was contemplated, the PACER source audit was run read-only against the fallback:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5
exit 0; ok=true; EA_FRAMEWORK_INPUT_PINNED hit_count=0
```

## Capacity stop

At the observation point, the governed database contained five active claims
on T5, T7, T8, T9, and T10 while
`D:/QM/strategy_farm/state/launch_gate_max.txt` was `1`. The paced launch
capacity was therefore already occupied five times over. Five whole-host CPU
samples averaged `68.996744%` and peaked at `71.305846%`, below the separate
97% hard CPU threshold; available physical memory was 38.598 GiB.

The stop is the paced launch-capacity guard, not a claim that the 97% CPU
threshold fired. No dispatch tick, tester launch, terminal reservation, Q02
enqueue, requeue, or priority mutation followed. The already-priority fallback
remains worker-owned.

Machine-readable receipt:
`artifacts/fx_cointegration_paced_capacity_stop_20260910T003623Z_board_advisor.json`.

## Safety

- No Strategy Card, EA source, EX5, setfile, basket manifest, registry row, or
  magic row changed.
- No portfolio-admission, portfolio-KPI, or Q08-contribution surface changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- Existing unrelated shared-worktree changes were left untouched and excluded
  from this commit.
